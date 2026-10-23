# BlackBreak — Shared traces and releases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every scheduler test platform-neutral data, so the Windows and Android schedulers are proven by the same cases as Linux, and give the repo one clean release scheme: one SemVer tag builds every platform that exists.

**Architecture:** The twelve hand-written node unit tests become `spec/traces.json` (explicit event lists in ms, so clock jumps and suspends can be expressed); `spec/scenarios.json` stays as is. A tag `vX.Y.Z` runs `release.yml`, which builds each platform job, names assets `blackbreak-<platform>-vX.Y.Z.<ext>`, writes `SHA256SUMS`, and takes the release notes from the matching `CHANGELOG.md` section.

**Tech Stack:** JSON, node 24 `node:test`, GitHub Actions, `gh`.

**Spec:** `docs/superpowers/specs/2026-10-23-blackbreak-design.md` (Requirements and tests; Delivery order: "One repo, one version tag builds every platform that exists at that point").

## Global Constraints

- All Global Constraints of `2026-10-23-linux-gnome.md` stay in force.
- Versions: SemVer, annotated tags `vX.Y.Z` on `main` only. Roadmap: `v0.1.0` Linux; `v0.2.0` + Windows; `v0.3.0` + Android; `v1.0.0` once every platform's manual checklist has passed on real hardware.
- Asset names: `blackbreak-linux-gnome-vX.Y.Z.zip`, `blackbreak-windows-x64-vX.Y.Z.zip`, `blackbreak-android-vX.Y.Z.apk`, plus `SHA256SUMS`.
- Release title `BlackBreak vX.Y.Z`; body = the `## [X.Y.Z]` section of `CHANGELOG.md` (Keep a Changelog format). A tag with no such section fails the release.
- The version shown to users comes from the tag: GNOME `metadata.json` `version-name`, Windows assembly `Version`, Android `versionName`/`versionCode` (`versionCode = X*10000 + Y*100 + Z`).

## Review Focus

- A trace that silently stops checking something the old unit test checked (e.g. `breakEndsAt` after a suspend) → every assertion of the twelve old tests appears as an `expect` field; Task 1 Step 3 lists the mapping in the commit message.
- Tag pushed without a CHANGELOG section, or tag version ≠ `CHANGELOG` heading → release job fails before uploading anything (Task 2 Step 1 check script).
- Release re-run on an existing tag → `gh release upload --clobber`, no duplicate release.
- A platform job failing → no half release: the `publish` job `needs:` all platform jobs.
- Tag on a commit not on `main` → `publish` refuses (`git merge-base --is-ancestor $GITHUB_SHA origin/main`).

---

## File map

```
spec/traces.json                         event-list cases (Task 1)
spec/README.md                           format of scenarios.json and traces.json (Task 1)
linux/test/scheduler.test.mjs            runs scenarios + traces; old unit tests removed (Task 1)
CHANGELOG.md                             Keep a Changelog (Task 2)
tools/release-notes.sh                   prints the CHANGELOG section for a version, fails if missing (Task 2)
.github/workflows/ci.yml                 tests only (release step removed) (Task 2)
.github/workflows/release.yml            tag → build platforms → publish (Task 2)
linux/Makefile                           `pack VERSION=x.y.z` stamps version-name (Task 2)
```

### Task 1: Traces

**Files:** Create `spec/traces.json`, `spec/README.md`. Modify `linux/test/scheduler.test.mjs`, `docs/requirements.md`.

