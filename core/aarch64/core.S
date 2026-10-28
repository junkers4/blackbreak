// core.S - the break scheduler, AArch64.
//
// The same rule as x86_64/core.S and linux/.../scheduler.js, line for line,
// held to the same shared cases (core/test/run_core.py, under qemu-aarch64
// on a PC and through JNI on the phone). Times are milliseconds since 1970;
// "scale" divides every duration and is 1 except in tests and fast runs.
//
// Every function is a leaf: x9 = state, x10-x12 = the other arguments,
// d1 = now in bb_update. The two helpers are macros, so nothing calls.

#include "core.inc"

// RESTART dat - a fresh work interval from the time in dat.
.macro RESTART dat
    mov     x13, #PH_WORK
    str     x13, [x9, #ST_PHASE]
    str     \dat, [x9, #ST_WORKSTART]
    str     xzr, [x9, #ST_HASHOLD]
    str     xzr, [x9, #ST_HOLDSPENT]
    str     xzr, [x9, #ST_CALLSEEN]
    str     xzr, [x9, #ST_PHONEHELD]
.endm

// DAY_OF xd, xs - xd = local day number of ms xs: floor((ms + tz) / day).
// Uses x13, x14.
.macro DAY_OF xd, xs
    ldr     x13, [x9, #ST_TZ]
    add     x13, \xs, x13
    movz    x14, #(86400000 & 0xffff)
    movk    x14, #(86400000 >> 16), lsl #16
    sdiv    \xd, x13, x14
    msub    x14, \xd, x14, x13      // remainder
    cmp     x14, #0
    b.ge    .Lday\@
    sub     \xd, \xd, #1            // floor, not truncation, before 1970
.Lday\@:
.endm

    .section .rodata
    .balign 8
k_work:     .double 1200000.0
k_warn:     .double 10000.0
k_break:    .double 30000.0
k_idle:     .double 300000.0
k_maxpause: .double 10800000.0      // also the longest wait for a call

    .text

// void bb_init(state *s, int64 now, double-bits scale, int64 last_pause_day)
    .globl  bb_init
    .type   bb_init, %function
    .balign 4
bb_init:
    mov     x9, x0
    fmov    d1, x2                  // scale
    str     d1, [x9, #ST_SCALE]
    adrp    x13, k_work
    add     x13, x13, :lo12:k_work
    ldr     d0, [x13]
    fdiv    d0, d0, d1
    str     d0, [x9, #ST_WORK]
    ldr     d0, [x13, #8]
    fdiv    d0, d0, d1
    str     d0, [x9, #ST_WARN]
    ldr     d0, [x13, #16]
    fdiv    d0, d0, d1
    str     d0, [x9, #ST_BREAK]
    ldr     d0, [x13, #24]
    fdiv    d0, d0, d1
    str     d0, [x9, #ST_IDLE]
    scvtf   d0, x1
    str     d0, [x9, #ST_LASTNOW]
    RESTART d0
    str     xzr, [x9, #ST_IDLEHELD]
    str     x3, [x9, #ST_LASTPAUSE]
    str     xzr, [x9, #ST_TZ]
    ret
    .size   bb_init, . - bb_init

// void bb_set_tz(state *s, int64 offset_ms)
    .globl  bb_set_tz
    .type   bb_set_tz, %function
    .balign 4
bb_set_tz:
    str     x1, [x0, #ST_TZ]
    ret
    .size   bb_set_tz, . - bb_set_tz

// int bb_pause(state *s, int64 duration_ms, int64 now) -> 1 if paused.
// The duration is scaled like every other; the 3 h cap is checked unscaled.
    .globl  bb_pause
    .type   bb_pause, %function
    .balign 4
bb_pause:
    mov     x9, x0
    mov     x0, #0
    ldr     x13, [x9, #ST_PHASE]
    cmp     x13, #PH_WORK
    b.ne    9f
    cmp     x1, #0
    b.le    9f
    movz    x13, #(10800000 & 0xffff)
    movk    x13, #(10800000 >> 16), lsl #16
    cmp     x1, x13
    b.gt    9f
    DAY_OF  x10, x2
    ldr     x13, [x9, #ST_LASTPAUSE]
    cmp     x10, x13
    b.eq    9f
    str     x10, [x9, #ST_LASTPAUSE]
    mov     x13, #PH_PAUSED
    str     x13, [x9, #ST_PHASE]
    scvtf   d0, x1
    ldr     d2, [x9, #ST_SCALE]
    fdiv    d0, d0, d2
    scvtf   d2, x2
    fadd    d0, d0, d2
    str     d0, [x9, #ST_PAUSEEND]
    mov     x0, #1
9:  ret
    .size   bb_pause, . - bb_pause

// int bb_cancel(state *s, int64 now) -> 1 if a pause was cancelled.
// Cancelling starts a fresh interval; the day's pause stays used.
    .globl  bb_cancel
    .type   bb_cancel, %function
    .balign 4
bb_cancel:
    mov     x9, x0
    mov     x0, #0
    ldr     x13, [x9, #ST_PHASE]
    cmp     x13, #PH_PAUSED
    b.ne    9f
    scvtf   d0, x1
    RESTART d0
    mov     x0, #1
9:  ret
    .size   bb_cancel, . - bb_cancel

// int bb_update(state *s, int64 now, int64 idle_ms, int flags) -> phase.
// flags: IN_CALL (microphone or camera in use, as the settings allow),
// IN_PHONE (a phone call is ringing or going on).
    .globl  bb_update
    .type   bb_update, %function
    .balign 4
bb_update:
    mov     x9, x0
    scvtf   d1, x1                  // now, for the whole function
    adrp    x15, k_maxpause
    add     x15, x15, :lo12:k_maxpause
.Ltop:
    ldr     x13, [x9, #ST_PHASE]
    cmp     x13, #PH_PAUSED
    b.ne    .Lnot_paused

    // Paused: idle input and calls do not matter; only the pause clock.
    ldr     d2, [x9, #ST_LASTNOW]                   // prev
    str     d1, [x9, #ST_LASTNOW]
    str     xzr, [x9, #ST_IDLEHELD]
    fcmp    d1, d2
    b.ge    1f
    // a backward step: never longer than the cap from now
    ldr     d0, [x15]
    ldr     d3, [x9, #ST_SCALE]
    fdiv    d0, d0, d3
    fadd    d0, d0, d1
    ldr     d3, [x9, #ST_PAUSEEND]
    fminnm  d0, d0, d3
    str     d0, [x9, #ST_PAUSEEND]
1:  ldr     d3, [x9, #ST_PAUSEEND]
    fcmp    d1, d3
    b.lt    .Lret_phase                             // still paused
    // Suspended through the end, or idle that long: the rest counts.
    ldr     d4, [x9, #ST_IDLE]
    fsub    d0, d1, d2                              // now - prev
    fcmp    d0, d4
    b.ge    2f
    fsub    d0, d1, d3                              // now - pauseEnd
    fcmp    d0, d4
    b.ge    2f
    fmov    d0, d3                                  // ends at its end
    b       3f
2:  fmov    d0, d1                                  // rested: from now
3:  RESTART d0
    b       .Ltop

.Lnot_paused:
    ldr     d0, [x9, #ST_LASTNOW]
    fsub    d0, d1, d0                              // gap
    str     d1, [x9, #ST_LASTNOW]
    ldr     d4, [x9, #ST_IDLE]
    fcmp    d0, #0.0
    b.lt    .Lrest_now                              // the clock went back
    fcmp    d0, d4
    b.ge    .Lrest_now                              // suspend or a jump

    scvtf   d0, x2                                  // idle_ms
    fcmp    d0, d4
    b.lt    1f
    mov     x13, #1
    str     x13, [x9, #ST_IDLEHELD]
    b       .Lrest_now
1:  ldr     x13, [x9, #ST_IDLEHELD]
    cbz     x13, 2f
    str     xzr, [x9, #ST_IDLEHELD]
    b       .Lrest_now

2:  // A break over by now ends at its end.
    ldr     x13, [x9, #ST_PHASE]
    cmp     x13, #PH_BREAK
    b.ne    3f
    ldr     d0, [x9, #ST_BREAKSTART]
    ldr     d2, [x9, #ST_BREAK]
    fadd    d0, d0, d2
    fcmp    d1, d0
    b.lt    3f
    RESTART d0

3:  // Only the work phase holds; calls in warning or break change nothing.
    ldr     x13, [x9, #ST_PHASE]
    cmp     x13, #PH_WORK
    b.ne    .Lphase
    ldr     x13, [x9, #ST_HOLDSPENT]
    cbnz    x13, .Lphase
    ldr     d2, [x9, #ST_WORKSTART]
    ldr     d0, [x9, #ST_WORK]
    fadd    d2, d2, d0
    ldr     d0, [x9, #ST_WARN]
    fsub    d2, d2, d0                              // dueAt
    fcmp    d1, d2
    b.ge    4f
    // before the warning is due: remember whether a call is on
    tst     x3, #(IN_CALL | IN_PHONE)
    cset    x13, ne
    str     x13, [x9, #ST_CALLSEEN]
    b       .Lphase
4:  ldr     x13, [x9, #ST_HASHOLD]
    cbnz    x13, 5f
    ldr     x13, [x9, #ST_CALLSEEN]
    cbz     x13, .Lphase            // a call first seen once due changes nothing
5:  ldr     d3, [x15]
    ldr     d0, [x9, #ST_SCALE]
    fdiv    d3, d3, d0
    fadd    d3, d3, d2                              // capEnd
    tbnz    x3, #1, 6f                              // IN_PHONE
    tbz     x3, #0, 7f                              // no IN_CALL
    fcmp    d1, d3
    b.ge    7f
6:  // held: the break waits
    str     d2, [x9, #ST_HOLDSINCE]
    mov     x13, #1
    str     x13, [x9, #ST_HASHOLD]
    tbz     x3, #1, .Lret_phase
    str     x13, [x9, #ST_PHONEHELD]
    b       .Lret_phase
7:  ldr     x13, [x9, #ST_HASHOLD]
    cbz     x13, .Lphase
    // Released: the warning starts now (at the cap if it ran out).
    fmov    d0, d1
    tbz     x3, #0, 8f
    ldr     x13, [x9, #ST_PHONEHELD]
    cbnz    x13, 8f
    fmov    d0, d3
8:  ldr     d2, [x9, #ST_WORK]
    fsub    d0, d0, d2
    ldr     d2, [x9, #ST_WARN]
    fadd    d0, d0, d2
    str     d0, [x9, #ST_WORKSTART]
    str     xzr, [x9, #ST_HASHOLD]
    mov     x13, #1
    str     x13, [x9, #ST_HOLDSPENT]
    str     xzr, [x9, #ST_PHONEHELD]

.Lphase:
    ldr     x13, [x9, #ST_PHASE]
    cmp     x13, #PH_BREAK
    b.eq    .Lret_phase
    ldr     d0, [x9, #ST_WORKSTART]
    fsub    d0, d1, d0                              // elapsed
    ldr     d2, [x9, #ST_WORK]
    fcmp    d0, d2
    b.lt    1f
    mov     x13, #PH_BREAK
    str     x13, [x9, #ST_PHASE]
    ldr     d0, [x9, #ST_WORKSTART]
    fadd    d0, d0, d2
    str     d0, [x9, #ST_BREAKSTART]
    ldr     d2, [x9, #ST_BREAK]
    fadd    d0, d0, d2
    fcmp    d1, d0
    b.lt    .Lret_phase
    RESTART d0                      // the whole break already passed
    b       .Lret_phase
1:  ldr     d3, [x9, #ST_WARN]
    fsub    d2, d2, d3
    fcmp    d0, d2
    cset    x13, ge                 // PH_WARNING once the warning is due
    str     x13, [x9, #ST_PHASE]
    b       .Lret_phase

.Lrest_now:
    RESTART d1
.Lret_phase:
    ldr     x0, [x9, #ST_PHASE]
    ret
    .size   bb_update, . - bb_update

// int64 bb_get(state *s, int which) -> the value, or NONE.
    .globl  bb_get
    .type   bb_get, %function
    .balign 4
bb_get:
    mov     x9, x0
    ldr     x10, [x9, #ST_PHASE]
    mov     x0, #NONE
    cmp     x1, #GET_PHASE
    b.ne    1f
    mov     x0, x10
    ret
1:  cmp     x1, #GET_CANPAUSE
    b.ne    2f
    mov     x0, #0
    cbnz    x10, 9f                 // not PH_WORK
    ldr     d0, [x9, #ST_LASTNOW]
    fcvtns  x11, d0
    DAY_OF  x12, x11
    ldr     x13, [x9, #ST_LASTPAUSE]
    cmp     x12, x13
    cset    x0, ne
    ret
2:  cmp     x1, #GET_NEXTBREAK
    b.ne    3f
    cmp     x10, #PH_WARNING
    b.hi    9f
    b       .Lwork_end
3:  cmp     x1, #GET_WARNENDS
    b.ne    4f
    cmp     x10, #PH_WARNING
    b.ne    9f
.Lwork_end:
    ldr     d0, [x9, #ST_WORKSTART]
    ldr     d2, [x9, #ST_WORK]
    fadd    d0, d0, d2
    fcvtns  x0, d0
    ret
4:  cmp     x1, #GET_BREAKENDS
    b.ne    5f
    cmp     x10, #PH_BREAK
    b.ne    9f
    ldr     d0, [x9, #ST_BREAKSTART]
    ldr     d2, [x9, #ST_BREAK]
    fadd    d0, d0, d2
    fcvtns  x0, d0
    ret
5:  cmp     x1, #GET_PAUSEENDS
    b.ne    6f
    cmp     x10, #PH_PAUSED
    b.ne    9f
    ldr     d0, [x9, #ST_PAUSEEND]
    fcvtns  x0, d0
    ret
6:  cmp     x1, #GET_LASTPAUSE
    b.ne    9f
    ldr     x0, [x9, #ST_LASTPAUSE]
9:  ret
    .size   bb_get, . - bb_get

// int bb_menu(state *s) -> MENU_* bits: what the app screen allows now.
// There is nothing that ends a break or turns BlackBreak off.
    .globl  bb_menu
    .type   bb_menu, %function
    .balign 4
bb_menu:
    mov     x9, x0
    mov     x0, #0
    ldr     x10, [x9, #ST_PHASE]
    cmp     x10, #PH_PAUSED
    b.ne    1f
    mov     x0, #(MENU_CANCEL | MENU_SETTINGS)
    ret
1:  cbnz    x10, 9f                 // warning, break: nothing
    mov     x0, #MENU_SETTINGS
    ldr     d0, [x9, #ST_LASTNOW]
    fcvtns  x11, d0
    DAY_OF  x12, x11
    ldr     x13, [x9, #ST_LASTPAUSE]
    cmp     x12, x13
    b.eq    9f
    orr     x0, x0, #MENU_PAUSE
9:  ret
    .size   bb_menu, . - bb_menu

// int bb_in_call(int settings, int mic_in_use, int camera_in_use) -> 1 if
// that counts as a call: the exemption is on, and the microphone is in use
// with "Microphone in use" on, or the camera with "Camera in use" on.
    .globl  bb_in_call
    .type   bb_in_call, %function
    .balign 4
bb_in_call:
    mov     x9, x0
    mov     x0, #0
    tbz     x9, #0, 9f              // SET_EXEMPT
    tbz     x9, #1, 1f              // SET_MIC
    cbnz    x1, 8f
1:  tbz     x9, #2, 9f              // SET_CAMERA
    cbz     x2, 9f
8:  mov     x0, #1
9:  ret
    .size   bb_in_call, . - bb_in_call

// int bb_seconds(char *out, int64 n, int slovak) -> length of the UTF-8
// text "N seconds" / "N sekúnd" (1 sekunda, 2-4 sekundy), not terminated.
    .globl  bb_seconds
    .type   bb_seconds, %function
    .balign 4
bb_seconds:
    mov     x9, x0                  // write pointer
    // the digits, backwards into 24 bytes below sp (a leaf may use them
    // only with sp moved down first)
    sub     sp, sp, #32
    add     x10, sp, #24
    mov     x11, x1
    mov     x12, #10
1:  udiv    x13, x11, x12
    msub    x14, x13, x12, x11
    add     x14, x14, #'0'
    strb    w14, [x10, #-1]!
    mov     x11, x13
    cbnz    x11, 1b
    add     x11, sp, #24
2:  cmp     x10, x11
    b.hs    3f
    ldrb    w14, [x10], #1
    strb    w14, [x9], #1
    b       2b
3:  add     sp, sp, #32
    cbnz    x2, .Lsk
    adrp    x12, s_seconds
    add     x12, x12, :lo12:s_seconds
    cmp     x1, #1
    b.ne    .Lcopy
    adrp    x12, s_second
    add     x12, x12, :lo12:s_second
    b       .Lcopy
.Lsk:
    adrp    x12, s_sekunda
    add     x12, x12, :lo12:s_sekunda
    cmp     x1, #1
    b.eq    .Lcopy
    adrp    x12, s_sekundy
    add     x12, x12, :lo12:s_sekundy
    sub     x13, x1, #2
    cmp     x13, #2
    b.ls    .Lcopy                  // 2, 3, 4
    adrp    x12, s_sekund
    add     x12, x12, :lo12:s_sekund
.Lcopy:
    ldrb    w14, [x12], #1
    cbz     w14, 4f
    strb    w14, [x9], #1
    b       .Lcopy
4:  sub     x0, x9, x0
    ret
    .size   bb_seconds, . - bb_seconds

    .section .rodata
s_second:   .asciz " second"
s_seconds:  .asciz " seconds"
s_sekunda:  .asciz " sekunda"
s_sekundy:  .asciz " sekundy"
s_sekund:   .asciz " sek\xc3\xband"
