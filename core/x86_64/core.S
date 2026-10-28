// core.S - the break scheduler, x86-64.
//
// Every 20 minutes of work a break of 30 seconds; 10 seconds before it a
// warning. Five minutes of idle, a suspend or a clock step counts as rest
// and the 20 minutes start again. One pause a day, up to 3 hours, and only
// in the work phase. With the call exemption on, a call that was already
// going before the warning was due holds the break, for at most 3 hours; a
// phone call (Android) holds it for as long as it lasts.
//
// This is the same rule as linux/.../scheduler.js, line for line, and it
// is held to the same shared cases: spec/scenarios.json and spec/traces.json
// (core/test/run_core.py). Times are milliseconds since 1970. "scale"
// divides every duration; it is 1 except in tests and fast debug runs.

#include "core.inc"

    .section .rodata
    .balign 8
k_work:     .double 1200000.0
k_warn:     .double 10000.0
k_break:    .double 30000.0
k_idle:     .double 300000.0
k_maxpause: .double 10800000.0      // also the longest wait for a call

    .text

// restart(r10 = state, xmm0 = at) - a fresh work interval from "at".
// Clobbers nothing but the state.
    .balign 16
restart:
    mov     qword ptr [r10 + ST_PHASE], PH_WORK
    movsd   qword ptr [r10 + ST_WORKSTART], xmm0
    mov     qword ptr [r10 + ST_HASHOLD], 0
    mov     qword ptr [r10 + ST_HOLDSPENT], 0
    mov     qword ptr [r10 + ST_CALLSEEN], 0
    mov     qword ptr [r10 + ST_PHONEHELD], 0
    ret

// day_of(r10 = state, rax = ms) -> rax = local day number, floor((ms + tz) / day).
// Clobbers rcx, rdx.
    .balign 16
day_of:
    add     rax, [r10 + ST_TZ]
    mov     rcx, 86400000
    cqo
    idiv    rcx
    test    rdx, rdx
    jns     1f
    dec     rax                     // floor, not truncation, before 1970
1:  ret

// void bb_init(state *s, int64 now, double-bits scale, int64 last_pause_day)
// The scale arrives as the bits of a double in an integer register, so
// that both calling conventions pass it the same way.
    .globl  bb_init
    .balign 16
bb_init:
    ARGS
    movq    xmm1, r8                // scale
    movsd   qword ptr [r10 + ST_SCALE], xmm1
    movsd   xmm0, qword ptr [rip + k_work]
    divsd   xmm0, xmm1
    movsd   qword ptr [r10 + ST_WORK], xmm0
    movsd   xmm0, qword ptr [rip + k_warn]
    divsd   xmm0, xmm1
    movsd   qword ptr [r10 + ST_WARN], xmm0
    movsd   xmm0, qword ptr [rip + k_break]
    divsd   xmm0, xmm1
    movsd   qword ptr [r10 + ST_BREAK], xmm0
    movsd   xmm0, qword ptr [rip + k_idle]
    divsd   xmm0, xmm1
    movsd   qword ptr [r10 + ST_IDLE], xmm0
    cvtsi2sd xmm0, r11              // now
    movsd   qword ptr [r10 + ST_LASTNOW], xmm0
    call    restart
    mov     qword ptr [r10 + ST_IDLEHELD], 0
    mov     [r10 + ST_LASTPAUSE], r9
    mov     qword ptr [r10 + ST_TZ], 0
    ret

// void bb_set_tz(state *s, int64 offset_ms) - the local offset for day numbers.
    .globl  bb_set_tz
    .balign 16
bb_set_tz:
    ARGS
    mov     [r10 + ST_TZ], r11
    ret

// int bb_pause(state *s, int64 duration_ms, int64 now) -> 1 if paused.
// The duration is scaled like every other; the 3 h cap is checked unscaled.
    .globl  bb_pause
    .balign 16
bb_pause:
    ARGS
    xor     eax, eax
    cmp     qword ptr [r10 + ST_PHASE], PH_WORK
    jne     9f
    test    r11, r11
    jle     9f
    cmp     r11, 10800000
    jg      9f
    mov     rax, r8
    call    day_of
    cmp     rax, [r10 + ST_LASTPAUSE]
    je      8f
    mov     [r10 + ST_LASTPAUSE], rax
    mov     qword ptr [r10 + ST_PHASE], PH_PAUSED
    cvtsi2sd xmm0, r11
    divsd   xmm0, qword ptr [r10 + ST_SCALE]
    cvtsi2sd xmm1, r8
    addsd   xmm0, xmm1
    movsd   qword ptr [r10 + ST_PAUSEEND], xmm0
    mov     eax, 1
    ret
