using BlackBreak.Core;
using Xunit;

namespace BlackBreak.Core.Tests;

public class StoreTests
{
    static string Tmp() => Path.Combine(Path.GetTempPath(), "bb-" + Guid.NewGuid().ToString("N"));

    [Fact(DisplayName = "round trip")]
    public void RoundTrip()
    {
        var d = Tmp();
        try
        {
            var s = new Settings(true, false, false, "20000");
            Store.Save(d, s);
            Assert.Equal(s, Store.LoadSettings(d));
            var b = new BreakState(123, 456);
            Store.Save(d, b);
            Assert.Equal(b, Store.LoadState(d));
            Assert.Contains("\"callExemption\"", File.ReadAllText(Path.Combine(d, "settings.json")));
        }
        finally { Directory.Delete(d, true); }
    }

    [Fact(DisplayName = "corrupt file gives defaults")]
    public void Corrupt()
    {
        var d = Tmp();
        Directory.CreateDirectory(d);
        try
        {
            File.WriteAllText(Path.Combine(d, "settings.json"), "{nope");
            File.WriteAllText(Path.Combine(d, "state.json"), "\0\0");
            Assert.Equal(new Settings(), Store.LoadSettings(d));
            Assert.Null(Store.LoadState(d));
        }
        finally { Directory.Delete(d, true); }
    }

    [Fact(DisplayName = "missing dir gives defaults")]
    public void Missing()
    {
        var d = Tmp();
        Assert.Equal(new Settings(), Store.LoadSettings(d));
        Assert.Null(Store.LoadState(d));
    }
}
