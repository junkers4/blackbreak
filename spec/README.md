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

A list of `{name, req, scale, lastPauseDay, start, events}`.
- `req`: the REQ ids the trace covers; may be empty.
- Construct `Scheduler(start, scale, dayKey, lastPauseDay)`: `start` is the
  clock value at creation, `scale` divides all durations (1 = real time),
  `dayKey(ms) = floor(ms / 86400000)` as a decimal string, `lastPauseDay` is
  that string or null. The JS reference takes an options object instead;
  another language may use any equivalent constructor.
- Every time in `now`, `walk`, `at` and `expect` is a raw clock value, already
  scaled: nothing in them is divided by `scale`.

Events are applied in order. An event has at most one action (`now`, `walk` or
`do`; a runner must throw on more) and may add `expect`, checked after it.
- `{"now": t, "idle"?, "inCall"?, "inPhoneCall"?}`: one `update` at `t`.
  `idle` is the user's idle time in ms (becomes `idleMs`, default 0);
  `inCall` and `inPhoneCall` default to false.
- `{"walk": t, "every"?: 60000}`: `update` at `last+every, last+2*every, ...`
  below `t`, then at `t`, with no inputs. `last` is the `now` of the previous
  update, or `start` if there was none.
- `{"do": "pause:<ms>" | "cancelPause", "at": t}`: call the method with the
  clock time `at` (required) and record its boolean as `result`. It does not
  call `update`. `pause:<ms>` is an unscaled duration that the scheduler
  divides by `scale`: `pause:100000` at scale 10 gives `pauseEndsAt` 10000.
- `{"expect": {...}}`: assert on the current state. Any of `phase`, `canPause`,
  `result`, `nextBreakAt`, `breakEndsAt`, `warningEndsAt`, `pauseEndsAt`,
  `lastPauseDay`. `null` means absent. `phase` is one of `work`, `warning`,
  `break`, `paused`. `result` is the boolean from the most recent `do`;
  expecting it before any `do` is invalid.

Reference runner: `linux/test/scheduler.test.mjs`.
