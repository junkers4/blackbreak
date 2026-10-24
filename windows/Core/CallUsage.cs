namespace BlackBreak.Core;

public static class CallUsage
{
    /// True when any entry is currently active (start > 0, stop == 0) and is not selfExe.
    public static bool InUse(IEnumerable<(string app, long start, long stop)> entries, string selfExe) =>
        entries.Any(e => e.start > 0 && e.stop == 0
            && !string.Equals(e.app, selfExe, StringComparison.OrdinalIgnoreCase));

    /// The call rule with the settings (the core's bb_in_call): false when the exemption is off; otherwise the microphone
    /// counts when exemptMic is on and the camera when exemptCamera is on.
    public static bool InCall(Settings s, IEnumerable<(string app, long start, long stop)> mic,
        IEnumerable<(string app, long start, long stop)> camera, string selfExe) =>
        CoreNative.bb_in_call((s.CallExemption ? 1 : 0) | (s.ExemptMic ? 2 : 0) | (s.ExemptCamera ? 4 : 0),
            InUse(mic, selfExe) ? 1 : 0, InUse(camera, selfExe) ? 1 : 0) == 1;
}
