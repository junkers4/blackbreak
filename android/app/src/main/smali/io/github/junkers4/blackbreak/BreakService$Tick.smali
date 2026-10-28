.class final Lio/github/junkers4/blackbreak/BreakService$Tick;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;

.field private final s:Lio/github/junkers4/blackbreak/BreakService;

.method constructor <init>(Lio/github/junkers4/blackbreak/BreakService;)V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lio/github/junkers4/blackbreak/BreakService$Tick;->s:Lio/github/junkers4/blackbreak/BreakService;
    return-void
.end method

.method public run()V
    .locals 1
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService$Tick;->s:Lio/github/junkers4/blackbreak/BreakService;
    invoke-virtual {v0}, Lio/github/junkers4/blackbreak/BreakService;->tick()V
    return-void
.end method
