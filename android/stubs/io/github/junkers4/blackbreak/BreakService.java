package io.github.junkers4.blackbreak;
public class BreakService extends android.app.Service {
    public static BreakService instance;
    public boolean pause(int minutes) { return false; }
    public void cancelPause() {}
    public boolean held() { return false; }
    public void showTestBreak(long endsAt, long failsafeAt) {}
    public Scheduler scheduler() { return null; }
    public android.os.IBinder onBind(android.content.Intent i) { return null; }
}
