# Session B: fast timings (20 s work, 0.5 s break).
. "$(dirname "$0")/lib.sh"

check_wait 'the extension is active' 15 "Main.extensionManager.lookup('$UUID').state === 1"

echo 'BREAK ENDS (REQ-001, REQ-003)'
check_wait 'a break comes after the work interval' 30 "$X._scheduler.phase === 'break'"
check_wait 'and ends by itself at its end time' 3 "$X._overlay._widget === null && $X._scheduler.phase === 'work'"

echo 'PAUSE (REQ-008, REQ-009, REQ-010)'
click_actor "$X._indicator"
click_actor "$X._indicator._pauseItems[0]"
check 'Pause 30 min pauses' "$X._scheduler.phase === 'paused'"
check 'the menu says Paused until' "$X._indicator._status.label.text.startsWith('Paused until')"
check 'the day of the pause is stored' "$X._settings.get_string('last-pause-day') !== ''"
check 'no break while paused' "$X._overlay._widget === null"
click_actor "$X._indicator"
click_actor "$X._indicator._cancel"
check 'Cancel pause starts a fresh interval' "$X._scheduler.phase === 'work' && $X._scheduler.nextBreakAt - Date.now() > 15000"
check 'a second pause today is not offered' "$X._indicator._pauseItems.every(i => !i.sensitive)"
ev "$X._indicator.menu.close()" >/dev/null
ev "Main.extensionManager.disableExtension('$UUID')" >/dev/null; sleep 1
ev "Main.extensionManager.enableExtension('$UUID')" >/dev/null; sleep 1
check 'still no second pause after the extension restarts' "!$X._scheduler.canPause && $X._indicator._pauseItems.every(i => !i.sensitive)"

echo 'CALLS (REQ-011, REQ-012, REQ-027, REQ-028)'
# The detector's device checks are replaced here; the real ones are in detector.test.js and MIC below.
set_use() { ev "(() => { const d = $X._detector; d._micInUse = () => $1; d._cameraInUse = () => $2; return true; })()" >/dev/null; }
restart_ext() { ev "Main.extensionManager.disableExtension('$UUID')" >/dev/null; sleep 0.5; ev "Main.extensionManager.enableExtension('$UUID')" >/dev/null; sleep 0.5; }
case_hold() { # case_hold <name> <call> <mic> <cam> <micUse> <camUse> <expect: hold|break>
    gsettings set org.gnome.shell.extensions.blackbreak call-exemption "$2"
    gsettings set org.gnome.shell.extensions.blackbreak exempt-mic "$3"
    gsettings set org.gnome.shell.extensions.blackbreak exempt-camera "$4"
    restart_ext
    set_use "$5" "$6"
    if [ "$7" = hold ]; then
        sleep 26
        check "$1" "$X._scheduler.phase === 'work' && $X._overlay._widget === null"
        set_use false false
        check_wait '  and the break comes once the call ends' 4 "$X._scheduler.phase === 'warning' || $X._scheduler.phase === 'break' || $X._scheduler.phase === 'work' && $X._scheduler.nextBreakAt > Date.now() + 15000"
    else
        check_wait "$1" 26 "$X._scheduler.phase === 'break' || $X._scheduler.phase === 'warning'"
    fi
}
export GSETTINGS_SCHEMA_DIR=$XDG_DATA_HOME/gnome-shell/extensions/$UUID/schemas
case_hold 'exemption off, microphone in use: the break comes' false true true true false break
case_hold 'exemption on, microphone on, microphone in use: the break waits' true true false true false hold
case_hold 'exemption on, microphone off, microphone in use: the break comes' true false true true false break
case_hold 'exemption on, camera on, camera in use: the break waits' true false true false true hold
case_hold 'exemption on, camera off, camera in use: the break comes' true true false false true break
case_hold 'exemption on, nothing in use: the break comes' true true true false false break

echo 'MIC: real microphone use through PipeWire is seen (REQ-027)'
restart_ext
if command -v pw-record >/dev/null && pw-cli info 0 >/dev/null 2>&1; then
    check 'no recording: microphone not in use' "$X._detector._micInUse() === false"
    pw-record /dev/null & REC=$!
    check_wait 'while recording: microphone in use' 10 "$X._detector._micInUse() === true"
    kill $REC; wait $REC 2>/dev/null
    check_wait 'recording stopped: not in use' 10 "$X._detector._micInUse() === false"
else
    echo "  FAIL PipeWire is not available in the test session"; FAILED=$((FAILED + 1))
fi

echo 'LOCK (REQ-032)'
gsettings set org.gnome.shell.extensions.blackbreak call-exemption false
restart_ext
ev "Main.screenShield.lock(false)" >/dev/null
check_wait 'the screen locks' 10 "Main.sessionMode.isLocked === true"
check 'the indicator is hidden on the lock screen' "$X._indicator.container.visible === false"
sleep 24
check 'no black screen over the lock screen when a break is due' "$X._overlay._widget === null"
check 'no notice over the lock screen' "$X._notice._bin === null"

echo "session-fast: $FAILED failed"
exit $FAILED
