# Changelog

All notable changes are listed here. The format follows Keep a Changelog,
and versions follow Semantic Versioning.

## [Unreleased]

- Windows: the same pixel look (animated rest scene, pixel warning, eye icon); written without a Windows test run.
- Android: the same pixel look (animated rest screen with an eye and a horizon, warning, app screen, eye icon), built by `android/build.sh`. No accessibility service: a foreground service and a window over other apps. New options: wait while music or video plays, buzz when a break ends, hide the warning, test break, breaks taken today.
- Linux: pixel-art look in the manner of Doom and Wolfenstein 3D: pixel-framed break screen with a progress bar, pixel-font warning, eye icon, pixel menu and settings.

## [0.3.0] - 2026-10-24

Android 8 or newer.

- An accessibility service covers the whole screen, bars included, for 30 seconds every 20 minutes and swallows touches and keys.
- A phone call always waits, and the dialer is never covered.
- Screen off for 5 minutes counts as rest.

## [0.2.0] - 2026-10-24

Windows 10 and 11.

- Tray app with the same break, warning, pause and call rules as Linux.
- The break runs on its own Windows desktop, so Win, Alt+Tab and the taskbar do nothing.
- A watchdog copy relaunches a killed app and always gets the desktop back after 35 seconds.
- Starts with Windows.

## [0.1.0] - 2026-10-23

First release, for Linux (GNOME 50, Wayland).

- Break: every 20 minutes the screen goes black for 30 seconds and input is blocked.
- Warning: a small notice shows 10 seconds before a break.
- Pause: one pause per day, for 30 minutes or 1, 2 or 3 hours.
- Idle: 5 minutes idle counts as rest and the interval starts again.
- Call exemption: optionally, a break waits (at most 3 hours) while the microphone or camera is in use.
- Fail-safe: the break screen removes itself after 35 seconds if anything goes wrong.
