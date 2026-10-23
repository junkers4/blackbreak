# BlackBreak — Linux (GNOME) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A GNOME Shell 50 extension that blacks out every monitor for 30 s every 20 min, swallows all input during the break, and allows only a pre-set pause of at most 3 h — plus the shared scenario table and requirements the Windows and Android plans will reuse.

**Architecture:** One pure ES module `scheduler.js` (no `gi` imports) holds all timing rules and is driven by `update(input)` once a second; it runs unchanged under node (tests) and gjs (extension). The extension wires it to a full-stage overlay with a modal grab, a top-bar indicator menu, a small notice, and a mic/camera detector. Shared behaviour is pinned by `spec/scenarios.json`, replayed by the node test runner.

**Tech Stack:** GJS ESM extension for GNOME Shell 50 (Wayland), GSettings, `node --test` (node 24) for unit tests, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-23-blackbreak-design.md`

## Global Constraints

- Work interval 20 min, warning 10 s, break 30 s, overlay fail-safe 35 s, max pause 3 h, idle reset 5 min, max wait for a call 3 h. Not configurable.
- Break text, verbatim, four lines: `Look at something far away — at least 6 m (20 ft).` / `Stretch your arms and your back.` / `Sit up straight, shoulders back.` / `Slowly turn and tilt your head to stretch your neck.`
- Break screen: solid black on all monitors incl. top bar; text light grey `#9a9a9a`, thin sans; countdown dimmer `#5a5a5a`. Nothing interactive.
- Warning notice text: `Break in 10 s`. No buttons.
- Pause and settings changes only in normal work interval (not warning, not break). After a pause ends or is cancelled, a full break must happen before another pause.
- Call exemption off by default; detection = microphone capture or camera open.
- No "AI look": native GNOME widgets, plain short labels, no emoji/gradients. No runtime dependencies beyond GNOME Shell.
- Extension UUID `blackbreak@junkers4.github.io`; GSettings schema `org.gnome.shell.extensions.blackbreak`. License MIT.

## Review Focus

- Laptop suspend/resume mid-interval or mid-break (wall clock jumps forward by hours) → treat as rest: fresh 20-min interval, never a late black screen on resume. Test in Task 1.
- Wall clock jumps backward (NTP/timezone fix) → no break storm, no interval longer than 20 min after the jump. Test in Task 1.
- Monitor hot-plug or resolution change during a break → new monitor is black too. Overlay re-sizes on `monitors-changed` (Task 4) + manual checklist item.
- Screen lock / session lock while a break is due → no overlay on top of the lock screen; break is treated as rest when unlocked (idle ≥ 5 min) or shown after unlock. Task 4 checks `Main.sessionMode.isLocked` before showing; manual item.
- Extension disabled/re-enabled (gnome-shell restart, update) during a break → overlay and grab always released in `disable()`. Manual item + code review gate in Task 4.

---

## File map

```
README.md, LICENSE                              repo docs (Task 6)
docs/requirements.md                            REQ-001… with test refs (Task 1, grown each task)
spec/scenarios.json                             shared scenario table (Tasks 1–3)
linux/blackbreak@junkers4.github.io/
  metadata.json                                 shell-version ["50"]
  scheduler.js                                  pure timing rules
  extension.js                                  enable/disable, 1 s tick, wiring
  overlay.js                                    break screen + modal grab + fail-safe
  indicator.js                                  top-bar menu: pause / cancel / status
  notice.js                                     "Break in 10 s" label
  callDetect.js                                 mic (Gvc) + camera (/proc fd) check
  prefs.js                                      Adw preferences: call exemption switches
  stylesheet.css
  schemas/org.gnome.shell.extensions.blackbreak.gschema.xml
linux/test/scheduler.test.mjs                   replays spec/scenarios.json + unit cases
linux/test/manual-checklist.md
linux/Makefile                                  test / pack / install
.github/workflows/ci.yml
```

---

### Task 1: Scheduler core — work, warning, break, idle, clock jumps

**Files:**
- Create: `linux/blackbreak@junkers4.github.io/scheduler.js`, `spec/scenarios.json`, `linux/test/scheduler.test.mjs`, `docs/requirements.md`, `linux/Makefile`