**Interfaces — `spec/traces.json` format (every platform's runner implements exactly this):**

```json
[{ "name": "suspend in break", "req": ["REQ-015"],
   "scale": 1, "lastPauseDay": null, "start": 0,
   "events": [
     { "walk": 1200000, "every": 60000 },
     { "expect": { "phase": "break", "breakEndsAt": 1230000 } },
     { "now": 8400000, "expect": { "phase": "work", "breakEndsAt": null } }
   ] }]
```

- Times in ms. The scheduler is created as `Scheduler(start, scale, dayKey, lastPauseDay)` with `dayKey(ms) = floor(ms / 86400000)` as a decimal string.
- Event kinds, applied in order:
  - `{"now": t, "idle"?, "inCall"?, "inPhoneCall"?}` → `update` once. Missing inputs default to 0 / false.
  - `{"walk": t, "every"?: 60000}` → `update` at `last+every, last+2·every, …` below `t`, then at `t`, with no inputs. `last` is the `now` of the previous update; it is `start` if there was none.
  - `{"do": "pause:<ms>" | "cancelPause", "at": t}` → calls the method and records its boolean `result`.
  - `{"expect": {...}}` → assert on the current state. Any of `phase`, `canPause`, `result` (the last `do`), `nextBreakAt`, `breakEndsAt`, `warningEndsAt`, `pauseEndsAt`, `lastPauseDay`. `null` means "absent".
  - An event may carry `now`/`walk`/`do` and `expect` together; the action runs first, then the expect.
- One trace per old unit test, same name: `suspend in work`, `suspend in break`, `clock backward`, `clock backward during warning ends it`, `gap just under the idle limit is not a jump`, `idle holds the interval, restarts at first non-idle update`, `scale divides durations`, `pause basics, scaling and cancel result`, `backward step during a pause clamps the end, keeps the pause`, `suspend across the end of a pause gives a fresh interval from wake`, `call first seen after a gap in the warning window does not hold`, `next break time`.

- [ ] **Step 1: Write `spec/traces.json`** with the twelve traces. Translate each assertion of the old test into an `expect`. For example, `pause basics` becomes: `do pause:0 → result false`, `do pause:-5 → false`, `do cancelPause → false`, `do pause:100000 at 0 → true`, `expect pauseEndsAt 10000, lastPauseDay "0"`, `do cancelPause at 1000 → true`, `expect pauseEndsAt null`, with `scale: 10`.
- [ ] **Step 2: Replace the twelve `test(...)` blocks** with `for (const tr of traces) test(\`trace: ${tr.name}\`, () => runTrace(tr))`, where `runTrace` implements the format above. Run `make -C linux test` → 31 tests, all pass.
- [ ] **Step 3: Prove the traces bite.** Temporarily change `scheduler.js` in each of three ways and confirm at least one trace fails each time: (a) `gap >= this._idle` → `gap > this._idle * 2`; (b) remove the `Math.min` clamp in the paused branch; (c) `this._callSeen = inCall || inPhoneCall` → `this._callSeen = true`. Revert. Note the results in the commit body.
- [ ] **Step 4: `spec/README.md`**: both formats, ≤ 40 lines. In `docs/requirements.md`, rename the `unit:` references to `traces:`.
- [ ] **Step 5: Commit** `test(spec): scheduler unit cases as shared traces`.

### Task 2: Release scheme and v0.1.0

**Files:** Create `CHANGELOG.md`, `tools/release-notes.sh`, `.github/workflows/release.yml`. Modify `.github/workflows/ci.yml`, `linux/Makefile`, `README.md`.

- [ ] **Step 1: `tools/release-notes.sh <X.Y.Z>`** prints the body of `## [X.Y.Z] - YYYY-MM-DD` up to the next `## [` heading. It exits 1 with `no CHANGELOG entry for X.Y.Z` when the section is missing or empty. Check it with `tools/release-notes.sh 0.1.0` (prints the section) and `tools/release-notes.sh 9.9.9` (exit 1).
- [ ] **Step 2: `CHANGELOG.md`** with a `## [Unreleased]` section and `## [0.1.0] - 2026-10-23`. The 0.1.0 entry is plain bullets for the Linux GNOME extension (break, warning, pause once a day, idle, call exemption, fail-safe) and has no emoji.
- [ ] **Step 3: `linux/Makefile`**: `pack` takes `VERSION` (default `0.0.0-dev`). It writes `"version-name": "$(VERSION)"` into a temporary copy of `metadata.json` (the source copy is not edited) and outputs `dist/blackbreak-linux-gnome-v$(VERSION).zip`. `install` keeps working: it picks the zip that `pack` just made. Check with `make -C linux pack VERSION=0.1.0` and `unzip -p linux/dist/*.zip metadata.json` → it shows `version-name` `0.1.0`.
- [ ] **Step 4: `release.yml`** on `push: tags: ['v*']`:
  - job `notes`: version = tag without `v`. Fails unless `git merge-base --is-ancestor $GITHUB_SHA origin/main` (needs `fetch-depth: 0`). Runs `tools/release-notes.sh` and saves the output as an artifact.
  - job `linux` (needs `notes`): tests, then `make -C linux pack VERSION=…`, then uploads the zip as an artifact.
  - job `publish` (needs all platform jobs): downloads the artifacts, runs `sha256sum * > SHA256SUMS`, then `gh release create vX.Y.Z --title "BlackBreak vX.Y.Z" --notes-file notes.md --verify-tag`, or `gh release upload --clobber` if the release already exists.
  - `ci.yml`: remove the release step. It keeps tests and pack on push and PR.
- [ ] **Step 5: README** gets a short "Releases" note (download from Releases; `SHA256SUMS`; the version scheme in one sentence). The install command uses the new zip name.
- [ ] **Step 6: Commit** `ci: tagged releases with changelog notes and checksums`, merge to `main`, push, CI green.
- [ ] **Step 7: Tag** `git tag -a v0.1.0 -m "BlackBreak 0.1.0 — Linux (GNOME)"`, `git push origin v0.1.0`, `gh run watch` → release `BlackBreak v0.1.0` with the zip and `SHA256SUMS`. Download the zip and run `sha256sum -c`.
