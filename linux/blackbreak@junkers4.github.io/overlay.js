import Cairo from 'gi://cairo';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {FAILSAFE_MS} from './scheduler.js';

import {LINES, seconds} from './copy.js';
import {PAL, PixelText, ROWS, LEADING, rect} from './pixel.js';

// The break screen is a 320 x 180 picture, scaled by a whole number and
// centred on the primary monitor.
const W = 320, H = 180, SEGMENTS = 15;
const TEXT_PX = 2;

// The break screen: warm black over the whole stage, a red pixel frame with
// the words, the seconds left and a segmented bar, with a modal grab.
export class Overlay {
    show(endsAtMs) {
        if (this._widget || Main.sessionMode.isLocked)
            return;
        this._endsAt = endsAtMs;
        this._total = Math.max(1, endsAtMs - Date.now());
        this._f = 1;
        this._ox = this._oy = 0;
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
        this._buildText();
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
        this._widget = this._text = this._countdown = this._canvas = this._lines = null;
    }

    destroy() {
        this.hide();
    }

    _buildText() {
        this._canvas = new St.DrawingArea();
        this._canvas.connect('repaint', () => this._paint());
        this._widget.add_child(this._canvas);
        this._text = new St.Widget();
        this._lines = LINES.map(([plain, accent]) => {
            const line = new PixelText(TEXT_PX, PAL.white, accent);
            line.text = plain;
            this._text.add_child(line);
            return line;
        });
        this._countdown = new PixelText(1, PAL.dim);
        this._widget.add_child(this._text);
        this._widget.add_child(this._countdown);
    }

    _resize() {
        this._widget.set_position(0, 0);
        this._widget.set_size(global.stage.width, global.stage.height);
        this._canvas.set_position(0, 0);
        this._canvas.set_size(global.stage.width, global.stage.height);
        const m = Main.layoutManager.primaryMonitor;
        if (!m)
            return;
        const f = Math.max(1, Math.floor(Math.min(m.width / W, m.height / H)));
        this._f = f;
        this._ox = m.x + Math.floor((m.width - W * f) / 2);
        this._oy = m.y + Math.floor((m.height - H * f) / 2);
        let y = 30;
        this._text.set_position(this._ox, this._oy);
        this._lines.forEach((line, i) => {
            line.setPx(TEXT_PX * f);
            line.set_position(24 * f, y * f);
            y += (LINES[i][1] ? LEADING + ROWS : ROWS) * TEXT_PX + 14;
        });
        this._countdown.setPx(f);
        this._countdown.set_position(this._ox + 24 * f, this._oy + 148 * f);
        this._canvas.queue_repaint();
    }

    _paint() {
        const cr = this._canvas.get_context();
        cr.setAntialias(Cairo.Antialias.NONE);
        rect(cr, PAL.bg, 0, 0, global.stage.width, global.stage.height);
        const f = this._f, ox = this._ox, oy = this._oy;
        const u = n => n * f;
        rect(cr, PAL.red, ox + u(6), oy + u(6), u(W - 12), u(2));
        rect(cr, PAL.red, ox + u(6), oy + u(H - 8), u(W - 12), u(2));
        rect(cr, PAL.red, ox + u(6), oy + u(6), u(2), u(H - 12));
        rect(cr, PAL.red, ox + u(W - 8), oy + u(6), u(2), u(H - 12));
        // one segment per two seconds of a 30 s break, filling as the break passes
        const done = Math.min(1, Math.max(0, 1 - (this._endsAt - Date.now()) / this._total));
        const lit = Math.round(done * SEGMENTS);
        for (let i = 0; i < SEGMENTS; i++)
            rect(cr, i < lit ? PAL.green : '#1d2a1d', ox + u(150 + i * 10), oy + u(150), u(8), u(7));
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
        this._countdown.text = seconds(this._left);
        this._canvas.queue_repaint();
        this._tickId = GLib.timeout_add(GLib.PRIORITY_HIGH, left % 1000 || 1000, () => {
            this._tickId = 0;
            this._updateCountdown();
            return GLib.SOURCE_REMOVE;
        });
    }
}
