using BlackBreak.Core;
using Xunit;

namespace BlackBreak.Core.Tests;

// REQ-008, REQ-010, REQ-014, REQ-017, REQ-021
public class MenuTests
{
    static string Clock(long ms) => (ms / 1000).ToString();
    static readonly Settings Defaults = new();

    static Scheduler At(Phase want)
    {
        var s = new Scheduler(0, 1, Spec.DayKey);
        switch (want)
        {
            case Phase.Warning: Walk(s, 1_195_000); break;
            case Phase.Break: Walk(s, 1_200_000); break;
            case Phase.Paused: s.Update(1000); Assert.True(s.Pause(1_800_000, 1000)); break;
            default: s.Update(1000); break;
        }
        Assert.Equal(want, s.Phase);
        return s;
    }

    // One update a minute: a longer gap would count as rest.
    static void Walk(Scheduler s, long to)
    {
        for (long t = 60_000; t < to; t += 60_000) s.Update(t);
        s.Update(to);
    }

    [Fact(DisplayName = "work: pause and settings on, cancel off")]
    public void Work()
    {
        var m = Menu.For(At(Phase.Work), Defaults, Clock);
        Assert.True(m.PauseEnabled);
        Assert.False(m.CancelEnabled);
        Assert.True(m.SettingsEnabled);
        Assert.Equal("Next break at 1200", m.Status);
    }

    [Theory(DisplayName = "warning and break: nothing can be changed")]
    [InlineData(Phase.Warning)]
    [InlineData(Phase.Break)]
    public void Locked(Phase p)
    {
        var m = Menu.For(At(p), Defaults, Clock);
        Assert.False(m.PauseEnabled);
        Assert.False(m.CancelEnabled);
        Assert.False(m.SettingsEnabled);
    }

    [Fact(DisplayName = "paused: cancel on, pause off")]
    public void Paused()
    {
        var m = Menu.For(At(Phase.Paused), Defaults, Clock);
        Assert.False(m.PauseEnabled);
        Assert.True(m.CancelEnabled);
        Assert.Equal("Paused until 1801", m.Status);
    }

    [Fact(DisplayName = "after the day's pause, pause stays off")]
    public void OnePerDay()
    {
        var s = At(Phase.Paused);
        Assert.True(s.CancelPause(2000));
        Assert.False(Menu.For(s, Defaults, Clock).PauseEnabled);
    }

    [Fact(DisplayName = "no item stops a break or quits")]
    public void NoQuit()
    {
        var names = typeof(MenuState).GetProperties().Select(p => p.Name).ToArray();
        Assert.DoesNotContain(names, n => n.Contains("Quit") || n.Contains("Skip") || n.Contains("Stop"));
    }
}

// REQ-026, REQ-027, REQ-028
public class CallSettingsTests
{
    const string Self = @"C:\Apps\BlackBreak.exe";
    static readonly (string, long, long)[] Active = [(@"C:#teams.exe", 100, 0)];
    static readonly (string, long, long)[] None = [];

    [Fact(DisplayName = "defaults: exemption off, microphone and camera on")]
    public void Defaults()
    {
        var s = new Settings();
        Assert.False(s.CallExemption);
        Assert.True(s.ExemptMic);
        Assert.True(s.ExemptCamera);
    }

    [Fact(DisplayName = "exemption off: a call never counts")]
    public void Off() => Assert.False(CallUsage.InCall(new Settings(), Active, Active, Self));

    [Fact(DisplayName = "microphone on: microphone use counts")]
    public void Mic() => Assert.True(CallUsage.InCall(new Settings(true, true, false), Active, None, Self));

    [Fact(DisplayName = "microphone off: microphone use does not count")]
    public void MicOff() => Assert.False(CallUsage.InCall(new Settings(true, false, true), Active, None, Self));

    [Fact(DisplayName = "camera on: camera use counts")]
    public void Camera() => Assert.True(CallUsage.InCall(new Settings(true, false, true), None, Active, Self));

    [Fact(DisplayName = "camera off: camera use does not count")]
    public void CameraOff() => Assert.False(CallUsage.InCall(new Settings(true, true, false), None, Active, Self));

    [Fact(DisplayName = "nothing in use: no call")]
    public void Idle() => Assert.False(CallUsage.InCall(new Settings(true, true, true), None, None, Self));
}

// REQ-003, REQ-030
public class CopyTests
{
    [Fact(DisplayName = "three lines, the middle one emphasised")]
    public void Lines()
    {
        foreach (var sk in new[] { false, true })
        {
            var l = Copy.Lines(sk);
            Assert.Equal(3, l.Length);
            Assert.NotEmpty(l[1].accent);
        }
    }

    [Theory(DisplayName = "seconds")]
    [InlineData(false, 1, "1 second")]
    [InlineData(false, 30, "30 seconds")]
    [InlineData(true, 1, "1 sekunda")]
    [InlineData(true, 4, "4 sekundy")]
    [InlineData(true, 30, "30 sekúnd")]
    public void Seconds(bool sk, long n, string want) => Assert.Equal(want, Copy.Seconds(sk, n));
}
