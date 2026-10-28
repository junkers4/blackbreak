import Cairo from 'gi://cairo';
import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';
import St from 'gi://St';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

import {Phase} from './scheduler.js';
import {PixelText, PAL, drawIcon} from './pixel.js';

const PAUSES = [
    ['Pause 30 min', 30], ['Pause 1 hour', 60],
    ['Pause 2 hours', 120], ['Pause 3 hours', 180],
];

function hhmm(ms) {
    const d = new Date(ms);
    const p = n => String(n).padStart(2, '0');
    return `${p(d.getHours())}:${p(d.getMinutes())}`;
}

// onChange() runs after a pause or cancel took effect.
export const Indicator = GObject.registerClass(
class Indicator extends PanelMenu.Button {
    _init(scheduler, onChange, onSettings, onTest) {
        super._init(0.5, 'BlackBreak');
        this._scheduler = scheduler;
        // A pixel eye as the top bar icon, drawn at 1:1.
        const icon = new St.DrawingArea({width: 16, height: 16, y_align: Clutter.ActorAlign.CENTER});
        icon.connect('repaint', () => {
            const cr = icon.get_context();
            cr.setAntialias(Cairo.Antialias.NONE);
            drawIcon(cr, 0, 0, 1);
            cr.$dispose();
        });
        this.add_child(icon);
        this.menu.actor.add_style_class_name('blackbreak-menu');

        // a title row: the eye and the name in pixels
        const head = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        const mark = new St.DrawingArea({width: 32, height: 32, y_align: Clutter.ActorAlign.CENTER});
        mark.connect('repaint', () => {
            const cr = mark.get_context();
            cr.setAntialias(Cairo.Antialias.NONE);
            drawIcon(cr, 0, 0, 2);
            cr.$dispose();
        });
        const title = new PixelText(2, PAL.gold);
        title.text = 'BlackBreak';
        title.y_align = Clutter.ActorAlign.CENTER;
        head.add_child(mark);
        head.add_child(title);
        this.menu.addMenuItem(head);

        this._status = new PopupMenu.PopupMenuItem('', {reactive: false});
        this.menu.addMenuItem(this._status);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._pauseItems = PAUSES.map(([label, min]) => this.menu.addAction(label, () => {
            if (scheduler.pause(min * 60_000, Date.now()))
                onChange();
        }));
        this._cancel = this.menu.addAction('Cancel pause', () => {
            if (scheduler.cancelPause(Date.now()))
                onChange();
        });
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._test = this.menu.addAction('Test break (5 s)', () => onTest());
        this._settings = this.menu.addAction('Settings', () => onSettings());

        this.menu.connect('open-state-changed', (_m, open) => {
            if (open)
                this.refresh();
        });
        this.refresh();
    }

    refresh() {
        const s = this._scheduler;
        const phase = s.phase;
        for (const item of this._pauseItems)
            item.setSensitive(s.canPause);
        this._test.setSensitive(phase === Phase.WORK);
        this._cancel.setSensitive(phase === Phase.PAUSED);
        this._settings.setSensitive(phase === Phase.WORK || phase === Phase.PAUSED);

        let text;
        if (phase === Phase.PAUSED) {
            text = `Paused until ${hhmm(s.pauseEndsAt)}`;
        } else if (phase === Phase.BREAK) {
            text = 'Break';
        } else {
            const min = Math.max(0, Math.ceil((s.nextBreakAt - Date.now()) / 60_000));
            text = `Next break in ${min} min`;
        }
        this._status.label.text = text;
    }
});
