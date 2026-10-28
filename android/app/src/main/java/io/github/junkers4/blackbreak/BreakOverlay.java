// The rest screen: an eye that looks around and blinks, the three lines, the seconds left, a
// 15-segment bar that fills, and a pixel horizon that drifts, in a red pixel frame over warm black.
package io.github.junkers4.blackbreak;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.view.KeyEvent;
import android.os.SystemClock;
import android.view.View;
import android.view.WindowManager;
import java.util.Locale;

public final class BreakOverlay {
    private static final int SEGMENTS = 15;

    private final Context context;
    private final WindowManager wm;
    private final boolean slovak;
    private final Screen root;
    private long secondsLeft;
    private long total;
    private boolean shown;

    public BreakOverlay(Context context, WindowManager wm) {
        this.context = context;
        this.wm = wm;
        this.slovak = Locale.getDefault().getLanguage().equals("sk");
        this.root = new Screen(context);
    }

    public boolean isShown() {
        return shown;
    }

    public View view() {
        return root;
    }

    public void update(long secondsLeft) {
        this.secondsLeft = Math.max(0, secondsLeft);
        total = Math.max(total, this.secondsLeft);
        root.invalidate();
    }

    public void show(long secondsLeft) {
        if (!shown)
            total = 0;
        update(secondsLeft);
        if (shown)
            return;
        WindowManager.LayoutParams p = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.OPAQUE);
        if (android.os.Build.VERSION.SDK_INT >= 28)
            p.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
        if (android.os.Build.VERSION.SDK_INT >= 30)
            p.setFitInsetsTypes(0);
        root.setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        wm.addView(root, p);
        root.requestFocus();
        shown = true;
    }

    public void hide() {
        if (!shown)
            return;
        shown = false;
        try {
            wm.removeViewImmediate(root);
        } catch (RuntimeException ignored) {
        }
        // a real break (30 s) that ran to its end; not a test and not a cut-off
        if (total >= 20 && secondsLeft <= 1)
            Options.breakEnded(context);
    }

    // Focused while shown, so every key reaches it and none reaches the app below (volume included).
    private final class Screen extends View {
        private final Paint paint = new Paint();
        private final int[] starX = new int[48], starY = new int[48];

        Screen(Context context) {
            super(context);
            paint.setAntiAlias(false);
            setClickable(true); // consumes every touch
            setFocusable(true);
            setFocusableInTouchMode(true);
            java.util.Random rnd = new java.util.Random(20);
            for (int i = 0; i < starX.length; i++) {
                starX[i] = rnd.nextInt(1000);
                starY[i] = rnd.nextInt(560);
            }
        }

        @Override
        public boolean dispatchKeyEvent(KeyEvent event) {
            return true;
        }

        // 0..1 triangle wave of u
        private float tri(float u) {
            return Math.abs(2 * (u - (float) Math.floor(u)) - 1);
        }

        private void ridge(Canvas c, int w, int h, int cell, float scroll, float period, float amp, int base, int color) {
            int cols = w / cell + 2;
            for (int i = 0; i < cols; i++) {
                float u = (i + scroll) / period;
                int top = base - Math.round((tri(u) + 0.5f * tri(u * 2.3f + 0.4f)) * amp / cell) * cell;
                Pixel.rect(c, paint, color, i * cell, top, cell, h - top);
            }
        }

        @Override
        protected void onDraw(Canvas c) {
            int w = getWidth(), h = getHeight();
            long now = SystemClock.uptimeMillis();
            float t = now / 1000f;
            Pixel.rect(c, paint, Pixel.BG, 0, 0, w, h);

            String[][] lines = new String[3][2];
            int longest = 1;
            for (int i = 0; i < 3; i++) {
                lines[i][0] = Copy.plain(slovak, i);
                lines[i][1] = Copy.accent(slovak, i);
                longest = Math.max(longest, Math.max(lines[i][0].trim().length(), lines[i][1].length()));
            }
            int margin = w * 9 / 100;
            int px = Math.max(2, (w - 2 * margin) / (longest * Pixel.CELL));
            int cell = px * 2;

            // stars, twinkling
            for (int i = 0; i < starX.length; i++) {
                int sx = starX[i] * w / 1000 / cell * cell, sy = (int) (starY[i] / 1000f * h / cell) * cell;
                boolean on = ((int) (t * 1.5f) + i) % 5 != 0;
                Pixel.rect(c, paint, on ? 0xFF8C88A8 : 0xFF3A3850, sx, sy, cell / 2, cell / 2);
            }

            // the eye: looks far to each side, up and down, and blinks
            int[][] gaze = {{0, 0}, {-2, 0}, {2, 0}, {0, -1}, {0, 1}, {0, 0}};
            int[] g = gaze[((int) (t / 2f)) % gaze.length];
            boolean blink = t % 4.2f < 0.22f;
            int pe = Math.max(4, (w * 5 / 10) / 16);
            Pixel.eyeAnim(c, paint, (w - 16 * pe) / 2f, h * 0.10f, pe, g[0], g[1], blink);

            // the words
            float y = h * 0.34f;
            for (int i = 0; i < 3; i++) {
                Pixel.text(c, paint, lines[i][0].trim(), margin, y, px, Pixel.WHITE, true);
                boolean accent = !lines[i][1].isEmpty();
                if (accent)
                    Pixel.text(c, paint, lines[i][1], margin, y + Pixel.LEADING * px, px, Pixel.GOLD, true);
                y += ((accent ? Pixel.LEADING + Pixel.ROWS : Pixel.ROWS) + 5) * px;
            }

            // the seconds and the bar
            int small = Math.max(2, px / 2);
            float barY = Math.max(y + px * 4, h * 0.60f);
            Pixel.text(c, paint, Copy.seconds(slovak, secondsLeft), margin, barY - 12 * small, small, Pixel.DIM, false);
            float seg = (w - 2f * margin) / SEGMENTS;
            int lit = total <= 0 ? 0 : Math.round((1f - (float) secondsLeft / total) * SEGMENTS);
            for (int i = 0; i < SEGMENTS; i++)
                Pixel.rect(c, paint, i < lit ? Pixel.GREEN : Pixel.DARK_GREEN, margin + i * seg, barY, seg * 0.8f, px * 3);

            // a far sun and a horizon that drifts
            int r = 7;
            float sx = w * 0.72f, sy = h * 0.82f;
            for (int dy = -r; dy <= r; dy++)
                for (int dx = -r; dx <= r; dx++)
                    if (dx * dx + dy * dy <= r * r)
                        Pixel.rect(c, paint, dy > 2 ? 0xFFC88018 : Pixel.GOLD, sx + dx * cell / 2f, sy + dy * cell / 2f, cell / 2f, cell / 2f);
            ridge(c, w, h, cell, t * 0.6f, 11f, h * 0.05f, (int) (h * 0.86f), 0xFF1C1C6C);
            ridge(c, w, h, cell, t * 1.1f + 7, 7f, h * 0.045f, (int) (h * 0.92f), 0xFF14144C);
            ridge(c, w, h, cell, t * 1.8f + 3, 4.5f, h * 0.03f, (int) (h * 0.97f), 0xFF0A0A2E);

            // the frame, over everything
            int frame = Math.max(2, px);
            int inset = w * 3 / 100;
            Pixel.rect(c, paint, Pixel.RED, inset, inset, w - 2 * inset, frame);
            Pixel.rect(c, paint, Pixel.RED, inset, h - inset - frame, w - 2 * inset, frame);
            Pixel.rect(c, paint, Pixel.RED, inset, inset, frame, h - 2 * inset);
            Pixel.rect(c, paint, Pixel.RED, w - inset - frame, inset, frame, h - 2 * inset);

            if (shown)
                postInvalidateDelayed(66);
        }
    }
}