8:  xor     eax, eax
9:  ret

// int bb_cancel(state *s, int64 now) -> 1 if a pause was cancelled.
// Cancelling starts a fresh interval; the day's pause stays used.
    .globl  bb_cancel
    .balign 16
bb_cancel:
    ARGS
    xor     eax, eax
    cmp     qword ptr [r10 + ST_PHASE], PH_PAUSED
    jne     9f
    cvtsi2sd xmm0, r11
    call    restart
    mov     eax, 1
9:  ret

// int bb_update(state *s, int64 now, int64 idle_ms, int flags) -> phase.
// flags: IN_CALL (microphone or camera in use, as the settings allow),
// IN_PHONE (a phone call is ringing or going on).
//   xmm1 = now, held for the whole function
    .globl  bb_update
    .balign 16
bb_update:
    ARGS
    cvtsi2sd xmm1, r11
.Ltop:
    cmp     qword ptr [r10 + ST_PHASE], PH_PAUSED
    jne     .Lnot_paused

    // Paused: idle input and calls do not matter; only the pause clock.
    movsd   xmm2, qword ptr [r10 + ST_LASTNOW]      // prev
    movsd   qword ptr [r10 + ST_LASTNOW], xmm1
    mov     qword ptr [r10 + ST_IDLEHELD], 0
    ucomisd xmm1, xmm2
    jae     1f
    // a backward step: never longer than the cap from now
    movsd   xmm0, qword ptr [rip + k_maxpause]
    divsd   xmm0, qword ptr [r10 + ST_SCALE]
    addsd   xmm0, xmm1
    minsd   xmm0, qword ptr [r10 + ST_PAUSEEND]
    movsd   qword ptr [r10 + ST_PAUSEEND], xmm0
1:  movsd   xmm3, qword ptr [r10 + ST_PAUSEEND]
    ucomisd xmm1, xmm3
    jb      .Lret_phase                             // still paused
    // Suspended through the end, or idle that long: the rest counts.
    movsd   xmm0, xmm1
    subsd   xmm0, xmm2                              // now - prev
    ucomisd xmm0, qword ptr [r10 + ST_IDLE]
    jae     2f
    movsd   xmm0, xmm1
    subsd   xmm0, xmm3                              // now - pauseEnd
    ucomisd xmm0, qword ptr [r10 + ST_IDLE]
    jae     2f
    movsd   xmm0, xmm3                              // ends at its end
    jmp     3f
2:  movsd   xmm0, xmm1                              // rested: from now
3:  call    restart
    jmp     .Ltop

.Lnot_paused:
    movsd   xmm0, xmm1
    subsd   xmm0, qword ptr [r10 + ST_LASTNOW]      // gap
    movsd   qword ptr [r10 + ST_LASTNOW], xmm1
    xorpd   xmm2, xmm2
    ucomisd xmm0, xmm2
    jb      .Lrest_now                              // the clock went back
    ucomisd xmm0, qword ptr [r10 + ST_IDLE]
    jae     .Lrest_now                              // suspend or a jump

    cvtsi2sd xmm0, r8                               // idle_ms
    ucomisd xmm0, qword ptr [r10 + ST_IDLE]
    jb      1f
    mov     qword ptr [r10 + ST_IDLEHELD], 1
    jmp     .Lrest_now
1:  cmp     qword ptr [r10 + ST_IDLEHELD], 0
    je      2f
    mov     qword ptr [r10 + ST_IDLEHELD], 0
    jmp     .Lrest_now

2:  // A break over by now ends at its end.
    cmp     qword ptr [r10 + ST_PHASE], PH_BREAK
    jne     3f
    movsd   xmm0, qword ptr [r10 + ST_BREAKSTART]
    addsd   xmm0, qword ptr [r10 + ST_BREAK]
    ucomisd xmm1, xmm0
    jb      3f
    call    restart

3:  // Only the work phase holds; calls in warning or break change nothing.
    cmp     qword ptr [r10 + ST_PHASE], PH_WORK
    jne     .Lphase
    cmp     qword ptr [r10 + ST_HOLDSPENT], 0
    jne     .Lphase
    movsd   xmm2, qword ptr [r10 + ST_WORKSTART]
    addsd   xmm2, qword ptr [r10 + ST_WORK]
    subsd   xmm2, qword ptr [r10 + ST_WARN]         // dueAt
    ucomisd xmm1, xmm2
    jae     4f
    // before the warning is due: remember whether a call is on
    xor     eax, eax
    test    r9, IN_CALL | IN_PHONE
    setnz   al
    mov     [r10 + ST_CALLSEEN], rax
    jmp     .Lphase
