# Manual checklist (Windows)

Fast runs: set `BLACKBREAK_DEBUG_FAST=1` before starting `BlackBreak.exe`
(20 s work, 0.5 s break). Real timings: no variable.

## Break screen
- [ ] The break covers every monitor and the taskbar; solid black.
- [ ] The four lines are light grey, centered on the primary monitor.
- [ ] The countdown counts down under them, dimmer.
- [ ] The break ends after 30 s and the normal desktop is back.

## No input
- [ ] Win, Alt+Tab, Alt+F4, Ctrl+Esc do nothing during a break.
- [ ] Mouse clicks do nothing during a break.
- [ ] Win+L locks the PC (allowed); after unlocking, the break is still black or already over.
- [ ] Ctrl+Alt+Del, then Cancel: black again within a second.

## Kill and fail-safe
- [ ] Kill `BlackBreak.exe` in Task Manager during a break (from behind Ctrl+Alt+Del): it comes back within about 2 s, black for the rest of the 30 s only.
- [ ] Kill both `BlackBreak.exe` processes during a break: the normal desktop is back after 35 s at the latest.
- [ ] Kill it when no break is running: it comes back after about 2 s.

## Monitors and power
- [ ] Plug or unplug a monitor during a break: every monitor is black.
- [ ] Sleep during a break, then wake: no black screen on wake.
- [ ] Reboot or sign in again: a fresh 20 min interval begins.

## Warning
- [ ] `Break in 10 s` appears 10 s before the break, top center.
- [ ] It has no buttons; clicks pass through it.
- [ ] It shows over a fullscreen video.

## Tray menu
- [ ] Left and right click open the same menu.
- [ ] `Next break at HH:MM` shows the right time.
- [ ] The pause items, the call items and `Quit` are greyed during the warning and the break (pause also outside the work phase).
- [ ] `Pause 30 min` works; the menu shows `Paused until HH:MM`; `Cancel pause` starts a fresh 20 min interval.
- [ ] A second pause the same day is greyed, also after a restart.
- [ ] `Quit` removes the icon and does not come back (the watchdog quits too).
- [ ] After a sign-in the app starts by itself (Run key).

## Calls
- [ ] By default a break comes during a Teams/Meet call.
- [ ] With `Wait with the break while I'm in a call` on, the break waits during a call with the microphone or the camera, and comes after it.
- [ ] `Microphone in use` off: a call with only the microphone does not hold.
