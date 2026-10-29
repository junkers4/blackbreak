// The scheduler's state outlives the service: when the system kills and restarts it, the work
// interval goes on where it was. The core's own rule decides the rest: five minutes or more
// since the last saved tick counts as rest and starts a fresh interval.
package io.github.junkers4.blackbreak;

import android.content.Context;
import android.util.Base64;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public final class Keep {
    static final String STATE = "schedulerState";
    private static final long EVERY_MS = 10_000;
    private static long savedAt;

    private Keep() {}

    /** At the service's start: the saved state, if it was made with the same scale and durations (a debug run is not mixed in). */
    public static void restore(Context c, ByteBuffer buf) {
        String s = Options.prefs(c).getString(STATE, null);
        if (s == null)
            return;
        byte[] saved;
        try {
            saved = Base64.decode(s, Base64.NO_WRAP);
        } catch (IllegalArgumentException e) {
            return;
        }
        ByteBuffer d = buf.duplicate();
        d.clear();
        if (saved.length != d.capacity())
            return;
        ByteBuffer was = ByteBuffer.wrap(saved).order(d.order());
        for (int i = 0; i < 40; i += 8)
            if (d.getLong(i) != was.getLong(i))
                return; // ST_SCALE to ST_IDLE differ: a fast or short debug run
        d.put(saved);
    }

    /** Every tick; written every 10 s, or at once when forced (screen off, service ending). */
    public static void save(Context c, ByteBuffer buf, long now, boolean force) {
        if (!force && Math.abs(now - savedAt) < EVERY_MS)
            return;
        savedAt = now;
        ByteBuffer d = buf.duplicate();
        d.clear();
        byte[] b = new byte[d.capacity()];
        d.get(b);
        Options.prefs(c).edit().putString(STATE, Base64.encodeToString(b, Base64.NO_WRAP)).apply();
    }

    /** Debug runs: setprop debug.blackbreak.work 10 makes the work interval 10 s, the break stays 30 s. */
    public static void work(ByteBuffer buf, String seconds) {
        try {
            double s = Double.parseDouble(seconds);
            if (s > 0)
                buf.duplicate().order(ByteOrder.nativeOrder()).putDouble(8, s * 1000); // ST_WORK
        } catch (NumberFormatException e) {
            // not set
        }
    }
}
