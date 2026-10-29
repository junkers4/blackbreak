import Cairo from 'gi://cairo';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {FAILSAFE_MS} from './scheduler.js';

import {LINES, seconds} from './copy.js';
import {PAL, drawScene, rect} from './pixel.js';

// The break screen: warm black over the whole stage and, on the primary monitor, the rest
// scene (the eye that looks around and blinks, the words, the seconds and a segmented bar,
// a drifting horizon, a red frame), redrawn ten times a second, with a modal grab.
export class Overlay {
    show(endsAtMs) {
        if (this._widget || Main.sessionMode.isLocked)
            return;
        this._endsAt = endsAtMs;
        this._total = Math.max(1, endsAtMs - Date.now());
        this._startedAt = Date.now();
        this._left = 0;
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
        this._canvas = new St.DrawingArea();
        this._canvas.connect('repaint', () => this._paint());
        this._widget.add_child(this._canvas);
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
        if (this._frameId)
            GLib.source_remove(this._frameId);
        this._failsafeId = this._tickId = this._frameId = 0;
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
        this._widget = this._canvas = this._drawn = null;
    }

    destroy() {
        this.hide();
    }

    _resize() {
        this._widget.set_position(0, 0);
        this._widget.set_size(global.stage.width, global.stage.height);
        this._canvas.set_position(0, 0);
        this._canvas.set_size(global.stage.width, global.stage.height);
        this._canvas.queue_repaint();
    }

    _paint() {
        const cr = this._canvas.get_context();
        cr.setAntialias(Cairo.Antialias.NONE);
        rect(cr, PAL.bg, 0, 0, global.stage.width, global.stage.height);
        const m = Main.layoutManager.primaryMonitor;
        if (m) {
            const done = Math.min(1, Math.max(0, 1 - (this._endsAt - Date.now()) / this._total));
            drawScene(cr, m.x, m.y, m.width, m.height, (Date.now() - this._startedAt) / 1000,
                LINES, seconds(this._left), done);
            // what the last frame showed, for the headless tests
            this._drawn = {lines: LINES.length, seconds: seconds(this._left)};
        }
        cr.$dispose();
    }

    // Updated on each whole second left; hides itself at the end.
    _updateCountdown() {
        const left = this._endsAt - Date.now();
        if (left <= 0) {
            this.hide();
            return;
        }
        this._left = Math.ceil(left / 1000);
        this._canvas.queue_repaint();
        // the scene moves: redrawn ten times a second
        this._frameId ||= GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
            this._canvas?.queue_repaint();
            return GLib.SOURCE_CONTINUE;
        });
        this._tickId = GLib.timeout_add(GLib.PRIORITY_HIGH, left % 1000 || 1000, () => {
            this._tickId = 0;
            this._updateCountdown();
            return GLib.SOURCE_REMOVE;
        });
    }
}
