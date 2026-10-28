# The break's root view: it eats every key, so none reaches the app below (volume included).
.class final Lio/github/junkers4/blackbreak/BreakOverlay$Root;
.super Landroid/widget/FrameLayout;

.method constructor <init>(Landroid/content/Context;)V
    .locals 0
    invoke-direct {p0, p1}, Landroid/widget/FrameLayout;-><init>(Landroid/content/Context;)V
    return-void
.end method

.method public dispatchKeyEvent(Landroid/view/KeyEvent;)Z
    .locals 1
    const/4 v0, 0x1
    return v0
.end method
