// The break screen: a private Win32 desktop with one popup per monitor (the pixel rest scene on the primary one, black on the others) and a swallowing keyboard hook.
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using BlackBreak.Core;

namespace BlackBreak;

internal sealed unsafe class BreakDesktop : IDisposable
{
    const string ClassName = "BlackBreak.Break", DesktopName = "BlackBreak";
    // The window procedure is static, and only one break is ever shown.
    static BreakDesktop? _cur;
    static List<(RECT rect, bool primary)>? _monitors;

    readonly Action<string>? _log;
    readonly List<nint> _wins = new();
    readonly ManualResetEventSlim _started = new();
    Thread? _thread;
    volatile uint _tid;
    long _endsAt, _failsafeAt, _total;
    nint _desk, _ctl, _primary, _hook, _bg;

    readonly bool _preview; // CI screenshots: draw on the current desktop, no switch and no hook

    public BreakDesktop(Action<string>? log = null, bool preview = false)
    {
        _log = log;
        _preview = preview;
    }

    public bool Visible => _thread is { IsAlive: true };

    public void Show(long endsAtMs, long failsafeAtMs)
    {
        if (Visible) return;
        _endsAt = endsAtMs;
        _total = Math.Max(1, endsAtMs - Native.UnixNow());
        _failsafeAt = failsafeAtMs;
        _started.Reset();
        _thread = new Thread(Run) { IsBackground = true };
        _thread.Start();
        _started.Wait(3000);
    }

    public void Hide()
    {
        var t = _thread;
        if (t is not { IsAlive: true }) return;
        _started.Wait(3000);
        Native.PostThreadMessageW(_tid, Native.WM_QUIT, 0, 0);
        t.Join(3000);
    }

    public void Dispose() => Hide();

    void Run()
    {
        _cur = this;
        _tid = Native.GetCurrentThreadId();
        var orig = Native.GetThreadDesktop(_tid);
        var switched = false;
        try
        {
            if (!_preview)
            {
                _desk = Native.CreateDesktopW(DesktopName, 0, 0, 0, Native.GENERIC_ALL, 0);
                if (_desk == 0 || Native.SetThreadDesktop(_desk) == 0) return;
            }
            Native.RegisterClass(ClassName, (nint)(delegate* unmanaged<nint, uint, nint, nint, nint>)&WndProc,
                _bg = Native.CreateSolidBrush(Native.Rgb(0x0D, 0x0C, 0x0B)));
            _ctl = Native.CreateWindowExW(Native.WS_EX_TOOLWINDOW, ClassName, null, Native.WS_POPUP, 0, 0, 1, 1, 0, 0, Native.Instance, 0);
            BuildWindows();
            switched = !_preview && Native.SwitchDesktop(_desk) != 0;
            if (switched) _log?.Invoke("desktop switched");
            if (!_preview) _hook = Native.SetWindowsHookExW(Native.WH_KEYBOARD_LL, (nint)(delegate* unmanaged<int, nint, nint, nint>)&KeyHook, Native.Instance, 0);
            Native.SetTimer(_ctl, 1, 100, 0); // the scene moves, so it is redrawn ten times a second
            Native.SetTimer(_ctl, 2, (uint)Math.Clamp(_failsafeAt - Native.UnixNow(), 1, int.MaxValue), 0); // fail-safe, independent of the end time
            _started.Set();
            MSG m;
            while (Native.GetMessageW(&m, 0, 0, 0) > 0)
            {
                Native.TranslateMessage(&m);
                Native.DispatchMessageW(&m);
            }
        }
        finally
        {
            _started.Set();
            if (_hook != 0) Native.UnhookWindowsHookEx(_hook);
            if (switched && Native.SwitchToDefault()) _log?.Invoke("desktop restored");
            foreach (var w in _wins) Native.DestroyWindow(w);
            _wins.Clear();
            if (_ctl != 0) Native.DestroyWindow(_ctl);
            if (_bg != 0) Native.DeleteObject(_bg);
            if (_desk != 0)
            {
                Native.SetThreadDesktop(orig);
                Native.CloseDesktop(_desk);
            }
            _hook = _ctl = _primary = _desk = _bg = 0;
        }
    }

