import Cairo from 'gi://cairo';

// The pixel look: a 5x7 font and a few icons, all drawn with
// Cairo rectangles on whole device pixels, so nothing is ever smoothed.

export const PAL = {
    bg: '#0d0c0b',
    white: '#f4f0e0',
    gold: '#fcc030',
    red: '#b01818',
    shadow: '#3c0808',
    green: '#30c030',
    dim: '#7a7468',
};

function rgb(cr, hex) {
    cr.setSourceRGB(parseInt(hex.slice(1, 3), 16) / 255,
        parseInt(hex.slice(3, 5), 16) / 255, parseInt(hex.slice(5, 7), 16) / 255);
}

export function rect(cr, hex, x, y, w, h) {
    rgb(cr, hex);
    cr.rectangle(x, y, w, h);
    cr.fill();
}

// 5 columns x 7 rows per glyph; '1' is a lit pixel.
const G = {
    A: '01110 10001 10001 11111 10001 10001 10001',
    B: '11110 10001 10001 11110 10001 10001 11110',
    C: '01110 10001 10000 10000 10000 10001 01110',
    D: '11110 10001 10001 10001 10001 10001 11110',
    E: '11111 10000 10000 11110 10000 10000 11111',
    F: '11111 10000 10000 11110 10000 10000 10000',
    G: '01110 10001 10000 10111 10001 10001 01111',
    H: '10001 10001 10001 11111 10001 10001 10001',
    I: '01110 00100 00100 00100 00100 00100 01110',
    J: '00111 00010 00010 00010 00010 10010 01100',
    K: '10001 10010 10100 11000 10100 10010 10001',
    L: '10000 10000 10000 10000 10000 10000 11111',
    M: '10001 11011 10101 10101 10001 10001 10001',
    N: '10001 11001 10101 10011 10001 10001 10001',
    O: '01110 10001 10001 10001 10001 10001 01110',
    P: '11110 10001 10001 11110 10000 10000 10000',
    Q: '01110 10001 10001 10001 10101 10010 01101',
    R: '11110 10001 10001 11110 10100 10010 10001',
    S: '01111 10000 10000 01110 00001 00001 11110',
    T: '11111 00100 00100 00100 00100 00100 00100',
    U: '10001 10001 10001 10001 10001 10001 01110',
    V: '10001 10001 10001 10001 10001 01010 00100',
    W: '10001 10001 10001 10101 10101 11011 10001',
    X: '10001 10001 01010 00100 01010 10001 10001',
    Y: '10001 10001 01010 00100 00100 00100 00100',
    Z: '11111 00001 00010 00100 01000 10000 11111',
    0: '01110 10001 10011 10101 11001 10001 01110',
    1: '00100 01100 00100 00100 00100 00100 01110',
    2: '01110 10001 00001 00010 00100 01000 11111',
    3: '11110 00001 00001 01110 00001 00001 11110',
    4: '00010 00110 01010 10010 11111 00010 00010',
    5: '11111 10000 11110 00001 00001 10001 01110',
    6: '00110 01000 10000 11110 10001 10001 01110',
    7: '11111 00001 00010 00100 01000 01000 01000',
    8: '01110 10001 10001 01110 10001 10001 01110',
    9: '01110 10001 10001 01111 00001 00010 01100',
    '.': '00000 00000 00000 00000 00000 01100 01100',
    ',': '00000 00000 00000 00000 00000 00100 01000',
    '!': '00100 00100 00100 00100 00100 00000 00100',
    '%': '11001 11010 00010 00100 01000 01011 10011',
    ':': '00000 00100 00100 00000 00100 00100 00000',
    '-': '00000 00000 00000 11111 00000 00000 00000',
    '/': '00001 00010 00010 00100 01000 01000 10000',
    '?': '01110 10001 00001 00010 00100 00000 00100',
    ' ': '00000 00000 00000 00000 00000 00000 00000',
};
const GLYPHS = {};
for (const [ch, rows] of Object.entries(G))
    GLYPHS[ch] = rows.split(' ');

// Slovak letters: a base glyph and two pixel rows above it.
const ACCENT = {
    caron: ['01010', '00100'],
    acute: ['00010', '00100'],
    circ: ['00100', '01010'],
    uml: ['01010', '00000'],
};
const SK = {
    Č: ['C', 'caron'], Ď: ['D', 'caron'], Ň: ['N', 'caron'], Š: ['S', 'caron'],
    Ť: ['T', 'caron'], Ž: ['Z', 'caron'], Ľ: ['L', 'caron'],
    Á: ['A', 'acute'], É: ['E', 'acute'], Í: ['I', 'acute'], Ó: ['O', 'acute'],
    Ú: ['U', 'acute'], Ý: ['Y', 'acute'], Ĺ: ['L', 'acute'], Ŕ: ['R', 'acute'],
    Ô: ['O', 'circ'], Ä: ['A', 'uml'],
};

