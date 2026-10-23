# BlackBreak

A 20-20-20 break enforcer. Every 20 minutes the screen goes black for 30
seconds, and nothing you press or click does anything until the break is
over. Other break tools let you skip or postpone a break when it arrives,
so in practice it gets skipped. BlackBreak has no skip button: you decide
in advance, never in the moment.

During a break the screen says:

    Look at something far away — at least 6 m (20 ft).
    Stretch your arms and your back.
    Sit up straight, shoulders back.
    Slowly turn and tilt your head to stretch your neck.

Ten seconds before a break a small notice says `Break in 10 s`. If you
have been idle for 5 minutes, that counts as rest and the 20 minutes
start again. After a restart or login a fresh interval begins.

## Install (GNOME 50, Wayland)

Download `blackbreak-linux-gnome-vX.Y.Z.zip` from the latest release,
then:

    gnome-extensions install blackbreak-linux-gnome-vX.Y.Z.zip

Log out and back in, then:

    gnome-extensions enable blackbreak@junkers4.github.io

From a checkout, `make -C linux install` does the same.

## Releases

Builds are on the GitHub Releases page, each with a `SHA256SUMS` file
(check with `sha256sum -c SHA256SUMS`). Versions follow SemVer (`vX.Y.Z`
tags on `main`); the notes of each release come from `CHANGELOG.md`.

## Pause

The alarm-clock icon in the top bar has a menu: pause for 30 minutes, 1, 2 or 3
hours. You get one pause per day (local time), and cancelling it early
still uses it. Pausing only works in a normal work interval, not during
the warning or a break.

## Calls

Off by default. In Settings (same menu) you can let a break wait while the microphone
or the camera is in use. A break waits at most 3 hours. A call that starts
during the warning does not stop the break. Settings changed during the
warning or a break take effect in the next work interval.

## What it cannot block

Switching to a text console (Ctrl+Alt+F3) and rebooting still work. If
anything goes wrong, the break screen removes itself after 35 seconds.

## Platforms

| Platform | Status |
|---|---|
| Linux (GNOME) | available |
| Windows | next |
| Android | next |
| iOS | later: needs a paid Apple developer account, a Mac and Apple's approval of the Screen Time entitlement |

## Development

    make -C linux test    # scheduler and shared scenarios (node 24)
    make -C linux pack    # zip in linux/dist/

The timing rules live in `linux/blackbreak@junkers4.github.io/scheduler.js`
and are pinned by `spec/scenarios.json`, which the other platforms will
reuse. Requirements and their tests: `docs/requirements.md`. Manual
checks: `linux/test/manual-checklist.md`.

## License

MIT
