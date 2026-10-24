# Requirements

Every requirement has an automated test on every platform it applies to. A dash means the
requirement does not apply there; "manual" means no automated test is possible and the item
is in that platform's `test/manual-checklist.md`.

How to run:

| suite | what | where it runs |
|---|---|---|
| **S** shared scenarios + traces | `spec/*.json` against each scheduler | Linux `make -C linux test`, Windows `dotnet test windows/Core.Tests`, Android `./gradlew :core:test`; all in CI |
| **LD** Linux detector | `make -C linux test-detector` (gjs) | locally; CI `gnome-pack` |
| **LH** Linux headless | `make -C linux test-headless`: two isolated GNOME Shell 50 sessions, two virtual monitors, synthetic keyboard and mouse, real PipeWire | locally (needs GNOME Shell 50) |
| **WU** Windows unit | `dotnet test windows/Core.Tests` (Menu, CallSettings, Copy, Store, BreakResume, CallUsage) | everywhere; CI |
| **WE** Windows end-to-end | `windows/test/e2e.ps1` on a real Windows session: synthetic keys and clicks, registry, screenshots | CI `windows` (windows-latest) |
| **AU** Android unit | `./gradlew :app:testDebugUnitTest` (BreakController, Copy) | everywhere; CI |
| **AI** Android instrumented | `./gradlew :app:connectedDebugAndroidTest` on a device | a connected phone (Pixel 9a, Android 17) |

## Timing

| REQ | requirement | Linux | Windows | Android |
|---|---|---|---|---|
| REQ-001 | Work interval is 20 minutes. | S basic cycle; LH "a break comes after the work interval" | S basic cycle; WE CALLS "nothing in use: the break comes" | S basic cycle; AI scheduledBreakComesAndGoes |
| REQ-002 | A warning `Break in 10 s` shows 10 s before a break; it takes no input. | S basic cycle; LH WARNING | S basic cycle; WE smoke "phase warning" | S basic cycle; AU warning shows notice |
| REQ-003 | A break lasts 30 s and covers every monitor / the whole display, bars included. | S basic cycle; LH "covers every monitor", "ends by itself"; LH pixels second monitor | S basic cycle; WE INPUT "ends by itself"; WE smoke | S basic cycle; AI breakCoversWholeDisplay, scheduledBreakComesAndGoes |
| REQ-005 | Idle of 5 minutes or more restarts the interval. | S idle resets | S idle resets | S idle resets; AU screen off 5 min is rest / 4 min is not |
| REQ-006 | Fail-safe: the break screen is gone 35 s after it appeared, whatever else happens. | LH FAIL-SAFE (stuck scheduler) | WE INPUT "within 35 s", KILL "not past breakStart + 35 s", RESCUE | AI failsafeRemovesStuckBreak |
| REQ-007 | A restart or login begins a fresh interval. | S restart is fresh; LH START | S restart is fresh; WU BreakResume | S restart is fresh; AI serviceStartsFresh |
| REQ-015 | Clock jumps (suspend, backward step) count as rest. | S traces suspend/backward | S traces | S traces |
| REQ-020 | Screen off for 5 minutes or more counts as idle. | — | — | AU screen off 5 min is rest, 4 min is not |

## No way out