**Interfaces:**
- Produces (exported from `scheduler.js`):
  - `export const WORK_MS = 1_200_000, WARN_MS = 10_000, BREAK_MS = 30_000, FAILSAFE_MS = 35_000, MAX_PAUSE_MS = 10_800_000, IDLE_MS = 300_000, MAX_CALL_WAIT_MS = 10_800_000;`
  - `export const Phase = Object.freeze({WORK:'work', WARNING:'warning', BREAK:'break', PAUSED:'paused'});`
  - `export class Scheduler { constructor(nowMs: number, scale: number = 1 /* all durations divided by scale; debug only */); update({now, idleMs = 0, inCall = false, inPhoneCall = false}): string /* Phase */; get phase(): string; get breakEndsAt(): number|null; get warningEndsAt(): number|null; get pauseEndsAt(): number|null; get canPause(): boolean; pause(durationMs: number, now: number): boolean; cancelPause(now: number): boolean; }`
- Scenario format (`spec/scenarios.json`): `[{ "name": str, "req": ["REQ-00x"], "steps": [{ "t": seconds, "idle"?: seconds, "inCall"?: bool, "inPhoneCall"?: bool, "do"?: "pause:<seconds>" | "cancelPause" }], "expect": [{ "t": seconds, "phase": "work|warning|break|paused", "canPause"?: bool, "pauseResult"?: bool }] }]`. The runner creates `new Scheduler(0)`, walks t = 0…max in 1 s steps, applies the step input valid from its `t` until the next step (inputs persist), performs `do` at its `t` before `update`, and checks every `expect` at its `t` after `update`.

- [ ] **Step 1: Write `docs/requirements.md`** with REQ-001 work interval 20 min, REQ-002 warning 10 s non-interactive, REQ-003 break 30 s all monitors black with the four lines + countdown, REQ-004 no input during break, REQ-005 idle ≥ 5 min restarts interval, REQ-006 fail-safe 35 s, REQ-007 fresh interval after restart/login, REQ-008 pause ≤ 3 h only in work phase, REQ-009 no chained pause, REQ-010 cancel pause → fresh interval, REQ-011 call exemption off by default, REQ-012 call wait capped at 3 h, REQ-013 phone call always holds (Android), REQ-014 settings only in work phase, REQ-015 clock jumps are rest. Each line: `| REQ | text | linux test | windows test | android test |`, windows/android columns `—` for now.

- [ ] **Step 2: Write scenarios** (failing, scheduler not written):
  - `basic cycle`: expect t=1189 work, t=1190 warning, t=1199 warning, t=1200 break, t=1229 break, t=1230 work, t=2420 break.
  - `idle resets`: step t=600 idle=300 → expect t=1200 work; step t=601 idle=0 → expect t=600+1+1190 warning (=1791).
  - `restart is fresh`: new Scheduler(5000) per runner option `"start": 5000` → t=5000+1190 warning.
- [ ] **Step 3: Write unit tests in `scheduler.test.mjs`** for clock jumps (not expressible in 1 s scenarios):
  - `suspend in work`: update at 0, 600_000, then 600_000+4h → phase `work`, next warning exactly WORK_MS−WARN_MS after the jump.
  - `suspend in break`: reach break, update at breakStart+2h → `work`, `breakEndsAt === null`.
  - `clock backward`: update at 1_000_000, then 100_000 → `work`, warning at 100_000+1_190_000, never at 1_190_000.
  - Rule: in work, warning or break, any forward gap between updates ≥ IDLE_MS, or any backward step, ends a running warning/break and restarts the work interval (REQ-015). In paused, the pause still ends at `pauseEndsAt` (backward step: pause end is clamped to now + MAX_PAUSE_MS).
  - Idle rule: while `idleMs ≥ IDLE_MS` the interval is held; it restarts (full 20 min) at the first update with `idleMs < IDLE_MS`.
- [ ] **Step 4: Run** `make -C linux test` (`node --test linux/test/`) → FAIL: cannot find module `scheduler.js`.
- [ ] **Step 5: Implement `Scheduler`** (work/warning/break/idle/jump only; `pause`/`cancelPause` return false for now, `canPause` true in work).
- [ ] **Step 6: Run** `make -C linux test` → all PASS.
- [ ] **Step 7: Commit** `feat(core): scheduler work/warning/break cycle with shared scenarios`.

### Task 2: Pause rules

**Files:** Modify `scheduler.js`, `spec/scenarios.json`, `docs/requirements.md`.

**Interfaces:** Consumes Task 1 `Scheduler`. Produces working `pause`, `cancelPause`, `canPause`, `pauseEndsAt`.

