import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {Scheduler, Phase} from './scheduler.js';
import {Overlay} from './overlay.js';
import {Notice} from './notice.js';
import {Indicator} from './indicator.js';

const FAST = GLib.getenv('BLACKBREAK_DEBUG_FAST') === '1';
const STUCK = GLib.getenv('BLACKBREAK_DEBUG_STUCK') === '1';

export default class BlackBreakExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._scheduler = new Scheduler(Date.now(), {
            scale: FAST ? 60 : 1,
            lastPauseDay: this._settings.get_string('last-pause-day') || null,
        });
        this._phase = null;
        this._overlay = new Overlay();
        this._notice = new Notice();
        this._indicator = new Indicator(this._scheduler,
            () => this._onPauseChanged(), () => this._openSettings());
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
        this._overlay.destroy();
        this._notice.destroy();
        this._indicator.destroy();
        this._tickId = this._sessionId = 0;
        this._overlay = this._notice = this._indicator = null;
        this._scheduler = this._settings = null;
    }

    _tick() {
        const s = this._scheduler;
        if (!(STUCK && s.phase === Phase.BREAK)) {
            s.update({
                now: Date.now(),
                idleMs: global.backend.get_core_idle_monitor().get_idletime(),
                inCall: false,
                inPhoneCall: false,
            });
        }
        if (s.phase === this._phase)
            return;
        this._phase = s.phase;
        if (s.phase === Phase.WARNING) {
            this._notice.show('Break in 10 s');
        } else if (s.phase === Phase.BREAK) {
            this._notice.hide();
            this._indicator.menu.close();
            this._overlay.show(s.breakEndsAt);
        } else {
            this._notice.hide();
            this._overlay.hide();
        }
        this._indicator.refresh();
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
        }
        this._indicator.container.visible = !locked;
    }

    _openSettings() {
        try {
            this.openPreferences();
        } catch (e) {
            logError(e, 'BlackBreak: open preferences');
        }
    }
}
