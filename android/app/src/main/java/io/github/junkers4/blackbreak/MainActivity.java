// The one screen, in pixels: status, the pause buttons, the call switch and the setup step.
package io.github.junkers4.blackbreak;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.MotionEvent;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

public final class MainActivity extends Activity {
    private static final long MENU_PAUSE = 1, MENU_CANCEL = 2, MENU_SETTINGS = 4;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private Item status, setup, cancel, call, media, test, today;
    private final List<Item> toggles = new ArrayList<>();
    private final List<Item> pauses = new ArrayList<>();
    private int unit;
    private boolean updatingSwitch, asked;

    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            refresh();
            handler.postDelayed(this, 1000);
        }
    };

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        if (getActionBar() != null)
            getActionBar().hide(); // the screen draws its own title
        getWindow().setStatusBarColor(Pixel.NAVY);
        getWindow().setNavigationBarColor(Pixel.NAVY);
        float d = getResources().getDisplayMetrics().density;
        unit = Math.max(2, Math.round(d * 2.2f));
        int gap = Math.round(d * 12);

        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setPadding(gap, Math.round(d * 40), gap, gap * 2);
        column.addView(new Banner(this));

        status = new Item(this, "", Pixel.WHITE, Item.CARD);
        column.addView(status, lp(gap));
        setup = new Item(this, "Allow BlackBreak to show over other apps", Pixel.GOLD, Item.ROW);
        setup.pos = Item.SINGLE;
        setup.action = () -> startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            android.net.Uri.parse("package:" + getPackageName())));
        column.addView(setup, lp(gap));

        column.addView(new Item(this, "Pause", Pixel.GOLD, Item.HEAD), lp(gap / 2));
        String[] labels = {"Pause 30 min", "Pause 1 hour", "Pause 2 hours", "Pause 3 hours"};
        int[] minutes = {30, 60, 120, 180};
        for (int i = 0; i < 4; i++) {
            final int min = minutes[i];
            Item b = new Item(this, labels[i], Pixel.WHITE, Item.ROW);
            b.pos = i == 0 ? Item.FIRST : Item.MIDDLE;
            b.action = () -> {
                BreakService s = BreakService.instance;
                if (s != null)
                    s.pause(min);
                refresh();
            };
            pauses.add(b);
            column.addView(b, lp(0));
        }
        cancel = new Item(this, "Cancel pause", Pixel.WHITE, Item.ROW);
        cancel.pos = Item.LAST;
        cancel.action = () -> {
            BreakService s = BreakService.instance;
            if (s != null)
                s.cancelPause();
            refresh();
        };
        column.addView(cancel, lp(gap / 2));
        column.addView(new Item(this, "One pause per day, up to 3 hours.", Pixel.DIM, Item.PLAIN), lp(gap));

        column.addView(new Item(this, "Calls", Pixel.GOLD, Item.HEAD), lp(gap / 2));
        call = toggle(Options.CALL, "Wait with the break during a call", Item.SINGLE);
        column.addView(call, lp(gap / 2));
        column.addView(new Item(this, "A break waits at most 3 hours. Phone calls always wait.", Pixel.DIM, Item.PLAIN), lp(gap));

        column.addView(new Item(this, "Busy", Pixel.GOLD, Item.HEAD), lp(gap / 2));
        media = toggle(Options.MEDIA, "Wait while music or video is playing", Item.SINGLE);
        column.addView(media, lp(gap));

        column.addView(new Item(this, "Reminders", Pixel.GOLD, Item.HEAD), lp(gap / 2));
        column.addView(toggle(Options.WARNING, "Show Break in 10 s before a break", Item.FIRST), lp(0));
        column.addView(toggle(Options.VIBRATE, "Short buzz when a break ends", Item.LAST), lp(gap));

        column.addView(new Item(this, "Try it", Pixel.GOLD, Item.HEAD), lp(gap / 2));
        test = new Item(this, "Test break, 5 s", Pixel.WHITE, Item.ROW);
        test.pos = Item.SINGLE;
        test.action = () -> {
            BreakService s = BreakService.instance;
            if (s != null) {
                long now = System.currentTimeMillis();
                s.showTestBreak(now + 5000, now + 8000);
            }
        };
        column.addView(test, lp(gap));

        column.addView(new Item(this, "Today", Pixel.GOLD, Item.HEAD), lp(gap / 2));
        today = new Item(this, "", Pixel.WHITE, Item.ROW);
        today.pos = Item.SINGLE;
        column.addView(today, lp(gap));

        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(Pixel.NAVY);
        scroll.addView(column);
        setContentView(scroll);
    }

    // A switch row bound to a preference; off unless the option defaults to on.
    private Item toggle(String key, String label, int pos) {
        Item t = new Item(this, label, Pixel.WHITE, Item.SWITCH);
        t.pos = pos;
        t.key = key;
        t.action = () -> {
            if (updatingSwitch)
                return;
            t.checked = !t.checked;
            Options.prefs(this).edit().putBoolean(key, t.checked).apply();
            t.invalidate();
        };
        toggles.add(t);
        return t;
    }

    private static LinearLayout.LayoutParams lp(int bottom) {
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1, -2);
        p.bottomMargin = bottom;
        return p;
    }

    @Override
    protected void onResume() {
        super.onResume();
        handler.post(tick);
    }

    @Override
    protected void onPause() {
        handler.removeCallbacks(tick);
        super.onPause();
    }

    // The break is a window over other apps; that is the one permission it needs.
    private boolean allowed() {
        return Settings.canDrawOverlays(this);
    }

    private void refresh() {
        // the service starts with the app once it is allowed, and again after a restart
        if (allowed() && BreakService.instance == null)
            startForegroundService(new Intent(this, BreakService.class));
        if (android.os.Build.VERSION.SDK_INT >= 33 && checkSelfPermission("android.permission.POST_NOTIFICATIONS") != android.content.pm.PackageManager.PERMISSION_GRANTED && !asked) {
            asked = true;
            requestPermissions(new String[] {"android.permission.POST_NOTIFICATIONS"}, 1);
        }
        BreakService svc = BreakService.instance;
        DateFormat clock = DateFormat.getTimeInstance(DateFormat.SHORT);
        setup.setVisibility(allowed() ? View.GONE : View.VISIBLE);
        if (svc == null) {
            status.setText(allowed() ? "BlackBreak is starting" : "BlackBreak is off");
            for (Item p : pauses)
                p.setEnabled(false);
            cancel.setEnabled(false);
            call.setEnabled(false);
            media.setEnabled(false);
            test.setEnabled(false);
            syncSwitches();
            return;
        }
        Scheduler s = svc.scheduler();
        long phase = Native.get(s.buf, 0);
        if (phase == 3)
            status.setText("Paused until " + clock.format(new Date(Native.get(s.buf, 5))));
        else if (phase == 2)
            status.setText("Break in progress");
        else
            status.setText("Next break at " + clock.format(new Date(Native.get(s.buf, 2))));
        long menu = Native.menu(s.buf);
        for (Item p : pauses)
            p.setEnabled((menu & MENU_PAUSE) != 0);
        cancel.setEnabled((menu & MENU_CANCEL) != 0);
        // the switches that change what the next break waits for are fixed while a break is on
        boolean settings = (menu & MENU_SETTINGS) != 0;
        call.setEnabled(settings && !svc.held());
        media.setEnabled(settings && !svc.held());
        test.setEnabled(phase == 0);
        syncSwitches();
    }

    private void syncSwitches() {
        SharedPreferences prefs = Options.prefs(this);
        updatingSwitch = true;
        for (Item t : toggles) {
            boolean on = prefs.getBoolean(t.key, t.key.equals(Options.WARNING));
            if (t.checked != on) {
                t.checked = on;
                t.invalidate();
            }
        }
        updatingSwitch = false;
        today.setText("Breaks taken: " + Options.breaksToday(this));
    }

    // The title: the eye, the name and the rule.
    private final class Banner extends View {
        private final Paint paint = new Paint();

        Banner(Context context) {
            super(context);
            paint.setAntiAlias(false);
        }

        @Override
        protected void onMeasure(int w, int h) {
            setMeasuredDimension(MeasureSpec.getSize(w), unit * 46);
        }

        @Override
        protected void onDraw(Canvas c) {
            int eye = unit * 2;
            Pixel.eye(c, paint, 0, unit * 2, eye);
            int title = Math.max(2, (getWidth() - eye * 16 - unit * 4) / (10 * Pixel.CELL));
            title = Math.min(title, unit * 2);
            int x = eye * 16 + unit * 4;
            Pixel.text(c, paint, "BlackBreak", x, unit * 2, title, Pixel.GOLD, true);
            int sub = Math.max(1, title / 2);
            Pixel.text(c, paint, "30 s every 20 min.", x, unit * 2 + Pixel.ROWS * title + unit * 2, sub, Pixel.DIM, false);
            Pixel.text(c, paint, "No skip.", x, unit * 2 + Pixel.ROWS * title + unit * 2 + Pixel.LEADING * sub, sub, Pixel.DIM, false);
        }
    }

    // A block of pixel text: plain, a heading, the status card, or a row of a group (a button or a switch).
    private final class Item extends View {
        static final int PLAIN = 0, HEAD = 1, CARD = 2, ROW = 3, SWITCH = 4;
        static final int SINGLE = 0, FIRST = 1, MIDDLE = 2, LAST = 3;

        private final Paint paint = new Paint();
        private final int color, kind;
        private String text;
        private List<String> lines = new ArrayList<>();
        Runnable action;
        String key;
        int pos = SINGLE;
        boolean checked;
        private boolean down;

        Item(Context context, String text, int color, int kind) {
            super(context);
            this.text = text;
            this.color = color;
            this.kind = kind;
            paint.setAntiAlias(false);
            if (kind == ROW || kind == SWITCH)
                setClickable(true);
        }

        void setText(String t) {
            if (t.equals(text))
                return;
            text = t;
            requestLayout();
            invalidate();
        }

        @Override
        public void setEnabled(boolean e) {
            if (e != isEnabled()) {
                super.setEnabled(e);
                invalidate();
            }
        }

        private int pad() {
            return kind == PLAIN || kind == HEAD ? 0 : unit * 5;
        }

        @Override
        protected void onMeasure(int wSpec, int hSpec) {
            int w = MeasureSpec.getSize(wSpec);
            int reserve = kind == SWITCH ? unit * 16 : 0;
            int cols = Math.max(4, (w - 2 * pad() - reserve) / (Pixel.CELL * unit));
            lines = Pixel.wrap(text, cols);
            int rows = lines.size() * (Pixel.ROWS + 2) - 2;
            int extra = kind == PLAIN ? 0 : kind == HEAD ? unit * 4 : unit * 2;
            setMeasuredDimension(w, rows * unit + 2 * pad() + extra);
        }

        @Override
        public boolean onTouchEvent(MotionEvent e) {
            if (!isClickable() || !isEnabled())
                return true;
            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    down = true;
                    invalidate();
                    return true;
                case MotionEvent.ACTION_UP:
                    down = false;
                    invalidate();
                    if (e.getX() >= 0 && e.getX() <= getWidth() && e.getY() >= 0 && e.getY() <= getHeight() && action != null)
                        action.run();
                    return true;
                case MotionEvent.ACTION_CANCEL:
                    down = false;
                    invalidate();
                    return true;
                default:
                    return true;
            }
        }

        @Override
        protected void onDraw(Canvas c) {
            int w = getWidth(), h = getHeight();
            boolean on = isEnabled();
            int ink = on ? color : Pixel.LOW_BLUE;
            if (kind == CARD) {
                Pixel.box(c, paint, 0, 0, w, h, unit, Pixel.BG, Pixel.BLUE, Pixel.BLUE);
            } else if (kind == ROW || kind == SWITCH) {
                int t = unit;
                Pixel.rect(c, paint, down ? Pixel.RED : Pixel.BG, 0, 0, w, h);
                Pixel.rect(c, paint, Pixel.BLUE, 0, 0, t, h);
                Pixel.rect(c, paint, Pixel.BLUE, w - t, 0, t, h);
                if (pos == SINGLE || pos == FIRST)
                    Pixel.rect(c, paint, Pixel.BLUE, 0, 0, w, t);
                if (pos == SINGLE || pos == LAST)
                    Pixel.rect(c, paint, Pixel.BLUE, 0, h - t, w, t);
                else
                    Pixel.rect(c, paint, 0xFF1C1C6C, t, h - t, w - 2 * t, t);
            }
            float y = pad() + (kind == PLAIN || kind == HEAD ? 0 : unit);
            for (String line : lines) {
                Pixel.text(c, paint, line, pad(), y - unit * 2, unit, down && kind == ROW ? Pixel.GOLD : ink, kind == HEAD && on);
                y += (Pixel.ROWS + 2) * unit;
            }
            if (kind == HEAD)
                Pixel.rect(c, paint, Pixel.BLUE, 0, h - unit, w, unit);
            if (kind == SWITCH) {
                int sw = unit * 12, sh = unit * 6;
                float x = w - pad() - sw, top = (h - sh) / 2f;
                Pixel.box(c, paint, x, top, sw, sh, unit, Pixel.NAVY, Pixel.BLUE, Pixel.BLUE);
                int knob = on ? (checked ? Pixel.GREEN : 0xFF8C8C9C) : Pixel.LOW_BLUE;
                Pixel.rect(c, paint, knob, checked ? x + sw - unit * 6 : x + unit * 2, top + unit * 2, unit * 4, sh - unit * 4);
            }
        }
    }
}
