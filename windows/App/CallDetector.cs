// Microphone and camera use from the CapabilityAccessManager consent store.
using Microsoft.Win32;
using BlackBreak.Core;

namespace BlackBreak;

internal static class CallDetector
{
    const string Root = @"Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\";

    public static bool InCall(Settings s)
    {
        if (!s.CallExemption) return false;
        var self = (Environment.ProcessPath ?? "").Replace('\\', '#');
        return (s.ExemptMic && InUse("microphone", self)) || (s.ExemptCamera && InUse("webcam", self));
    }

    static bool InUse(string capability, string self)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(Root + capability);
            if (key == null) return false;
            var entries = new List<(string, long, long)>();
            Collect(key, entries);
            using var np = key.OpenSubKey("NonPackaged");
            if (np != null) Collect(np, entries);
            return CallUsage.InUse(entries, self);
        }
        catch { return false; }
    }

    static void Collect(RegistryKey key, List<(string, long, long)> into)
    {
        foreach (var name in key.GetSubKeyNames())
        {
            if (name == "NonPackaged") continue;
            using var sub = key.OpenSubKey(name);
            if (sub?.GetValue("LastUsedTimeStart") is long start && sub.GetValue("LastUsedTimeStop") is long stop)
                into.Add((name, start, stop));
        }
    }
}
