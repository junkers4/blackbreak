# The break schedule: a handle on the assembler core's state, a direct buffer.
.class public final Lio/github/junkers4/blackbreak/Scheduler;
.super Ljava/lang/Object;

.field public final buf:Ljava/nio/ByteBuffer;

# Scheduler(now, scale, lastPauseDay): lastPauseDay is a local day number, or Native.NONE
.method public constructor <init>(JDJ)V
    .locals 8
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    invoke-static {}, Lio/github/junkers4/blackbreak/Native;->stateSize()J
    move-result-wide v0
    long-to-int v0, v0
    invoke-static {v0}, Ljava/nio/ByteBuffer;->allocateDirect(I)Ljava/nio/ByteBuffer;
    move-result-object v0
    iput-object v0, p0, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {p3, p4}, Ljava/lang/Double;->doubleToRawLongBits(D)J
    move-result-wide v3
    move-wide v1, p1
    move-wide v5, p5
    invoke-static/range {v0 .. v6}, Lio/github/junkers4/blackbreak/Native;->init(Ljava/nio/ByteBuffer;JJJ)J
    invoke-virtual {p0, p1, p2}, Lio/github/junkers4/blackbreak/Scheduler;->followTimeZone(J)V
    return-void
.end method

# Day numbers follow the local calendar day; summer time changes it.
.method public followTimeZone(J)V
    .locals 4
    invoke-static {}, Ljava/util/TimeZone;->getDefault()Ljava/util/TimeZone;
    move-result-object v0
    invoke-virtual {v0, p1, p2}, Ljava/util/TimeZone;->getOffset(J)I
    move-result v0
    int-to-long v0, v0
    iget-object v2, p0, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {v2, v0, v1}, Lio/github/junkers4/blackbreak/Native;->setTz(Ljava/nio/ByteBuffer;J)J
    return-void
.end method

# the core's getter: 0 phase, 1 canPause, 2 nextBreakAt, 3 breakEndsAt, 4 warningEndsAt, 5 pauseEndsAt, 6 lastPauseDay
.method public get(J)J
    .locals 2
    iget-object v0, p0, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {v0, p1, p2}, Lio/github/junkers4/blackbreak/Native;->get(Ljava/nio/ByteBuffer;J)J
    move-result-wide v0
    return-wide v0
.end method

# 0 work, 1 warning, 2 break, 3 paused
.method public phase()I
    .locals 3
    const-wide/16 v0, 0x0
    invoke-virtual {p0, v0, v1}, Lio/github/junkers4/blackbreak/Scheduler;->get(J)J
    move-result-wide v0
    long-to-int v0, v0
    return v0
.end method

# MENU bits: 1 pause, 2 cancel, 4 settings
.method public menu()J
    .locals 2
    iget-object v0, p0, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {v0}, Lio/github/junkers4/blackbreak/Native;->menu(Ljava/nio/ByteBuffer;)J
    move-result-wide v0
    return-wide v0
.end method

.method public pause(JJ)Z
    .locals 3
    iget-object v0, p0, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {v0, p1, p2, p3, p4}, Lio/github/junkers4/blackbreak/Native;->pause(Ljava/nio/ByteBuffer;JJ)J
    move-result-wide v0
    const-wide/16 v2, 0x1
    cmp-long v0, v0, v2
    if-nez v0, :no
    const/4 v0, 0x1
    return v0
    :no
    const/4 v0, 0x0
    return v0
.end method

.method public cancelPause(J)Z
    .locals 3
    iget-object v0, p0, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {v0, p1, p2}, Lio/github/junkers4/blackbreak/Native;->cancel(Ljava/nio/ByteBuffer;J)J
    move-result-wide v0
    const-wide/16 v2, 0x1
    cmp-long v0, v0, v2
    if-nez v0, :no
    const/4 v0, 0x1
    return v0
    :no
    const/4 v0, 0x0
    return v0
.end method
