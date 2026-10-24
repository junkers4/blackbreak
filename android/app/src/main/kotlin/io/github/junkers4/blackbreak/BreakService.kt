// The accessibility service owns the timer, the scheduler and the overlays. It reads no screen content.
package io.github.junkers4.blackbreak

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import io.github.junkers4.blackbreak.core.Phase
import io.github.junkers4.blackbreak.core.Scheduler

class BreakService : AccessibilityService() {
    companion object {
        @Volatile var instance: BreakService? = null
        const val PREFS = "blackbreak"
        const val PREF_LAST_PAUSE_DAY = "lastPauseDay"
        const val PREF_CALL_EXEMPTION = "callExemption"
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var controller: BreakController
    private lateinit var breakOverlay: BreakOverlay
    private lateinit var notice: NoticeOverlay
    private var scale = 1.0
    private var exemption = false // snapshot, taken at each work-phase tick
    private var screenOffAt: Long? = null
    private var breakEndsAt = 0L

    val scheduler: Scheduler get() = controller.scheduler
    val breakShown: Boolean get() = this::breakOverlay.isInitialized && breakOverlay.shown
    fun held(): Boolean = controller.held(System.currentTimeMillis())

    private val tickRunnable = Runnable { tick() }
    private val failsafe = Runnable {
        testBreakEndsAt = null
        breakOverlay.hide()
    }

    // Tests only: a break shown on request, ended by its end time or the fail-safe.
    private var testBreakEndsAt: Long? = null
    val breakView: android.view.View get() = breakOverlay.view

    /** Tests only: shows the break now until [endsAt], with the fail-safe at [failsafeAt]. */
    fun showTestBreak(endsAt: Long, failsafeAt: Long) {
        val now = System.currentTimeMillis()
        testBreakEndsAt = endsAt
        handler.removeCallbacks(failsafe)
        handler.postDelayed(failsafe, (failsafeAt - now).coerceAtLeast(1))
        breakOverlay.show((endsAt - now + 999) / 1000)
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) {
                screenOffAt = System.currentTimeMillis()
                handler.removeCallbacks(tickRunnable)
            } else {
                val now = System.currentTimeMillis()
                screenOffAt?.let { controller.screenOn(now, now - it) }
                screenOffAt = null
                tick()
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (debuggable) {
            // "1" means 60x; any other number is the factor itself.
            val fast = getprop("debug.blackbreak.fast")
            scale = if (fast == "1") 60.0 else fast.toDoubleOrNull()?.takeIf { it > 1 } ?: 1.0
        }
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        breakOverlay = BreakOverlay(this, wm)
        notice = NoticeOverlay(this, wm)
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        controller = BreakController(Scheduler(System.currentTimeMillis(), scale, lastPauseDay = prefs.getString(PREF_LAST_PAUSE_DAY, null)))
        registerReceiver(screenReceiver, IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        })
        tick()
    }

    private fun getprop(name: String): String = try {
        Runtime.getRuntime().exec(arrayOf("getprop", name)).inputStream.bufferedReader().readText().trim()
    } catch (e: Exception) {
        ""
    }

    private fun tick() {
        handler.removeCallbacks(tickRunnable)
        val now = System.currentTimeMillis()
        if (controller.scheduler.phase == Phase.WORK)
            exemption = getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(PREF_CALL_EXEMPTION, false)
        val audio = (getSystemService(Context.AUDIO_SERVICE) as AudioManager).mode
        val show = controller.tick(now, 0, audio, exemption)
        if (show.notice) notice.show() else notice.hide()
        val test = testBreakEndsAt
        if (test != null && now < test) {
            breakOverlay.update((test - now + 999) / 1000)
            handler.postDelayed(tickRunnable, 1000)
            return
        }
        testBreakEndsAt = null
        val ends = show.breakEndsAt
        if (ends != null) {
            if (!breakOverlay.shown) {
                // The independent fail-safe is armed before the view is added.
                val start = ends - Math.round(Scheduler.BREAK_MS / scale)
                handler.removeCallbacks(failsafe)
                handler.postDelayed(failsafe, (start + Scheduler.FAILSAFE_MS - now).coerceAtLeast(1))
            }
            breakEndsAt = ends
            breakOverlay.show((ends - now + 999) / 1000)
        } else {
            handler.removeCallbacks(failsafe)
            breakOverlay.hide()
        }
        if (screenOffAt == null) handler.postDelayed(tickRunnable, if (scale > 1) 50 else 1000)
    }

    /** Pause for [minutes]; false when it is not allowed now. */
    fun pause(minutes: Int): Boolean {
        val now = System.currentTimeMillis()
        if (!controller.scheduler.pause(minutes * 60_000L, now)) return false
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(PREF_LAST_PAUSE_DAY, controller.scheduler.lastPauseDay).apply()
        tick()
        return true
    }

    fun cancelPause() {
        controller.scheduler.cancelPause(System.currentTimeMillis())
        tick()
    }

    override fun onKeyEvent(event: KeyEvent): Boolean = breakShown

    override fun onAccessibilityEvent(event: AccessibilityEvent) {}

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        shutdown()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        shutdown()
        super.onDestroy()
    }

    private fun shutdown() {
        instance = null
        handler.removeCallbacksAndMessages(null)
        if (this::breakOverlay.isInitialized) {
            breakOverlay.hide()
            notice.hide()
            runCatching { unregisterReceiver(screenReceiver) }
        }
    }
}
