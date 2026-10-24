#!/bin/bash
# Runs the extension in two isolated headless GNOME Shell sessions and checks it from outside.
# Needs gnome-shell 50, gdbus, gjs, PipeWire. Your own session, settings and extensions are not touched.
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(mktemp -d /tmp/blackbreak-test-XXXXXX)
uuid=blackbreak@junkers4.github.io
ext=$root/data/gnome-shell/extensions/$uuid
mkdir -p "$ext" /tmp/bbt
make -s -C "$here/.." pack VERSION=0.0.0-test >/dev/null
(cd "$ext" && unzip -q "$here/../dist/blackbreak-linux-gnome-v0.0.0-test.zip")
glib-compile-schemas "$ext/schemas"

run_session() { # run_session <name> <extra env> <script>
    local rt=$root/run-$1
    mkdir -p "$rt" && chmod 700 "$rt"
    env -u WAYLAND_DISPLAY -u DISPLAY XDG_DATA_HOME=$root/data XDG_CONFIG_HOME=$root/config-$1 \
        XDG_RUNTIME_DIR=$rt BLACKBREAK_DEBUG_FAST=1 BLACKBREAK_DEBUG_NOIDLE=1 $2 \
        dbus-run-session -- bash -c "
            pipewire >/dev/null 2>&1 & sleep 1; wireplumber >/dev/null 2>&1 & pipewire-pulse >/dev/null 2>&1 & sleep 1
            gsettings set org.gnome.shell enabled-extensions \"['$uuid']\"
            gsettings set org.gnome.shell disable-user-extensions false
            gnome-shell --headless --wayland --no-x11 --unsafe-mode \
                --virtual-monitor 1280x720 --virtual-monitor 1024x768 > $root/shell-$1.log 2>&1 &
            sleep 6
            bash '$here/headless/$3'; code=\$?
            kill %4 2>/dev/null; kill %1 %2 %3 2>/dev/null
            exit \$code"
}

fail=0
echo '== session A: stuck break'
run_session stuck BLACKBREAK_DEBUG_STUCK=1 session-stuck.sh || fail=1
echo '== screenshot of the break'
python3 "$here/headless/pixels.py" /tmp/bbt/break-linux.png || fail=1
echo '== session B: fast timings'
run_session fast "" session-fast.sh || fail=1
grep -E 'JS ERROR|CRITICAL.*blackbreak' "$root"/shell-*.log && { echo 'extension errors in the shell log'; fail=1; }
[ $fail = 0 ] && echo 'headless: all passed' || echo "headless: FAILED (logs in $root)"
exit $fail
