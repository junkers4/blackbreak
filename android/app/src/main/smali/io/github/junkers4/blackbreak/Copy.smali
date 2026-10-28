# The words of the break screen, in English or Slovak. The seconds come from the core.
.class public final Lio/github/junkers4/blackbreak/Copy;
.super Ljava/lang/Object;

# the plain part of line i (0..2)
.method public static plain(ZI)Ljava/lang/String;
    .locals 1
    if-eqz p0, :en
    if-nez p1, :sk1
    const-string v0, "Odlož oči."
    return-object v0
    :sk1
    const/4 v0, 0x1
    if-ne p1, v0, :sk2
    const-string v0, "Pozri von oknom, "
    return-object v0
    :sk2
    const-string v0, "Potom sa natiahni."
    return-object v0
    :en
    if-nez p1, :en1
    const-string v0, "Rest your eyes."
    return-object v0
    :en1
    const/4 v0, 0x1
    if-ne p1, v0, :en2
    const-string v0, "Look out of the window, "
    return-object v0
    :en2
    const-string v0, "Then stretch."
    return-object v0
.end method

# the emphasised part of line i, set in italic; empty for most lines
.method public static accent(ZI)Ljava/lang/String;
    .locals 1
    const/4 v0, 0x1
    if-ne p1, v0, :none
    if-eqz p0, :en
    const-string v0, "\u010do naj\u010falej."
    return-object v0
    :en
    const-string v0, "as far as you can."
    return-object v0
    :none
    const-string v0, ""
    return-object v0
.end method

# "N seconds" / "N sekúnd", from the core
.method public static seconds(ZJ)Ljava/lang/String;
    .locals 4
    if-eqz p0, :en
    const-wide/16 v0, 0x1
    goto :go
    :en
    const-wide/16 v0, 0x0
    :go
    invoke-static {p1, p2, v0, v1}, Lio/github/junkers4/blackbreak/Native;->seconds(JJ)Ljava/lang/String;
    move-result-object v0
    return-object v0
.end method
