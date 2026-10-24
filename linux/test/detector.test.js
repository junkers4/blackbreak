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
    return {get_boolean: k => values[k]};
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
