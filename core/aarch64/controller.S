// controller.S - what the Android app shows now, from the scheduler and the call state.
//
// The phone's audio mode tells a call without any permission: ringing or in
// a phone call always counts (a phone call always holds a due break), and a
// VoIP call (communication mode) counts when the exemption is on. A phone
// call during a break takes the break's screen away at once and for the
// rest of that break: the dialer is never covered.

#include "core.inc"

    .equ CALL_WATCH_MS, 60000       // calls matter from this long before the warning is due

    .text

// int64 bb_tick(state *s, int64 now, int64 idle_ms, int audio_mode, int exemption)
//   -> the end of the break to show now, or NONE. The warning shows when
//   bb_get(s, GET_PHASE) is PH_WARNING after this call.
    .globl  bb_tick
    .type   bb_tick, %function
    .balign 4
bb_tick:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x19, x0                 // state
    mov     x20, x1                 // now
    mov     x21, x2                 // idle
    // phone: ringing or in a call
    cmp     w3, #MODE_RINGTONE
    ccmp    w3, #MODE_IN_CALL, #4, ne
    cset    x22, eq
    // voip: exemption on, communication mode, and within the call watch
    mov     x9, #0
    cbz     w4, 1f
    cmp     w3, #MODE_IN_COMMUNICATION
    b.ne    1f
    mov     x1, #GET_PHASE
    bl      bb_get                  // (bb_get clobbers x9-x14)
    mov     x9, #0
    cbnz    x0, 1f                  // only the work phase watches
    mov     x0, x19
    mov     x1, #GET_NEXTBREAK
    bl      bb_get
    movz    x9, #((10000 + CALL_WATCH_MS) & 0xffff)
    movk    x9, #((10000 + CALL_WATCH_MS) >> 16), lsl #16
    sub     x0, x0, x9              // unscaled, as before: the watch only starts early
    cmp     x20, x0
    cset    x9, ge
1:  // flags = voip | phone << 1
    orr     x3, x9, x22, lsl #1
    mov     x0, x19
    mov     x1, x20
    mov     x2, x21
    bl      bb_update
    cmp     x0, #PH_BREAK
    b.eq    2f
    str     xzr, [x19, #ST_DISMISSED]
    b       3f
2:  cbz     x22, 3f
    mov     x9, #1
    str     x9, [x19, #ST_DISMISSED]
3:  mov     x9, #NONE
    cmp     x0, #PH_BREAK
    b.ne    4f
    ldr     x10, [x19, #ST_DISMISSED]
    cbnz    x10, 4f
    mov     x0, x19
    mov     x1, #GET_BREAKENDS
    bl      bb_get
    mov     x9, x0
4:  mov     x0, x9
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
    .size   bb_tick, . - bb_tick

// void bb_screen_on(state *s, int64 now, int64 off_ms) - the screen was off
// for off_ms: five minutes or more is rest. Two updates, as with idle input.
    .globl  bb_screen_on
    .type   bb_screen_on, %function
    .balign 4
bb_screen_on:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     x19, x0
    mov     x20, x1
    mov     x3, #0
    bl      bb_update               // (s, now, off_ms, 0)
    mov     x0, x19
    mov     x1, x20
    mov     x2, #0
    mov     x3, #0
    bl      bb_update
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
    .size   bb_screen_on, . - bb_screen_on

// int bb_held(state *s, int64 now) -> 1 while a call keeps a due break waiting.
    .globl  bb_held
    .type   bb_held, %function
    .balign 4
bb_held:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     x19, x0
    mov     x20, x1
    mov     x1, #GET_PHASE
    bl      bb_get
    mov     x9, x0
    mov     x0, #0
    cbnz    x9, 9f                  // only in the work phase
    mov     x0, x19
    mov     x1, #GET_NEXTBREAK
    bl      bb_get
    mov     x9, #10000              // WARN_MS, unscaled
    sub     x0, x0, x9
    cmp     x20, x0
    cset    x0, ge
9:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
    .size   bb_held, . - bb_held