- [ ] **Step 1: Add scenarios:**
  - `pause 1h`: t=10 `pause:3600` → pauseResult true, t=11 paused, t=3609 paused, t=3610 work, t=3610+1190 warning.
  - `pause too long`: t=10 `pause:10801` → pauseResult false, t=11 work.
  - `pause max`: t=10 `pause:10800` → true.
  - `no pause in warning`: t=1195 `pause:600` → false, t=1200 break.
  - `no pause in break`: t=1210 `pause:600` → false.
  - `no chained pause`: t=10 `pause:60` true; t=80 `pause:60` false, canPause false; after first break (t=70+1200=1270 break, t=1300 work) t=1301 `pause:60` true.
  - `cancel`: t=10 `pause:3600`; t=100 `cancelPause` → t=101 work, canPause false, t=100+1190 warning.
  - `idle ignored while paused`: t=10 `pause:3600`, step t=20 idle=900 → t=3609 paused.
- [ ] **Step 2: Run** → new scenarios FAIL.
- [ ] **Step 3: Implement** pause in `Scheduler`; zero/negative duration → false.
- [ ] **Step 4: Run** → PASS. Update REQ-008/009/010 test refs.
- [ ] **Step 5: Commit** `feat(core): pause up to 3 h, no chaining, cancel`.

### Task 3: Call holds

**Files:** Modify `scheduler.js`, `spec/scenarios.json`, `docs/requirements.md`.

**Interfaces:** `update({inCall, inPhoneCall})` — the platform passes `inCall=true` only when the exemption setting is on and mic/camera is in use; `inPhoneCall` is uncapped (Android only, Linux always false).

- [ ] **Step 1: Add scenarios:**
  - `call holds`: step t=1000 inCall → t=1190 work, t=5000 work; step t=5000 inCall=false → t=5000 warning, t=5010 break.
  - `call cap`: step t=1000 inCall forever → warning at t=1190+10800 (cap counted from when the warning was first due), break 10 s later.
  - `call during warning ignored`: step t=1195 inCall → t=1200 break.
  - `phone call uncapped`: step t=1000 inPhoneCall → t=1190+20000 work; release → warning same second.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** hold in work phase when warning is due; record `holdSince`; cap applies to `inCall` only.
- [ ] **Step 4: Run** → PASS. Update REQ-011/012/013.
- [ ] **Step 5: Commit** `feat(core): optional call hold with 3 h cap`.

### Task 4: Extension — overlay, notice, indicator, wiring

**Files:**
- Create: `metadata.json`, `extension.js`, `overlay.js`, `notice.js`, `indicator.js`, `stylesheet.css`, `schemas/org.gnome.shell.extensions.blackbreak.gschema.xml` (keys `call-exemption` b false, `exempt-mic` b true, `exempt-camera` b true), `linux/test/manual-checklist.md`
- Modify: `linux/Makefile` (`pack` → `gnome-extensions pack` into `dist/`, `install` → `gnome-extensions install --force` + note to log out/in), `docs/requirements.md`

**Interfaces:**
- Consumes: `Scheduler`, `Phase`, `FAILSAFE_MS`, `BREAK_MS` from Task 1–3.
- `overlay.js`: `export class Overlay { show(endsAtMs: number): void; hide(): void; destroy(): void }` — one `St.Widget` (black, `reactive: true`) added to `Main.layoutManager.addTopChrome` covering `global.stage` size, re-sized on `Main.layoutManager` `monitors-changed`; `Main.pushModal(widget, {actionMode: Shell.ActionMode.NONE})` grab, popped in `hide()`; labels for the four lines and countdown (`Math.ceil` seconds, updated each second); own `GLib.timeout_add(…, FAILSAFE_MS)` that calls `hide()` regardless of scheduler. `show()` is a no-op when `Main.sessionMode.isLocked`.
- `notice.js`: `export class Notice { show(text: string): void; hide(): void; destroy(): void }` — small non-reactive `St.Label` top-center.
- `indicator.js`: `export class Indicator extends PanelMenu.Button` with constructor `(scheduler, onChange)`; menu items `Pause 30 min`, `Pause 1 hour`, `Pause 2 hours`, `Pause 3 hours`, `Cancel pause`, separator, `Settings`; refreshes sensitivity from `scheduler.canPause` / `phase` on `open-state-changed`; status line `Next break in N min` / `Paused until HH:MM`.
- `extension.js`: `enable()` creates Scheduler(Date.now()), Overlay, Notice, Indicator, a 1 s `GLib.timeout_add_seconds` tick: `idleMs` from `global.backend.get_core_idle_monitor().get_idletime()`, `inCall` from Task 5 (stub `false` here); on phase change: warning → `notice.show('Break in 10 s')`, break → `notice.hide(); overlay.show(scheduler.breakEndsAt)`, work/paused → hide both. `disable()` removes the timeout and destroys everything (grab released).

