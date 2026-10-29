// The pixel look, shared by every screen: a 5x7 font, the eye, and a few drawing helpers.
// The same glyphs as the Linux extension (linux/.../pixelfont.js); nothing is smoothed.
package io.github.junkers4.blackbreak;

import android.graphics.Canvas;
import android.graphics.Paint;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class Pixel {
    static final int BG = 0xFF0D0C0B, WHITE = 0xFFF4F0E0, GOLD = 0xFFFCC030, RED = 0xFFB01818,
        SHADOW = 0xFF3C0808, DIM = 0xFF7A7468, GREEN = 0xFF30C030, DARK_GREEN = 0xFF1D2A1D,
        BLUE = 0xFF5C5CFC, NAVY = 0xFF04042C, LOW_BLUE = 0xFF5A5A8C;
    static final int CELL = 6, ROWS = 9, LEADING = 11;

    private static final String[] FONT = {
        "A", "01110100011000111111100011000110001",
        "B", "11110100011000111110100011000111110",
        "C", "01110100011000010000100001000101110",
        "D", "11110100011000110001100011000111110",
        "E", "11111100001000011110100001000011111",
        "F", "11111100001000011110100001000010000",
        "G", "01110100011000010111100011000101111",
        "H", "10001100011000111111100011000110001",
        "I", "01110001000010000100001000010001110",
        "J", "00111000100001000010000101001001100",
        "K", "10001100101010011000101001001010001",
        "L", "10000100001000010000100001000011111",
        "M", "10001110111010110101100011000110001",
        "N", "10001110011010110011100011000110001",
        "O", "01110100011000110001100011000101110",
        "P", "11110100011000111110100001000010000",
        "Q", "01110100011000110001101011001001101",
        "R", "11110100011000111110101001001010001",
        "S", "01111100001000001110000010000111110",
        "T", "11111001000010000100001000010000100",
        "U", "10001100011000110001100011000101110",
        "V", "10001100011000110001100010101000100",
        "W", "10001100011000110101101011101110001",
        "X", "10001100010101000100010101000110001",
        "Y", "10001100010101000100001000010000100",
        "Z", "11111000010001000100010001000011111",
        "0", "01110100011001110101110011000101110",
        "1", "00100011000010000100001000010001110",
        "2", "01110100010000100010001000100011111",
        "3", "11110000010000101110000010000111110",
        "4", "00010001100101010010111110001000010",
        "5", "11111100001111000001000011000101110",
        "6", "00110010001000011110100011000101110",
        "7", "11111000010001000100010000100001000",
        "8", "01110100011000101110100011000101110",
        "9", "01110100011000101111000010001001100",
        ".", "00000000000000000000000000110001100",
        ",", "00000000000000000000000000010001000",
        "!", "00100001000010000100001000000000100",
        "%", "11001110100001000100010000101110011",
        ":", "00000001000010000000001000010000000",
        "-", "00000000000000011111000000000000000",
        "/", "00001000100001000100010000100010000",
        "?", "01110100010000100010001000000000100",
        "'", "00100001000100000000000000000000000",
        "(", "00010001000100001000010000010000010",
        ")", "01000001000001000010000100010001000",
        "+", "00000001000010011111001000010000000",
        "&", "01100100101010001000101011001001101",
        " ", "00000000000000000000000000000000000"
    };
    private static final String[] ICON = {
        "................",
        "................",
        "...Y.Y..Y.Y.Y...",
        "...YYYYYYYYYY...",
        ".YYWWWWIIWWWWYY.",
        "YYWWWIIIIIIWWWYY",
        "YWWWWIHPPiIWWWWY",
        "YWWWIIPPPPIIWWWY",
        "YWWWIIPPPPIIWWWY",
        "YwwwwIiPPiIwwwwY",
        "YYwwwIIIIIIwwwYY",
        ".YYwwwwIIwwwwYY.",
        "...YYYYYYYYYY...",
        "................",
        "................",
        "................",
    };
    private static final int[] ICON_COLORS = new int[128];
    private static final Map<Character, String> GLYPHS = new HashMap<>();
    private static final Map<Character, String[]> SK = new HashMap<>();
    private static final String[][] ACCENTS = {
        {"01010", "00100"}, // caron
        {"00010", "00100"}, // acute
        {"00100", "01010"}, // circumflex
        {"01010", "00000"}, // umlaut
    };

    static {
        for (int i = 0; i < FONT.length; i += 2)
            GLYPHS.put(FONT[i].charAt(0), FONT[i + 1]);
        String caron = "CČ DĎ NŇ SŠ TŤ ZŽ LĽ";
        for (String p : caron.split(" ")) SK.put(p.charAt(1), new String[] {p.substring(0, 1), "0"});
        for (String p : "AÁ EÉ IÍ OÓ UÚ YÝ LĹ RŔ".split(" ")) SK.put(p.charAt(1), new String[] {p.substring(0, 1), "1"});
        SK.put('Ô', new String[] {"O", "2"});
        SK.put('Ä', new String[] {"A", "3"});
        ICON_COLORS['Y'] = GOLD;
        ICON_COLORS['W'] = 0xFFFFFBE8;
        ICON_COLORS['w'] = 0xFFD0C8A8;
        ICON_COLORS['I'] = 0xFF3A7AD8;
        ICON_COLORS['i'] = 0xFF1C3C8C;
        ICON_COLORS['P'] = 0xFF000000;
        ICON_COLORS['H'] = 0xFFFFFFFF;
    }

    private Pixel() {}

    static int width(String text, int px) {
        return Math.max(0, text.length() * CELL - 1) * px;
    }

    static void rect(Canvas c, Paint p, int color, float x, float y, float w, float h) {
        p.setColor(color);
        c.drawRect(x, y, x + w, y + h, p);
    }

    /** Draws text (upper-cased) with its top, the accent rows included, at y. */
    static void text(Canvas c, Paint p, String text, float x, float y, int px, int color, boolean shadow) {
        int sh = Math.max(1, px / 2);
        for (int pass = shadow ? 0 : 1; pass < 2; pass++) {
            p.setColor(pass == 0 ? SHADOW : color);
            float dx = pass == 0 ? sh : 0;
            float cx = x;
            for (char ch : text.toUpperCase(java.util.Locale.ROOT).toCharArray()) {
                String rows = GLYPHS.get(ch);
                String[] acc = null;
                if (rows == null && SK.containsKey(ch)) {
                    rows = GLYPHS.get(SK.get(ch)[0].charAt(0));
                    acc = ACCENTS[Integer.parseInt(SK.get(ch)[1])];
                }
                if (rows == null) rows = GLYPHS.get('?');
                for (int r = 0; r < 7; r++)
                    for (int col = 0; col < 5; col++)
                        if (rows.charAt(r * 5 + col) == '1')
                            c.drawRect(cx + col * px + dx, y + (r + 2) * px + dx, cx + (col + 1) * px + dx, y + (r + 3) * px + dx, p);
                if (acc != null)
                    for (int r = 0; r < 2; r++)
                        for (int col = 0; col < 5; col++)
                            if (acc[r].charAt(col) == '1')
                                c.drawRect(cx + col * px + dx, y + r * px + dx, cx + (col + 1) * px + dx, y + (r + 1) * px + dx, p);
                cx += CELL * px;
            }
        }
    }

    static void eye(Canvas c, Paint p, float x, float y, int px) {
        for (int r = 0; r < 16; r++)
            for (int col = 0; col < 16; col++) {
                char k = ICON[r].charAt(col);
                if (k != '.') rect(c, p, ICON_COLORS[k], x + col * px, y + r * px, px, px);
            }
    }

    /** The eye with a moving pupil (gx, gy in pixels) or closed for a blink. */
    static void eyeAnim(Canvas c, Paint p, float x, float y, int px, int gx, int gy, boolean blink) {
        if (blink) {
            for (int col = 1; col < 15; col++)
                rect(c, p, GOLD, x + col * px, y + 7 * px, px, 2 * px);
            for (int col : new int[] {3, 5, 8, 10, 12})
                rect(c, p, GOLD, x + col * px, y + 9 * px, px, px);
            return;
        }
        for (int r = 0; r < 16; r++)
            for (int col = 0; col < 16; col++) {
                char k = ICON[r].charAt(col);
                if (k == '.') continue;
                if ("IiPH".indexOf(k) >= 0) k = r <= 8 ? 'W' : 'w';
                rect(c, p, ICON_COLORS[k], x + col * px, y + r * px, px, px);
            }
        for (int r = 0; r < 16; r++)
            for (int col = 0; col < 16; col++) {
                char k = ICON[r].charAt(col);
                if ("IiPH".indexOf(k) < 0) continue;
                int tc = col + gx, tr = r + gy;
                if (tc < 0 || tc > 15 || tr < 0 || tr > 15) continue;
                char under = ICON[tr].charAt(tc);
                if (under == '.' || under == 'Y') continue;
                rect(c, p, ICON_COLORS[k], x + tc * px, y + tr * px, px, px);
            }
    }

    /** A bevelled box: a light top-left edge, a dark bottom-right edge, filled inside. */
    static void box(Canvas c, Paint p, float x, float y, float w, float h, int t, int fill, int hi, int lo) {
        rect(c, p, fill, x, y, w, h);
        rect(c, p, hi, x, y, w, t);
        rect(c, p, hi, x, y, t, h);
        rect(c, p, lo, x, y + h - t, w, t);
        rect(c, p, lo, x + w - t, y, t, h);
    }

    static List<String> wrap(String text, int cols) {
        List<String> out = new ArrayList<>();
        StringBuilder line = new StringBuilder();
        for (String word : text.split(" ")) {
            if (line.length() > 0 && line.length() + 1 + word.length() > cols) {
                out.add(line.toString());
                line.setLength(0);
            }
            if (line.length() > 0) line.append(' ');
            line.append(word);
        }
        if (line.length() > 0) out.add(line.toString());
        return out;
    }
}
