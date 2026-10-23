import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {FAILSAFE_MS} from './scheduler.js';

const LINES = [
    'Look at something far away — at least 6 m (20 ft).',
    'Stretch your arms and your back.',
    'Sit up straight, shoulders back.',
    'Slowly turn and tilt your head to stretch your neck.',
];

// The break screen: black over the whole stage, with a modal grab.
export class Overlay {
    show(endsAtMs) {
        if (this._widget || Main.sessionMode.isLocked)
            return;
        this._endsAt = endsAtMs;
        // Armed first, so nothing below can leave the screen black.
        this._failsafeId = GLib.timeout_add(GLib.PRIORITY_HIGH, FAILSAFE_MS, () => {
            this._failsafeId = 0;
            this.hide();
            return GLib.SOURCE_REMOVE;
        });
        this._widget = new St.Widget({
            style_class: 'blackbreak-overlay',
            reactive: true,
            can_focus: true,
        });
        this._box = new St.Bin({
            child: this._buildText(),
        });
        this._widget.add_child(this._box);
        Main.layoutManager.addTopChrome(this._widget);
        this._monitorsId = Main.layoutManager.connect('monitors-changed',
            () => this._resize());
        this._resize();
        this._grab = Main.pushModal(this._widget, {actionMode: Shell.ActionMode.NONE});
        this._updateCountdown();
    }

    hide() {
        if (this._failsafeId)
            GLib.source_remove(this._failsafeId);
        if (this._tickId)
            GLib.source_remove(this._tickId);
        this._failsafeId = this._tickId = 0;
        if (this._monitorsId)
            Main.layoutManager.disconnect(this._monitorsId);
        this._monitorsId = 0;
        try {
            if (this._grab)
                Main.popModal(this._grab);
        } catch (e) {
            logError(e, 'BlackBreak: popModal');
        }
        this._grab = null;
        this._widget?.destroy();
        this._widget = this._box = this._countdown = null;
    }

    destroy() {
        this.hide();
    }

    _buildText() {
        const box = new St.BoxLayout({
            style_class: 'blackbreak-text',
            orientation: Clutter.Orientation.VERTICAL,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: true,
            y_expand: true,
        });
        for (const text of LINES)
            box.add_child(new St.Label({style_class: 'blackbreak-line', text}));
        this._countdown = new St.Label({
            style_class: 'blackbreak-countdown',
            x_align: Clutter.ActorAlign.CENTER,
        });
        box.add_child(this._countdown);
        return box;
    }

    _resize() {
        this._widget.set_position(0, 0);
        this._widget.set_size(global.stage.width, global.stage.height);
        // The text sits in the middle of the primary monitor.
        const m = Main.layoutManager.primaryMonitor;
        if (m) {
            this._box.set_position(m.x, m.y);
            this._box.set_size(m.width, m.height);
        }
    }

    // Updated on each whole second left; hides itself at the end.
    _updateCountdown() {
        const left = this._endsAt - Date.now();
        if (left <= 0) {
            this.hide();
            return;
        }
        this._countdown.text = String(Math.ceil(left / 1000));
        this._tickId = GLib.timeout_add(GLib.PRIORITY_HIGH, left % 1000 || 1000, () => {
            this._tickId = 0;
            this._updateCountdown();
            return GLib.SOURCE_REMOVE;
        });
    }
}
