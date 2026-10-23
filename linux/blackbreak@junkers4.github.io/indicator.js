import GObject from 'gi://GObject';
import St from 'gi://St';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

import {Phase} from './scheduler.js';

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
    _init(scheduler, onChange, onSettings) {
        super._init(0.5, 'BlackBreak');
        this._scheduler = scheduler;
        this.add_child(new St.Icon({
            icon_name: 'alarm-symbolic',
            style_class: 'system-status-icon',
        }));

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
