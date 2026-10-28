import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {Scheduler, Phase, WARN_MS, localDayKey} from './scheduler.js';
import {CallDetector} from './callDetect.js';
import {Overlay} from './overlay.js';
import {Notice} from './notice.js';
import {Indicator} from './indicator.js';

const FAST = GLib.getenv('BLACKBREAK_DEBUG_FAST') === '1';
const STUCK = GLib.getenv('BLACKBREAK_DEBUG_STUCK') === '1';
const NO_IDLE = GLib.getenv('BLACKBREAK_DEBUG_NOIDLE') === '1'; // a headless test session has no input
const SCALE = FAST ? 60 : 1;
// Calls are watched from this long before the warning is due, and while held.
const CALL_LEAD_MS = 60_000;

export default class BlackBreakExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._scheduler = new Scheduler(Date.now(), {
            scale: SCALE,
            lastPauseDay: this._settings.get_string('last-pause-day') || null,
        });
        this._phase = null;
        this._detector = new CallDetector(this._settings);
        this._settingsDirty = false;
        this._settingsId = this._settings.connect('changed', () => {
            this._settingsDirty = true;
        });
        this._overlay = new Overlay();
        this._notice = new Notice();
        this._indicator = new Indicator(this._scheduler,
            () => this._onPauseChanged(), () => this._openSettings(), () => this._testBreak());
        Main.panel.addToStatusArea(this.uuid, this._indicator);
        this._sessionId = Main.sessionMode.connect('updated', () => this._onSession());
        this._onSession();
        this._tick();
        // The warning is 10 s / 60 in fast mode, so tick faster to see it.
        this._tickId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, FAST ? 100 : 1000, () => {
            try {
                this._tick();
            } catch (e) {
                logError(e, 'BlackBreak: tick');
            }
            return GLib.SOURCE_CONTINUE;
        });
    }

    disable() {
        GLib.source_remove(this._tickId);
        Main.sessionMode.disconnect(this._sessionId);
        this._settings.disconnect(this._settingsId);
        this._detector.destroy();
        this._detector = null;
        this._overlay.destroy();
        this._notice.destroy();
        this._indicator.destroy();
        this._tickId = this._sessionId = 0;
        this._overlay = this._notice = this._indicator = null;
        this._scheduler = this._settings = null;
    }

    _tick() {
        const s = this._scheduler;
        const now = Date.now();
        const due = s.nextBreakAt === null ? null : s.nextBreakAt - WARN_MS / SCALE;
        // Settings take effect only in a normal work interval.
        if (this._settingsDirty && s.phase === Phase.WORK && now < due) {
            this._settingsDirty = false;
            this._detector.snapshot();
        }
        const watch = s.phase === Phase.WORK && now >= due - CALL_LEAD_MS / SCALE;
        if (!(STUCK && s.phase === Phase.BREAK)) {
            s.update({
                now,
                idleMs: NO_IDLE ? 0 : global.backend.get_core_idle_monitor().get_idletime(),
                inCall: watch && this._detector.inCall(),
                inPhoneCall: false,
            });
        }
        if (s.phase === this._phase)
            return;
        if (this._phase === Phase.BREAK && !STUCK)
            this._onBreakEnded();
        this._phase = s.phase;
        if (s.phase === Phase.WARNING) {
            if (this._settings.get_boolean('show-warning'))
                this._notice.show('Break in 10 s');
        } else if (s.phase === Phase.BREAK) {
            this._notice.hide();
            this._indicator.menu.close();
            this._overlay.hide(); // a test break may be showing
            // Stuck: a wrong end time, so only the fail-safe clears the screen.
            this._overlay.show(STUCK ? Date.now() + 3_600_000 : s.breakEndsAt);
        } else {
            this._notice.hide();
            this._overlay.hide();
        }
        this._indicator.refresh();
    }

    // A break that ran to its end: counted for today, and a soft sound if asked.
    _onBreakEnded() {
        const day = localDayKey(Date.now());
        const n = this._settings.get_string('stats-day') === day ? this._settings.get_int('stats-breaks') : 0;
        this._settings.set_string('stats-day', day);
        this._settings.set_int('stats-breaks', n + 1);
        if (this._settings.get_boolean('end-sound'))
            global.display.get_sound_player().play_from_theme('complete', 'BlackBreak', null);
    }

    _onPauseChanged() {
        this._settings.set_string('last-pause-day', this._scheduler.lastPauseDay ?? '');
        this._tick();
    }

    _onSession() {
        const locked = Main.sessionMode.isLocked;
        if (locked) {
            this._indicator.menu.close();
            this._overlay.hide();
            this._notice.hide();
        }
        this._indicator.container.visible = !locked;
    }

    // A 5 s look at the break screen; the schedule is not touched.
    _testBreak() {
        if (this._scheduler.phase !== Phase.WORK)
            return;
        this._indicator.menu.close();
        this._overlay.show(Date.now() + 5000);
    }

    _openSettings() {
        try {
            this.openPreferences();
        } catch (e) {
            logError(e, 'BlackBreak: open preferences');
        }
    }
}
