// The options of the app screen, read by the service and the screens. All off unless noted.
package io.github.junkers4.blackbreak;

import android.content.Context;
import android.content.SharedPreferences;
import android.media.AudioManager;
import android.os.VibrationEffect;
import android.os.Vibrator;
import java.util.Calendar;

public final class Options {
    static final String PREFS = "blackbreak";
    static final String CALL = "callExemption", MEDIA = "mediaWait", WARNING = "showWarning",
        VIBRATE = "vibrateAtEnd", DAY = "statsDay", COUNT = "statsBreaks";

    private Options() {}

    static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    /** The "Break in 10 s" notice; on unless turned off. */
    public static boolean showWarning(Context c) {
        return prefs(c).getBoolean(WARNING, true);
    }

    /** The audio mode handed to the core: music or video playing counts as a call when asked. */
    public static int mode(Context c, int mode) {
        if (prefs(c).getBoolean(MEDIA, false)) {
            AudioManager am = (AudioManager) c.getSystemService(Context.AUDIO_SERVICE);
            if (am != null && am.isMusicActive())
                return AudioManager.MODE_IN_COMMUNICATION;
        }
        return mode;
    }

    /** The core only looks at the audio mode when the exemption is on. */
    public static boolean exemption(Context c, boolean callOn) {
        return callOn || prefs(c).getBoolean(MEDIA, false);
    }

    static String today() {
        Calendar k = Calendar.getInstance();
        return k.get(Calendar.YEAR) + "-" + (k.get(Calendar.MONTH) + 1) + "-" + k.get(Calendar.DAY_OF_MONTH);
    }

    static int breaksToday(Context c) {
        SharedPreferences p = prefs(c);
        return today().equals(p.getString(DAY, "")) ? p.getInt(COUNT, 0) : 0;
    }

    /** A break ran to its end: counted for today, and a short buzz when asked. */
    static void breakEnded(Context c) {
        SharedPreferences p = prefs(c);
        p.edit().putString(DAY, today()).putInt(COUNT, breaksToday(c) + 1).apply();
        if (p.getBoolean(VIBRATE, false)) {
            Vibrator v = (Vibrator) c.getSystemService(Context.VIBRATOR_SERVICE);
            if (v != null)
                v.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE));
        }
    }
}
