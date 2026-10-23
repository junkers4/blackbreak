using System.Text.Json;
using System.Text.Json.Serialization;

namespace BlackBreak.Core;

public sealed record Settings(bool CallExemption = false, bool ExemptMic = true, bool ExemptCamera = true, string? LastPauseDay = null);

public sealed record BreakState(long? BreakStartMs, long BootMs);

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase, WriteIndented = true)]
[JsonSerializable(typeof(Settings))]
[JsonSerializable(typeof(BreakState))]
internal partial class StoreJson : JsonSerializerContext { }

public static class Store
{
    const string SettingsFile = "settings.json", StateFile = "state.json";

    public static Settings LoadSettings(string dir) =>
        Load(Path.Combine(dir, SettingsFile), StoreJson.Default.Settings) ?? new Settings();

    public static void Save(string dir, Settings s) =>
        Write(Path.Combine(dir, SettingsFile), JsonSerializer.Serialize(s, StoreJson.Default.Settings), dir);

    public static BreakState? LoadState(string dir) =>
        Load(Path.Combine(dir, StateFile), StoreJson.Default.BreakState);

    public static void Save(string dir, BreakState s) =>
        Write(Path.Combine(dir, StateFile), JsonSerializer.Serialize(s, StoreJson.Default.BreakState), dir);

    static T? Load<T>(string path, System.Text.Json.Serialization.Metadata.JsonTypeInfo<T> info) where T : class
    {
        try { return JsonSerializer.Deserialize(File.ReadAllText(path), info); }
        catch { return null; }
    }

    static void Write(string path, string json, string dir)
    {
        Directory.CreateDirectory(dir);
        var tmp = path + ".tmp";
        File.WriteAllText(tmp, json);
        File.Move(tmp, path, overwrite: true);
    }
}
