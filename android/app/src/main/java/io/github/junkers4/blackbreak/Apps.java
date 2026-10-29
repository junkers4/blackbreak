// The apps a break never covers (Waze, Maps, ...): while one of them is on screen, picture-in-picture
// included, a due break waits like a phone call. It needs "Usage access"; nothing of the screen is read.
package io.github.junkers4.blackbreak;

import android.app.AppOpsManager;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Process;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class Apps {
    static final String KEY = "exemptApps";
    /** Navigation apps, listed first in the picker. */
    static final List<String> NAVIGATION = Arrays.asList(
        "com.waze", "com.google.android.apps.maps", "com.google.android.projection.gearhead",
        "com.sygic.aura", "com.here.app.maps", "net.osmand", "net.osmand.plus", "cz.seznam.mapy",
        "com.mapfactor.navigator", "com.tomtom.gplay.navapp", "app.organicmaps", "com.mapswithme.maps.pro",
        "us.spotco.maps");

    private static final long HISTORY_MS = 6 * 3600_000L, OVERLAP_MS = 2000;
    private static final int RESUMED = 1, PAUSED = 2, STOPPED = 23;

    // the activities on screen now (package/class -> package), kept from the usage events
    private static final Map<String, String> visible = new HashMap<>();
    private static final Map<String, String> labels = new HashMap<>();
    private static long readUntil;

    private Apps() {}

    static Set<String> chosen(Context c) {
        return Options.prefs(c).getStringSet(KEY, Collections.<String>emptySet());
    }

    static void choose(Context c, String pkg, boolean on) {
        Set<String> s = new HashSet<>(chosen(c));
        if (on)
            s.add(pkg);
        else
            s.remove(pkg);
        Options.prefs(c).edit().putStringSet(KEY, s).apply();
    }

    /** Usage access, the one thing this needs. */
    static boolean allowed(Context c) {
        AppOpsManager ops = (AppOpsManager) c.getSystemService(Context.APP_OPS_SERVICE);
        if (ops == null)
            return false;
        int mode = android.os.Build.VERSION.SDK_INT >= 29
            ? ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), c.getPackageName())
            : ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), c.getPackageName());
        return mode == AppOpsManager.MODE_ALLOWED;
    }

    static String label(Context c, String pkg) {
        String l = labels.get(pkg);
        if (l == null) {
            PackageManager pm = c.getPackageManager();
            try {
                l = pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString();
            } catch (PackageManager.NameNotFoundException e) {
                l = pkg;
            }
            labels.put(pkg, l);
        }
        return l;
    }

    /** The apps with a launcher icon, navigation first, then by name; not BlackBreak itself. */
    static List<String> listable(Context c) {
        PackageManager pm = c.getPackageManager();
        Intent main = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        Set<String> seen = new HashSet<>();
        List<String> nav = new ArrayList<>(), rest = new ArrayList<>();
        for (ResolveInfo r : pm.queryIntentActivities(main, 0)) {
            String pkg = r.activityInfo.packageName;
            if (pkg.equals(c.getPackageName()) || !seen.add(pkg))
                continue;
            labels.put(pkg, r.loadLabel(pm).toString());
            (NAVIGATION.contains(pkg) ? nav : rest).add(pkg);
        }
        Collections.sort(nav, (a, b) -> NAVIGATION.indexOf(a) - NAVIGATION.indexOf(b));
        Collections.sort(rest, (a, b) -> labels.get(a).compareToIgnoreCase(labels.get(b)));
        nav.addAll(rest);
        return nav;
    }

    /** The name of a chosen app on screen now, or null. Called every tick while the screen is on. */
    static String onScreen(Context c, long now) {
        Set<String> chosen = chosen(c);
        if (chosen.isEmpty())
            return null;
        UsageStatsManager usm = (UsageStatsManager) c.getSystemService(Context.USAGE_STATS_SERVICE);
        if (usm == null)
            return null;
        long from = readUntil == 0 || now - readUntil > HISTORY_MS ? now - HISTORY_MS : readUntil - OVERLAP_MS;
        if (readUntil == 0 || now - readUntil > HISTORY_MS)
            visible.clear();
        try {
            UsageEvents ev = usm.queryEvents(from, now + 1);
            UsageEvents.Event e = new UsageEvents.Event();
            // events replayed from the overlap land in the same state, so the overlap is safe
            while (ev != null && ev.getNextEvent(e)) {
                String key = e.getPackageName() + "/" + e.getClassName();
                int t = e.getEventType();
                if (t == RESUMED)
                    visible.put(key, e.getPackageName());
                else if (t == STOPPED || (t == PAUSED && android.os.Build.VERSION.SDK_INT < 29))
                    visible.remove(key); // paused alone is still on screen: picture-in-picture, split screen
            }
            readUntil = now;
        } catch (RuntimeException e) {
            return null; // no usage access: nothing waits
        }
        for (String pkg : visible.values())
            if (chosen.contains(pkg))
                return label(c, pkg);
        return null;
    }
}
