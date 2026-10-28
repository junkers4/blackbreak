# Manual checklist (GNOME)

Fast runs: start a nested or headless shell with `BLACKBREAK_DEBUG_FAST=1`
(20 s work, 0.5 s break). Real timings: no variable.

## Break screen
- [ ] The break covers every monitor and the top bar; solid black.
- [ ] A red pixel frame with three white pixel-font lines (the middle one with a gold second row), the seconds left in grey bottom left and a 15-segment bar that fills over the break.
- [ ] The break ends after 30 s.

## No input
- [ ] Alt+Tab, Super, Alt+F2, Ctrl+Alt+T do nothing during a break.
- [ ] Mouse clicks and scrolling do nothing during a break.

## Warning
- [ ] `Break in 10 s` appears 10 s before the break, top center.
- [ ] It has no buttons; clicks pass through it.
- [ ] It shows over a fullscreen video (e.g. a YouTube video in fullscreen).

## Pause
- [ ] Pause items are greyed during the warning and the break.
- [ ] `Pause 30 min` works; the menu shows `Paused until HH:MM`.
- [ ] `Cancel pause` works and starts a fresh 20 min interval.
- [ ] A second pause the same day is greyed.
- [ ] It stays greyed after `gnome-extensions disable` / `enable`.

## Calls
Settings: the top bar menu, `Settings`.
- [ ] By default the switch is off: a break comes during a Teams/Meet call
      in the browser.
- [ ] `Microphone in use` and `Camera in use` are greyed while the switch
      is off.
- [ ] Switch on: the break waits while the microphone is on, and the
      warning comes right after the call ends.
- [ ] Camera only (`ffplay /dev/video0`, no microphone) holds the break
      when `Camera in use` is on, and not when it is off.
- [ ] Turning the switch on or off during a break, or while a break waits
      for a call, has no effect on that break; it counts from the next
      interval.
- [ ] A call that starts during the 10 s warning does not stop the break.

## Edge cases
- [ ] Plug or unplug a monitor during a break: still all black.
- [ ] Lock the screen with a break due: the lock screen works; no black
      screen and no `Break in 10 s` over it; the indicator is hidden on the
      lock screen.
- [ ] `gnome-extensions disable blackbreak@junkers4.github.io` from a VT
      (Ctrl+Alt+F3) during a break releases the screen.

## Fail-safe
- [ ] With `BLACKBREAK_DEBUG_STUCK=1` (the scheduler never leaves the
      break, and the screen gets a wrong end time of about 3600 s) the
      screen still clears 35 s after it appeared.
