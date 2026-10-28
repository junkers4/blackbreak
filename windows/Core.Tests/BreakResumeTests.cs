using BlackBreak.Core;
using Xunit;

namespace BlackBreak.Core.Tests;

public class BreakResumeTests
{
    [Fact(DisplayName = "relaunch mid-break shows the rest")]
    public void MidBreak() => Assert.Equal(1_030_000L, BreakResume.EndsAt(1_000_000, 5, 1_010_000, 5));

    [Fact(DisplayName = "relaunch after 30 s shows nothing")]
    public void After30s() => Assert.Null(BreakResume.EndsAt(1_000_000, 5, 1_030_000, 5));

    [Fact(DisplayName = "relaunch after reboot shows nothing")]
    public void AfterReboot() => Assert.Null(BreakResume.EndsAt(1_000_000, 5, 1_010_000, 500_000));

    [Fact(DisplayName = "relaunch repeatedly never extends")]
    public void NeverExtends()
    {
        for (long now = 0; now <= 40_000; now += 500)
        {
            var e = BreakResume.EndsAt(0, 7, now, 7);
            Assert.True(e is null || e == 30_000L, $"now={now} e={e}");
        }
    }

    [Fact] public void NoBreakStartIsNull() => Assert.Null(BreakResume.EndsAt(null, 5, 10, 5));
}
