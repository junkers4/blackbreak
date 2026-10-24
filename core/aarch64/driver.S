// driver.S - drives the AArch64 core from text commands, for the tests.
//
// The same protocol as x86_64/driver.S (see there); a Linux program with no
// libc, run under qemu-aarch64 on a PC.
//
// x19 = read cursor, x20 = end of input, x21 = write cursor, x22 = &state

#include "core.inc"

    .bss
    .balign 16
state:  .skip ST_SIZE
inbuf:  .skip 4 << 20
outbuf: .skip 4 << 20

    .text
    .globl  _start
_start:
    adrp    x19, inbuf
    add     x19, x19, :lo12:inbuf
    mov     x20, x19
    adrp    x22, state
    add     x22, x22, :lo12:state
1:  mov     x0, #0                  // read(0, x20, room)
    mov     x1, x20
    adrp    x2, outbuf
    add     x2, x2, :lo12:outbuf    // inbuf ends where outbuf starts
    sub     x2, x2, x20
    mov     x8, #63
    svc     #0
    cmp     x0, #0
    b.le    2f
    add     x20, x20, x0
    b       1b
2:  adrp    x21, outbuf
    add     x21, x21, :lo12:outbuf

.Lnext:
    bl      skip_space
    cmp     x19, x20
    b.hs    .Lexit
    ldrb    w23, [x19], #1
    cmp     w23, #'i'
    b.eq    .Linit
    cmp     w23, #'t'
    b.eq    .Ltz
    cmp     w23, #'u'
    b.eq    .Lupdate
    cmp     w23, #'p'
    b.eq    .Lpause
    cmp     w23, #'c'
    b.eq    .Lcancel
    cmp     w23, #'g'
    b.eq    .Lget
    cmp     w23, #'m'
    b.eq    .Lmenu
    cmp     w23, #'k'
    b.eq    .Lincall
    cmp     w23, #'s'
    b.eq    .Lseconds
    mov     x24, #2                 // unknown command
    b       .Lexit_code

.Linit:
    bl      parse_int
    mov     x24, x0
    bl      parse_int
    mov     x25, x0
    bl      parse_int
    mov     x3, x0
    mov     x0, x22
    mov     x1, x24
    mov     x2, x25
    bl      bb_init
    b       .Lnext
.Ltz:
    bl      parse_int
    mov     x1, x0
    mov     x0, x22
    bl      bb_set_tz
    b       .Lnext
.Lupdate:
    bl      parse_int
    mov     x24, x0
    bl      parse_int
    mov     x25, x0
    bl      parse_int
    mov     x3, x0
    mov     x0, x22
    mov     x1, x24
    mov     x2, x25
    bl      bb_update
    b       .Lanswer
.Lpause:
    bl      parse_int
    mov     x24, x0
    bl      parse_int
    mov     x2, x0
    mov     x0, x22
    mov     x1, x24
    bl      bb_pause
    b       .Lanswer
.Lcancel:
    bl      parse_int
    mov     x1, x0
    mov     x0, x22
    bl      bb_cancel
    b       .Lanswer
.Lget:
    bl      parse_int
    mov     x1, x0
    mov     x0, x22
    bl      bb_get
    b       .Lanswer
.Lmenu:
    mov     x0, x22
    bl      bb_menu
    b       .Lanswer
.Lincall:
    bl      parse_int
    mov     x24, x0
    bl      parse_int
    mov     x25, x0
    bl      parse_int
    mov     x2, x0
    mov     x0, x24
    mov     x1, x25
    bl      bb_in_call
    b       .Lanswer
.Lseconds:
    bl      parse_int
    mov     x24, x0
    bl      parse_int
    mov     x2, x0
    mov     x0, x21
    mov     x1, x24
    bl      bb_seconds
    add     x21, x21, x0
    mov     w0, #10
    strb    w0, [x21], #1
    b       .Lnext

.Lanswer:
    bl      put_int
    b       .Lnext

.Lexit:
    mov     x24, #0
.Lexit_code:
    mov     x0, #1                  // write(1, outbuf, len)
    adrp    x1, outbuf
    add     x1, x1, :lo12:outbuf
    sub     x2, x21, x1
    mov     x8, #64
    svc     #0
    mov     x0, x24
    mov     x8, #93                 // exit
    svc     #0

// skip_space: advance x19 over spaces, tabs and newlines.
skip_space:
1:  cmp     x19, x20
    b.hs    2f
    ldrb    w9, [x19]
    cmp     w9, #' '
    b.hi    2f
    add     x19, x19, #1
    b       1b
2:  ret

// parse_int -> x0: a signed decimal number at x19.
parse_int:
    mov     x10, x30
    bl      skip_space
    mov     x30, x10
    mov     x0, #0
    mov     x11, #0                 // negative?
    cmp     x19, x20
    b.hs    3f
    ldrb    w9, [x19]
    cmp     w9, #'-'
    b.ne    1f
    mov     x11, #1
    add     x19, x19, #1
1:  cmp     x19, x20
    b.hs    2f
    ldrb    w9, [x19]
    sub     w9, w9, #'0'
    cmp     w9, #9
    b.hi    2f
    mov     x12, #10
    madd    x0, x0, x12, x9
    add     x19, x19, #1
    b       1b
2:  cbz     x11, 3f
    neg     x0, x0
3:  ret

// put_int(x0): a signed decimal number and a newline at x21.
put_int:
    sub     sp, sp, #32
    add     x10, sp, #32            // digits grow down from here
    mov     x11, x0
    cmp     x0, #0
    b.ge    1f
    neg     x11, x0                 // NONE stays itself; its magnitude as unsigned
    mov     w9, #'-'
    strb    w9, [x21], #1
1:  mov     x12, #10
2:  udiv    x13, x11, x12
    msub    x14, x13, x12, x11
    add     x14, x14, #'0'
    strb    w14, [x10, #-1]!
    mov     x11, x13
    cbnz    x11, 2b
    add     x11, sp, #32
3:  cmp     x10, x11
    b.hs    4f
    ldrb    w9, [x10], #1
    strb    w9, [x21], #1
    b       3b
4:  mov     w9, #10
    strb    w9, [x21], #1
    add     sp, sp, #32
    ret
