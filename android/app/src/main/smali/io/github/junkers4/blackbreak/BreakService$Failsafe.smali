# The independent fail-safe: the break screen goes at breakStart + 35 s whatever else happens.
.class final Lio/github/junkers4/blackbreak/BreakService$Failsafe;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;

.field private final s:Lio/github/junkers4/blackbreak/BreakService;

.method constructor <init>(Lio/github/junkers4/blackbreak/BreakService;)V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lio/github/junkers4/blackbreak/BreakService$Failsafe;->s:Lio/github/junkers4/blackbreak/BreakService;
    return-void
.end method

.method public run()V
    .locals 1
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService$Failsafe;->s:Lio/github/junkers4/blackbreak/BreakService;
    invoke-virtual {v0}, Lio/github/junkers4/blackbreak/BreakService;->failsafe()V
    return-void
.end method
