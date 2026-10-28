# The break screen: warm black over the whole display, three cream serif lines
# (the middle one ending in tan italic) and the seconds left in the corner.
.class public final Lio/github/junkers4/blackbreak/BreakOverlay;
.super Ljava/lang/Object;

.field private final context:Landroid/content/Context;
.field private final wm:Landroid/view/WindowManager;
.field private final root:Landroid/widget/FrameLayout;
.field private final countdown:Landroid/widget/TextView;
.field private final slovak:Z
.field private shown:Z

.method public constructor <init>(Landroid/content/Context;Landroid/view/WindowManager;)V
    .locals 16
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->context:Landroid/content/Context;
    iput-object p2, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->wm:Landroid/view/WindowManager;

    # slovak = Locale.getDefault().getLanguage().equals("sk")
    invoke-static {}, Ljava/util/Locale;->getDefault()Ljava/util/Locale;
    move-result-object v0
    invoke-virtual {v0}, Ljava/util/Locale;->getLanguage()Ljava/lang/String;
    move-result-object v0
    const-string v1, "sk"
    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v14
    iput-boolean v14, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->slovak:Z

    # v13 = density, v12 = display height
    invoke-virtual {p1}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;
    move-result-object v0
    invoke-virtual {v0}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;
    move-result-object v0
    iget v13, v0, Landroid/util/DisplayMetrics;->density:F
    iget v12, v0, Landroid/util/DisplayMetrics;->heightPixels:I

    # the serif typeface; the weight 400 where the system has it (API 28), so bold-text settings do not thicken it
    sget v0, Landroid/os/Build$VERSION;->SDK_INT:I
    const/16 v1, 0x1c
    if-lt v0, v1, :old
    sget-object v0, Landroid/graphics/Typeface;->SERIF:Landroid/graphics/Typeface;
    const/16 v1, 0x190
    const/4 v2, 0x0
    invoke-static {v0, v1, v2}, Landroid/graphics/Typeface;->create(Landroid/graphics/Typeface;IZ)Landroid/graphics/Typeface;
    move-result-object v11
    goto :typeface_done
    :old
    const-string v0, "serif"
    const/4 v1, 0x0
    invoke-static {v0, v1}, Landroid/graphics/Typeface;->create(Ljava/lang/String;I)Landroid/graphics/Typeface;
    move-result-object v11
    :typeface_done

    # the root: a FrameLayout that eats keys, warm black, taking touches and the focus
    new-instance v10, Lio/github/junkers4/blackbreak/BreakOverlay$Root;
    invoke-direct {v10, p1}, Lio/github/junkers4/blackbreak/BreakOverlay$Root;-><init>(Landroid/content/Context;)V
    const-string v0, "#0D0C0B"
    invoke-static {v0}, Landroid/graphics/Color;->parseColor(Ljava/lang/String;)I
    move-result v0
    invoke-virtual {v10, v0}, Landroid/view/View;->setBackgroundColor(I)V
    const/4 v0, 0x1
    invoke-virtual {v10, v0}, Landroid/view/View;->setClickable(Z)V
    invoke-virtual {v10, v0}, Landroid/view/View;->setFocusable(Z)V
    invoke-virtual {v10, v0}, Landroid/view/View;->setFocusableInTouchMode(Z)V
    iput-object v10, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->root:Landroid/widget/FrameLayout;

    # the column of three lines
    new-instance v9, Landroid/widget/LinearLayout;
    invoke-direct {v9, p1}, Landroid/widget/LinearLayout;-><init>(Landroid/content/Context;)V
    const/4 v0, 0x1
    invoke-virtual {v9, v0}, Landroid/widget/LinearLayout;->setOrientation(I)V

    const/4 v8, 0x0                          # i
    :lines
    const/4 v0, 0x3
    if-ge v8, v0, :lines_done
    new-instance v7, Landroid/widget/TextView;
    invoke-direct {v7, p1}, Landroid/widget/TextView;-><init>(Landroid/content/Context;)V
    invoke-virtual {v7, v11}, Landroid/widget/TextView;->setTypeface(Landroid/graphics/Typeface;)V
    const/high16 v0, 0x41d80000                # 27f
    const/4 v1, 0x2
    invoke-virtual {v7, v1, v0}, Landroid/widget/TextView;->setTextSize(IF)V
    const-string v0, "#ECE8E1"
    invoke-static {v0}, Landroid/graphics/Color;->parseColor(Ljava/lang/String;)I
    move-result v0
    invoke-virtual {v7, v0}, Landroid/widget/TextView;->setTextColor(I)V
    const/4 v0, 0x0
    const v1, 0x3f8ccccd                       # 1.1f
    invoke-virtual {v7, v0, v1}, Landroid/widget/TextView;->setLineSpacing(FF)V
    # text = plain + accent (italic, tan)
    invoke-static {v14, v8}, Lio/github/junkers4/blackbreak/Copy;->plain(ZI)Ljava/lang/String;
    move-result-object v0
    new-instance v6, Landroid/text/SpannableStringBuilder;
    invoke-direct {v6, v0}, Landroid/text/SpannableStringBuilder;-><init>(Ljava/lang/CharSequence;)V
    invoke-static {v14, v8}, Lio/github/junkers4/blackbreak/Copy;->accent(ZI)Ljava/lang/String;
    move-result-object v5
    invoke-virtual {v5}, Ljava/lang/String;->length()I
    move-result v0
    if-eqz v0, :no_accent
    invoke-virtual {v6}, Landroid/text/SpannableStringBuilder;->length()I
    move-result v4
    invoke-virtual {v6, v5}, Landroid/text/SpannableStringBuilder;->append(Ljava/lang/CharSequence;)Landroid/text/SpannableStringBuilder;
    invoke-virtual {v6}, Landroid/text/SpannableStringBuilder;->length()I
    move-result v3
    new-instance v0, Landroid/text/style/StyleSpan;
    const/4 v1, 0x2
    invoke-direct {v0, v1}, Landroid/text/style/StyleSpan;-><init>(I)V
    const/16 v1, 0x21
    invoke-virtual {v6, v0, v4, v3, v1}, Landroid/text/SpannableStringBuilder;->setSpan(Ljava/lang/Object;III)V
    const-string v0, "#C9B99A"
    invoke-static {v0}, Landroid/graphics/Color;->parseColor(Ljava/lang/String;)I
    move-result v0
    new-instance v2, Landroid/text/style/ForegroundColorSpan;
    invoke-direct {v2, v0}, Landroid/text/style/ForegroundColorSpan;-><init>(I)V
    const/16 v1, 0x21
    invoke-virtual {v6, v2, v4, v3, v1}, Landroid/text/SpannableStringBuilder;->setSpan(Ljava/lang/Object;III)V
    :no_accent
    invoke-virtual {v7, v6}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V
    invoke-virtual {v9, v7}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V
    add-int/lit8 v8, v8, 0x1
    goto :lines
    :lines_done

    # the column goes at 22 % of the height, 26 dp from the sides
    new-instance v6, Landroid/widget/FrameLayout$LayoutParams;
    const/4 v0, -0x1
    const/4 v1, -0x2
    invoke-direct {v6, v0, v1}, Landroid/widget/FrameLayout$LayoutParams;-><init>(II)V
    mul-int/lit8 v0, v12, 0x16
    div-int/lit8 v0, v0, 0x64
    iput v0, v6, Landroid/widget/FrameLayout$LayoutParams;->topMargin:I
    const/high16 v0, 0x41d00000                # 26f
    mul-float/2addr v0, v13
    float-to-int v0, v0
    invoke-virtual {v6, v0}, Landroid/widget/FrameLayout$LayoutParams;->setMarginStart(I)V
    invoke-virtual {v6, v0}, Landroid/widget/FrameLayout$LayoutParams;->setMarginEnd(I)V
    invoke-virtual {v10, v9, v6}, Landroid/widget/FrameLayout;->addView(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V

    # the seconds left, bottom left, dim
    new-instance v7, Landroid/widget/TextView;
    invoke-direct {v7, p1}, Landroid/widget/TextView;-><init>(Landroid/content/Context;)V
    const-string v0, "#7B756B"
    invoke-static {v0}, Landroid/graphics/Color;->parseColor(Ljava/lang/String;)I
    move-result v0
    invoke-virtual {v7, v0}, Landroid/widget/TextView;->setTextColor(I)V
    const/high16 v0, 0x41600000                # 14f
    const/4 v1, 0x2
    invoke-virtual {v7, v1, v0}, Landroid/widget/TextView;->setTextSize(IF)V
    iput-object v7, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->countdown:Landroid/widget/TextView;
    new-instance v6, Landroid/widget/FrameLayout$LayoutParams;
    const/4 v0, -0x2
    invoke-direct {v6, v0, v0}, Landroid/widget/FrameLayout$LayoutParams;-><init>(II)V
    const/16 v0, 0x53                          # BOTTOM | START
    iput v0, v6, Landroid/widget/FrameLayout$LayoutParams;->gravity:I
    const/high16 v0, 0x41d00000
    mul-float/2addr v0, v13
    float-to-int v0, v0
    invoke-virtual {v6, v0}, Landroid/widget/FrameLayout$LayoutParams;->setMarginStart(I)V
    mul-int/lit8 v0, v12, 0x9
    div-int/lit8 v0, v0, 0x64
    iput v0, v6, Landroid/widget/FrameLayout$LayoutParams;->bottomMargin:I
    invoke-virtual {v10, v7, v6}, Landroid/widget/FrameLayout;->addView(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V
    return-void
.end method

.method public isShown()Z
    .locals 1
    iget-boolean v0, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->shown:Z
    return v0
.end method

.method public view()Landroid/view/View;
    .locals 1
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->root:Landroid/widget/FrameLayout;
    return-object v0
.end method

.method public update(J)V
    .locals 4
    const-wide/16 v0, 0x0
    cmp-long v2, p1, v0
    if-gez v2, :ok
    move-wide p1, v0
    :ok
    iget-boolean v2, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->slovak:Z
    invoke-static {v2, p1, p2}, Lio/github/junkers4/blackbreak/Copy;->seconds(ZJ)Ljava/lang/String;
    move-result-object v0
    iget-object v1, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->countdown:Landroid/widget/TextView;
    invoke-virtual {v1, v0}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V
    return-void
.end method

# Shown over the status and navigation bars, in the cut-out too, until hide().
.method public show(J)V
    .locals 6
    invoke-virtual {p0, p1, p2}, Lio/github/junkers4/blackbreak/BreakOverlay;->update(J)V
    iget-boolean v0, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->shown:Z
    if-eqz v0, :add
    return-void
    :add
    new-instance v0, Landroid/view/WindowManager$LayoutParams;
    const/4 v1, -0x1                           # MATCH_PARENT
    const/16 v2, 0x7f0                         # TYPE_ACCESSIBILITY_OVERLAY
    const/16 v3, 0x380                         # LAYOUT_IN_SCREEN | LAYOUT_NO_LIMITS | KEEP_SCREEN_ON
    const/4 v4, -0x1                           # OPAQUE
    invoke-direct {v0, v1, v1, v2, v3, v4}, Landroid/view/WindowManager$LayoutParams;-><init>(IIIII)V
    sget v1, Landroid/os/Build$VERSION;->SDK_INT:I
    const/16 v2, 0x1c
    if-lt v1, v2, :no_cutout
    const/4 v2, 0x3                            # CUTOUT_MODE_ALWAYS
    iput v2, v0, Landroid/view/WindowManager$LayoutParams;->layoutInDisplayCutoutMode:I
    :no_cutout
    const/16 v2, 0x1e
    if-lt v1, v2, :no_insets
    const/4 v2, 0x0
    invoke-virtual {v0, v2}, Landroid/view/WindowManager$LayoutParams;->setFitInsetsTypes(I)V
    :no_insets
    iget-object v1, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->wm:Landroid/view/WindowManager;
    iget-object v2, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->root:Landroid/widget/FrameLayout;
    invoke-interface {v1, v2, v0}, Landroid/view/ViewManager;->addView(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V
    invoke-virtual {v2}, Landroid/view/View;->requestFocus()Z
    const/4 v0, 0x1
    iput-boolean v0, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->shown:Z
    return-void
.end method

.method public hide()V
    .locals 3
    iget-boolean v0, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->shown:Z
    if-nez v0, :go
    return-void
    :go
    const/4 v0, 0x0
    iput-boolean v0, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->shown:Z
    :try_start
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->wm:Landroid/view/WindowManager;
    iget-object v1, p0, Lio/github/junkers4/blackbreak/BreakOverlay;->root:Landroid/widget/FrameLayout;
    invoke-interface {v0, v1}, Landroid/view/WindowManager;->removeViewImmediate(Landroid/view/View;)V
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :done
    :done
    return-void
.end method
