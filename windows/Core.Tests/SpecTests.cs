using System.Text.Json;
using BlackBreak.Core;
using Xunit;

namespace BlackBreak.Core.Tests;

static class Spec
{
    public static JsonElement Load(string file) =>
        JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "spec", file))).RootElement.Clone();

    public static IEnumerable<object[]> Names(string file) =>
        Load(file).EnumerateArray().Select(e => new object[] { e.GetProperty("name").GetString()! });

    public static JsonElement Find(string file, string name) =>
        Load(file).EnumerateArray().First(e => e.GetProperty("name").GetString() == name);

    public static long? Day(string? s) => s is null ? null : long.Parse(s);

    public static bool Has(JsonElement e, string k) => e.TryGetProperty(k, out _);
    public static long Long(JsonElement e, string k, long d = 0) => e.TryGetProperty(k, out var v) && v.ValueKind != JsonValueKind.Null ? v.GetInt64() : d;
    public static bool Bool(JsonElement e, string k) => e.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.True;
    public static string? Str(JsonElement e, string k) => e.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;

    public static string PhaseName(Phase p) => p.ToString().ToLowerInvariant();
}

public class ScenarioTests
{
    public static IEnumerable<object[]> Cases() => Spec.Names("scenarios.json");

    [Theory, MemberData(nameof(Cases))]
    public void Scenario(string name)
    {
        var sc = Spec.Find("scenarios.json", name);
        long startS = Spec.Long(sc, "start");
        var s = new Scheduler(startS * 1000, 1, Spec.Day(Spec.Str(sc, "lastPauseDay")));
        var steps = sc.GetProperty("steps").EnumerateArray().ToList();
        var expects = sc.GetProperty("expect").EnumerateArray().ToList();
        long maxT = expects.Max(e => e.GetProperty("t").GetInt64());
        long idle = 0; bool inCall = false, inPhone = false;
        for (long t = startS; t <= maxT; t++)
        {
            var step = steps.Cast<JsonElement?>().FirstOrDefault(st => st!.Value.GetProperty("t").GetInt64() == t);
            if (step is { } st2)
            {
                idle = Spec.Long(st2, "idle");
                inCall = Spec.Bool(st2, "inCall");
                inPhone = Spec.Bool(st2, "inPhoneCall");
            }
            bool? result = null;
            var act = step is { } st3 ? Spec.Str(st3, "do") : null;
            if (act != null && act.StartsWith("pause:"))
                result = s.Pause(long.Parse(act[6..]) * 1000, t * 1000);
            else if (act == "cancelPause")
                result = s.CancelPause(t * 1000);
            s.Update(t * 1000, idle * 1000, inCall, inPhone);
            foreach (var e in expects.Where(x => x.GetProperty("t").GetInt64() == t))
            {
                var where = $"{name} @{t}s";
                Assert.True(e.GetProperty("phase").GetString() == Spec.PhaseName(s.Phase), $"{where} phase");
                if (Spec.Has(e, "canPause"))
                    Assert.True(Spec.Bool(e, "canPause") == s.CanPause, $"{where} canPause");
                if (Spec.Has(e, "pauseResult"))
                    Assert.True(Spec.Bool(e, "pauseResult") == result, $"{where} pauseResult");
            }
        }
    }
}

public class TraceTests
{
    public static IEnumerable<object[]> Cases() => Spec.Names("traces.json");

    [Theory, MemberData(nameof(Cases))]
    public void Trace(string name)
    {
        var tr = Spec.Find("traces.json", name);
        long start = Spec.Long(tr, "start");
        var s = new Scheduler(start, tr.TryGetProperty("scale", out var sv) ? sv.GetDouble() : 1,
            Spec.Day(Spec.Str(tr, "lastPauseDay")));
        long last = start;
        bool? result = null;
        void Update(long now, long idle = 0, bool call = false, bool phone = false)
        {
            s.Update(now, idle, call, phone);
            last = now;
        }
        int i = 0;
        foreach (var ev in tr.GetProperty("events").EnumerateArray())
        {
            var w = $"{name} #{i++}";
            int actions = new[] { "now", "walk", "do" }.Count(k => Spec.Has(ev, k));
            Assert.True(actions <= 1, $"{w}: more than one action");
            if (Spec.Has(ev, "now"))
                Update(Spec.Long(ev, "now"), Spec.Long(ev, "idle"), Spec.Bool(ev, "inCall"), Spec.Bool(ev, "inPhoneCall"));
            else if (Spec.Has(ev, "walk"))
            {
                long every = Spec.Long(ev, "every", 60_000), to = Spec.Long(ev, "walk");
                for (long n = last + every; n < to; n += every)
                    Update(n);
                Update(to);
            }
            else if (Spec.Has(ev, "do"))
            {
                Assert.True(Spec.Has(ev, "at"), $"{w}: do needs at");
                var d = Spec.Str(ev, "do")!;
                long at = Spec.Long(ev, "at");
                if (d.StartsWith("pause:")) result = s.Pause(long.Parse(d[6..]), at);
                else if (d == "cancelPause") result = s.CancelPause(at);
                else Assert.Fail($"{w}: unknown do {d}");
            }
            if (!ev.TryGetProperty("expect", out var ex)) continue;
            foreach (var p in ex.EnumerateObject())
            {
                var m = $"{w} {p.Name}";
                var v = p.Value;
                switch (p.Name)
                {
                    case "phase": Assert.True(v.GetString() == Spec.PhaseName(s.Phase), m); break;
                    case "canPause": Assert.True(v.GetBoolean() == s.CanPause, m); break;
                    case "result":
                        Assert.True(result is not null, $"{w}: no do yet");
                        Assert.True(v.GetBoolean() == result, m); break;
                    case "lastPauseDay": Assert.Equal(Spec.Day(v.ValueKind == JsonValueKind.Null ? null : v.GetString()), s.LastPauseDay); break;
                    case "nextBreakAt": Assert.Equal(L(v), s.NextBreakAt); break;
                    case "breakEndsAt": Assert.Equal(L(v), s.BreakEndsAt); break;
                    case "warningEndsAt": Assert.Equal(L(v), s.WarningEndsAt); break;
                    case "pauseEndsAt": Assert.Equal(L(v), s.PauseEndsAt); break;
                    default: Assert.Fail($"{m}: unknown expect key"); break;
                }
            }
        }
    }

    static long? L(JsonElement v) => v.ValueKind == JsonValueKind.Null ? null : v.GetInt64();
}
