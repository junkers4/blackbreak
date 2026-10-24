// driver.S - drives the x86-64 core from text commands, for the tests.
//
// A Linux program with no libc. It reads all of stdin, runs one command a
// line, and writes one answer a line for the commands that answer:
//   i NOW SCALE_BITS LAST_PAUSE_DAY   bb_init (no answer)
//   t TZ_MS                           bb_set_tz (no answer)
//   u NOW IDLE_MS FLAGS               bb_update -> phase
//   p DURATION_MS AT                  bb_pause -> 0/1
//   c AT                              bb_cancel -> 0/1
//   g WHICH                           bb_get -> value
//   m                                 bb_menu -> bits
//   k SETTINGS MIC CAMERA             bb_in_call -> 0/1
//   s N SLOVAK                        bb_seconds -> the text
// core/test/run_core.py writes the commands from spec/*.json.
//
// rbx = read cursor, r12 = end of input, r13 = write cursor

#include "core.inc"

    .bss
    .balign 16
state:  .skip ST_SIZE
inbuf:  .skip 4 << 20
outbuf: .skip 4 << 20

    .text
    .globl  _start
_start:
    lea     rbx, [rip + inbuf]
    mov     r12, rbx
1:  mov     eax, 0                  // read(0, r12, room)
    xor     edi, edi
    mov     rsi, r12
    lea     rdx, [rip + inbuf + (4 << 20)]
    sub     rdx, r12
    syscall
    test    rax, rax
    jle     2f
    add     r12, rax
    jmp     1b
2:  lea     r13, [rip + outbuf]

.Lnext:
    call    skip_space
    cmp     rbx, r12
    jae     .Lexit
    movzx   eax, byte ptr [rbx]
    inc     rbx
    cmp     al, 'i'
    je      .Linit
    cmp     al, 't'
    je      .Ltz
    cmp     al, 'u'
    je      .Lupdate
    cmp     al, 'p'
    je      .Lpause
    cmp     al, 'c'
    je      .Lcancel
    cmp     al, 'g'
    je      .Lget
    cmp     al, 'm'
    je      .Lmenu
    cmp     al, 'k'
    je      .Lincall
    cmp     al, 's'
    je      .Lseconds
    mov     edi, 2                  // unknown command
    jmp     .Lexit_code

.Linit:
    call    parse_int
    mov     r14, rax
    call    parse_int
    mov     r15, rax
    call    parse_int
    mov     rcx, rax
    lea     rdi, [rip + state]
    mov     rsi, r14
    mov     rdx, r15
    call    bb_init
    jmp     .Lnext
.Ltz:
    call    parse_int
    lea     rdi, [rip + state]
    mov     rsi, rax
    call    bb_set_tz
    jmp     .Lnext
.Lupdate:
    call    parse_int
    mov     r14, rax
    call    parse_int
    mov     r15, rax
    call    parse_int
    mov     rcx, rax
    lea     rdi, [rip + state]
    mov     rsi, r14
    mov     rdx, r15
    call    bb_update
    jmp     .Lanswer
.Lpause:
    call    parse_int
    mov     r14, rax
    call    parse_int
    lea     rdi, [rip + state]
    mov     rsi, r14
    mov     rdx, rax
    call    bb_pause
    jmp     .Lanswer
.Lcancel:
    call    parse_int
    lea     rdi, [rip + state]
    mov     rsi, rax
    call    bb_cancel
    jmp     .Lanswer
.Lget:
    call    parse_int
    lea     rdi, [rip + state]
    mov     rsi, rax
    call    bb_get
    jmp     .Lanswer
.Lmenu:
    lea     rdi, [rip + state]
    call    bb_menu
    jmp     .Lanswer
.Lincall:
    call    parse_int
    mov     r14, rax
    call    parse_int
    mov     r15, rax
    call    parse_int
    mov     rdi, r14
    mov     rsi, r15
    mov     rdx, rax
    call    bb_in_call
    jmp     .Lanswer
.Lseconds:
    call    parse_int
    mov     r14, rax
    call    parse_int
    mov     rdi, r13
    mov     rsi, r14
    mov     rdx, rax
    call    bb_seconds
    add     r13, rax
    mov     byte ptr [r13], 10
    inc     r13
    jmp     .Lnext

.Lanswer:
    call    put_int
    jmp     .Lnext

.Lexit:
    xor     edi, edi
.Lexit_code:
    push    rdi
    mov     eax, 1                  // write(1, outbuf, len)
    mov     edi, 1
    lea     rsi, [rip + outbuf]
    mov     rdx, r13
    sub     rdx, rsi
    syscall
    pop     rdi
    mov     eax, 60                 // exit
    syscall

// skip_space: advance rbx over spaces, tabs and newlines.
skip_space:
1:  cmp     rbx, r12
    jae     2f
    movzx   eax, byte ptr [rbx]
    cmp     al, ' '
    ja      2f
    inc     rbx
    jmp     1b
2:  ret

// parse_int -> rax: a signed decimal number at rbx.
parse_int:
    call    skip_space
    xor     eax, eax
    xor     ecx, ecx                // negative?
    cmp     rbx, r12
    jae     3f
    cmp     byte ptr [rbx], '-'
    jne     1f
    mov     ecx, 1
    inc     rbx
1:  cmp     rbx, r12
    jae     2f
    movzx   edx, byte ptr [rbx]
    sub     edx, '0'
    cmp     edx, 9
    ja      2f
    imul    rax, rax, 10
    add     rax, rdx
    inc     rbx
    jmp     1b
2:  test    ecx, ecx
    jz      3f
    neg     rax
3:  ret

// put_int(rax): a signed decimal number and a newline at r13.
put_int:
    sub     rsp, 40
    lea     rsi, [rsp + 32]         // digits grow down from here
    xor     r9d, r9d                // negative?
    mov     rcx, rax
    test    rax, rax
    jns     1f
    mov     r9d, 1
    neg     rcx                     // NONE stays itself and prints as its magnitude
1:  mov     rax, rcx
    mov     r8, 10
2:  xor     edx, edx
    div     r8
    add     dl, '0'
    dec     rsi
    mov     [rsi], dl
    test    rax, rax
    jnz     2b
    test    r9d, r9d
    jz      3f
    mov     byte ptr [r13], '-'
    inc     r13
3:  lea     rdx, [rsp + 32]
4:  cmp     rsi, rdx
    jae     5f
    mov     al, [rsi]
    mov     [r13], al
    inc     r13
    inc     rsi
    jmp     4b
5:  mov     byte ptr [r13], 10
    inc     r13
    add     rsp, 40
    ret
