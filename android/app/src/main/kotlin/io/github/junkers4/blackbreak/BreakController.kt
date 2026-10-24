// What to show now: the scheduler's phase plus the call state, with no Android types.
package io.github.junkers4.blackbreak

import io.github.junkers4.blackbreak.core.Phase
import io.github.junkers4.blackbreak.core.Scheduler

data class Show(val notice: Boolean, val breakEndsAt: Long?)

class BreakController(val scheduler: Scheduler) {
    companion object {
        // android.media.AudioManager modes
        const val MODE_RINGTONE = 1
        const val MODE_IN_CALL = 2
        const val MODE_IN_COMMUNICATION = 3
        private const val CALL_WATCH_MS = 60_000L
    }

    // A phone call during a break removes the overlay; it does not come back for the rest of that break.
    private var dismissed = false

    fun tick(now: Long, idleMs: Long, audioMode: Int, exemption: Boolean): Show {
        val phone = audioMode == MODE_RINGTONE || audioMode == MODE_IN_CALL
        // VoIP use only matters from 60 s before the warning is due, and while it holds the break.
        val watching = scheduler.phase == Phase.WORK &&
            (scheduler.nextBreakAt?.let { now >= it - Scheduler.WARN_MS - CALL_WATCH_MS } ?: false)
        val voip = exemption && watching && audioMode == MODE_IN_COMMUNICATION
        val phase = scheduler.update(now, idleMs, voip, phone)
        if (phase != Phase.BREAK) dismissed = false
        else if (phone) dismissed = true
        return Show(
            notice = phase == Phase.WARNING,
            breakEndsAt = if (phase == Phase.BREAK && !dismissed) scheduler.breakEndsAt else null,
        )
    }

    /** The screen was off for [offMs]: five minutes or more is rest. */
    fun screenOn(now: Long, offMs: Long) {
        scheduler.update(now, offMs)
        scheduler.update(now, 0)
    }

    /** True while a call keeps a due break waiting. */
    fun held(now: Long): Boolean =
        scheduler.phase == Phase.WORK && (scheduler.nextBreakAt?.let { now >= it - Scheduler.WARN_MS } ?: false)
}

/** What the app screen allows: settings only in a normal work interval, never in the warning, the break or a hold. */
object ScreenRules {
    fun callSwitchEnabled(phase: Phase, held: Boolean): Boolean = phase == Phase.WORK && !held
    fun cancelEnabled(phase: Phase): Boolean = phase == Phase.PAUSED
}
