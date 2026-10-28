// The pixel look: a 5x7 font, the eye and a few drawing helpers, all as whole-pixel rectangles
// (the same glyphs as the Linux extension and the Android app); nothing is smoothed.
using System.Runtime.InteropServices;

namespace BlackBreak;

internal static unsafe class PixelArt
{
    public const int Cell = 6, Rows = 9, Leading = 11;
    public static readonly uint Bg = Native.Rgb(0x0D, 0x0C, 0x0B), White = Native.Rgb(0xF4, 0xF0, 0xE0),
        Gold = Native.Rgb(0xFC, 0xC0, 0x30), Red = Native.Rgb(0xB0, 0x18, 0x18), Shadow = Native.Rgb(0x3C, 0x08, 0x08),
        Dim = Native.Rgb(0x7A, 0x74, 0x68), Green = Native.Rgb(0x30, 0xC0, 0x30), DarkGreen = Native.Rgb(0x1D, 0x2A, 0x1D);

    static readonly Dictionary<char, string> Glyphs = new()
    {
        ['A'] = "01110100011000111111100011000110001",
        ['B'] = "11110100011000111110100011000111110",
        ['C'] = "01110100011000010000100001000101110",
        ['D'] = "11110100011000110001100011000111110",
        ['E'] = "11111100001000011110100001000011111",
        ['F'] = "11111100001000011110100001000010000",
        ['G'] = "01110100011000010111100011000101111",
        ['H'] = "10001100011000111111100011000110001",
        ['I'] = "01110001000010000100001000010001110",
        ['J'] = "00111000100001000010000101001001100",
        ['K'] = "10001100101010011000101001001010001",
        ['L'] = "10000100001000010000100001000011111",
        ['M'] = "10001110111010110101100011000110001",
        ['N'] = "10001110011010110011100011000110001",
        ['O'] = "01110100011000110001100011000101110",
        ['P'] = "11110100011000111110100001000010000",
        ['Q'] = "01110100011000110001101011001001101",
        ['R'] = "11110100011000111110101001001010001",
        ['S'] = "01111100001000001110000010000111110",
        ['T'] = "11111001000010000100001000010000100",
        ['U'] = "10001100011000110001100011000101110",
        ['V'] = "10001100011000110001100010101000100",
        ['W'] = "10001100011000110101101011101110001",
        ['X'] = "10001100010101000100010101000110001",
        ['Y'] = "10001100010101000100001000010000100",
        ['Z'] = "11111000010001000100010001000011111",
        ['0'] = "01110100011001110101110011000101110",
        ['1'] = "00100011000010000100001000010001110",
        ['2'] = "01110100010000100010001000100011111",
        ['3'] = "11110000010000101110000010000111110",
        ['4'] = "00010001100101010010111110001000010",
        ['5'] = "11111100001111000001000011000101110",
        ['6'] = "00110010001000011110100011000101110",
        ['7'] = "11111000010001000100010000100001000",
        ['8'] = "01110100011000101110100011000101110",
        ['9'] = "01110100011000101111000010001001100",
        ['.'] = "00000000000000000000000000110001100",
        [','] = "00000000000000000000000000010001000",
        ['!'] = "00100001000010000100001000000000100",
        ['%'] = "11001110100001000100010000101110011",
        [':'] = "00000001000010000000001000010000000",
        ['-'] = "00000000000000011111000000000000000",
        ['/'] = "00001000100001000100010000100010000",
        ['?'] = "01110100010000100010001000000000100",
        [' '] = "00000000000000000000000000000000000",
    };

    static readonly string[] Icon =
    [
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
    ];

    // Slovak letters: a base glyph and two pixel rows above it (0 caron, 1 acute, 2 circumflex, 3 umlaut).
    static readonly string[][] Accents = [["01010", "00100"], ["00010", "00100"], ["00100", "01010"], ["01010", "00000"]];
    static readonly Dictionary<char, (char b, int a)> Sk = new()
    {
        ['Č'] = ('C', 0), ['Ď'] = ('D', 0), ['Ň'] = ('N', 0), ['Š'] = ('S', 0), ['Ť'] = ('T', 0), ['Ž'] = ('Z', 0), ['Ľ'] = ('L', 0),
        ['Á'] = ('A', 1), ['É'] = ('E', 1), ['Í'] = ('I', 1), ['Ó'] = ('O', 1), ['Ú'] = ('U', 1), ['Ý'] = ('Y', 1), ['Ĺ'] = ('L', 1), ['Ŕ'] = ('R', 1),
        ['Ô'] = ('O', 2), ['Ä'] = ('A', 3),
    };

