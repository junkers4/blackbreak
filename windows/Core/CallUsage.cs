namespace BlackBreak.Core;

public static class CallUsage
{
    /// True when any entry is currently active (start > 0, stop == 0) and is not selfExe.
    public static bool InUse(IEnumerable<(string app, long start, long stop)> entries, string selfExe) =>
        entries.Any(e => e.start > 0 && e.stop == 0
            && !string.Equals(e.app, selfExe, StringComparison.OrdinalIgnoreCase));

    /// The call rule with the settings: false when the exemption is off; otherwise the microphone
    /// counts when exemptMic is on and the camera when exemptCamera is on.
    public static bool InCall(Settings s, IEnumerable<(string app, long start, long stop)> mic,
        IEnumerable<(string app, long start, long stop)> camera, string selfExe) =>
        s.CallExemption && ((s.ExemptMic && InUse(mic, selfExe)) || (s.ExemptCamera && InUse(camera, selfExe)));
}
