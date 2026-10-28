// The one quiet notification a foreground service needs; nothing else is ever posted.
package io.github.junkers4.blackbreak;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;

public final class Notifier {
    private static final String CHANNEL = "blackbreak";

    private Notifier() {}

    public static void start(Service s) {
        NotificationManager nm = (NotificationManager) s.getSystemService(Service.NOTIFICATION_SERVICE);
        NotificationChannel ch = new NotificationChannel(CHANNEL, "BlackBreak", NotificationManager.IMPORTANCE_MIN);
        ch.setShowBadge(false);
        nm.createNotificationChannel(ch);
        PendingIntent open = PendingIntent.getActivity(s, 0, new Intent(s, MainActivity.class), PendingIntent.FLAG_IMMUTABLE);
        int icon = s.getResources().getIdentifier("ic_notify", "drawable", s.getPackageName());
        Notification n = new Notification.Builder(s, CHANNEL)
            .setSmallIcon(icon)
            .setContentTitle("BlackBreak is on")
            .setContentText("30 s every 20 min")
            .setContentIntent(open)
            .setOngoing(true)
            .build();
        if (android.os.Build.VERSION.SDK_INT >= 34)
            s.startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        else
            s.startForeground(1, n);
    }
}
