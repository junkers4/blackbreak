// After a restart or an update the service starts again, so a break never depends on opening the app.
package io.github.junkers4.blackbreak;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.provider.Settings;

public final class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Settings.canDrawOverlays(context))
            context.startForegroundService(new Intent(context, BreakService.class));
    }
}
