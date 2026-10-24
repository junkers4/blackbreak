namespace BlackBreak.Core;

/// What the tray menu shows and allows. There is no item that stops a break or quits the app.
public sealed record MenuState(string Status, bool PauseEnabled, bool CancelEnabled, bool SettingsEnabled,
    bool CallExemption, bool ExemptMic, bool ExemptCamera);

public static class Menu
{
    public static readonly (string label, int minutes)[] Pauses =
        [("Pause 30 min", 30), ("Pause 1 hour", 60), ("Pause 2 hours", 120), ("Pause 3 hours", 180)];

    /// <param name="clock">formats a time as HH:mm in local time</param>
    public static MenuState For(Scheduler s, Settings settings, Func<long, string> clock)
    {
        var status = s.Phase switch
        {
            Phase.Paused => $"Paused until {clock(s.PauseEndsAt!.Value)}",
            Phase.Break => "Break in progress",
            _ => $"Next break at {clock(s.NextBreakAt!.Value)}",
        };
        // The rule is the core's (bb_menu): settings only outside the warning and the break.
        var bits = s.MenuBits;
        return new MenuState(status, (bits & Scheduler.MenuPause) != 0, (bits & Scheduler.MenuCancel) != 0,
            (bits & Scheduler.MenuSettings) != 0,
            settings.CallExemption, settings.ExemptMic, settings.ExemptCamera);
    }
}
