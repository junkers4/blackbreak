// The break schedule: a handle on the assembler core's state.
package io.github.junkers4.blackbreak

import java.nio.ByteBuffer
import java.util.TimeZone

enum class Phase { WORK, WARNING, BREAK, PAUSED }

/** [lastPauseDay] is a local day number, as the core counts days. */
class Scheduler(nowMs: Long, scale: Double = 1.0, lastPauseDay: Long? = null) {
    companion object {
        const val BREAK_MS = 30_000L
        const val FAILSAFE_MS = 35_000L
        private const val GET_PHASE = 0L
        private const val GET_CANPAUSE = 1L
        private const val GET_NEXTBREAK = 2L
        private const val GET_BREAKENDS = 3L
        private const val GET_PAUSEENDS = 5L
        private const val GET_LASTPAUSE = 6L
        const val MENU_PAUSE = 1L
        const val MENU_CANCEL = 2L
        const val MENU_SETTINGS = 4L
    }

    internal val buf: ByteBuffer = ByteBuffer.allocateDirect(Native.stateSize().toInt())

    init {
        Native.init(buf, nowMs, java.lang.Double.doubleToRawLongBits(scale), lastPauseDay ?: Native.NONE)
        followTimeZone(nowMs)
    }

    /** Day numbers follow the local calendar day; summer time changes it. */
    fun followTimeZone(now: Long) {
        Native.setTz(buf, TimeZone.getDefault().getOffset(now).toLong())
    }

    private fun value(which: Long): Long? = Native.get(buf, which).takeIf { it != Native.NONE }

    val phase: Phase get() = Phase.entries[Native.get(buf, GET_PHASE).toInt()]
    val canPause: Boolean get() = Native.get(buf, GET_CANPAUSE) == 1L
    val nextBreakAt: Long? get() = value(GET_NEXTBREAK)
    val breakEndsAt: Long? get() = value(GET_BREAKENDS)
    val pauseEndsAt: Long? get() = value(GET_PAUSEENDS)
    val lastPauseDay: Long? get() = value(GET_LASTPAUSE)
    val menu: Long get() = Native.menu(buf)

    fun pause(durationMs: Long, now: Long): Boolean = Native.pause(buf, durationMs, now) == 1L
    fun cancelPause(now: Long): Boolean = Native.cancel(buf, now) == 1L
}
