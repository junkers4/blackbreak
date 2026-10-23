# Requirements

| REQ | text | linux test | windows test | android test |
|---|---|---|---|---|
| REQ-001 | Work interval is 20 minutes. | scenarios: basic cycle | — | — |
| REQ-002 | Warning 10 s before a break; non-interactive. | scenarios: basic cycle; manual: warning | — | — |
| REQ-003 | Break lasts 30 s; all monitors black with the four lines and a countdown. | scenarios: basic cycle; manual: break screen | — | — |
| REQ-004 | No input during a break. | manual: no input | — | — |
| REQ-005 | Idle of 5 minutes or more restarts the interval. | scenarios: idle resets | — | — |
| REQ-006 | Fail-safe: the break screen is gone 35 s after it appeared. | manual: fail-safe | — | — |
| REQ-007 | A restart or login begins a fresh interval. | scenarios: restart is fresh | — | — |
| REQ-008 | Pause up to 3 h, only in the work phase. | scenarios: pause 1h, pause too long, pause max, no pause in warning, no pause in break, idle ignored while paused; manual: pause | — | — |
| REQ-009 | One pause per calendar day; survives restart. | scenarios: one per day, cancel uses the day, restart keeps the day; manual: pause | — | — |
| REQ-010 | Cancelling a pause starts a fresh interval. | scenarios: cancel, cancel uses the day | — | — |
| REQ-011 | Call exemption is off by default. | scenarios: call holds, call during warning ignored, call during break ignored; manual: calls | — | — |
| REQ-012 | A break waits for a call at most 3 h. | scenarios: call cap | — | — |
| REQ-013 | A phone call always holds a due break (Android). | scenarios: phone call uncapped | — | — |
| REQ-014 | Settings can be changed only in the work phase. | manual: calls (switch during a break or a held break) | — | — |
| REQ-015 | Clock jumps (suspend, backward step) count as rest. | traces: suspend in work, suspend in break, clock backward | — | — |

The scenarios and traces run in CI on every push (`.github/workflows/ci.yml`); the manual checks are in `linux/test/manual-checklist.md`.
