import Clutter from 'gi://Clutter';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// A small label at the top center of the primary monitor; no input.
export class Notice {
    show(text) {
        if (Main.sessionMode.isLocked)
            return;
        if (!this._bin) {
            // Drawn over fullscreen windows too, as Main.pushModal does.
            global.compositor.disable_unredirect();
            this._label = new St.Label({
                style_class: 'blackbreak-notice',
                x_align: Clutter.ActorAlign.CENTER,
                x_expand: true,
            });
            this._bin = new St.Bin({child: this._label, reactive: false});
            Main.layoutManager.addTopChrome(this._bin);
        }
        const m = Main.layoutManager.primaryMonitor;
        if (m) {
            this._bin.set_position(m.x, m.y + Main.panel.height + 12);
            this._bin.set_width(m.width);
        }
        this._label.text = text;
    }

    hide() {
        if (this._bin)
            global.compositor.enable_unredirect();
        this._bin?.destroy();
        this._bin = this._label = null;
    }

    destroy() {
        this.hide();
    }
}
