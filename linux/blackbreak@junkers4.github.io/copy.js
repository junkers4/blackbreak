import GLib from 'gi://GLib';

// The words of the break screen, in English or Slovak by the session language.
const SK = GLib.get_language_names()[0]?.startsWith('sk') ?? false;

const SERIF = 'Iowan Old Style, Palatino Linotype, Palatino, P052, Noto Serif, DejaVu Serif, serif';

// Each line is [plain, emphasised]; the emphasised part is set in italic.
export const LINES = SK
    ? [['Odlož oči.', ''], ['Pozri von oknom, ', 'čo najďalej.'], ['Potom sa natiahni.', '']]
    : [['Rest your eyes.', ''], ['Look out of the window, ', 'as far as you can.'], ['Then stretch.', '']];

export function seconds(n) {
    if (!SK)
        return n === 1 ? '1 second' : `${n} seconds`;
    if (n === 1)
        return '1 sekunda';
    return n >= 2 && n <= 4 ? `${n} sekundy` : `${n} sekúnd`;
}

export function markup(line) {
    const esc = s => GLib.markup_escape_text(s, -1);
    const [plain, accent] = line;
    const body = accent
        ? `${esc(plain)}<i><span foreground="#c9b99a">${esc(accent)}</span></i>`
        : esc(plain);
    return `<span font_family="${SERIF}">${body}</span>`;
}
