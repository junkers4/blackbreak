using BlackBreak.Core;
using Xunit;

namespace BlackBreak.Core.Tests;

public class CallUsageTests
{
    const string Self = @"C:\Apps\BlackBreak.exe";

    [Fact(DisplayName = "active entry counts")]
    public void Active() => Assert.True(CallUsage.InUse([(@"C:\zoom.exe", 100, 0)], Self));

    [Fact(DisplayName = "stopped entry does not")]
    public void Stopped() => Assert.False(CallUsage.InUse([(@"C:\zoom.exe", 100, 200)], Self));

    [Fact(DisplayName = "never used does not")]
    public void Never() => Assert.False(CallUsage.InUse([(@"C:\zoom.exe", 0, 0)], Self));

    [Fact(DisplayName = "self is skipped")]
    public void SelfSkipped() => Assert.False(CallUsage.InUse([(@"c:\apps\blackbreak.EXE", 100, 0)], Self));
}
