import Cairo from 'gi://cairo';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {PAL, CELL, ROWS, LEADING, textWidth, drawText} from './pixelfont.js';

export * from './pixelfont.js';

// One or two lines of text (the second in the accent colour) as an actor.
export const PixelText = GObject.registerClass({
    Properties: {
        text: GObject.ParamSpec.string('text', null, null, GObject.ParamFlags.READWRITE, ''),
    },
}, class PixelText extends St.DrawingArea {
    _init(px, color = PAL.white, accent = '', accentColor = PAL.gold) {
        super._init();
        this._px = px;
        this._color = color;
        this._accent = accent;
        this._accentColor = accentColor;
        this._text = '';
        this.connect('repaint', () => this._paint());
    }

    get text() {
        return this._text;
    }

    set text(v) {
        this._text = v;
        this._fit();
        this.queue_repaint();
    }

    setPx(px) {
        this._px = px;
        this._fit();
        this.queue_repaint();
    }

    _fit() {
        const px = this._px;
        const w = Math.max(textWidth(this._text, px), textWidth(this._accent, px));
        const rows = this._accent ? LEADING + ROWS : ROWS;
        this.set_size(w + px * 2, rows * px + px);
    }

    _paint() {
        const cr = this.get_context();
        cr.setAntialias(Cairo.Antialias.NONE);
        drawText(cr, this._text, 0, 0, this._px, this._color);
        if (this._accent)
            drawText(cr, this._accent, 0, LEADING * this._px, this._px, this._accentColor);
        cr.$dispose();
    }
});
