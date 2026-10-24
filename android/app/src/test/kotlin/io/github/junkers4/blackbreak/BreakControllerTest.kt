package io.github.junkers4.blackbreak

import io.github.junkers4.blackbreak.core.Phase
import io.github.junkers4.blackbreak.core.Scheduler
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class BreakControllerTest {
    private val none = 0
    private val ring = BreakController.MODE_RINGTONE
    private val voip = BreakController.MODE_IN_COMMUNICATION

    private fun controller() = BreakController(Scheduler(0))

    /** One tick per second from [from] to [to] with a fixed audio mode; returns the last result. */
    private fun run(c: BreakController, from: Long, to: Long, mode: Int = none, exemption: Boolean = false): Show {
        var s = Show(false, null)
        var t = from
        while (t <= to) {
            s = c.tick(t, 0, mode, exemption)
            t += 1000
        }
        return s
    }

    @Test fun `warning shows notice`() {
        val s = run(controller(), 0, 1_190_000)
        assertTrue(s.notice)
        assertNull(s.breakEndsAt)
    }

    @Test fun `break shows overlay until breakEndsAt`() {
        val c = controller()
        val s = run(c, 0, 1_200_000)
        assertFalse(s.notice)
        assertEquals(1_230_000L, s.breakEndsAt)
        assertNull(run(c, 1_201_000, 1_230_000).breakEndsAt)
    }

    @Test fun `ringing during break hides overlay`() {
        val c = controller()
        run(c, 0, 1_200_000)
        assertNull(c.tick(1_205_000, 0, ring, false).breakEndsAt)
        // and it does not come back when the ringing stops within the same break
        assertNull(c.tick(1_206_000, 0, none, false).breakEndsAt)
    }

    @Test fun `VoIP mode ignored when exemption off`() {
        val c = controller()
        val s = run(c, 0, 1_200_000, voip, exemption = false)
        assertNotNull(s.breakEndsAt)
    }

    @Test fun `VoIP mode holds when on and seen before due`() {
        val c = controller()
        run(c, 0, 1_139_000)
        val s = run(c, 1_140_000, 1_300_000, voip, exemption = true)
        assertEquals(Phase.WORK, c.scheduler.phase)
        assertFalse(s.notice)
        assertNull(s.breakEndsAt)
        assertTrue(c.held(1_300_000))
        assertTrue(c.tick(1_301_000, 0, none, true).notice) // call over: the warning starts now
    }

    @Test fun `phone call holds without exemption`() {
        val c = controller()
        val s = run(c, 0, 1_300_000, ring, exemption = false)
        assertEquals(Phase.WORK, c.scheduler.phase)
        assertNull(s.breakEndsAt)
    }

    @Test fun `screen off 5 min is rest`() {
        val c = controller()
        run(c, 0, 100_000)
        c.screenOn(400_000, 300_000)
        assertEquals(1_600_000L, c.scheduler.nextBreakAt)
    }

    @Test fun `screen off 4 min is not`() {
        val c = controller()
        run(c, 0, 100_000)
        c.screenOn(340_000, 240_000)
        assertEquals(1_200_000L, c.scheduler.nextBreakAt)
    }

    // REQ-014: the call switch only in a normal work interval
    @Test fun `call switch only in work and not while held`() {
        assertTrue(ScreenRules.callSwitchEnabled(Phase.WORK, false))
        assertFalse(ScreenRules.callSwitchEnabled(Phase.WORK, true))
        for (p in listOf(Phase.WARNING, Phase.BREAK, Phase.PAUSED)) assertFalse(ScreenRules.callSwitchEnabled(p, false), "$p")
    }

    // REQ-010: cancel only while paused
    @Test fun `cancel only while paused`() {
        assertTrue(ScreenRules.cancelEnabled(Phase.PAUSED))
        for (p in listOf(Phase.WORK, Phase.WARNING, Phase.BREAK)) assertFalse(ScreenRules.cancelEnabled(p), "$p")
    }
}