export const CELL = 6; // glyph advance in font pixels
export const ROWS = 9; // 2 accent rows + 7 glyph rows
export const LEADING = 11; // font pixels between two lines

export function textWidth(text, px) {
    return Math.max(0, [...text].length * CELL - 1) * px;
}

// Draws `text` (upper-cased) with its top (accent row) at y.
export function drawText(cr, text, x, y, px, color, shadowColor = PAL.shadow) {
    const sh = Math.max(1, Math.floor(px / 2));
    for (const pass of shadowColor ? [0, 1] : [1]) {
        const col = pass ? color : shadowColor;
        const dx = pass ? 0 : sh;
        const dy = pass ? 0 : sh;
        rgb(cr, col);
        let cx = x;
        for (const ch of text.toUpperCase()) {
            let rows = GLYPHS[ch];
            let acc = null;
            if (!rows && SK[ch]) {
                rows = GLYPHS[SK[ch][0]];
                acc = ACCENT[SK[ch][1]];
            }
            rows ??= GLYPHS['?'];
            for (let r = 0; r < 7; r++)
                for (let c = 0; c < 5; c++)
                    if (rows[r][c] === '1')
                        cr.rectangle(cx + c * px + dx, y + (r + 2) * px + dy, px, px);
            if (acc) {
                for (let r = 0; r < 2; r++)
                    for (let c = 0; c < 5; c++)
                        if (acc[r][c] === '1')
                            cr.rectangle(cx + c * px + dx, y + r * px + dy, px, px);
            }
            cr.fill();
            cx += CELL * px;
        }
    }
}

// The eye icon (the 20-20-20 rule is about eyes), 16 x 16 pixels: top bar, menu, banner, app icon.
const ICON = [
    '................',
    '................',
    '...Y.Y..Y.Y.Y...',
    '...YYYYYYYYYY...',
    '.YYWWWWIIWWWWYY.',
    'YYWWWIIIIIIWWWYY',
    'YWWWWIHPPiIWWWWY',
    'YWWWIIPPPPIIWWWY',
    'YWWWIIPPPPIIWWWY',
    'YwwwwIiPPiIwwwwY',
    'YYwwwIIIIIIwwwYY',
    '.YYwwwwIIwwwwYY.',
    '...YYYYYYYYYY...',
    '................',
    '................',
    '................',
];
const ICON_PAL = {
    Y: '#fcc030', W: '#fffbe8', w: '#d0c8a8', I: '#3a7ad8', i: '#1c3c8c', P: '#000000', H: '#ffffff',
};

export function drawIcon(cr, x, y, f) {
    ICON.forEach((row, r) => {
        for (let c = 0; c < row.length; c++)
            if (row[c] !== '.')
                rect(cr, ICON_PAL[row[c]], x + c * f, y + r * f, f, f);
    });
}

// The eye (16 x 16 cells) with a moving pupil (gx, gy in cells), or closed for a blink.
export function drawEye(cr, x, y, f, gx, gy, blink) {
    if (blink) {
        for (let c = 1; c < 15; c++)
            rect(cr, ICON_PAL.Y, x + c * f, y + 7 * f, f, 2 * f);
        for (const c of [3, 5, 8, 10, 12])
            rect(cr, ICON_PAL.Y, x + c * f, y + 9 * f, f, f);
        return;
    }
    const iris = k => 'IiPH'.includes(k);
    ICON.forEach((row, r) => {
        for (let c = 0; c < 16; c++) {
            let k = row[c];
            if (k === '.')
                continue;
            if (iris(k))
                k = r <= 8 ? 'W' : 'w';
            rect(cr, ICON_PAL[k], x + c * f, y + r * f, f, f);
        }
    });
    ICON.forEach((row, r) => {
        for (let c = 0; c < 16; c++) {
            const k = row[c];
            if (!iris(k))
                continue;
            const tc = c + gx, tr = r + gy;
            if (tc < 0 || tc > 15 || tr < 0 || tr > 15)
                continue;
            const under = ICON[tr][tc];
            if (under === '.' || under === 'Y')
                continue;
            rect(cr, ICON_PAL[k], x + tc * f, y + tr * f, f, f);
        }
    });
}

// 0..1 triangle wave of u
const tri = u => Math.abs(2 * (u - Math.floor(u)) - 1);

function ridge(cr, x0, w, h, cell, scroll, period, amp, base, color) {
    const cols = Math.floor(w / cell) + 2;
    for (let i = 0; i < cols; i++) {
        const u = (i + scroll) / period;
        const top = base - Math.round((tri(u) + 0.5 * tri(u * 2.3 + 0.4)) * amp / cell) * cell;
        rect(cr, color, x0 + i * cell, top, Math.min(cell, x0 + w - (x0 + i * cell)), h - top);
    }
}

