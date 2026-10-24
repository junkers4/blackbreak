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
        return CallUsage.InCall(s, Entries("microphone"), Entries("webcam"), self);
    }

    static List<(string, long, long)> Entries(string capability)
    {
        var entries = new List<(string, long, long)>();
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(Root + capability);
            if (key == null) return entries;
            Collect(key, entries);
            using var np = key.OpenSubKey("NonPackaged");
            if (np != null) Collect(np, entries);
        }
        catch { }
        return entries;
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