| REQ | requirement | Linux | Windows | Android |
|---|---|---|---|---|
| REQ-004 | Nothing the user presses or taps during a break reaches anything else. | LH BREAK keys + click | WE INPUT | AI tapsDoNotReachAppDuringBreak, volumeKeysDoNothingDuringBreak |
| REQ-021 | The app offers no way to stop a break, skip it or turn BlackBreak off. Only a reboot or the pre-set pause gets rid of breaks. | LH "no menu item turns BlackBreak off" | WU "no item stops a break or quits"; WE KILL (killed app and watchdog come back) | AI appScreenHasNoOffAndSwitchWorks |
| REQ-022 | During a break, shortcuts do nothing: Super/Win, Alt+Tab, Alt+F2, Alt+F4, Ctrl+Esc, Escape, Back, Home, Recents, volume. | LH Super, Alt+F2, Alt+Tab, Escape | WE INPUT Win, Alt+Tab, Alt+F4, Ctrl+Esc | AI navigationDoesNotEndBreak, volumeKeysDoNothingDuringBreak |
| REQ-023 | During a break, clicks and taps do nothing underneath. | LH "a click on the top bar does not open the menu" | WE INPUT clicks | AI tapsDoNotReachAppDuringBreak |
| REQ-016 | A killed app is relaunched; a relaunch never extends a break. | — (a GNOME extension cannot be killed apart from the shell) | WU BreakResume; WE KILL | — (a killed service takes its overlay with it) |
| REQ-018 | The app starts at login. | — (GNOME starts enabled extensions) | WE INPUT "Run key is set" | — (Android binds enabled accessibility services) |
| REQ-032 | No black screen and no notice over the lock screen. | LH LOCK | manual (the break desktop is never shown over the secure desktop) | — |

## Pause

| REQ | requirement | Linux | Windows | Android |
|---|---|---|---|---|
| REQ-008 | Pause for 30 min, 1, 2 or 3 h, only in the work phase. | S pause cases; LH PAUSE | S pause cases; WU Menu "warning and break: nothing can be changed" | S pause cases |
| REQ-009 | One pause per calendar day; it survives a restart. | S one per day; LH "still no second pause after the extension restarts" | S one per day; WU "after the day's pause, pause stays off"; WU Store round trip | S one per day |
| REQ-010 | Cancelling a pause starts a fresh interval and still uses the day. | S cancel; LH "Cancel pause starts a fresh interval" | S cancel; WU Menu paused | S cancel |

## Calls and settings

| REQ | requirement | Linux | Windows | Android |
|---|---|---|---|---|
| REQ-026 | Defaults: call exemption off; microphone on; camera on (Android: one switch, off). | LH DEFAULTS | WU "defaults" | AI appScreenHasNoOffAndSwitchWorks |
| REQ-011 | With the exemption off, a call never holds a break. | S call cases; LD; LH CALLS | S; WU; WE CALLS | S; AU VoIP mode ignored when exemption off |
| REQ-027 | Exemption on: microphone use holds the break when "Microphone in use" is on, not when it is off. | LD matrix; LH CALLS; LH MIC (real PipeWire recording) | WU CallSettings; WE CALLS (registry) | AU VoIP mode holds when on and seen before due |
| REQ-028 | Exemption on: camera use holds the break when "Camera in use" is on, not when it is off. | LD matrix + camera scan of a fake /proc; LH CALLS | WU CallSettings; WE CALLS (registry) | — (no camera rule on Android) |
| REQ-012 | A break waits for a call at most 3 h; when the call ends the warning starts. | S call cap; LH "the break comes once the call ends" | S call cap | S call cap |
| REQ-013 | A phone call always holds a due break (Android). | — | — | S phone call uncapped; AU phone call holds without exemption |
| REQ-019 | The dialer is never covered: a phone call removes the break screen for the rest of that break. | — | — | AU ringing during break hides overlay |
| REQ-014 | Settings and pause cannot be changed in the warning or the break; a change counts from the next work interval. | LD snapshot; LH warning/break "settings are disabled" | WU Menu locked | AI switch enabled in work; manual: greyed in break |
| REQ-017 | During the warning and the break every menu item is disabled. | LH "pause items are disabled", "settings are disabled" | WU Menu locked | — (the app screen is covered) |

## Look

| REQ | requirement | Linux | Windows | Android |
|---|---|---|---|---|
| REQ-030 | The break is warm black (#0D0C0B) with three cream serif lines, the middle one ending in tan italic, and the seconds left in the corner; English, or Slovak when the system is Slovak. | LH "three lines", "the seconds left are shown"; LH pixels | WU Copy; WE SCREEN pixels | AU Copy; AI breakCoversWholeDisplay (texts) |

Requirements without an automated test on a platform where they apply: REQ-032 on Windows (manual).
