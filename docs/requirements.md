# Requirements

| REQ | text | linux test | windows test | android test |
|---|---|---|---|---|
| REQ-001 | Work interval is 20 minutes. | scenarios: basic cycle | — | — |
| REQ-002 | Warning 10 s before a break; non-interactive. | scenarios: basic cycle | — | — |
| REQ-003 | Break lasts 30 s; all monitors black with the four lines and a countdown. | scenarios: basic cycle | — | — |
| REQ-004 | No input during a break. | — | — | — |
| REQ-005 | Idle of 5 minutes or more restarts the interval. | scenarios: idle resets | — | — |
| REQ-006 | Fail-safe: the break screen is gone 35 s after it appeared. | — | — | — |
| REQ-007 | A restart or login begins a fresh interval. | scenarios: restart is fresh | — | — |
| REQ-008 | Pause up to 3 h, only in the work phase. | — | — | — |
| REQ-009 | One pause per calendar day; survives restart. | — | — | — |
| REQ-010 | Cancelling a pause starts a fresh interval. | — | — | — |
| REQ-011 | Call exemption is off by default. | — | — | — |
| REQ-012 | A break waits for a call at most 3 h. | — | — | — |
| REQ-013 | A phone call always holds a due break (Android). | — | — | — |
| REQ-014 | Settings can be changed only in the work phase. | — | — | — |
| REQ-015 | Clock jumps (suspend, backward step) count as rest. | unit: suspend in work, suspend in break, clock backward | — | — |
