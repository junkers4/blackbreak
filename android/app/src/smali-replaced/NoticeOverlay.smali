# The warning: a small dark pill at the top centre; no touch, no focus.
.class public final Lio/github/junkers4/blackbreak/NoticeOverlay;
.super Ljava/lang/Object;

.field private final context:Landroid/content/Context;
.field private final wm:Landroid/view/WindowManager;
.field private final view:Landroid/widget/TextView;
.field private shown:Z

.method public constructor <init>(Landroid/content/Context;Landroid/view/WindowManager;)V
    .locals 6
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->context:Landroid/content/Context;
    iput-object p2, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->wm:Landroid/view/WindowManager;
    new-instance v0, Landroid/widget/TextView;
    invoke-direct {v0, p1}, Landroid/widget/TextView;-><init>(Landroid/content/Context;)V
    iput-object v0, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->view:Landroid/widget/TextView;
    const-string v1, "Break in 10 s"
    invoke-virtual {v0, v1}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V
    const-string v1, "#ECE8E1"
    invoke-static {v1}, Landroid/graphics/Color;->parseColor(Ljava/lang/String;)I
    move-result v1
    invoke-virtual {v0, v1}, Landroid/widget/TextView;->setTextColor(I)V
    const/high16 v1, 0x41700000                # 15f
    const/4 v2, 0x2
    invoke-virtual {v0, v2, v1}, Landroid/widget/TextView;->setTextSize(IF)V
    const/16 v1, 0x11                          # CENTER
    invoke-virtual {v0, v1}, Landroid/widget/TextView;->setGravity(I)V
    # padding 12 dp, sides 24 dp
    invoke-virtual {p1}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;
    move-result-object v1
    invoke-virtual {v1}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;
    move-result-object v1
    iget v1, v1, Landroid/util/DisplayMetrics;->density:F
    const/high16 v2, 0x41400000                # 12f
    mul-float/2addr v2, v1
    float-to-int v2, v2
    mul-int/lit8 v3, v2, 0x2
    invoke-virtual {v0, v3, v2, v3, v2}, Landroid/widget/TextView;->setPadding(IIII)V
    new-instance v3, Landroid/graphics/drawable/GradientDrawable;
    invoke-direct {v3}, Landroid/graphics/drawable/GradientDrawable;-><init>()V
    const-string v4, "#EB1F1D1A"
    invoke-static {v4}, Landroid/graphics/Color;->parseColor(Ljava/lang/String;)I
    move-result v4
    invoke-virtual {v3, v4}, Landroid/graphics/drawable/GradientDrawable;->setColor(I)V
    const/high16 v4, 0x447a0000                # 1000f
    invoke-virtual {v3, v4}, Landroid/graphics/drawable/GradientDrawable;->setCornerRadius(F)V
    invoke-virtual {v0, v3}, Landroid/widget/TextView;->setBackground(Landroid/graphics/drawable/Drawable;)V
    return-void
.end method

.method public show()V
    .locals 6
    iget-boolean v0, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->shown:Z
    if-eqz v0, :add
    return-void
    :add
    new-instance v0, Landroid/view/WindowManager$LayoutParams;
    const/4 v1, -0x2                           # WRAP_CONTENT
    const/16 v2, 0x7f0                         # TYPE_ACCESSIBILITY_OVERLAY
    const/16 v3, 0x118                         # NOT_TOUCHABLE | NOT_FOCUSABLE | LAYOUT_IN_SCREEN
    const/4 v4, -0x3                           # TRANSLUCENT
    invoke-direct {v0, v1, v1, v2, v3, v4}, Landroid/view/WindowManager$LayoutParams;-><init>(IIIII)V
    const/16 v1, 0x31                          # TOP | CENTER_HORIZONTAL
    iput v1, v0, Landroid/view/WindowManager$LayoutParams;->gravity:I
    iget-object v1, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->context:Landroid/content/Context;
    invoke-virtual {v1}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;
    move-result-object v1
    invoke-virtual {v1}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;
    move-result-object v1
    iget v1, v1, Landroid/util/DisplayMetrics;->density:F
    const/high16 v2, 0x425c0000                # 55f
    mul-float/2addr v2, v1
    float-to-int v2, v2
    iput v2, v0, Landroid/view/WindowManager$LayoutParams;->y:I
    iget-object v1, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->wm:Landroid/view/WindowManager;
    iget-object v2, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->view:Landroid/widget/TextView;
    invoke-interface {v1, v2, v0}, Landroid/view/ViewManager;->addView(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V
    const/4 v0, 0x1
    iput-boolean v0, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->shown:Z
    return-void
.end method

.method public hide()V
    .locals 3
    iget-boolean v0, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->shown:Z
    if-nez v0, :go
    return-void
    :go
    const/4 v0, 0x0
    iput-boolean v0, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->shown:Z
    :try_start
    iget-object v0, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->wm:Landroid/view/WindowManager;
    iget-object v1, p0, Lio/github/junkers4/blackbreak/NoticeOverlay;->view:Landroid/widget/TextView;
    invoke-interface {v0, v1}, Landroid/view/WindowManager;->removeViewImmediate(Landroid/view/View;)V
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :done
    :done
    return-void
.end method
