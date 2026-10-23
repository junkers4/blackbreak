import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Gvc from 'gi://Gvc';

const CAMERA_SCAN_MS = 5000, STALE_MS = 30_000;
const TARGET = 'standard::symlink-target';
// The shell itself and volume meters capture without a call.
const SKIPPED_APPS = ['org.gnome.Shell', 'org.gnome.VolumeControl', 'org.PulseAudio.pavucontrol'];

Gio._promisify(Gio.File.prototype, 'enumerate_children_async');
Gio._promisify(Gio.FileEnumerator.prototype, 'next_files_async');

// True when some process of ours has an open fd to a /dev/video* device.
// Async, so the scan of /proc runs in GIO's threads, not in the shell's.
export async function cameraOpen(procDir = '/proc') {
    for (const pid of await listDir(procDir, 'standard::name')) {
        const name = pid.get_name();
        if (!/^\d+$/.test(name))
            continue;
        // Other users' fd dirs are not readable, so only ours are listed.
        const fds = await listDir(`${procDir}/${name}/fd`, TARGET);
        if (fds.some(fd => fd.get_attribute_byte_string(TARGET)?.startsWith('/dev/video')))
            return true;
    }
    return false;
}

async function listDir(path, attrs) {
    const infos = [];
    try {
        const en = await Gio.File.new_for_path(path).enumerate_children_async(attrs,
            Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, GLib.PRIORITY_LOW, null);
        let batch;
        while ((batch = await en.next_files_async(256, GLib.PRIORITY_LOW, null)).length)
            infos.push(...batch);
        en.close(null);
    } catch (e) {
        // gone meanwhile, or not ours
    }
    return infos;
}

export class CallDetector {
    constructor(settings) {
        this._settings = settings;
        this._cameraAt = -Infinity;
        this._camera = false;
        this._scanning = false;
        this._mixer = new Gvc.MixerControl({name: 'blackbreak'});
        this._mixer.open();
        this.snapshot();
    }

    // The settings in force; read at the start of each work phase.
    snapshot() {
        const s = this._settings;
        this._on = s.get_boolean('call-exemption');
        this._mic = s.get_boolean('exempt-mic');
        this._cam = s.get_boolean('exempt-camera');
    }

    inCall() {
        if (!this._on)
            return false;
        if (this._mic && this._micInUse())
            return true;
        return this._cam && this._cameraInUse();
    }

    _micInUse() {
        if (this._mixer.get_state() !== Gvc.MixerControlState.READY)
            return false;
        return this._mixer.get_source_outputs().some(
            o => !SKIPPED_APPS.includes(o.get_application_id()));
    }

    // The last scan's result; a new scan starts when it is 5 s old.
    _cameraInUse() {
        const now = GLib.get_monotonic_time() / 1000;
        if (!this._scanning && now - this._cameraAt >= CAMERA_SCAN_MS) {
            if (now - this._cameraAt >= STALE_MS)
                this._camera = false; // from an earlier interval
            this._scanning = true;
            cameraOpen().then(open => {
                this._camera = open;
                this._cameraAt = GLib.get_monotonic_time() / 1000;
            }).catch(e => logError(e, 'BlackBreak: camera scan'))
                .finally(() => (this._scanning = false));
        }
        return this._camera;
    }

    destroy() {
        this._mixer.close();
        this._mixer = this._settings = null;
    }
}
