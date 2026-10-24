import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {FAILSAFE_MS} from './scheduler.js';

import {LINES, markup, seconds} from './copy.js';

// The break screen: warm black over the whole stage, with a modal grab.
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
        this._widget = this._text = this._countdown = null;
    }

    destroy() {
        this.hide();
    }

    _buildText() {
        this._text = new St.BoxLayout({
            style_class: 'blackbreak-text',
            orientation: Clutter.Orientation.VERTICAL,
        });
        for (const line of LINES) {
            const label = new St.Label({style_class: 'blackbreak-line'});
            label.clutter_text.set_markup(markup(line));
            this._text.add_child(label);
        }
        this._countdown = new St.Label({style_class: 'blackbreak-countdown'});
        this._widget.add_child(this._text);
        this._widget.add_child(this._countdown);
    }

    _resize() {
        this._widget.set_position(0, 0);
        this._widget.set_size(global.stage.width, global.stage.height);
        // The words sit on the left of the primary monitor, sized by its height.
        const m = Main.layoutManager.primaryMonitor;
        if (!m)
            return;
        const px = Math.max(24, Math.round(m.height / 17));
        const left = m.x + Math.round(m.width * 0.1);
        this._text.set_style(`font-size: ${px}px; spacing: ${Math.round(px * 0.18)}px;`);
        this._text.set_position(left, m.y + Math.round(m.height * 0.22));
        this._text.set_width(Math.round(m.width * 0.8));
        this._countdown.set_style(`font-size: ${Math.max(14, Math.round(px * 0.5))}px;`);
        this._countdown.set_position(left, m.y + m.height - Math.round(m.height * 0.09));
    }

    // Updated on each whole second left; hides itself at the end.
    _updateCountdown() {
        const left = this._endsAt - Date.now();
        if (left <= 0) {
            this.hide();
            return;
        }
        this._countdown.text = seconds(Math.ceil(left / 1000));
        this._tickId = GLib.timeout_add(GLib.PRIORITY_HIGH, left % 1000 || 1000, () => {
            this._tickId = 0;
            this._updateCountdown();
            return GLib.SOURCE_REMOVE;
        });
    }
}