const STARS = (() => {
    // a fixed sky: the same stars on every break (a small LCG, seeded)
    let s = 20;
    const next = n => {
        s = (s * 1103515245 + 12345) % 2147483648;
        return s % n;
    };
    return Array.from({length: 48}, () => [next(1000), next(560)]);
})();

// The whole rest scene in the w x h box at (x0, y0), t seconds into the break: stars, the eye
// looking around, the words, the seconds and a 15-segment bar, a far sun and a drifting
// horizon, a red frame. The same scene as on Windows and Android.
export function drawScene(cr, x0, y0, w, h, t, lines, secondsText, done) {
    rect(cr, PAL.bg, x0, y0, w, h);
    let longest = 1;
    for (const [plain, accent] of lines)
        longest = Math.max(longest, plain.trim().length, accent.length);
    const px = Math.max(2, Math.min(Math.floor(h / 170), Math.floor(w * 0.8 / (longest * CELL))));
    const cell = px * 2;

    STARS.forEach(([sx, sy], i) => {
        const on = (Math.floor(t * 1.5) + i) % 5 !== 0;
        rect(cr, on ? '#8c88a8' : '#3a3850', x0 + Math.floor(sx * w / 1000 / cell) * cell,
            y0 + Math.floor(sy / 1000 * h / cell) * cell, cell / 2, cell / 2);
    });

    // the eye looks far to each side, up and down, and blinks
    const gaze = [[0, 0], [-2, 0], [2, 0], [0, -1], [0, 1], [0, 0]];
    const [gx, gy] = gaze[Math.floor(t / 2) % gaze.length];
    const pe = Math.max(4, Math.floor(h / 48));
    drawEye(cr, x0 + Math.floor((w - 16 * pe) / 2), y0 + Math.floor(h * 0.07), pe, gx, gy, t % 4.2 < 0.22);

    // the words, as one block centred on the screen
    const blockW = longest * CELL * px;
    const left = x0 + Math.max(px * 4, Math.floor((w - blockW) / 2));
    let y = y0 + Math.floor(h * 0.43);
    for (const [plain, accent] of lines) {
        drawText(cr, plain.trim(), left, y, px, PAL.white);
        if (accent)
            drawText(cr, accent, left, y + LEADING * px, px, PAL.gold);
        y += ((accent ? LEADING + ROWS : ROWS) + 5) * px;
    }

    // the seconds and a 15-segment bar
    const segments = 15;
    const barY = Math.max(y + px * 3, y0 + Math.floor(h * 0.76));
    const small = Math.max(2, Math.floor(px / 2));
    drawText(cr, secondsText, left, barY - 12 * small, small, PAL.dim, null);
    const seg = blockW / segments;
    const lit = Math.round(done * segments);
    for (let i = 0; i < segments; i++)
        rect(cr, i < lit ? PAL.green : '#1d2a1d', left + Math.floor(i * seg), barY, Math.floor(seg * 0.8), px * 3);

    // a far sun and a horizon that drifts
    const r = 7, sunX = x0 + Math.floor(w * 0.72), sunY = y0 + Math.floor(h * 0.80);
    for (let dy = -r; dy <= r; dy++)
        for (let dx = -r; dx <= r; dx++)
            if (dx * dx + dy * dy <= r * r)
                rect(cr, dy > 2 ? '#c88018' : PAL.gold, sunX + dx * cell / 2, sunY + dy * cell / 2, cell / 2, cell / 2);
    ridge(cr, x0, w, y0 + h, cell, t * 0.6, 11, h * 0.05, y0 + Math.floor(h * 0.86), '#1c1c6c');
    ridge(cr, x0, w, y0 + h, cell, t * 1.1 + 7, 7, h * 0.045, y0 + Math.floor(h * 0.92), '#14144c');
    ridge(cr, x0, w, y0 + h, cell, t * 1.8 + 3, 4.5, h * 0.03, y0 + Math.floor(h * 0.97), '#0a0a2e');

    // the frame, over everything
    const frame = Math.max(2, px), inset = Math.floor(w * 2 / 100);
    rect(cr, PAL.red, x0 + inset, y0 + inset, w - 2 * inset, frame);
    rect(cr, PAL.red, x0 + inset, y0 + h - inset - frame, w - 2 * inset, frame);
    rect(cr, PAL.red, x0 + inset, y0 + inset, frame, h - 2 * inset);
    rect(cr, PAL.red, x0 + w - inset - frame, y0 + inset, frame, h - 2 * inset);
}
