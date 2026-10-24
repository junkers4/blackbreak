// Entry point: tray app, 1 s tick, the scheduler and the break screen.
using System.Runtime.InteropServices;
using Microsoft.Win32;
using BlackBreak.Core;

namespace BlackBreak;

internal static unsafe class Program
{
    const string ClassName = "BlackBreak.Main";

    static readonly string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "BlackBreak");
    static string _exe = "";
    static Scheduler _sch = null!;
    static Settings _settings = new(), _snapshot = new();
    static BreakDesktop _desk = null!;
    static Notice _notice = null!;
    static nint _hwnd;
    static Phase _phase = Phase.Work;
    static double _scale = 1;
    static bool _smoke;
    static string? _smokeLog;
    static long _smokeEnd, _bootMs;
    static uint _taskbarCreated;

    static int Main(string[] args)
    {
        _exe = Environment.ProcessPath ?? "";
        if (args.Length >= 2 && args[0] == "--watchdog")
            return Watchdog.Run(_exe, int.TryParse(args[1], out var pid) ? pid : 0, Dir);
        // CI helpers: stand in for a crashed app that holds the break desktop, and report the input desktop.
        if (args.Length >= 1 && args[0] == "--test-hold-desktop")
        {
            var d = Native.CreateDesktopW("BlackBreak", 0, 0, 0, Native.GENERIC_ALL, 0);
            Native.SwitchDesktop(d);
            Thread.Sleep(Timeout.Infinite);
        }
        if (args.Length >= 2 && args[0] == "--test-input-desktop")
        {
            File.WriteAllText(args[1], Native.InputDesktopName() ?? "(none)");
            return 0;
        }
        if (args.Length >= 2 && args[0] == "--smoke")
        {
            _smoke = true;
            _smokeEnd = Native.UnixNow() + long.Parse(args[1]) * 1000;
            _smokeLog = args.Length > 2 ? args[2] : null;
        }
        using var mutex = _smoke ? null : new Mutex(true, "Local\\BlackBreak.App", out _);
        if (!_smoke && !mutex!.WaitOne(0)) return 0; // another copy is running
        // "1" means 60x; any other number is the factor itself.
        var fast = Environment.GetEnvironmentVariable("BLACKBREAK_DEBUG_FAST");
        if (fast == "1") _scale = 60;
        else if (double.TryParse(fast, System.Globalization.CultureInfo.InvariantCulture, out var f) && f > 1) _scale = f;

        if (!_smoke) SetAutostart();
        _settings = _snapshot = Store.LoadSettings(Dir);
        var now = Native.UnixNow();
        _bootMs = now - Environment.TickCount64;
        _sch = new Scheduler(now, _scale, lastPauseDay: _settings.LastPauseDay);
        _notice = new Notice();
        _desk = new BreakDesktop(_smoke ? Log : null);

        Native.RegisterClass(ClassName, (nint)(delegate* unmanaged<nint, uint, nint, nint, nint>)&WndProc, 0);
        _hwnd = Native.CreateWindowExW(Native.WS_EX_TOOLWINDOW, ClassName, "BlackBreak", Native.WS_POPUP, 0, 0, 1, 1, 0, 0, Native.Instance, 0);
        _taskbarCreated = Native.RegisterWindowMessageW("TaskbarCreated");
        if (!_smoke) Tray.Add(_hwnd);

        // Relaunched in the middle of a break: show what is left of it, never past the fail-safe.
        var state = Store.LoadState(Dir);
        if (BreakResume.EndsAt(state?.BreakStartMs, state is null ? null : state.BootMs, now, _bootMs) is long resumeEnd)
            _desk.Show(resumeEnd, state!.BreakStartMs!.Value + Scheduler.FailsafeMs);

        Native.SetTimer(_hwnd, 1, _smoke && _scale > 1 ? 50u : 1000u, 0);
        Tick();
        MSG m;
        while (Native.GetMessageW(&m, 0, 0, 0) > 0)
        {
            Native.TranslateMessage(&m);
            Native.DispatchMessageW(&m);
        }
        _desk.Hide();
        _notice.Dispose();
        return 0;
    }

    static void Log(string line)
    {
        Console.WriteLine(line);
        if (_smokeLog != null)
            try { File.AppendAllText(_smokeLog, line + "\n"); }
            catch { }
    }

    static void SetAutostart()
    {
        try
        {
            using var run = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
            run.SetValue("BlackBreak", $"\"{_exe}\"");
        }
        catch { }
    }

    static unsafe long IdleMs()
    {
        var li = new LASTINPUTINFO { CbSize = (uint)sizeof(LASTINPUTINFO) };
        return Native.GetLastInputInfo(&li) == 0 ? 0 : unchecked((uint)Environment.TickCount - li.Time);
    }

    static void Tick()
    {
        if (!_smoke) Watchdog.EnsureRunning(_exe);
        var now = Native.UnixNow();
        if (_smoke && now >= _smokeEnd)
        {
            Quit();
            return;
        }
        if (_phase == Phase.Work) _snapshot = _settings; // settings take effect in the next work interval
        // The call state matters from 60 s before the warning is due, and while a call holds the break.
        var inCall = false;
        if (_phase == Phase.Work && _sch.NextBreakAt is long next && now >= next - Scheduler.WarnMs - 60_000)
            inCall = CallDetector.InCall(_snapshot);
        var phase = _sch.Update(now, _smoke ? 0 : IdleMs(), inCall);
        if (phase == _phase) return;
        _phase = phase;
        switch (phase)
        {
            case Phase.Warning:
                Log("phase warning");
                _notice.Show("Break in 10 s");
                break;
            case Phase.Break:
                Log("phase break");
                var ends = _sch.BreakEndsAt!.Value;
                var start = ends - (long)Math.Round(Scheduler.BreakMs / _scale);
                Store.Save(Dir, new BreakState(start, _bootMs));
                _notice.Hide();
                _desk.Show(ends, start + Scheduler.FailsafeMs);
                break;
            default:
                _notice.Hide();
                _desk.Hide();
                if (Store.LoadState(Dir) is { BreakStartMs: not null }) Store.Save(Dir, new BreakState(null, _bootMs));
                Log(phase == Phase.Paused ? "phase paused" : "phase work");
                break;
        }
    }

    static void Quit()
    {
        Watchdog.SignalQuit();
        _desk.Hide();
        Tray.Remove(_hwnd);
        Native.PostQuitMessage(0);
    }

    static string Status() => _sch.Phase switch
    {
        Phase.Paused => $"Paused until {Clock(_sch.PauseEndsAt!.Value)}",
        Phase.Break => "Break in progress",
        _ => $"Next break at {Clock(_sch.NextBreakAt!.Value)}",
    };

    static string Clock(long ms) => DateTimeOffset.FromUnixTimeMilliseconds(ms).ToLocalTime().ToString("HH:mm");

    static void Menu()
    {
        var locked = _sch.Phase is Phase.Warning or Phase.Break;
        var cmd = Tray.ShowMenu(_hwnd, Status(), _sch.CanPause, _sch.Phase == Phase.Paused, locked, _settings);
        var now = Native.UnixNow();
        switch (cmd)
        {
            case Tray.Pause30: Pause(30, now); break;
            case Tray.Pause60: Pause(60, now); break;
            case Tray.Pause120: Pause(120, now); break;
            case Tray.Pause180: Pause(180, now); break;
            case Tray.CancelPause: _sch.CancelPause(now); break;
            case Tray.CallExemption: SaveSettings(_settings with { CallExemption = !_settings.CallExemption }); break;
            case Tray.Mic: SaveSettings(_settings with { ExemptMic = !_settings.ExemptMic }); break;
            case Tray.Camera: SaveSettings(_settings with { ExemptCamera = !_settings.ExemptCamera }); break;
            case Tray.Quit: if (!locked) Quit(); break;
        }
        if (cmd != 0) Tick();
    }

    static void Pause(int minutes, long now)
    {
        if (_sch.Pause(minutes * 60_000L, now))
            SaveSettings(_settings with { LastPauseDay = _sch.LastPauseDay });
    }

    static void SaveSettings(Settings s)
    {
        _settings = s;
        try { Store.Save(Dir, s); }
        catch { }
    }

    [UnmanagedCallersOnly]
    static nint WndProc(nint hwnd, uint msg, nint w, nint l)
    {
        try
        {
            if (hwnd == _hwnd)
            {
                if (msg == Native.WM_TIMER) { Tick(); return 0; }
                if (msg == Tray.Callback && ((uint)l is Native.WM_RBUTTONUP or Native.WM_LBUTTONUP)) { Menu(); return 0; }
                if (msg == Native.WM_POWERBROADCAST && w is 0x12 or 0x7) { Tick(); return 1; } // resumed from sleep: tick before anything is painted
                if (msg == _taskbarCreated && !_smoke) { Tray.Add(hwnd); return 0; }
            }
        }
        catch { }
        return Native.DefWindowProcW(hwnd, msg, w, l);
    }
}
