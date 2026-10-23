# Shared spec

Platform-neutral cases that every port (GNOME/JS, Windows/C#, Android/Kotlin)
runs against its own scheduler. Times are milliseconds unless noted.

## scenarios.json (coarse, seconds, one step per second)

A list of `{name, req, start?, lastPauseDay?, steps, expect}`.
- `steps`: `{t, idle?, inCall?, inPhoneCall?, do?}`; `t` in seconds. Inputs hold
  until the next step. `do` is `pause:<s>` or `cancelPause`, run before the update.
- The runner calls `update` once per second from `start` to the last `expect`.
- `expect`: `{t, phase, canPause?, pauseResult?}` checked after the update at `t`.

## traces.json (exact, milliseconds, arbitrary clock)

A list of `{name, req, scale, lastPauseDay, start, events}`. The scheduler is
`Scheduler(start, scale, dayKey, lastPauseDay)` with
`dayKey(ms) = floor(ms / 86400000)` as a decimal string.

Events are applied in order:
- `{"now": t, "idle"?, "inCall"?, "inPhoneCall"?}`: one `update` at `t`;
  missing inputs are 0 / false.
- `{"walk": t, "every"?: 60000}`: `update` at `last+every, last+2*every, ...`
  below `t`, then at `t`, with no inputs. `last` is the `now` of the previous
  update, or `start` if there was none.
- `{"do": "pause:<ms>" | "cancelPause", "at": t}`: call the method, record its
  boolean as `result`.
- `{"expect": {...}}`: assert on the current state. Any of `phase`, `canPause`,
  `result` (of the last `do`), `nextBreakAt`, `breakEndsAt`, `warningEndsAt`,
  `pauseEndsAt`, `lastPauseDay`. `null` means absent.
- An event may carry `now`/`walk`/`do` and `expect` together; the action runs
  first, then the expect.

Reference runners: `linux/test/scheduler.test.mjs`.
