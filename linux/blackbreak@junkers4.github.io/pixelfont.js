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
