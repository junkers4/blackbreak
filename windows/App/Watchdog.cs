// A second copy of the exe (--watchdog) that relaunches the app and gets the desktop back after the fail-safe.
using System.Diagnostics;
using BlackBreak.Core;

namespace BlackBreak;

internal static class Watchdog
{
    const string WatchdogMutex = "Local\\BlackBreak.Watchdog";

    public static int Run(string exePath, int appPid, string dir)
    {
        using var mutex = new Mutex(true, WatchdogMutex, out var first);
        if (!first) return 0;
        var app = Attach(appPid);
        // There is no quit: the two copies keep each other alive until the session ends.
        while (true)
        {
            Thread.Sleep(1000);
            Rescue(dir);
            if (app is { HasExited: false }) continue;
            Thread.Sleep(1000);
            try { app = Process.Start(new ProcessStartInfo(exePath) { UseShellExecute = false }); }
            catch { app = null; }
        }
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
