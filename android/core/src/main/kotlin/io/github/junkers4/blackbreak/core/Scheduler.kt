// Pure scheduling logic: no Android APIs, runs on any JVM.
package io.github.junkers4.blackbreak.core

import java.time.Instant
import java.time.ZoneId

enum class Phase { WORK, WARNING, BREAK, PAUSED }

fun localDayKey(ms: Long): String =
    Instant.ofEpochMilli(ms).atZone(ZoneId.systemDefault()).toLocalDate().toString()

class Scheduler(
    nowMs: Long,
    private val scale: Double = 1.0,
    private val dayKey: (Long) -> String = ::localDayKey,
    lastPauseDay: String? = null,
) {
    companion object {
        const val WORK_MS = 1_200_000L
        const val WARN_MS = 10_000L
        const val BREAK_MS = 30_000L
        const val FAILSAFE_MS = 35_000L
        const val MAX_PAUSE_MS = 10_800_000L
        const val IDLE_MS = 300_000L
        const val MAX_CALL_WAIT_MS = 10_800_000L
    }

    // Scaled durations can be fractional, so the internal clock values are doubles.
    private val work = WORK_MS / scale
    private val warn = WARN_MS / scale
    private val brk = BREAK_MS / scale
    private val idle = IDLE_MS / scale
    private var lastPause: String? = lastPauseDay
    private var current = Phase.WORK
    private var workStart = nowMs.toDouble()
    private var breakStart: Double? = null
    private var holdSince: Double? = null // when the warning was first due, while a call holds it
    private var callSeen = false // a call was active before the warning was due
    private var phoneHeld = false // the current hold included a phone call
    private var holdSpent = false // a hold already ended in this interval
    private var lastNow = nowMs.toDouble()
    private var idleHeld = false
    private var pauseStart: Double? = null
    private var pauseEnd: Double? = null

    private fun ms(v: Double) = Math.round(v)

    val lastPauseDay: String? get() = lastPause
    val phase: Phase get() = current
    val breakEndsAt: Long? get() = if (current == Phase.BREAK) ms(breakStart!! + brk) else null
    val warningEndsAt: Long? get() = if (current == Phase.WARNING) ms(workStart + work) else null
    val nextBreakAt: Long? get() = if (current == Phase.WORK || current == Phase.WARNING) ms(workStart + work) else null
    val pauseEndsAt: Long? get() = if (current == Phase.PAUSED) ms(pauseEnd!!) else null
    val canPause: Boolean get() = current == Phase.WORK && dayKey(ms(lastNow)) != lastPause

    // Durations are scaled like every other duration; the cap is checked unscaled.
    fun pause(durationMs: Long, now: Long): Boolean {
        if (current != Phase.WORK || durationMs <= 0 || durationMs > MAX_PAUSE_MS || dayKey(now) == lastPause) return false
        current = Phase.PAUSED
        pauseStart = now.toDouble()
        pauseEnd = now + durationMs / scale
        lastPause = dayKey(now)
        breakStart = null
        return true
    }

    fun cancelPause(now: Long): Boolean {
        if (current != Phase.PAUSED) return false
        endPause(now.toDouble())
        return true
    }

    private fun endPause(at: Double) {
        pauseStart = null
        pauseEnd = null
        restart(at)
    }

    private fun restart(now: Double) {
        current = Phase.WORK
        workStart = now
        breakStart = null
        holdSince = null
        holdSpent = false
        callSeen = false
        phoneHeld = false
    }

    fun update(now: Long, idleMs: Long = 0, inCall: Boolean = false, inPhoneCall: Boolean = false): Phase {
        val nowD = now.toDouble()
        if (current == Phase.PAUSED) {
            // Idle input and calls do not matter; only the pause clock.
            val prev = lastNow
            lastNow = nowD
            idleHeld = false
            if (nowD < prev) // backward step: never longer than the cap from now
                pauseEnd = minOf(pauseEnd!!, nowD + MAX_PAUSE_MS / scale)
            if (nowD < pauseEnd!!) return current
            // Suspended through the end, or idle that long: the rest counts.
            val rested = nowD - prev >= idle || nowD - pauseEnd!! >= idle
            endPause(if (rested) nowD else pauseEnd!!)
            return update(now, idleMs, inCall, inPhoneCall)
        }
        val gap = nowD - lastNow
        lastNow = nowD
        if (gap < 0 || gap >= idle) {
            restart(nowD) // suspend or clock step counts as rest
            return current
        }

        if (idleMs >= idle) {
            idleHeld = true
            restart(nowD)
            return current
        }
        if (idleHeld) {
            idleHeld = false
            restart(nowD)
            return current
        }

        if (current == Phase.BREAK && nowD >= breakStart!! + brk) restart(breakStart!! + brk)
        if (current == Phase.WORK && !holdSpent) {
            // Only the work phase holds; calls in warning or break change nothing.
            val dueAt = workStart + work - warn
            if (nowD < dueAt) {
                callSeen = inCall || inPhoneCall
            } else if (holdSince != null || callSeen) {
                // A call first seen once the warning is due changes nothing.
                val capEnd = dueAt + MAX_CALL_WAIT_MS / scale
                if (inPhoneCall || (inCall && nowD < capEnd)) {
                    holdSince = dueAt
                    phoneHeld = phoneHeld || inPhoneCall
                    return current
                }
                if (holdSince != null) {
                    // Released: the warning starts now (at the cap if it ran out).
                    val at = if (inCall && !phoneHeld) capEnd else nowD
                    workStart = at - (work - warn)
                    holdSince = null
                    holdSpent = true
                    phoneHeld = false
                }
            }
        }
        if (current != Phase.BREAK) {
            val elapsed = nowD - workStart
            if (elapsed >= work) {
                current = Phase.BREAK
                breakStart = workStart + work
                if (nowD >= breakStart!! + brk) restart(breakStart!! + brk)
            } else {
                current = if (elapsed >= work - warn) Phase.WARNING else Phase.WORK
            }
        }
        return current
    }
}