    static uint IconColor(char k) => k switch
    {
        'Y' => Gold, 'W' => Native.Rgb(0xFF, 0xFB, 0xE8), 'w' => Native.Rgb(0xD0, 0xC8, 0xA8), 'I' => Native.Rgb(0x3A, 0x7A, 0xD8),
        'i' => Native.Rgb(0x1C, 0x3C, 0x8C), 'P' => Native.Rgb(0, 0, 0), _ => Native.Rgb(0xFF, 0xFF, 0xFF),
    };

    public static void Rect(nint dc, uint color, int x, int y, int w, int h)
    {
        if (w <= 0 || h <= 0) return;
        Native.SetDCBrushColor(dc, color);
        var r = new RECT { Left = x, Top = y, Right = x + w, Bottom = y + h };
        Native.FillRect(dc, &r, Native.GetStockObject(Native.DC_BRUSH));
    }

    public static int TextWidth(string text, int px) => Math.Max(0, text.Length * Cell - 1) * px;

    /// Draws text (upper-cased) with its top, the accent rows included, at y.
    public static void Text(nint dc, string text, int x, int y, int px, uint color, bool shadow)
    {
        var sh = Math.Max(1, px / 2);
        for (var pass = shadow ? 0 : 1; pass < 2; pass++)
        {
            var col = pass == 0 ? Shadow : color;
            var d = pass == 0 ? sh : 0;
            var cx = x;
            foreach (var ch in text.ToUpperInvariant())
            {
                var key = ch;
                string[]? acc = null;
                if (!Glyphs.ContainsKey(ch) && Sk.TryGetValue(ch, out var s))
                {
                    key = s.b;
                    acc = Accents[s.a];
                }
                var rows = Glyphs.TryGetValue(key, out var g) ? g : Glyphs['?'];
                for (var r = 0; r < 7; r++)
                    for (var c = 0; c < 5; c++)
                        if (rows[r * 5 + c] == '1') Rect(dc, col, cx + c * px + d, y + (r + 2) * px + d, px, px);
                if (acc != null)
                    for (var r = 0; r < 2; r++)
                        for (var c = 0; c < 5; c++)
                            if (acc[r][c] == '1') Rect(dc, col, cx + c * px + d, y + r * px + d, px, px);
                cx += Cell * px;
            }
        }
    }

    /// The eye icon (16 x 16 cells) with a moving pupil (gx, gy in cells), or closed for a blink.
    public static void Eye(nint dc, int x, int y, int px, int gx, int gy, bool blink)
    {
        if (blink)
        {
            for (var c = 1; c < 15; c++) Rect(dc, Gold, x + c * px, y + 7 * px, px, 2 * px);
            foreach (var c in new[] { 3, 5, 8, 10, 12 }) Rect(dc, Gold, x + c * px, y + 9 * px, px, px);
            return;
        }
        for (var r = 0; r < 16; r++)
            for (var c = 0; c < 16; c++)
            {
                var k = Icon[r][c];
                if (k == '.') continue;
                if ("IiPH".Contains(k)) k = r <= 8 ? 'W' : 'w';
                Rect(dc, IconColor(k), x + c * px, y + r * px, px, px);
            }
        for (var r = 0; r < 16; r++)
            for (var c = 0; c < 16; c++)
            {
                var k = Icon[r][c];
                if (!"IiPH".Contains(k)) continue;
                int tc = c + gx, tr = r + gy;
                if (tc is < 0 or > 15 || tr is < 0 or > 15) continue;
                var under = Icon[tr][tc];
                if (under is '.' or 'Y') continue;
                Rect(dc, IconColor(k), x + tc * px, y + tr * px, px, px);
            }
    }

    /// A bevelled box: a light top-left edge and a dark bottom-right edge around a fill.
    public static void Box(nint dc, int x, int y, int w, int h, int t, uint fill, uint hi, uint lo)
    {
        Rect(dc, fill, x, y, w, h);
        Rect(dc, hi, x, y, w, t);
        Rect(dc, hi, x, y, t, h);
        Rect(dc, lo, x, y + h - t, w, t);
        Rect(dc, lo, x + w - t, y, t, h);
    }

    // 0..1 triangle wave of u
    static double Tri(double u) => Math.Abs(2 * (u - Math.Floor(u)) - 1);

    static void Ridge(nint dc, int w, int h, int cell, double scroll, double period, double amp, int baseY, uint color)
    {
        var cols = w / cell + 2;
        for (var i = 0; i < cols; i++)
        {
            var u = (i + scroll) / period;
            var top = baseY - (int)Math.Round((Tri(u) + 0.5 * Tri(u * 2.3 + 0.4)) * amp / cell) * cell;
            Rect(dc, color, i * cell, top, cell, h - top);
        }
    }