4:  cmp     qword ptr [r10 + ST_HASHOLD], 0
    jne     5f
    cmp     qword ptr [r10 + ST_CALLSEEN], 0
    je      .Lphase                 // a call first seen once due changes nothing
5:  movsd   xmm3, qword ptr [rip + k_maxpause]
    divsd   xmm3, qword ptr [r10 + ST_SCALE]
    addsd   xmm3, xmm2                              // capEnd
    test    r9, IN_PHONE
    jnz     6f
    test    r9, IN_CALL
    jz      7f
    ucomisd xmm1, xmm3
    jae     7f
6:  // held: the break waits
    movsd   qword ptr [r10 + ST_HOLDSINCE], xmm2
    mov     qword ptr [r10 + ST_HASHOLD], 1
    test    r9, IN_PHONE
    jz      .Lret_phase
    mov     qword ptr [r10 + ST_PHONEHELD], 1
    jmp     .Lret_phase
7:  cmp     qword ptr [r10 + ST_HASHOLD], 0
    je      .Lphase
    // Released: the warning starts now (at the cap if it ran out).
    movsd   xmm0, xmm1
    test    r9, IN_CALL
    jz      8f
    cmp     qword ptr [r10 + ST_PHONEHELD], 0
    jne     8f
    movsd   xmm0, xmm3
8:  subsd   xmm0, qword ptr [r10 + ST_WORK]
    addsd   xmm0, qword ptr [r10 + ST_WARN]
    movsd   qword ptr [r10 + ST_WORKSTART], xmm0
    mov     qword ptr [r10 + ST_HASHOLD], 0
    mov     qword ptr [r10 + ST_HOLDSPENT], 1
    mov     qword ptr [r10 + ST_PHONEHELD], 0

.Lphase:
    cmp     qword ptr [r10 + ST_PHASE], PH_BREAK
    je      .Lret_phase
    movsd   xmm0, xmm1
    subsd   xmm0, qword ptr [r10 + ST_WORKSTART]    // elapsed
    ucomisd xmm0, qword ptr [r10 + ST_WORK]
    jb      1f
    mov     qword ptr [r10 + ST_PHASE], PH_BREAK
    movsd   xmm0, qword ptr [r10 + ST_WORKSTART]
    addsd   xmm0, qword ptr [r10 + ST_WORK]
    movsd   qword ptr [r10 + ST_BREAKSTART], xmm0
    addsd   xmm0, qword ptr [r10 + ST_BREAK]
    ucomisd xmm1, xmm0
    jb      .Lret_phase
    call    restart                 // the whole break already passed
    jmp     .Lret_phase
1:  movsd   xmm2, qword ptr [r10 + ST_WORK]
    subsd   xmm2, qword ptr [r10 + ST_WARN]
    xor     eax, eax
    ucomisd xmm0, xmm2
    setae   al                      // PH_WARNING once the warning is due
    mov     [r10 + ST_PHASE], rax
    jmp     .Lret_phase

.Lrest_now:
    movsd   xmm0, xmm1
    call    restart
.Lret_phase:
    mov     rax, [r10 + ST_PHASE]
    ret

// int64 bb_get(state *s, int which) -> the value, or NONE.
    .globl  bb_get
    .balign 16
bb_get:
    ARGS
    mov     rcx, [r10 + ST_PHASE]
    mov     rax, NONE
    cmp     r11, GET_PHASE
    jne     1f
    mov     rax, rcx
    ret
1:  cmp     r11, GET_CANPAUSE
    jne     2f
    xor     eax, eax
    test    rcx, rcx                // PH_WORK
    jnz     9f
    cvtsd2si rax, qword ptr [r10 + ST_LASTNOW]
    call    day_of
    cmp     rax, [r10 + ST_LASTPAUSE]
    setne   al
    movzx   eax, al
    ret
2:  cmp     r11, GET_NEXTBREAK
    jne     3f
    cmp     rcx, PH_WARNING
    ja      9f
    jmp     .Lwork_end
3:  cmp     r11, GET_WARNENDS
    jne     4f
    cmp     rcx, PH_WARNING
    jne     9f
