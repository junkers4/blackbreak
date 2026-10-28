# Screen on and off: the service has no tick while the screen is off.
.class final Lio/github/junkers4/blackbreak/BreakService$Screen;
.super Landroid/content/BroadcastReceiver;

.field private final s:Lio/github/junkers4/blackbreak/BreakService;

.method constructor <init>(Lio/github/junkers4/blackbreak/BreakService;)V
    .locals 0
    invoke-direct {p0}, Landroid/content/BroadcastReceiver;-><init>()V
    iput-object p1, p0, Lio/github/junkers4/blackbreak/BreakService$Screen;->s:Lio/github/junkers4/blackbreak/BreakService;
    return-void
.end method

.method public onReceive(Landroid/content/Context;Landroid/content/Intent;)V
    .locals 3
    invoke-virtual {p2}, Landroid/content/Intent;->getAction()Ljava/lang/String;
    move-result-object v0
    const-string v1, "android.intent.action.SCREEN_OFF"
    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    iget-object v1, p0, Lio/github/junkers4/blackbreak/BreakService$Screen;->s:Lio/github/junkers4/blackbreak/BreakService;
    if-eqz v0, :on
    const/4 v2, 0x0
    invoke-virtual {v1, v2}, Lio/github/junkers4/blackbreak/BreakService;->onScreen(Z)V
    return-void
    :on
    const/4 v2, 0x1
    invoke-virtual {v1, v2}, Lio/github/junkers4/blackbreak/BreakService;->onScreen(Z)V
    return-void
.end method
