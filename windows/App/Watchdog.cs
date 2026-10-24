// A second copy of the exe (--watchdog) that relaunches the app and gets the desktop back after the fail-safe.
using System.Diagnostics;
using BlackBreak.Core;

namespace BlackBreak;

internal static class Watchdog
{
    const string WatchdogMutex = "Local\\BlackBreak.Watchdog", QuitEvent = "Local\\BlackBreak.Quit";

    public static int Run(string exePath, int appPid, string dir)
    {
        using var mutex = new Mutex(true, WatchdogMutex, out var first);
        if (!first) return 0;
        using var quit = new EventWaitHandle(false, EventResetMode.ManualReset, QuitEvent);
        var app = Attach(appPid);
        while (!quit.WaitOne(1000))
        {
            Rescue(dir);
            if (app is { HasExited: false }) continue;
            if (quit.WaitOne(1000)) break;
            try { app = Process.Start(new ProcessStartInfo(exePath) { UseShellExecute = false }); }
            catch { app = null; }
        }
        return 0;
    }

    public static void EnsureRunning(string exePath)
    {
        if (Mutex.TryOpenExisting(WatchdogMutex, out var m))
        {
            m.Dispose();
            return;
        }
        try { Process.Start(new ProcessStartInfo(exePath, $"--watchdog {Environment.ProcessId}") { UseShellExecute = false }); }
        catch { }
    }

    public static void SignalQuit()
    {
        using var e = new EventWaitHandle(false, EventResetMode.ManualReset, QuitEvent);
        e.Set();
    }

    static Process? Attach(int pid)
    {
        try { return Process.GetProcessById(pid); }
        catch { return null; }
    }

    // The break desktop must never outlive breakStart + 35 s, whatever happened to the app.
    static void Rescue(string dir)
    {
        if (Store.LoadState(dir) is not { BreakStartMs: long start }) return;
        if (Native.UnixNow() > start + Scheduler.FailsafeMs && Native.InputDesktopName() == "BlackBreak")
            Native.SwitchToDefault();
    }
}
