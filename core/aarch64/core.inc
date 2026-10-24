// core.inc - the scheduler's state layout (the same as x86_64/core.inc).
//
// AArch64 (AAPCS64): every core function is a leaf that takes its
// arguments in x0-x3 and uses only x0-x15 and d0-d7.

// struct state, every field 8 bytes. Times are milliseconds as doubles,
// because scaled durations can be fractional (scale is a test speed-up).
.equ ST_SCALE,      0
.equ ST_WORK,       8       // WORK_MS / scale
.equ ST_WARN,       16
.equ ST_BREAK,      24
.equ ST_IDLE,       32
.equ ST_PHASE,      40      // int: PH_*
.equ ST_WORKSTART,  48
.equ ST_BREAKSTART, 56      // meaningful only in PH_BREAK
.equ ST_HOLDSINCE,  64      // when the warning was first due, while a call holds it
.equ ST_HASHOLD,    72      // int flag: HOLDSINCE is set
.equ ST_CALLSEEN,   80      // int flag: a call was active before the warning was due
.equ ST_PHONEHELD,  88      // int flag: the current hold included a phone call
.equ ST_HOLDSPENT,  96      // int flag: a hold already ended in this interval
.equ ST_IDLEHELD,   104     // int flag
.equ ST_LASTNOW,    112
.equ ST_PAUSEEND,   120     // meaningful only in PH_PAUSED
.equ ST_LASTPAUSE,  128     // int: day number of the last pause, or NONE
.equ ST_TZ,         136     // int: local offset from UTC in ms, for day numbers
.equ ST_SIZE,       144

.equ PH_WORK,       0
.equ PH_WARNING,    1
.equ PH_BREAK,      2
.equ PH_PAUSED,     3

// "no value", for getters and for "never paused"
.equ NONE,          0x8000000000000000

// bb_get selectors
.equ GET_PHASE,     0
.equ GET_CANPAUSE,  1
.equ GET_NEXTBREAK, 2
.equ GET_BREAKENDS, 3
.equ GET_WARNENDS,  4
.equ GET_PAUSEENDS, 5
.equ GET_LASTPAUSE, 6

// bb_update flags
.equ IN_CALL,       1
.equ IN_PHONE,      2

// bb_menu bits
.equ MENU_PAUSE,    1
.equ MENU_CANCEL,   2
.equ MENU_SETTINGS, 4

// bb_in_call settings bits
.equ SET_EXEMPT,    1
.equ SET_MIC,       2
.equ SET_CAMERA,    4
