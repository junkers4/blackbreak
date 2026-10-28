import GLib from 'gi://GLib';

// The words of the break screen, in English or Slovak by the session language.
const SK = GLib.get_language_names()[0]?.startsWith('sk') ?? false;

// Each line is [plain, emphasised]; the emphasised part is set in gold below it.
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

