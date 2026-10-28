# The assembler core (core/aarch64/*.S), through JNI. Every value is a long.
.class public final Lio/github/junkers4/blackbreak/Native;
.super Ljava/lang/Object;

.field public static final NONE:J = -0x8000000000000000L

.method static constructor <clinit>()V
    .locals 1
    const-string v0, "blackbreak"
    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
    return-void
.end method

.method public static native stateSize()J
.end method

.method public static native init(Ljava/nio/ByteBuffer;JJJ)J
.end method

.method public static native setTz(Ljava/nio/ByteBuffer;J)J
.end method

.method public static native update(Ljava/nio/ByteBuffer;JJJ)J
.end method

.method public static native pause(Ljava/nio/ByteBuffer;JJ)J
.end method

.method public static native cancel(Ljava/nio/ByteBuffer;J)J
.end method

.method public static native get(Ljava/nio/ByteBuffer;J)J
.end method

.method public static native menu(Ljava/nio/ByteBuffer;)J
.end method

.method public static native tick(Ljava/nio/ByteBuffer;JJJJ)J
.end method

.method public static native screenOn(Ljava/nio/ByteBuffer;JJ)J
.end method

.method public static native held(Ljava/nio/ByteBuffer;J)J
.end method

.method public static native seconds(JJ)Ljava/lang/String;
.end method
