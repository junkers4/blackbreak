// jni.S - the JNI entry points the Android app calls (io.github.junkers4.blackbreak.Native).
//
// The state lives in a direct ByteBuffer the app owns, of ST_SIZE_CTL bytes;
// each entry asks the JVM for its address (JNIEnv function 230,
// GetDirectBufferAddress) and calls the core with the rest of the
// arguments. Every argument and result is a jlong, so there are no 32-bit
// values with undefined upper halves.
//
// A JNI call arrives as (JNIEnv *env, jobject Native, jobject buf, a, b, c, d).

#include "core.inc"

    .equ JNI_GET_DIRECT_BUFFER_ADDRESS, 230
    .equ JNI_NEW_STRING_UTF,            167

// BUFCALL name, target - Java_..._name(env, this, buf, x3..x6) -> target(addr, x3..x6)
.macro BUFCALL name, target
    .globl  Java_io_github_junkers4_blackbreak_Native_\name
    .type   Java_io_github_junkers4_blackbreak_Native_\name, %function
    .balign 4
Java_io_github_junkers4_blackbreak_Native_\name:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x19, x3
    mov     x20, x4
    mov     x21, x5
    mov     x22, x6
    ldr     x9, [x0]
    ldr     x9, [x9, #(JNI_GET_DIRECT_BUFFER_ADDRESS * 8)]
    mov     x1, x2
    blr     x9                      // x0 = the state's address
    mov     x1, x19
    mov     x2, x20
    mov     x3, x21
    mov     x4, x22
    bl      \target
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
    .size   Java_io_github_junkers4_blackbreak_Native_\name, . - Java_io_github_junkers4_blackbreak_Native_\name
.endm

    .text
    BUFCALL init, bb_init           // (buf, now, scaleBits, lastPauseDay)
    BUFCALL setTz, bb_set_tz        // (buf, offsetMs)
    BUFCALL update, bb_update       // (buf, now, idleMs, flags) -> phase
    BUFCALL pause, bb_pause         // (buf, durationMs, now) -> 0/1
    BUFCALL cancel, bb_cancel       // (buf, now) -> 0/1
    BUFCALL get, bb_get             // (buf, which) -> value or NONE
    BUFCALL menu, bb_menu           // (buf) -> MENU_* bits
    BUFCALL tick, bb_tick           // (buf, now, idleMs, audioMode, exemption) -> break end or NONE
    BUFCALL screenOn, bb_screen_on  // (buf, now, offMs)
    BUFCALL held, bb_held           // (buf, now) -> 0/1

// long Native.stateSize() - how big the app's buffer must be.
    .globl  Java_io_github_junkers4_blackbreak_Native_stateSize
    .type   Java_io_github_junkers4_blackbreak_Native_stateSize, %function
    .balign 4
Java_io_github_junkers4_blackbreak_Native_stateSize:
    mov     x0, #ST_SIZE_CTL
    ret
    .size   Java_io_github_junkers4_blackbreak_Native_stateSize, . - Java_io_github_junkers4_blackbreak_Native_stateSize

// String Native.seconds(long n, long slovak) - "N seconds" / "N sekúnd".
    .globl  Java_io_github_junkers4_blackbreak_Native_seconds
    .type   Java_io_github_junkers4_blackbreak_Native_seconds, %function
    .balign 4
Java_io_github_junkers4_blackbreak_Native_seconds:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     x19, x0                 // env
    add     x0, sp, #32             // 64 bytes of text
    mov     x1, x2
    mov     x2, x3
    bl      bb_seconds
    add     x1, sp, #32
    strb    wzr, [x1, x0]           // NUL-terminated for NewStringUTF
    mov     x0, x19
    ldr     x9, [x19]
    ldr     x9, [x9, #(JNI_NEW_STRING_UTF * 8)]
    blr     x9
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret
    .size   Java_io_github_junkers4_blackbreak_Native_seconds, . - Java_io_github_junkers4_blackbreak_Native_seconds
