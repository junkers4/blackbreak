// The warning, "Break in 10 s": a pixel box at the top that no touch or key reaches.
package io.github.junkers4.blackbreak;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;

public final class NoticeOverlay {
    private static final String TEXT = "Break in 10 s";

    private final WindowManager wm;
    private final Box view;
    private final int px;
    private boolean shown;

    public NoticeOverlay(Context context, WindowManager wm) {
        this.wm = wm;
        this.px = Math.max(2, Math.round(context.getResources().getDisplayMetrics().density * 2.2f));
        this.view = new Box(context);
    }

    public void show() {
        if (shown)
            return;
        WindowManager.LayoutParams p = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT);
        p.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        p.y = px * 28;
        wm.addView(view, p);
        shown = true;
    }

    public void hide() {
        if (!shown)
            return;
        shown = false;
        try {
            wm.removeViewImmediate(view);
        } catch (RuntimeException ignored) {
        }
    }

    private final class Box extends View {
        private final Paint paint = new Paint();

        Box(Context context) {
            super(context);
            paint.setAntiAlias(false);
        }

        @Override
        protected void onMeasure(int wSpec, int hSpec) {
            setMeasuredDimension(Pixel.width(TEXT, px) + px * 10, Pixel.ROWS * px + px * 8);
        }

        @Override
        protected void onDraw(Canvas c) {
            int w = getWidth(), h = getHeight();
            Pixel.rect(c, paint, Pixel.SHADOW, px, px, w - px, h - px);
            Pixel.box(c, paint, 0, 0, w - px, h - px, px, Pixel.BG, Pixel.RED, Pixel.RED);
            Pixel.text(c, paint, TEXT, px * 4, px * 3, px, Pixel.GOLD, false);
        }
    }
}
