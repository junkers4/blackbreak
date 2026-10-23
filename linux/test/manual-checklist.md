# Manual checklist (GNOME)

Fast runs: start a nested or headless shell with `BLACKBREAK_DEBUG_FAST=1`
(20 s work, 0.5 s break). Real timings: no variable.

## Break screen
- [ ] The break covers every monitor and the top bar; solid black.
- [ ] The four lines are light grey, centered on the primary monitor.
- [ ] The countdown counts down under them, dimmer.
- [ ] The break ends after 30 s.

## No input
- [ ] Alt+Tab, Super, Alt+F2, Ctrl+Alt+T do nothing during a break.
- [ ] Mouse clicks and scrolling do nothing during a break.

## Warning
- [ ] `Break in 10 s` appears 10 s before the break, top center.
- [ ] It has no buttons; clicks pass through it.

## Pause
- [ ] Pause items are greyed during the warning and the break.
- [ ] `Pause 30 min` works; the menu shows `Paused until HH:MM`.
- [ ] `Cancel pause` works and starts a fresh 20 min interval.
- [ ] A second pause the same day is greyed.
- [ ] It stays greyed after `gnome-extensions disable` / `enable`.

## Edge cases
- [ ] Plug or unplug a monitor during a break: still all black.
- [ ] Lock the screen with a break due: the lock screen works; no black
      screen over it; the indicator is hidden on the lock screen.
- [ ] `gnome-extensions disable blackbreak@junkers4.github.io` from a VT
      (Ctrl+Alt+F3) during a break releases the screen.

## Fail-safe
- [ ] With `BLACKBREAK_DEBUG_STUCK=1` (the scheduler never leaves the
      break) the screen still clears 35 s after it appeared.