- [ ] **Step 1: Write `manual-checklist.md`**: break covers both monitors and top bar; Alt+Tab, Super, Alt+F2, Ctrl+Alt+T, mouse clicks, scroll do nothing; break ends at 30 s; countdown counts down; `Break in 10 s` appears 10 s before and has no buttons; menu pause items greyed in warning/break; pause 30 min works; second pause greyed until a break; cancel pause works; plug/unplug monitor during break; lock screen with break due; `gnome-extensions disable` from a VT (Ctrl+Alt+F3) during a break releases the screen; fail-safe: temporarily set scheduler to never end break (debug env `BLACKBREAK_DEBUG_STUCK=1`) → screen still clears at 35 s.
- [ ] **Step 2: Implement the files above.** For fast manual runs, `BLACKBREAK_DEBUG_FAST=1` in the environment of a nested shell divides all durations by 60 (handled in `extension.js`, not in `scheduler.js`; see Task 1 `scale`).
- [ ] **Step 3: Smoke test** in a nested shell: `make -C linux install && dbus-run-session -- env BLACKBREAK_DEBUG_FAST=1 gnome-shell --devkit` → enable extension inside, observe a break at 20 s, no `JS ERROR` lines for `blackbreak` in its output.
- [ ] **Step 4: Run** `make -C linux test` → still PASS.
- [ ] **Step 5: Commit** `feat(gnome): overlay, notice, indicator`.

### Task 5: Call detection and preferences

**Files:** Create `callDetect.js`, `prefs.js`. Modify `extension.js`, `docs/requirements.md`, `manual-checklist.md`.

**Interfaces:**
- `callDetect.js`: `export class CallDetector { constructor(settings); inCall(): boolean; destroy(): void }` — returns false when `call-exemption` is false. Mic: `Gvc.MixerControl` (name `blackbreak`) open, true when any `get_source_outputs()` entry is not from gnome-shell itself (`get_application_id() !== 'org.gnome.Shell'`) and `exempt-mic`. Camera: true when `exempt-camera` and any `/proc/<pid>/fd/*` owned by the user links to `/dev/video*`; scan at most every 5 s and only while the warning is due (cache last result).
- `prefs.js`: `Adw.PreferencesPage` with one group "Calls": switch `Wait with the break while I'm in a call` (call-exemption), switches `Microphone in use`, `Camera in use` (sensitive only when the first is on), caption `A break waits at most 3 hours.` Prefs cannot enforce the phase rule from the prefs process, so extension.js ignores settings changes during warning/break by snapshotting `call-exemption` at the start of each work phase.

- [ ] **Step 1: Add manual checklist items:** default off → break comes during a Teams/Meet call in the browser; switch on → break waits while mic is on, comes right after call ends; camera only (`ffplay /dev/video0`) holds when camera switch on; toggling switch during a break has no effect on that break.
- [ ] **Step 2: Implement** and wire `inCall: detector.inCall()` into the tick.
- [ ] **Step 3: Smoke test** as Task 4 Step 3, plus `arecord -d 60 /dev/null` while the fast break is due with exemption on → break waits.
- [ ] **Step 4: Commit** `feat(gnome): optional call exemption`.

### Task 6: CI, packaging, README, GitHub

**Files:** Create `.github/workflows/ci.yml`, `README.md`, `LICENSE` (MIT, `junkers4`). Modify `docs/requirements.md`.

- [ ] **Step 1: CI**: job `core` on ubuntu-latest: `node --test linux/test/`; job `gnome-pack`: install `gnome-shell-common`/`glib2.0-bin`, `glib-compile-schemas --strict` on the schema, `gnome-extensions pack`; on tag `v*` upload the zip to a GitHub Release.
- [ ] **Step 2: README**: one paragraph what it is and why (no skipping in the moment), install (`gnome-extensions install blackbreak@junkers4.github.io.shell-extension.zip`, log out/in, enable), how to pause, call exemption, what cannot be blocked (VT switch, reboot), platforms table (Linux ✓, Windows next, Android next, iOS later — needs paid Apple account, Mac and Apple approval of Screen Time entitlement). Plain text, no badges wall, no emoji.
- [ ] **Step 3: Verify** `make -C linux test pack` locally → PASS, zip in `linux/dist/`.
- [ ] **Step 4: Commit**, then `gh repo create junkers4/blackbreak --public --source . --push`, check CI green with `gh run watch`.
