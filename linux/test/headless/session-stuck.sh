# Session A: BLACKBREAK_DEBUG_STUCK=1, so a break lasts until the 35 s fail-safe.
. "$(dirname "$0")/lib.sh"

echo 'START (REQ-007)'
check_wait 'the extension is active' 15 "Main.extensionManager.lookup('$UUID').state === 1"
check 'a fresh interval starts in the work phase' "$X._scheduler.phase === 'work'"

echo 'DEFAULTS (REQ-011, REQ-026)'
check 'call exemption is off' "$X._settings.get_boolean('call-exemption') === false"
check 'microphone is off' "$X._settings.get_boolean('exempt-mic') === false"
check 'camera is off' "$X._settings.get_boolean('exempt-camera') === false"
check 'fullscreen and chosen app are off' "$X._settings.get_boolean('exempt-fullscreen') === false && $X._settings.get_boolean('exempt-app-on') === false"

echo 'CONTROLS: before the break, keys and clicks work (proves the input is real)'
key Super_L
check 'Super opens the overview' "Main.overview.visible === true"
ev "Main.overview.hide()" >/dev/null; sleep 1
click_actor "$X._indicator"
check 'a click opens the BlackBreak menu' "$X._indicator.menu.isOpen === true"
check 'pause items are enabled in work' "$X._indicator._pauseItems.every(i => i.sensitive)"
check 'no menu item turns BlackBreak off or skips a break (REQ-021)' \
    "!$X._indicator.menu._getMenuItems().some(i => /quit|skip|stop|disable|turn off/i.test(i.label?.text ?? ''))"
ev "$X._indicator.menu.close()" >/dev/null

echo 'WARNING (REQ-002, REQ-014, REQ-017)'
check_wait 'the warning comes' 25 "$X._scheduler.phase === 'warning' || $X._scheduler.phase === 'break'"
check 'Break in 10 s is shown, or the break already began' "$X._notice._bin !== null || $X._scheduler.phase === 'break'"

echo 'BREAK (REQ-003, REQ-004, REQ-022, REQ-023, REQ-030)'
check_wait 'the break begins' 5 "$X._overlay._widget !== null"
check 'the black screen covers every monitor (the whole stage)' \
    "$X._overlay._widget.width === global.stage.width && $X._overlay._widget.height === global.stage.height"
check 'two monitors are present' "Main.layoutManager.monitors.length === 2"
check 'input is grabbed (modal, no shell actions)' "Main.modalCount > 0 && Main.actionMode === 0"
check 'three lines of text' "$X._overlay._drawn.lines === 3"
check 'the seconds left are shown' "/^[0-9]+ (seconds?|sekúnd|sekundy|sekunda)\$/.test($X._overlay._drawn.seconds)"
check 'pause items are disabled' "$X._indicator._pauseItems.every(i => !i.sensitive)"
check 'settings are disabled' "!$X._indicator._settings.sensitive"
key Super_L
check 'Super does not open the overview' "Main.overview.visible === false"
key Alt_L F2
check 'Alt+F2 does not open the run dialog' "!(Main._runDialog?.visible)"
key Alt_L Tab
check 'Alt+Tab does not open the switcher' "!global.stage.get_children().some(a => a.constructor.name.includes('Switcher') && a.visible)"
key Escape
check 'Escape does not end the break' "$X._overlay._widget !== null"
click_actor "$X._indicator"
check 'a click on the top bar does not open the menu' "$X._indicator.menu.isOpen === false"
ev "$X._indicator.menu.close()" >/dev/null
check 'the break is still on after all of that' "$X._overlay._widget !== null"
screenshot /tmp/bbt/break-linux.png

echo 'FAIL-SAFE (REQ-006)'
check_wait 'the black screen removes itself within 35 s even though the scheduler is stuck' 40 "$X._overlay._widget === null"

echo "session-stuck: $FAILED failed"
exit $FAILED
