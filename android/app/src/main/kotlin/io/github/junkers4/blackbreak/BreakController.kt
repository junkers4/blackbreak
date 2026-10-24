// What to show now. The decision is in the assembler core (core/aarch64/controller.S).
package io.github.junkers4.blackbreak

data class Show(val notice: Boolean, val breakEndsAt: Long?)

class BreakController(val scheduler: Scheduler) {
    fun tick(now: Long, idleMs: Long, audioMode: Int, exemption: Boolean): Show {
        scheduler.followTimeZone(now)
        val ends = Native.tick(scheduler.buf, now, idleMs, audioMode.toLong(), if (exemption) 1 else 0)
        return Show(notice = scheduler.phase == Phase.WARNING, breakEndsAt = ends.takeIf { it != Native.NONE })
    }

    /** The screen was off for [offMs]: five minutes or more is rest. */
    fun screenOn(now: Long, offMs: Long) {
        Native.screenOn(scheduler.buf, now, offMs)
    }

    /** True while a call keeps a due break waiting. */
    fun held(now: Long): Boolean = Native.held(scheduler.buf, now) == 1L
}

/** What the app screen allows, from the core's menu rule; the call switch also not while a call holds a break. */
object ScreenRules {
    fun callSwitchEnabled(s: Scheduler, held: Boolean): Boolean = s.menu and Scheduler.MENU_SETTINGS != 0L && !held
    fun cancelEnabled(s: Scheduler): Boolean = s.menu and Scheduler.MENU_CANCEL != 0L
    fun pauseEnabled(s: Scheduler): Boolean = s.menu and Scheduler.MENU_PAUSE != 0L
}