    static int[]? _starX, _starY;

    /// The whole rest scene on a w x h surface at time t seconds: stars, the eye, the words, the bar, a horizon, a frame.
    public static void Scene(nint dc, int w, int h, double t, (string plain, string accent)[] lines, string seconds, double done)
    {
        Rect(dc, Bg, 0, 0, w, h);
        if (_starX == null)
        {
            var rnd = new Random(20);
            _starX = new int[48];
            _starY = new int[48];
            for (var i = 0; i < 48; i++) { _starX[i] = rnd.Next(1000); _starY[i] = rnd.Next(560); }
        }
        var longest = 1;
        foreach (var (p, a) in lines) longest = Math.Max(longest, Math.Max(p.Trim().Length, a.Length));
        var px = Math.Max(2, Math.Min(h / 170, (int)(w * 0.8) / (longest * Cell)));
        var cell = px * 2;

        for (var i = 0; i < 48; i++)
        {
            var sx = _starX![i] * w / 1000 / cell * cell;
            var sy = (int)(_starY![i] / 1000.0 * h / cell) * cell;
            var on = ((int)(t * 1.5) + i) % 5 != 0;
            Rect(dc, on ? Native.Rgb(0x8C, 0x88, 0xA8) : Native.Rgb(0x3A, 0x38, 0x50), sx, sy, cell / 2, cell / 2);
        }

        // the eye looks far to each side, up and down, and blinks
        int[][] gaze = [[0, 0], [-2, 0], [2, 0], [0, -1], [0, 1], [0, 0]];
        var g = gaze[(int)(t / 2) % gaze.Length];
        var blink = t % 4.2 < 0.22;
        var pe = Math.Max(4, h / 48);
        Eye(dc, (w - 16 * pe) / 2, (int)(h * 0.07), pe, g[0], g[1], blink);

        // the words, as one block centred on the screen
        var blockW = longest * Cell * px;
        var left = Math.Max(px * 4, (w - blockW) / 2);
        var y = (int)(h * 0.43);
        foreach (var (plain, accent) in lines)
        {
            Text(dc, plain.Trim(), left, y, px, White, true);
            var hasAccent = accent.Length > 0;
            if (hasAccent) Text(dc, accent, left, y + Leading * px, px, Gold, true);
            y += ((hasAccent ? Leading + Rows : Rows) + 5) * px;
        }

        // the seconds and a 15-segment bar
        const int segments = 15;
        var barY = Math.Max(y + px * 3, (int)(h * 0.76));
        var small = Math.Max(2, px / 2);
        Text(dc, seconds, left, barY - 12 * small, small, Dim, false);
        var seg = blockW / (double)segments;
        var lit = (int)Math.Round(done * segments);
        for (var i = 0; i < segments; i++)
            Rect(dc, i < lit ? Green : DarkGreen, left + (int)(i * seg), barY, (int)(seg * 0.8), px * 3);

        // a far sun and a horizon that drifts
        const int r2 = 7;
        int sunX = (int)(w * 0.72), sunY = (int)(h * 0.80);
        for (var dy = -r2; dy <= r2; dy++)
            for (var dx = -r2; dx <= r2; dx++)
                if (dx * dx + dy * dy <= r2 * r2)
                    Rect(dc, dy > 2 ? Native.Rgb(0xC8, 0x80, 0x18) : Gold, sunX + dx * cell / 2, sunY + dy * cell / 2, cell / 2, cell / 2);
        Ridge(dc, w, h, cell, t * 0.6, 11, h * 0.05, (int)(h * 0.86), Native.Rgb(0x1C, 0x1C, 0x6C));
        Ridge(dc, w, h, cell, t * 1.1 + 7, 7, h * 0.045, (int)(h * 0.92), Native.Rgb(0x14, 0x14, 0x4C));
        Ridge(dc, w, h, cell, t * 1.8 + 3, 4.5, h * 0.03, (int)(h * 0.97), Native.Rgb(0x0A, 0x0A, 0x2E));

        // the frame, over everything
        var frame = Math.Max(2, px);
        var inset = w * 2 / 100;
        Rect(dc, Red, inset, inset, w - 2 * inset, frame);
        Rect(dc, Red, inset, h - inset - frame, w - 2 * inset, frame);
        Rect(dc, Red, inset, inset, frame, h - 2 * inset);
        Rect(dc, Red, w - inset - frame, inset, frame, h - 2 * inset);
    }
}
