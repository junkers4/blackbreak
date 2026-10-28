# BlackBreak: notes for Claude

- The break is 30 s, every 20 min of work (the 20-20-20 idea, but a 30 s break).
- Visual style, whole app: old-school pixel art in the manner of Doom and
  Wolfenstein 3D (red pixel frame, segmented progress bar, pixel eye icon,
  gold and white 5x7 pixel font, no smoothing, no rounded corners).
  Palette: bg #0D0C0B, frame red #B01818, menu blue #5C5CFC on #04042C, gold #FCC030, white #F4F0E0, green #30C030.
  Linux is the reference: `linux/blackbreak@junkers4.github.io/pixel.js`.
- Order of work: Linux first (tested), the phone (Android, Pixel connected) and Windows afterwards.
- Linux checks: `make -C linux test-all`; the headless run leaves a screenshot in `/tmp/bbt/break-linux.png`. Always look at it after a visual change.
- Slovak texts need accents in the pixel font (see `SK` in pixel.js).
- Android: `android/build.sh debug` builds the APK without Gradle: the service, scheduler glue and
  text are smali (`app/src/main/smali`), the pixel screens (`BreakOverlay`, `NoticeOverlay`,
  `MainActivity`, `Pixel`) are Java in `app/src/main/java`, dexed as `classes2.dex`; `android/stubs`
  are compile-only stand-ins for the smali classes. The old Kotlin sources are not built any more.
- Android options (all off unless noted): wait during a call, wait while music/video plays, show
  "Break in 10 s" (on), short buzz at the end, Test break, breaks taken today. They live in
  `Options.java`; the smali service asks `Options` in `tick`.
- Android needs no accessibility service: `BreakService` is a foreground service (quiet min-importance
  notification, `Notifier.java`) and the break is a `TYPE_APPLICATION_OVERLAY` window, so the one
  permission is "show over other apps". `BootReceiver` restarts it after boot and updates.
  The rest screen (BreakOverlay) has an eye that looks around and blinks, stars and a drifting horizon.
