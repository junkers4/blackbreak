# The foreground service owns the timer, the scheduler and the overlays. It reads no screen content
# and needs no accessibility: the break is a window drawn over other apps.
.class public Lio/github/junkers4/blackbreak/BreakService;
.super Landroid/app/Service;

.field public static instance:Lio/github/junkers4/blackbreak/BreakService;

.field private handler:Landroid/os/Handler;
.field private scheduler:Lio/github/junkers4/blackbreak/Scheduler;
.field private breakOverlay:Lio/github/junkers4/blackbreak/BreakOverlay;
.field private notice:Lio/github/junkers4/blackbreak/NoticeOverlay;
.field private tickRunnable:Ljava/lang/Runnable;
.field private failsafeRunnable:Ljava/lang/Runnable;
.field private receiver:Landroid/content/BroadcastReceiver;
.field private scale:D
.field private exemption:Z
.field private screenOffAt:J
.field private testBreakEndsAt:J

.method public constructor <init>()V
    .locals 2
    invoke-direct {p0}, Landroid/app/Service;-><init>()V
    const-wide/high16 v0, 0x3ff0000000000000L      # scale 1.0
    iput-wide v0, p0, Lio/github/junkers4/blackbreak/BreakService;->scale:D
    return-void
.end method

# a system property, "" when it cannot be read
.method private getprop(Ljava/lang/String;)Ljava/lang/String;
    .locals 6
    :try_start
    invoke-static {}, Ljava/lang/Runtime;->getRuntime()Ljava/lang/Runtime;
    move-result-object v0
    const/4 v1, 0x2
    new-array v1, v1, [Ljava/lang/String;
    const/4 v2, 0x0
    const-string v3, "getprop"
    aput-object v3, v1, v2
    const/4 v2, 0x1
    aput-object p1, v1, v2
    invoke-virtual {v0, v1}, Ljava/lang/Runtime;->exec([Ljava/lang/String;)Ljava/lang/Process;
    move-result-object v0
    invoke-virtual {v0}, Ljava/lang/Process;->getInputStream()Ljava/io/InputStream;
    move-result-object v0
    new-instance v1, Ljava/io/BufferedReader;
    new-instance v2, Ljava/io/InputStreamReader;
    invoke-direct {v2, v0}, Ljava/io/InputStreamReader;-><init>(Ljava/io/InputStream;)V
    invoke-direct {v1, v2}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V
    invoke-virtual {v1}, Ljava/io/BufferedReader;->readLine()Ljava/lang/String;
    move-result-object v0
    if-nez v0, :got
    const-string v0, ""
    :got
    invoke-virtual {v0}, Ljava/lang/String;->trim()Ljava/lang/String;
    move-result-object v0
    return-object v0
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :failed
    :failed
    const-string v0, ""
    return-object v0
.end method

.method private setup()V
    .locals 8
    sput-object p0, Lio/github/junkers4/blackbreak/BreakService;->instance:Lio/github/junkers4/blackbreak/BreakService;

    new-instance v0, Landroid/os/Handler;
    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;
    move-result-object v1
    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V
    iput-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->handler:Landroid/os/Handler;
    new-instance v0, Lio/github/junkers4/blackbreak/BreakService$Tick;
    invoke-direct {v0, p0}, Lio/github/junkers4/blackbreak/BreakService$Tick;-><init>(Lio/github/junkers4/blackbreak/BreakService;)V
    iput-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->tickRunnable:Ljava/lang/Runnable;
    new-instance v0, Lio/github/junkers4/blackbreak/BreakService$Failsafe;
    invoke-direct {v0, p0}, Lio/github/junkers4/blackbreak/BreakService$Failsafe;-><init>(Lio/github/junkers4/blackbreak/BreakService;)V
    iput-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->failsafeRunnable:Ljava/lang/Runnable;

    # debug builds: setprop debug.blackbreak.fast 1 means 60x, any other number is the factor
    invoke-virtual {p0}, Landroid/content/Context;->getApplicationInfo()Landroid/content/pm/ApplicationInfo;
    move-result-object v0
    iget v0, v0, Landroid/content/pm/ApplicationInfo;->flags:I
    and-int/lit8 v0, v0, 0x2
    if-eqz v0, :scale_done
    const-string v0, "debug.blackbreak.fast"
    invoke-direct {p0, v0}, Lio/github/junkers4/blackbreak/BreakService;->getprop(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    const-string v1, "1"
    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v1
    if-eqz v1, :parse
    const-wide/high16 v2, 0x404e000000000000L      # 60.0
    iput-wide v2, p0, Lio/github/junkers4/blackbreak/BreakService;->scale:D
    goto :scale_done
    :parse
    :try_start
    invoke-static {v0}, Ljava/lang/Double;->parseDouble(Ljava/lang/String;)D
    move-result-wide v2
    const-wide/high16 v4, 0x3ff0000000000000L
    cmpl-double v6, v2, v4
    if-lez v6, :scale_done
    iput-wide v2, p0, Lio/github/junkers4/blackbreak/BreakService;->scale:D
    :try_end
    .catch Ljava/lang/NumberFormatException; {:try_start .. :try_end} :scale_done
    :scale_done

    # the overlays, from the window manager of this service
    const-string v0, "window"
    invoke-virtual {p0, v0}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v0
    check-cast v0, Landroid/view/WindowManager;
    new-instance v1, Lio/github/junkers4/blackbreak/BreakOverlay;
    invoke-direct {v1, p0, v0}, Lio/github/junkers4/blackbreak/BreakOverlay;-><init>(Landroid/content/Context;Landroid/view/WindowManager;)V
    iput-object v1, p0, Lio/github/junkers4/blackbreak/BreakService;->breakOverlay:Lio/github/junkers4/blackbreak/BreakOverlay;
    new-instance v1, Lio/github/junkers4/blackbreak/NoticeOverlay;
    invoke-direct {v1, p0, v0}, Lio/github/junkers4/blackbreak/NoticeOverlay;-><init>(Landroid/content/Context;Landroid/view/WindowManager;)V
    iput-object v1, p0, Lio/github/junkers4/blackbreak/BreakService;->notice:Lio/github/junkers4/blackbreak/NoticeOverlay;

    # the scheduler, with the day of the last pause from the preferences
    const-string v0, "blackbreak"
    const/4 v1, 0x0
    invoke-virtual {p0, v0, v1}, Landroid/content/Context;->getSharedPreferences(Ljava/lang/String;I)Landroid/content/SharedPreferences;
    move-result-object v0
    const-string v1, "lastPauseDayNumber"
    const-wide/high16 v2, -0x8000000000000000L
    invoke-interface {v0, v1, v2, v3}, Landroid/content/SharedPreferences;->getLong(Ljava/lang/String;J)J
    move-result-wide v5
    new-instance v0, Lio/github/junkers4/blackbreak/Scheduler;
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v1
    iget-wide v3, p0, Lio/github/junkers4/blackbreak/BreakService;->scale:D
    invoke-direct/range {v0 .. v6}, Lio/github/junkers4/blackbreak/Scheduler;-><init>(JDJ)V
    iput-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->scheduler:Lio/github/junkers4/blackbreak/Scheduler;
    # a restart by the system goes on with the saved interval (Keep)
    iget-object v0, v0, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {p0, v0}, Lio/github/junkers4/blackbreak/Keep;->restore(Landroid/content/Context;Ljava/nio/ByteBuffer;)V

    # screen on and off
    new-instance v0, Lio/github/junkers4/blackbreak/BreakService$Screen;
    invoke-direct {v0, p0}, Lio/github/junkers4/blackbreak/BreakService$Screen;-><init>(Lio/github/junkers4/blackbreak/BreakService;)V
    iput-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->receiver:Landroid/content/BroadcastReceiver;
    new-instance v1, Landroid/content/IntentFilter;
    invoke-direct {v1}, Landroid/content/IntentFilter;-><init>()V
    const-string v2, "android.intent.action.SCREEN_OFF"
    invoke-virtual {v1, v2}, Landroid/content/IntentFilter;->addAction(Ljava/lang/String;)V
    const-string v2, "android.intent.action.SCREEN_ON"
    invoke-virtual {v1, v2}, Landroid/content/IntentFilter;->addAction(Ljava/lang/String;)V
    invoke-virtual {p0, v0, v1}, Landroid/content/Context;->registerReceiver(Landroid/content/BroadcastReceiver;Landroid/content/IntentFilter;)Landroid/content/Intent;

    invoke-virtual {p0}, Lio/github/junkers4/blackbreak/BreakService;->tick()V
    return-void
.end method

.method public tick()V
    .locals 14
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->handler:Landroid/os/Handler;
    iget-object v1, p0, Lio/github/junkers4/blackbreak/BreakService;->tickRunnable:Ljava/lang/Runnable;
    invoke-virtual {v0, v1}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v2                          # now (v2,v3)
    iget-object v4, p0, Lio/github/junkers4/blackbreak/BreakService;->scheduler:Lio/github/junkers4/blackbreak/Scheduler;
    invoke-virtual {v4, v2, v3}, Lio/github/junkers4/blackbreak/Scheduler;->followTimeZone(J)V

    # the call settings are read in a normal work interval only
    invoke-virtual {v4}, Lio/github/junkers4/blackbreak/Scheduler;->phase()I
    move-result v7
    if-nez v7, :audio
    const-string v7, "blackbreak"
    const/4 v8, 0x0
    invoke-virtual {p0, v7, v8}, Landroid/content/Context;->getSharedPreferences(Ljava/lang/String;I)Landroid/content/SharedPreferences;
    move-result-object v7
    const-string v8, "callExemption"
    const/4 v9, 0x0
    invoke-interface {v7, v8, v9}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z
    move-result v7
    iput-boolean v7, p0, Lio/github/junkers4/blackbreak/BreakService;->exemption:Z
    :audio

    # the audio mode tells a call, with no permission: Native.tick(buf, now, idle, mode, exemption)
    const-string v7, "audio"
    invoke-virtual {p0, v7}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v7
    check-cast v7, Landroid/media/AudioManager;
    invoke-virtual {v7}, Landroid/media/AudioManager;->getMode()I
    move-result v7
    invoke-static {p0, v7}, Lio/github/junkers4/blackbreak/Options;->mode(Landroid/content/Context;I)I
    move-result v7
    iget-boolean v8, p0, Lio/github/junkers4/blackbreak/BreakService;->exemption:Z
    invoke-static {p0, v8}, Lio/github/junkers4/blackbreak/Options;->exemption(Landroid/content/Context;Z)Z
    move-result v8
    invoke-static {v4, v2, v3, v7, v8}, Lio/github/junkers4/blackbreak/BreakService;->nativeTick(Lio/github/junkers4/blackbreak/Scheduler;JII)J
    move-result-wide v5                          # the end of the break to show, or NONE (v5,v6)
    iget-object v7, v4, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    const/4 v8, 0x0
    invoke-static {p0, v7, v2, v3, v8}, Lio/github/junkers4/blackbreak/Keep;->save(Landroid/content/Context;Ljava/nio/ByteBuffer;JZ)V

    # the warning
    invoke-virtual {v4}, Lio/github/junkers4/blackbreak/Scheduler;->phase()I
    move-result v7
    iget-object v8, p0, Lio/github/junkers4/blackbreak/BreakService;->notice:Lio/github/junkers4/blackbreak/NoticeOverlay;
    const/4 v9, 0x1
    if-ne v7, v9, :no_notice
    invoke-static {p0}, Lio/github/junkers4/blackbreak/Options;->showWarning(Landroid/content/Context;)Z
    move-result v9
    if-eqz v9, :no_notice
    invoke-virtual {v8}, Lio/github/junkers4/blackbreak/NoticeOverlay;->show()V
    goto :notice_done
    :no_notice
    invoke-virtual {v8}, Lio/github/junkers4/blackbreak/NoticeOverlay;->hide()V
    :notice_done

    # a break shown for the tests runs to its own end
    iget-wide v7, p0, Lio/github/junkers4/blackbreak/BreakService;->testBreakEndsAt:J
    const-wide/16 v9, 0x0
    cmp-long v11, v7, v9
    if-eqz v11, :no_test
    cmp-long v11, v2, v7
    if-gez v11, :test_over
    sub-long v9, v7, v2
    const-wide/16 v11, 0x3e7
    add-long/2addr v9, v11
    const-wide/16 v11, 0x3e8
    div-long/2addr v9, v11
    iget-object v11, p0, Lio/github/junkers4/blackbreak/BreakService;->breakOverlay:Lio/github/junkers4/blackbreak/BreakOverlay;
    invoke-virtual {v11, v9, v10}, Lio/github/junkers4/blackbreak/BreakOverlay;->update(J)V
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->handler:Landroid/os/Handler;
    iget-object v1, p0, Lio/github/junkers4/blackbreak/BreakService;->tickRunnable:Ljava/lang/Runnable;
    const-wide/16 v7, 0x3e8
    invoke-virtual {v0, v1, v7, v8}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
    return-void
    :test_over
    const-wide/16 v7, 0x0
    iput-wide v7, p0, Lio/github/junkers4/blackbreak/BreakService;->testBreakEndsAt:J
    :no_test

    # the break screen
    iget-object v7, p0, Lio/github/junkers4/blackbreak/BreakService;->breakOverlay:Lio/github/junkers4/blackbreak/BreakOverlay;
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->handler:Landroid/os/Handler;
    iget-object v1, p0, Lio/github/junkers4/blackbreak/BreakService;->failsafeRunnable:Ljava/lang/Runnable;
    const-wide/high16 v8, -0x8000000000000000L
    cmp-long v10, v5, v8
    if-eqz v10, :hide
    invoke-virtual {v7}, Lio/github/junkers4/blackbreak/BreakOverlay;->isShown()Z
    move-result v10
    if-nez v10, :show
    # the independent fail-safe is armed before the view is added: start = ends - round(30000 / scale)
    invoke-virtual {v0, v1}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V
    const-wide v10, 0x40dd4c0000000000L           # 30000.0
    iget-wide v12, p0, Lio/github/junkers4/blackbreak/BreakService;->scale:D
    div-double/2addr v10, v12
    invoke-static {v10, v11}, Ljava/lang/Math;->round(D)J
    move-result-wide v10
    sub-long v10, v5, v10                         # start
    const-wide/16 v12, 0x88b8                     # 35000
    add-long/2addr v10, v12
    sub-long/2addr v10, v2
    const-wide/16 v12, 0x1
    invoke-static {v10, v11, v12, v13}, Ljava/lang/Math;->max(JJ)J
    move-result-wide v10
    invoke-virtual {v0, v1, v10, v11}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
    :show
    sub-long v10, v5, v2
    const-wide/16 v12, 0x3e7
    add-long/2addr v10, v12
    const-wide/16 v12, 0x3e8
    div-long/2addr v10, v12
    invoke-virtual {v7, v10, v11}, Lio/github/junkers4/blackbreak/BreakOverlay;->show(J)V
    goto :scheduled
    :hide
    invoke-virtual {v0, v1}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V
    invoke-virtual {v7}, Lio/github/junkers4/blackbreak/BreakOverlay;->hide()V
    :scheduled

    # the next tick: every second, 50 ms in fast debug runs; none while the screen is off
    iget-wide v7, p0, Lio/github/junkers4/blackbreak/BreakService;->screenOffAt:J
    const-wide/16 v9, 0x0
    cmp-long v7, v7, v9
    if-nez v7, :done
    const-wide/16 v7, 0x3e8
    iget-wide v9, p0, Lio/github/junkers4/blackbreak/BreakService;->scale:D
    const-wide/high16 v11, 0x3ff0000000000000L
    cmpl-double v9, v9, v11
    if-lez v9, :every_second
    const-wide/16 v7, 0x32
    :every_second
    iget-object v1, p0, Lio/github/junkers4/blackbreak/BreakService;->tickRunnable:Ljava/lang/Runnable;
    invoke-virtual {v0, v1, v7, v8}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
    :done
    return-void
.end method

.method public failsafe()V
    .locals 2
    const-wide/16 v0, 0x0
    iput-wide v0, p0, Lio/github/junkers4/blackbreak/BreakService;->testBreakEndsAt:J
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->breakOverlay:Lio/github/junkers4/blackbreak/BreakOverlay;
    invoke-virtual {v0}, Lio/github/junkers4/blackbreak/BreakOverlay;->hide()V
    return-void
.end method

# the screen went off (false) or on (true); five minutes or more off is rest
.method public onScreen(Z)V
    .locals 8
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v0
    if-eqz p1, :off
    iget-wide v2, p0, Lio/github/junkers4/blackbreak/BreakService;->screenOffAt:J
    const-wide/16 v4, 0x0
    cmp-long v6, v2, v4
    if-eqz v6, :on_tick
    sub-long v2, v0, v2
    iget-object v6, p0, Lio/github/junkers4/blackbreak/BreakService;->scheduler:Lio/github/junkers4/blackbreak/Scheduler;
    iget-object v6, v6, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {v6, v0, v1, v2, v3}, Lio/github/junkers4/blackbreak/Native;->screenOn(Ljava/nio/ByteBuffer;JJ)J
    :on_tick
    const-wide/16 v4, 0x0
    iput-wide v4, p0, Lio/github/junkers4/blackbreak/BreakService;->screenOffAt:J
    invoke-virtual {p0}, Lio/github/junkers4/blackbreak/BreakService;->tick()V
    return-void
    :off
    iput-wide v0, p0, Lio/github/junkers4/blackbreak/BreakService;->screenOffAt:J
    iget-object v2, p0, Lio/github/junkers4/blackbreak/BreakService;->scheduler:Lio/github/junkers4/blackbreak/Scheduler;
    iget-object v2, v2, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    const/4 v3, 0x1
    invoke-static {p0, v2, v0, v1, v3}, Lio/github/junkers4/blackbreak/Keep;->save(Landroid/content/Context;Ljava/nio/ByteBuffer;JZ)V
    iget-object v2, p0, Lio/github/junkers4/blackbreak/BreakService;->handler:Landroid/os/Handler;
    iget-object v3, p0, Lio/github/junkers4/blackbreak/BreakService;->tickRunnable:Ljava/lang/Runnable;
    invoke-virtual {v2, v3}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V
    return-void
.end method

# Native.tick(buf, now, idle, mode, exemption); the idle time is 0, the screen on/off events cover it
.method private static nativeTick(Lio/github/junkers4/blackbreak/Scheduler;JII)J
    .locals 10
    iget-object v1, p0, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    move-wide v2, p1
    const-wide/16 v4, 0x0
    int-to-long v6, p3
    int-to-long v8, p4
    invoke-static/range {v1 .. v9}, Lio/github/junkers4/blackbreak/Native;->tick(Ljava/nio/ByteBuffer;JJJJ)J
    move-result-wide v0
    return-wide v0
.end method

# Pause for the given minutes; false when it is not allowed now.
.method public pause(I)Z
    .locals 9
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v0
    iget-object v2, p0, Lio/github/junkers4/blackbreak/BreakService;->scheduler:Lio/github/junkers4/blackbreak/Scheduler;
    int-to-long v3, p1
    const-wide/32 v5, 0xea60
    mul-long/2addr v3, v5
    invoke-virtual {v2, v3, v4, v0, v1}, Lio/github/junkers4/blackbreak/Scheduler;->pause(JJ)Z
    move-result v3
    if-nez v3, :ok
    const/4 v0, 0x0
    return v0
    :ok
    const-string v3, "blackbreak"
    const/4 v4, 0x0
    invoke-virtual {p0, v3, v4}, Landroid/content/Context;->getSharedPreferences(Ljava/lang/String;I)Landroid/content/SharedPreferences;
    move-result-object v3
    invoke-interface {v3}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;
    move-result-object v3
    const-string v4, "lastPauseDayNumber"
    const-wide/16 v5, 0x6
    invoke-virtual {v2, v5, v6}, Lio/github/junkers4/blackbreak/Scheduler;->get(J)J
    move-result-wide v5
    invoke-interface {v3, v4, v5, v6}, Landroid/content/SharedPreferences$Editor;->putLong(Ljava/lang/String;J)Landroid/content/SharedPreferences$Editor;
    move-result-object v3
    invoke-interface {v3}, Landroid/content/SharedPreferences$Editor;->apply()V
    invoke-virtual {p0}, Lio/github/junkers4/blackbreak/BreakService;->tick()V
    const/4 v0, 0x1
    return v0
.end method

.method public cancelPause()V
    .locals 4
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v0
    iget-object v2, p0, Lio/github/junkers4/blackbreak/BreakService;->scheduler:Lio/github/junkers4/blackbreak/Scheduler;
    invoke-virtual {v2, v0, v1}, Lio/github/junkers4/blackbreak/Scheduler;->cancelPause(J)Z
    invoke-virtual {p0}, Lio/github/junkers4/blackbreak/BreakService;->tick()V
    return-void
.end method

# true while a call keeps a due break waiting
.method public held()Z
    .locals 5
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v0
    iget-object v2, p0, Lio/github/junkers4/blackbreak/BreakService;->scheduler:Lio/github/junkers4/blackbreak/Scheduler;
    iget-object v2, v2, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {v2, v0, v1}, Lio/github/junkers4/blackbreak/Native;->held(Ljava/nio/ByteBuffer;J)J
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

.method public scheduler()Lio/github/junkers4/blackbreak/Scheduler;
    .locals 1
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->scheduler:Lio/github/junkers4/blackbreak/Scheduler;
    return-object v0
.end method

.method public breakOverlay()Lio/github/junkers4/blackbreak/BreakOverlay;
    .locals 1
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->breakOverlay:Lio/github/junkers4/blackbreak/BreakOverlay;
    return-object v0
.end method

# Tests only (the debug receiver calls this): the break now, to endsAt, with the fail-safe at failsafeAt.
.method public showTestBreak(JJ)V
    .locals 8
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v0
    iput-wide p1, p0, Lio/github/junkers4/blackbreak/BreakService;->testBreakEndsAt:J
    iget-object v2, p0, Lio/github/junkers4/blackbreak/BreakService;->handler:Landroid/os/Handler;
    iget-object v3, p0, Lio/github/junkers4/blackbreak/BreakService;->failsafeRunnable:Ljava/lang/Runnable;
    invoke-virtual {v2, v3}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V
    sub-long v4, p3, v0
    const-wide/16 v6, 0x1
    invoke-static {v4, v5, v6, v7}, Ljava/lang/Math;->max(JJ)J
    move-result-wide v4
    invoke-virtual {v2, v3, v4, v5}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
    sub-long v4, p1, v0
    const-wide/16 v6, 0x3e7
    add-long/2addr v4, v6
    const-wide/16 v6, 0x3e8
    div-long/2addr v4, v6
    iget-object v2, p0, Lio/github/junkers4/blackbreak/BreakService;->breakOverlay:Lio/github/junkers4/blackbreak/BreakOverlay;
    invoke-virtual {v2, v4, v5}, Lio/github/junkers4/blackbreak/BreakOverlay;->show(J)V
    invoke-virtual {p0}, Lio/github/junkers4/blackbreak/BreakService;->tick()V
    return-void
.end method

# While the break is shown, every key is taken; the power button never reaches this.
.method public onBind(Landroid/content/Intent;)Landroid/os/IBinder;
    .locals 1
    const/4 v0, 0x0
    return-object v0
.end method

# started from the app or after boot: the notification first (the system gives five seconds), then the setup once
.method public onStartCommand(Landroid/content/Intent;II)I
    .locals 1
    invoke-static {p0}, Lio/github/junkers4/blackbreak/Notifier;->start(Landroid/app/Service;)V
    sget-object v0, Lio/github/junkers4/blackbreak/BreakService;->instance:Lio/github/junkers4/blackbreak/BreakService;
    if-nez v0, :running
    invoke-direct {p0}, Lio/github/junkers4/blackbreak/BreakService;->setup()V
    :running
    const/4 v0, 0x1
    return v0
.end method

.method public onDestroy()V
    .locals 0
    invoke-direct {p0}, Lio/github/junkers4/blackbreak/BreakService;->shutdown()V
    invoke-super {p0}, Landroid/app/Service;->onDestroy()V
    return-void
.end method

# no views, no callbacks and no receiver outlive the service
.method private shutdown()V
    .locals 4
    const/4 v0, 0x0
    sput-object v0, Lio/github/junkers4/blackbreak/BreakService;->instance:Lio/github/junkers4/blackbreak/BreakService;
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->scheduler:Lio/github/junkers4/blackbreak/Scheduler;
    if-eqz v0, :saved
    iget-object v0, v0, Lio/github/junkers4/blackbreak/Scheduler;->buf:Ljava/nio/ByteBuffer;
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v1
    const/4 v3, 0x1
    invoke-static {p0, v0, v1, v2, v3}, Lio/github/junkers4/blackbreak/Keep;->save(Landroid/content/Context;Ljava/nio/ByteBuffer;JZ)V
    :saved
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->handler:Landroid/os/Handler;
    if-eqz v0, :handler_done
    const/4 v1, 0x0
    invoke-virtual {v0, v1}, Landroid/os/Handler;->removeCallbacksAndMessages(Ljava/lang/Object;)V
    :handler_done
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->breakOverlay:Lio/github/junkers4/blackbreak/BreakOverlay;
    if-eqz v0, :overlays_done
    invoke-virtual {v0}, Lio/github/junkers4/blackbreak/BreakOverlay;->hide()V
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->notice:Lio/github/junkers4/blackbreak/NoticeOverlay;
    invoke-virtual {v0}, Lio/github/junkers4/blackbreak/NoticeOverlay;->hide()V
    :try_start
    iget-object v0, p0, Lio/github/junkers4/blackbreak/BreakService;->receiver:Landroid/content/BroadcastReceiver;
    invoke-virtual {p0, v0}, Landroid/content/Context;->unregisterReceiver(Landroid/content/BroadcastReceiver;)V
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :overlays_done
    :overlays_done
    return-void
.end method