.Lwork_end:
    movsd   xmm0, qword ptr [r10 + ST_WORKSTART]
    addsd   xmm0, qword ptr [r10 + ST_WORK]
    cvtsd2si rax, xmm0
    ret
4:  cmp     r11, GET_BREAKENDS
    jne     5f
    cmp     rcx, PH_BREAK
    jne     9f
    movsd   xmm0, qword ptr [r10 + ST_BREAKSTART]
    addsd   xmm0, qword ptr [r10 + ST_BREAK]
    cvtsd2si rax, xmm0
    ret
5:  cmp     r11, GET_PAUSEENDS
    jne     6f
    cmp     rcx, PH_PAUSED
    jne     9f
    cvtsd2si rax, qword ptr [r10 + ST_PAUSEEND]
    ret
6:  cmp     r11, GET_LASTPAUSE
    jne     9f
    mov     rax, [r10 + ST_LASTPAUSE]
9:  ret

// int bb_menu(state *s) -> MENU_* bits: what the menu allows now.
// There is no item that ends a break or turns BlackBreak off.
    .globl  bb_menu
    .balign 16
bb_menu:
    ARGS
    xor     r8d, r8d
    mov     rcx, [r10 + ST_PHASE]
    cmp     rcx, PH_PAUSED
    jne     1f
    or      r8d, MENU_CANCEL | MENU_SETTINGS
    jmp     9f
1:  test    rcx, rcx
    jnz     9f                      // warning, break: nothing
    or      r8d, MENU_SETTINGS
    cvtsd2si rax, qword ptr [r10 + ST_LASTNOW]
    call    day_of
    cmp     rax, [r10 + ST_LASTPAUSE]
    je      9f
    or      r8d, MENU_PAUSE
9:  mov     eax, r8d
    ret

// int bb_in_call(int settings, int mic_in_use, int camera_in_use) -> 1 if
// that counts as a call: the exemption is on, and the microphone is in use
// with "Microphone in use" on, or the camera with "Camera in use" on.
    .globl  bb_in_call
    .balign 16
bb_in_call:
    ARGS
    xor     eax, eax
    test    r10, SET_EXEMPT
    jz      9f
    test    r10, SET_MIC
    jz      1f
    test    r11, r11
    jnz     8f
1:  test    r10, SET_CAMERA
    jz      9f
    test    r8, r8
    jz      9f
8:  mov     eax, 1
9:  ret

// int bb_seconds(char *out, int64 n, int slovak) -> length of the UTF-8
// text "N seconds" / "N sekúnd" (1 sekunda, 2-4 sekundy), not terminated.
    .globl  bb_seconds
    .balign 16
bb_seconds:
    ARGS
    sub     rsp, 40                 // [rsp, rsp+24): digits; [rsp+32]: out
    mov     [rsp + 32], r10
    mov     rcx, r10                // write pointer
    // the number, written backwards into the buffer, then copied
    mov     rax, r11
    lea     r9, [rsp + 24]
1:  xor     edx, edx
    mov     r10, 10
    div     r10
    add     dl, '0'
    dec     r9
    mov     [r9], dl
    test    rax, rax
    jnz     1b
    lea     r10, [rsp + 24]
2:  cmp     r9, r10
    jae     3f
    mov     al, [r9]
    mov     [rcx], al
    inc     rcx
    inc     r9
    jmp     2b
3:  test    r8, r8
    jnz     .Lsk
    lea     rdx, [rip + s_seconds]
    cmp     r11, 1
    jne     .Lcopy
    lea     rdx, [rip + s_second]
    jmp     .Lcopy
.Lsk:
    lea     rdx, [rip + s_sekunda]
    cmp     r11, 1
    je      .Lcopy
    lea     rdx, [rip + s_sekundy]
    cmp     r11, 2
    jb      4f
    cmp     r11, 4
    jbe     .Lcopy
4:  lea     rdx, [rip + s_sekund]
.Lcopy:
    mov     al, [rdx]
    test    al, al
    jz      5f
    mov     [rcx], al
    inc     rcx
    inc     rdx
    jmp     .Lcopy
5:  mov     rax, rcx
    sub     rax, [rsp + 32]
    add     rsp, 40
    ret

    .section .rodata
s_second:   .asciz " second"
s_seconds:  .asciz " seconds"
s_sekunda:  .asciz " sekunda"
s_sekundy:  .asciz " sekundy"
s_sekund:   .asciz " sek\xc3\xband"
