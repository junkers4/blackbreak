// gjs tests for the call detector: the settings matrix and the camera scan.
// Run: GI_TYPELIB_PATH=/usr/lib/gnome-shell gjs -m test/detector.test.js
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import {CallDetector, cameraOpen} from '../blackbreak@junkers4.github.io/callDetect.js';

let failed = 0;
function check(ok, what) {
    print(`${ok ? '  ok  ' : '  FAIL'} ${what}`);
    if (!ok)
        failed++;
}

function fakeSettings(values) {
    return {get_boolean: k => values[k] ?? false, get_strv: k => values[k] ?? []};
}

function detector(call, mic, cam, micUse, camUse) {
    const d = new CallDetector(fakeSettings({'call-exemption': call, 'exempt-mic': mic, 'exempt-camera': cam}));
    d._micInUse = () => micUse;
    d._cameraInUse = () => camUse;
    return d;
}

// REQ-011, REQ-026..028: what the switches do
print('settings matrix');
const cases = [
    ['exemption off: microphone use does not count', [false, true, true, true, false], false],
    ['exemption off: camera use does not count', [false, true, true, false, true], false],
    ['microphone on: microphone use counts', [true, true, false, true, false], true],
    ['microphone off: microphone use does not count', [true, false, true, true, false], false],
    ['camera on: camera use counts', [true, false, true, false, true], true],
    ['camera off: camera use does not count', [true, true, false, false, true], false],
    ['nothing in use: no call', [true, true, true, false, false], false],
];
for (const [name, args, want] of cases) {
    const d = detector(...args);
    check(d.inCall() === want, name);
    d.destroy();
}

// Busy windows: a fullscreen window and listed apps, independent of the call switch
print('busy windows');
function win({fullscreen = false, cls = 'firefox', app = null} = {}) {
    return {is_fullscreen: () => fullscreen, get_wm_class: () => cls, get_gtk_application_id: () => app};
}
function busy(values, focus) {
    globalThis.global = {display: {focus_window: focus}};
    const d = new CallDetector(fakeSettings(values));
    const r = d.inCall();
    d.destroy();
    return r;
}
check(busy({'exempt-fullscreen': true}, win({fullscreen: true})) === true, 'fullscreen on: a fullscreen window holds the break');
check(busy({'exempt-fullscreen': true}, win()) === false, 'fullscreen on: a normal window does not');
check(busy({}, win({fullscreen: true})) === false, 'fullscreen off: it does not');
check(busy({'exempt-app-on': true, 'exempt-apps': [' Steam.desktop ']}, win({cls: 'steam_app_730'})) === true, 'a listed app in focus holds it (case, spaces)');
check(busy({'exempt-app-on': true, 'exempt-apps': ['org.blender.Blender.desktop']}, win({cls: 'firefox', app: 'org.blender.Blender'})) === true, 'the app id counts too');
check(busy({'exempt-app-on': true, 'exempt-apps': ['steam.desktop']}, win()) === false, 'another app does not');
check(busy({'exempt-apps': ['steam.desktop']}, win({cls: 'steam'})) === false, 'a chosen app with the switch off holds nothing');
check(busy({'exempt-app-on': true, 'exempt-apps': ['steam.desktop']}, null) === false, 'no focused window: no hold');
delete globalThis.global;

// Settings take effect only at snapshot() (the start of a work interval): REQ-014
print('snapshot');
{
    const values = {'call-exemption': false, 'exempt-mic': true, 'exempt-camera': true};
    const d = new CallDetector(fakeSettings(values));
    d._micInUse = () => true;
    values['call-exemption'] = true;
    check(d.inCall() === false, 'a switch flipped mid-interval changes nothing yet');
    d.snapshot();
    check(d.inCall() === true, 'it counts after the next snapshot');
    d.destroy();
}

// The camera scan over a fake /proc: REQ-028
print('camera scan');
function fakeProc(target) {
    const root = GLib.dir_make_tmp('bbproc-XXXXXX');
    GLib.mkdir_with_parents(`${root}/4242/fd`, 0o755);
    GLib.mkdir_with_parents(`${root}/self/fd`, 0o755);
    Gio.File.new_for_path(`${root}/4242/fd/7`).make_symbolic_link(target, null);
    return root;
}
const loop = new GLib.MainLoop(null, false);
(async () => {
    check(await cameraOpen(fakeProc('/dev/video0')) === true, 'an open /dev/video0 counts');
    check(await cameraOpen(fakeProc('/dev/snd/pcmC0D0c')) === false, 'other devices do not');
    check(await cameraOpen('/nonexistent') === false, 'no /proc: no camera');
})().catch(e => {
    logError(e);
    failed++;
}).finally(() => loop.quit());
loop.run();

print(failed ? `detector: ${failed} failed` : 'detector: all passed');
imports.system.exit(failed ? 1 : 0);
