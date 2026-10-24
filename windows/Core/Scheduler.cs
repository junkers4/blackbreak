// The break schedule: a handle on the x86-64 assembler core (core/x86_64/core.S).
// The rules live there; this file only carries values across.
using System.Runtime.InteropServices;

namespace BlackBreak.Core;

public enum Phase { Work, Warning, Break, Paused }

internal static unsafe partial class CoreNative
{
    // Linked into BlackBreak.exe (DirectPInvoke); a shared library in the tests.
    const string Lib = "blackbreak_core";
    public const long None = long.MinValue;
    public const int StateSize = 144;

    [LibraryImport(Lib)] public static partial void bb_init(void* s, long now, long scaleBits, long lastPauseDay);
    [LibraryImport(Lib)] public static partial void bb_set_tz(void* s, long offsetMs);
    [LibraryImport(Lib)] public static partial long bb_update(void* s, long now, long idleMs, long flags);
    [LibraryImport(Lib)] public static partial long bb_pause(void* s, long durationMs, long now);
    [LibraryImport(Lib)] public static partial long bb_cancel(void* s, long now);
    [LibraryImport(Lib)] public static partial long bb_get(void* s, long which);
    [LibraryImport(Lib)] public static partial long bb_menu(void* s);
    [LibraryImport(Lib)] public static partial long bb_in_call(long settings, long mic, long camera);
    [LibraryImport(Lib)] public static partial long bb_seconds(byte* text, long n, long slovak);
}

public sealed unsafe class Scheduler
{
    public const long WorkMs = 1_200_000, WarnMs = 10_000, BreakMs = 30_000, FailsafeMs = 35_000;
    const long GetPhase = 0, GetCanPause = 1, GetNextBreak = 2, GetBreakEnds = 3, GetWarnEnds = 4,
        GetPauseEnds = 5, GetLastPause = 6;
    public const long MenuPause = 1, MenuCancel = 2, MenuSettings = 4;

    readonly void* _s = NativeMemory.AllocZeroed(CoreNative.StateSize);

    /// <param name="lastPauseDay">local day number of the last pause</param>
    /// <param name="tzOffsetMs">local time minus UTC; day numbers count local days</param>
    public Scheduler(long nowMs, double scale = 1, long? lastPauseDay = null, long tzOffsetMs = 0)
    {
        CoreNative.bb_init(_s, nowMs, BitConverter.DoubleToInt64Bits(scale), lastPauseDay ?? CoreNative.None);
        CoreNative.bb_set_tz(_s, tzOffsetMs);
    }

    ~Scheduler() => NativeMemory.Free(_s);

    long? Value(long which) => CoreNative.bb_get(_s, which) is var v && v != CoreNative.None ? v : null;

    public void SetTimeZone(long offsetMs) => CoreNative.bb_set_tz(_s, offsetMs);
    public Phase Phase => (Phase)CoreNative.bb_get(_s, GetPhase);
    public bool CanPause => CoreNative.bb_get(_s, GetCanPause) == 1;
    public long? NextBreakAt => Value(GetNextBreak);
    public long? BreakEndsAt => Value(GetBreakEnds);
    public long? WarningEndsAt => Value(GetWarnEnds);
    public long? PauseEndsAt => Value(GetPauseEnds);
    public long? LastPauseDay => Value(GetLastPause);
    public long MenuBits => CoreNative.bb_menu(_s);

    public bool Pause(long durationMs, long now) => CoreNative.bb_pause(_s, durationMs, now) == 1;
    public bool CancelPause(long now) => CoreNative.bb_cancel(_s, now) == 1;

    public Phase Update(long now, long idleMs = 0, bool inCall = false, bool inPhoneCall = false) =>
        (Phase)CoreNative.bb_update(_s, now, idleMs, (inCall ? 1 : 0) | (inPhoneCall ? 2 : 0));
}
