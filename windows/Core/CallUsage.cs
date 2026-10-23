namespace BlackBreak.Core;

public static class CallUsage
{
    /// True when any entry is currently active (start > 0, stop == 0) and is not selfExe.
    public static bool InUse(IEnumerable<(string app, long start, long stop)> entries, string selfExe) =>
        entries.Any(e => e.start > 0 && e.stop == 0
            && !string.Equals(e.app, selfExe, StringComparison.OrdinalIgnoreCase));
}