    void BuildWindows()
    {
        foreach (var w in _wins) Native.DestroyWindow(w);
        _wins.Clear();
        _primary = 0;
        _monitors = new();
        Native.EnumDisplayMonitors(0, null, (nint)(delegate* unmanaged<nint, nint, RECT*, nint, int>)&MonitorEnum, 0);
        var mons = _monitors;
        _monitors = null;
        if (mons.Count == 0) // no monitor list: cover the primary screen
            mons.Add((new RECT { Right = Native.GetSystemMetrics(Native.SM_CXSCREEN), Bottom = Native.GetSystemMetrics(Native.SM_CYSCREEN) }, true));
        foreach (var (r, primary) in mons)
        {
            var w = Native.CreateWindowExW(Native.WS_EX_TOPMOST | Native.WS_EX_TOOLWINDOW, ClassName, null,
                Native.WS_POPUP | Native.WS_VISIBLE, r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top, 0, 0, Native.Instance, 0);
            if (w == 0) continue;
            _wins.Add(w);
            Native.SetWindowPos(w, Native.HWND_TOPMOST, 0, 0, 0, 0, Native.SWP_NOSIZE | Native.SWP_NOMOVE | Native.SWP_NOACTIVATE | Native.SWP_SHOWWINDOW);
            if (primary) _primary = w;
        }
        if (_primary == 0 && _wins.Count > 0) _primary = _wins[0];
    }

    void Paint(nint hwnd)
    {
        PAINTSTRUCT ps;
        var dc = Native.BeginPaint(hwnd, &ps);
        RECT r;
        Native.GetClientRect(hwnd, &r);
        if (hwnd == _primary)
        {
            // drawn off screen and copied at once, so the animation does not flicker
            var mem = Native.CreateCompatibleDC(dc);
            var bmp = Native.CreateCompatibleBitmap(dc, r.Right, r.Bottom);
            var old = Native.SelectObject(mem, bmp);
            var left = Math.Max(0, _endsAt - Native.UnixNow());
            var done = _total <= 0 ? 0 : Math.Clamp(1.0 - (double)left / _total, 0, 1);
            PixelArt.Scene(mem, r.Right, r.Bottom, Environment.TickCount64 / 1000.0, Copy.Lines(Locale.Slovak),
                Copy.Seconds(Locale.Slovak, (left + 999) / 1000), done);
            Native.BitBlt(dc, 0, 0, r.Right, r.Bottom, mem, 0, 0, Native.SRCCOPY);
            Native.SelectObject(mem, old);
            Native.DeleteObject(bmp);
            Native.DeleteDC(mem);
        }
        else
        {
            Native.FillRect(dc, &r, _bg);
        }
        Native.EndPaint(hwnd, &ps);
    }

    void OnTimer(nint id)
    {
        var now = Native.UnixNow();
        if (id == 2 || now >= _endsAt || now >= _failsafeAt)
        {
            Native.PostQuitMessage(0);
            return;
        }
        // Ctrl+Alt+Del then Cancel returns to the default desktop: take the input back.
        if (!_preview && Native.InputDesktopName() is { } name && name != DesktopName)
            Native.SwitchDesktop(_desk);
        if (_primary != 0) Native.InvalidateRect(_primary, null, 0);
    }

    [UnmanagedCallersOnly]
    static nint WndProc(nint hwnd, uint msg, nint w, nint l)
    {
        try
        {
            var self = _cur;
            if (self != null)
                switch (msg)
                {
                    case Native.WM_PAINT: self.Paint(hwnd); return 0;
                    case Native.WM_ERASEBKGND: return 1;
                    case Native.WM_TIMER when hwnd == self._ctl: self.OnTimer(w); return 0;
                    case Native.WM_DISPLAYCHANGE when hwnd == self._ctl:
                        self.BuildWindows();
                        return 0;
                    case Native.WM_CLOSE: return 0;
                    case Native.WM_SYSCOMMAND: return 0;
                }
        }
        catch { }
        return Native.DefWindowProcW(hwnd, msg, w, l);
    }

    [UnmanagedCallersOnly]
    static int MonitorEnum(nint mon, nint dc, RECT* rect, nint data)
    {
        var mi = new MONITORINFO { CbSize = (uint)sizeof(MONITORINFO) };
        var primary = Native.GetMonitorInfoW(mon, &mi) != 0 && (mi.Flags & 1) != 0;
        _monitors?.Add((*rect, primary));
        return 1;
    }

    [UnmanagedCallersOnly]
    static nint KeyHook(int code, nint w, nint l) => code >= 0 ? 1 : Native.CallNextHookEx(0, code, w, l);
}
