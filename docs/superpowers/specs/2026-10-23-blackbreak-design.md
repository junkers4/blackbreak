# BlackBreak — design

Date: 2026-10-23
Status: approved by owner 2026-10-23

## Intent

An open-source 20-20-20 break enforcer. Every 20 minutes the screen goes
fully black for 30 seconds and the user cannot do anything: no keys, no
mouse, no touch, no closing it, no skipping it. Light grey English text on
the black tells them what to do during those 30 seconds. The only way out
of a break that got stuck is a restart of the device.

Why: existing tools (Safe Eyes, Stretchly, Workrave) let you skip or
postpone the break at the moment it arrives, so in practice the break gets
skipped. The point of BlackBreak is that the decision is made in advance,
never in the moment.

Owner: GitHub user `junkers4`, public repo `junkers4/blackbreak`.

## Behaviour (same on every platform)

- **Work interval:** 20 minutes. **Break:** 30 seconds. Both fixed; not
  user-configurable in v1.
- **Break screen:** solid black over every monitor / the whole display,
  including panels, task bars, status and navigation bars. Centered, light
  grey (#9A9A9A-ish), thin sans-serif text, English:

      Look at something far away — at least 6 m (20 ft).
      Stretch your arms and your back.
      Sit up straight, shoulders back.
      Slowly turn and tilt your head to stretch your neck.

  plus a small, dimmer countdown of the seconds left.
- **No input during a break.** Every key, click, touch and gesture the
  platform lets an app swallow is swallowed. Nothing on the break screen
  is interactive.
- **Warning:** 10 seconds before a break a small, non-interactive notice
  says "Break in 10 s". It has no buttons; it cannot postpone or skip.
  *(Designer's call: the owner said a pause must not be possible "when it
  pops up", which implies a notice exists.)*
- **Pause:** the user can pause BlackBreak in advance for a chosen time,
  at most 3 hours. Pausing is possible only while in a normal work
  interval — not during the 10-second warning and not during a break.
  When the pause ends, a fresh 20-minute interval starts.
- **One pause per day (owner's decision):** at most one pause per
  calendar day (local time, resets at midnight), up to 3 hours. Cancelling
  it early still uses up that day's pause. The day of the last pause is
  stored, so a restart does not give a new one.
- A running pause can be cancelled early at any time; that starts a fresh
  20-minute interval.
- **Idle:** if the user has been idle (no input / screen off) for 5
  minutes, that counts as rest and the 20-minute interval restarts when
  they come back.
- **Fail-safe:** the break screen removes itself at the latest 35 seconds
  after it appeared, by its own independent timer, even if the scheduler
  logic is broken. A stuck screen should be impossible in normal
  operation; restart is the last resort.
- **After restart/boot/login:** starts automatically, begins a fresh
  20-minute interval. A break is never resumed after a restart.
- **Tamper:** outside a break the owner may quit or uninstall the app;
  that is accepted. Inside a break, quitting is blocked as far as the
  platform allows (see below).

## Platforms

### Linux (v1): GNOME Shell extension

The owner runs Ubuntu 26.04 GNOME on Wayland. On Wayland only the
compositor can grab all input, so BlackBreak on Linux is a GNOME Shell
extension (GJS):

- the break screen is an actor covering the whole stage (all monitors,
  top bar included), with a modal grab on the whole UI group the way the
  lock screen does it, so Alt+Tab, Super, and the mouse do nothing;
- pause is set from a top-bar indicator menu (30 min, 1 h, 2 h, 3 h);
  the menu is disabled during warning and break;
- what remains possible: switching to a text VT (Ctrl+Alt+F3) and
  rebooting. Accepted.
- Other desktops (KDE, X11) are out of scope for v1.

### Windows (v1): .NET 8 tray app

- C# / .NET 8, single self-contained exe, tray icon with the pause menu,
  starts with the user's login.
- The break runs on a separate Win32 desktop (CreateDesktop /
  SwitchDesktop, like UAC), black window on every monitor, plus a
  low-level keyboard hook. Win, Alt+Tab, Alt+F4 do nothing.
- Ctrl+Alt+Del cannot be blocked by any app; Task Manager would open on
  the normal desktop, which is not visible during the break. A small
  watchdog process relaunches BlackBreak if it is killed. If it was
  killed during a break, the relaunched break only covers what is left of
  the original 30 s: the break deadline is absolute (start + 30 s, hard
  fail-safe start + 35 s) and is written to a small state file, so
  kill/relaunch cycles can never extend the black screen. A full reboot
  discards that state (fresh 20-minute interval).
- Quitting from the tray outside a break is allowed: it signals the
  watchdog (named event) to stop too. The tray Quit item is disabled
  during warning and break. *(Designer's call.)*
- Installer: zip or simple installer from GitHub Releases; no
  Microsoft Store.

### Android (v1): Kotlin app, sideloaded APK

- Kotlin, min SDK 26, distributed as an APK on GitHub Releases (later
  F-Droid possible; not Google Play, whose accessibility policy would
  reject it).
- A foreground service keeps the 20-minute timer; the break is drawn as
  an AccessibilityService overlay (TYPE_ACCESSIBILITY_OVERLAY) covering
  status and navigation bars, and the accessibility service swallows
  Back/Home/Recents and touches during the break.
- First-run setup walks the user through enabling the accessibility
  service and battery-optimisation exemption.
- What remains possible: the power button and a forced reboot. Accepted.
- Idle = screen off for 5 minutes.
- **Phone calls (owner's decision):** while a phone call is ringing or
  active, a due break waits; it starts right after the call ends. A break
  never covers the dialer, so emergency calls stay possible.

### iOS: postponed

Apple only lets an app cover other apps through the Screen Time API
(ManagedSettings shield), which needs a paid developer account, a Mac and
Apple's approval of the Family Controls entitlement, and still leaves the
home screen usable. Not in v1. The README lists it as "later" and explains
why.

### Call exemptions (owner's decision: optional, off by default)

A settings switch per platform, **off by default**: "Wait with the break
while I'm in a call". When on, a due break waits until the call ends and
starts right after it; the 10 s warning then comes as usual.

- **Detection = microphone or camera in use**, which catches MS Teams,
  Zoom, Google Meet, Discord, Slack, Signal, WhatsApp desktop etc. without
  per-app code:
  - Linux: an active PipeWire capture stream (microphone), or an open
    /dev/video* device (camera);
  - Windows: CapabilityAccessManager ConsentStore shows an app currently
    using microphone/webcam (LastUsedTimeStop = 0);
  - Android: AudioManager mode MODE_IN_COMMUNICATION (VoIP calls in any
    app), in addition to the always-on phone-call rule above.
- Under the switch, a list of which kinds count is shown (microphone,
  camera), both on when the switch is turned on. *(Designer's call.)*
- **Cap:** a break can wait for a call at most 3 hours; after that it
  comes anyway, so a microphone left open cannot disable BlackBreak.
  *(Designer's call, matches the 3 h pause limit.)*
- The switch can be changed only outside warning and break, like pause.

### More exemptions later

Any further exemption follows the same pattern: optional, off by
default, changeable only outside warning and break, and capped so a
break waits at most 3 hours.

## Look and size (owner's decision)

Small, simple, plain. No "AI app" look: no gradients, glow, emoji,
rounded card stacks, onboarding carousels, mascots or marketing copy.
Settings use the platform's own native widgets (GNOME popup menu and
preferences, Windows tray menu and a small plain dialog, Android
Material defaults) with short, plain labels. The break screen is only
black, the grey text and the countdown. Few dependencies; small
binaries.

## Requirements and tests

- `docs/requirements.md` lists each behaviour above as a numbered
  requirement (REQ-001 …). Every requirement names the test(s) that cover
  it on each platform, or says why it can only be checked by hand.
- The scheduler (work interval, warning, break, pause rules, max 3 h,
  idle reset, fail-safe timing, fresh start after restart) is pure logic
  with an injectable clock, implemented once per platform language and
  unit-tested with the same test cases on all three (a shared table of
  scenarios in `spec/scenarios.json` that each platform's tests read).
- Platform glue (overlay, input blocking) gets what automated tests the
  platform allows (Windows UI test on CI runner, Android instrumented
  test on emulator, GNOME extension tested in a nested/headless
  gnome-shell where feasible) plus a written manual test checklist.
- GitHub Actions: tests on every push; tagged releases build the GNOME
  extension zip, the Windows exe and the Android APK.

## Non-goals

- Configurable intervals (call exemptions are the only setting besides pause), themes, languages other than English, stats,
  accounts, cloud sync, telemetry. None of it in v1.
- Defeating the device owner (preventing uninstall outside a break).

## Anti-goals (would be a failure even if it "works")

- Any way to skip or shorten a break at the moment it arrives.
- A break screen that can stay stuck beyond its 30 seconds in normal use.
- Bright or busy break screen — it must be black with quiet grey text.

## Delivery order

*(Designer's call.)* Linux ships first (the owner's machine), then
Windows, then Android. One repo, one version tag builds every platform
that exists at that point; the shared scenario table is written with the
Linux scheduler and reused by the others.

## Left to the builder

Exact fonts and grey shades within "thin, light grey on black"; repo
layout; license (proposed MIT); test frameworks per platform; how the
shared scenario table is shaped.

## Amendments (approved by owner 2026-10-23)

- Windows: .NET 10 LTS with NativeAOT and plain Win32 instead of .NET 8 (.NET 8 support ends 2026-11-10; exe of a few MB).
- Windows: the call settings are check items in the tray menu, not a dialog.
- Android: no foreground service; the AccessibilityService owns the timer (no permanent notification, no battery-optimisation step).
- Android: calls are detected from the audio mode only (VoIP and phone); no separate camera rule in v1.
- Releases: SemVer tags `vX.Y.Z` — v0.1.0 Linux, v0.2.0 + Windows, v0.3.0 + Android, v1.0.0 after the manual checklists pass on real hardware.
