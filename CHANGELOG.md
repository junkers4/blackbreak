# Changelog

All notable changes are listed here. The format follows Keep a Changelog,
and versions follow Semantic Versioning.

## [Unreleased]

## [0.1.0] - 2026-10-23

First release, for Linux (GNOME 50, Wayland).

- Break: every 20 minutes the screen goes black for 30 seconds and input is blocked.
- Warning: a small notice shows 10 seconds before a break.
- Pause: one pause per day, for 30 minutes or 1, 2 or 3 hours.
- Idle: 5 minutes idle counts as rest and the interval starts again.
- Call exemption: optionally, a break waits (at most 3 hours) while the microphone or camera is in use.
- Fail-safe: the break screen removes itself after 35 seconds if anything goes wrong.
