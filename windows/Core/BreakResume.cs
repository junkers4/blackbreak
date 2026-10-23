namespace BlackBreak.Core;

public static class BreakResume
{
    /// End of the break to show now, or null. Callers also arm a fail-safe at breakStart + Scheduler.FailsafeMs.
    public static long? EndsAt(long? breakStartMs, long? savedBootMs, long nowMs, long bootMs)
    {
        if (breakStartMs is not long start || savedBootMs is not long saved) return null;
        if (Math.Abs(saved - bootMs) > 120_000) return null;
        var end = start + Scheduler.BreakMs;
        return nowMs >= end ? null : end;
    }
}
