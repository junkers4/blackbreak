# Manual checklist (Android)

Fast runs need a debug build: `adb shell setprop debug.blackbreak.fast 6`
(scale 6: 200 s work, 5 s break; `1` means scale 60), then turn the service
off and on. Real timings: release build, or no property.
A short work interval with the real 30 s break: `adb shell setprop debug.blackbreak.work 10`
(a break after 10 s of work), then `adb shell am force-stop io.github.junkers4.blackbreak` and open the app.
Test over an ordinary app (Calculator): Settings and the notification shade hide every overlay.

## Break screen
- [ ] The break covers the status bar and the navigation bar; solid black, also around a camera cutout.
- [ ] The three lines are cream on warm black, left aligned, the middle one with an italic tan ending; the seconds left are in the bottom left corner.
- [ ] The break ends after 30 s.
- [ ] Rotating the phone, or folding it, during a break keeps everything covered.

## No input
- [ ] Taps and swipes do nothing during a break.
- [ ] Back, Home and Recents gestures: still black, nothing usable underneath.
- [ ] Volume keys do nothing useful during a break.

## Warning
- [ ] `Break in 10 s` appears 10 s before the break, top center; touches pass through it.

## Calls
- [ ] An incoming phone call during a break removes the break at once; the call screen is usable; the break does not come back.
- [ ] A phone call that is on when a break is due holds it (switch off or on); the break comes after the call.
- [ ] A WhatsApp/Meet call with `Wait with the break while I'm in a call` on holds the break; with it off it does not.

## Screen off, reboot
- [ ] Screen off for 5 minutes or more counts as rest (the next break is 20 min after the screen came on).
- [ ] Reboot gives a fresh interval and keeps the day's pause (no second pause that day).
- [ ] Force stop and reopen within 5 minutes: `Next break at` keeps the same time (the interval is saved).

## Apps
- [ ] `Apps` lists the launcher apps, navigation first; choosing Waze shows `Allow usage access` until it is granted.
- [ ] Waze on screen when the break is due: no warning, no break, status `The break waits for Waze`; leaving Waze gives the warning and the break.
- [ ] Waze in picture-in-picture also holds the break; Waze opened during the 10 s warning: the break screen does not cover it.

## Pause and setup
- [ ] The buttons `Pause 30 min` … `Pause 3 hours` work; the status shows `Paused until HH:MM`; `Cancel pause` starts a fresh interval.
- [ ] After one pause the pause buttons are greyed until tomorrow, also after a restart.
- [ ] The call switch is greyed in the warning, the break and while a call holds a break.
- [ ] With the service off the screen says `BlackBreak is off` and shows the setup button.
- [ ] Turning the service off in Accessibility settings is impossible during a break (nothing is touchable), and works outside it.
