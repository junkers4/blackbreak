# Helpers for the headless session tests; sourced inside the test session.
UUID=blackbreak@junkers4.github.io
X="Main.extensionManager.lookup('$UUID').stateObj"
FAILED=0

# Evaluate JS in the shell; prints the value (strings without quotes).
ev() {
    local out
    out=$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval "$1" 2>&1)
    case "$out" in
        "(true, "*) out=${out#(true, \'}; out=${out%\')}; out=${out#\"}; out=${out%\"}; echo "$out" ;;
        *) echo "ERROR: $out" ;;
    esac
}

check() { # check <what> <js expression that should be true>
    local got
    got=$(ev "$2")
    if [ "$got" = true ]; then echo "  ok   $1"; else echo "  FAIL $1 (got: $got)"; FAILED=$((FAILED + 1)); fi
}

wait_for() { # wait_for <seconds> <js expression>
    local end=$((SECONDS + $1))
    while [ $SECONDS -lt $end ]; do
        [ "$(ev "$2")" = true ] && return 0
        sleep 0.2
    done
    return 1
}

check_wait() { # check_wait <what> <seconds> <js expression>
    if wait_for "$2" "$3"; then echo "  ok   $1"; else echo "  FAIL $1 (timeout)"; FAILED=$((FAILED + 1)); fi
}

# Synthetic input through Clutter virtual devices, as a real keyboard and mouse would send.
key() { # key <keyval name>... (pressed in order, released in reverse)
    local names="" n
    for n in "$@"; do names="$names'$n',"; done
    ev "(() => { const C = imports.gi.Clutter, G = imports.gi.GLib;
        const kb = global._bbKb ??= C.get_default_backend().get_default_seat().create_virtual_device(C.InputDeviceType.KEYBOARD_DEVICE);
        const ks = [$names].map(n => C['KEY_' + n]); let t = G.get_monotonic_time();
        for (const k of ks) kb.notify_keyval(t += 10000, k, C.KeyState.PRESSED);
        for (const k of ks.reverse()) kb.notify_keyval(t += 10000, k, C.KeyState.RELEASED);
        return true; })()" >/dev/null
    sleep 0.6
}

click_actor() { # click_actor <js expression for an actor>
    ev "(() => { const C = imports.gi.Clutter, G = imports.gi.GLib; const a = $1;
        const [x, y] = a.get_transformed_position(), [w, h] = a.get_transformed_size();
        const p = global._bbPtr ??= C.get_default_backend().get_default_seat().create_virtual_device(C.InputDeviceType.POINTER_DEVICE);
        let t = G.get_monotonic_time();
        p.notify_absolute_motion(t, x + w / 2, y + h / 2);
        p.notify_button(t += 20000, C.BUTTON_PRIMARY, C.ButtonState.PRESSED);
        p.notify_button(t += 20000, C.BUTTON_PRIMARY, C.ButtonState.RELEASED);
        return true; })()" >/dev/null
    sleep 0.6
}

screenshot() { # screenshot <file>
    gdbus call --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot \
        --method org.gnome.Shell.Screenshot.Screenshot false false "$1" >/dev/null
}
