package io.github.junkers4.blackbreak

import android.app.Instrumentation
import android.app.UiAutomation
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.Switch
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.Configurator
import androidx.test.uiautomator.UiDevice
import io.github.junkers4.blackbreak.core.Phase
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * On a real device: the service is turned on through `settings`, as adb would.
 * Each test names the requirements it covers (docs/requirements.md).
 */
@RunWith(AndroidJUnit4::class)
class BreakOverlayTest {
    private val inst: Instrumentation = InstrumentationRegistry.getInstrumentation()

    // UiAutomation would otherwise switch every other accessibility service off, BlackBreak included.
    private val automation = inst.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
    private val device = run {
        Configurator.getInstance().uiAutomationFlags = UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES
        UiDevice.getInstance(inst)
    }
    private val component = "io.github.junkers4.blackbreak/io.github.junkers4.blackbreak.BreakService"

    private fun shell(cmd: String): String =
        automation.executeShellCommand(cmd).let { pfd ->
            android.os.ParcelFileDescriptor.AutoCloseInputStream(pfd).bufferedReader().readText().trim()
        }

    private fun waitFor(ms: Long, cond: () -> Boolean): Boolean {
        val end = System.currentTimeMillis() + ms
        while (System.currentTimeMillis() < end) {
            if (cond()) return true
            Thread.sleep(100)
        }
        return cond()
    }

    private fun onMain(block: () -> Unit) = inst.runOnMainSync(block)

    private fun service(): BreakService = BreakService.instance ?: error("service not running")

    private fun startService(fast: String) {
        shell("setprop debug.blackbreak.fast $fast")
        shell("settings delete secure enabled_accessibility_services")
        assertTrue("service stops", waitFor(5000) { BreakService.instance == null })
        shell("settings put secure enabled_accessibility_services $component")
        shell("settings put secure accessibility_enabled 1")
        assertTrue("service starts", waitFor(10_000) { BreakService.instance != null })
    }

    private fun startTarget(): TargetActivity {
        val intent = Intent(inst.targetContext, TargetActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val a = inst.startActivitySync(intent) as TargetActivity
        inst.waitForIdleSync()
        return a
    }

    private fun breakShown(): Boolean {
        var shown = false
        onMain { shown = service().breakShown && service().breakView.isAttachedToWindow }
        return shown
    }

    private fun testBreak(seconds: Long, failsafeSeconds: Long = 35) {
        val now = System.currentTimeMillis()
        onMain { service().showTestBreak(now + seconds * 1000, now + failsafeSeconds * 1000) }
        assertTrue("break shown", waitFor(3000) { breakShown() })
    }

    @Before fun setUp() {
        shell("svc power stayon usb") // the screen must stay on between tests
        device.wakeUp()
        startService("0")
    }

    @After fun tearDown() {
        shell("setprop debug.blackbreak.fast 0")
        shell("settings delete secure enabled_accessibility_services")
        shell("settings put secure accessibility_enabled 0")
        shell("svc power stayon false")
    }

    // REQ-007: turned on, it starts a fresh interval
    @Test fun serviceStartsFresh() {
        var phase: Phase? = null
        var next = 0L
        onMain {
            phase = service().scheduler.phase
            next = service().scheduler.nextBreakAt ?: 0
        }
        assertEquals(Phase.WORK, phase)
        assertTrue(next - System.currentTimeMillis() > 19 * 60_000)
    }

    // REQ-003: the break covers the whole display, bars included; REQ-030: its text
    @Test fun breakCoversWholeDisplay() {
        startTarget()
        testBreak(20)
        var w = 0
        var h = 0
        var texts = listOf<String>()
        onMain {
            val v = service().breakView
            w = v.width
            h = v.height
            texts = allTexts(v)
        }
        val real = android.graphics.Point().also {
            @Suppress("DEPRECATION")
            (inst.targetContext.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).defaultDisplay.getRealSize(it)
        }
        assertEquals("width", real.x, w)
        assertEquals("height", real.y, h)
        assertTrue("three lines and the seconds: $texts", texts.size == 4 && texts.last().matches(Regex("\\d+ (seconds?|sekúnd|sekundy|sekunda)")))
    }

    private fun allTexts(v: View): List<String> = when (v) {
        is android.widget.TextView -> listOf(v.text.toString())
        is ViewGroup -> (0 until v.childCount).flatMap { allTexts(v.getChildAt(it)) }
        else -> emptyList()
    }

    // REQ-004, REQ-023: taps do not reach the app underneath; they do before and after
    @Test fun tapsDoNotReachAppDuringBreak() {
        val target = startTarget()
        device.click(device.displayWidth / 2, device.displayHeight / 2)
        assertTrue("a tap reaches the app before the break", waitFor(2000) { target.taps == 1 })
        testBreak(6)
        repeat(5) { device.click(device.displayWidth / 2, device.displayHeight / 2) }
        device.swipe(100, device.displayHeight / 2, device.displayWidth - 100, device.displayHeight / 2, 10)
        Thread.sleep(500)
        assertEquals("taps during the break", 1, target.taps)
        assertTrue("break ends by itself", waitFor(8000) { !breakShown() })
        Thread.sleep(500)
        device.click(device.displayWidth / 2, device.displayHeight / 2)
        assertTrue("a tap reaches the app after the break", waitFor(2000) { target.taps == 2 })
    }

    // REQ-022: Back, Home and Recents leave the black screen in place
    @Test fun navigationDoesNotEndBreak() {
        startTarget()
        testBreak(15)
        device.pressBack()
        assertTrue("after Back", breakShown())
        device.pressHome()
        Thread.sleep(800)
        assertTrue("after Home", breakShown())
        device.pressRecentApps()
        Thread.sleep(800)
        assertTrue("after Recents", breakShown())
        device.pressBack()
    }

    // REQ-022: hardware keys are swallowed during a break (volume does not change)
    @Test fun volumeKeysDoNothingDuringBreak() {
        val audio = inst.targetContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val stream = AudioManager.STREAM_MUSIC
        val before = audio.getStreamVolume(stream)
        val key = if (before < audio.getStreamMaxVolume(stream)) KeyEvent.KEYCODE_VOLUME_UP else KeyEvent.KEYCODE_VOLUME_DOWN
        testBreak(10)
        repeat(3) { device.pressKeyCode(key) }
        Thread.sleep(500)
        assertEquals("volume during the break", before, audio.getStreamVolume(stream))
        device.pressBack()
    }

    // REQ-006: the fail-safe removes the screen at 35 s even if its end time is wrong
    @Test fun failsafeRemovesStuckBreak() {
        testBreak(3600, failsafeSeconds = 35)
        Thread.sleep(30_000)
        assertTrue("still shown at 30 s", breakShown())
        assertTrue("gone by 36 s", waitFor(6_500) { !breakShown() })
    }

    // REQ-001, REQ-003: in fast mode (60x) the scheduled break comes and goes by itself
    @Test fun scheduledBreakComesAndGoes() {
        startService("1")
        assertTrue("break within 25 s", waitFor(25_000) { breakShown() })
        assertTrue("gone again within 3 s", waitFor(3_000) { !breakShown() })
    }

    // REQ-021: the app screen offers no way to turn BlackBreak off or skip a break
    // REQ-026: the call switch is off by default and writes the setting
    @Test fun appScreenHasNoOffAndSwitchWorks() {
        inst.targetContext.getSharedPreferences(BreakService.PREFS, Context.MODE_PRIVATE).edit().clear().commit()
        val a = inst.startActivitySync(
            Intent(inst.targetContext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        inst.waitForIdleSync()
        Thread.sleep(1200)
        var labels = listOf<String>()
        var sw: Switch? = null
        onMain {
            val root = a.window.decorView
            labels = buttons(root).map { it.text.toString() }
            sw = switches(root).single()
        }
        assertFalse("off/quit/skip button: $labels", labels.any { Regex("(?i)quit|skip|stop|turn off|disable|exit").containsMatchIn(it) })
        assertFalse("call switch off by default", sw!!.isChecked)
        assertTrue("switch usable in work", sw!!.isEnabled)
        onMain { sw!!.performClick() }
        val prefs = inst.targetContext.getSharedPreferences(BreakService.PREFS, Context.MODE_PRIVATE)
        assertTrue("switch writes the setting", prefs.getBoolean(BreakService.PREF_CALL_EXEMPTION, false))
        onMain { sw!!.performClick() }
        assertFalse(prefs.getBoolean(BreakService.PREF_CALL_EXEMPTION, true))
        a.finish()
    }

    private fun buttons(v: View): List<Button> = when (v) {
        is Switch -> emptyList()
        is Button -> listOf(v)
        is ViewGroup -> (0 until v.childCount).flatMap { buttons(v.getChildAt(it)) }
        else -> emptyList()
    }

    private fun switches(v: View): List<Switch> = when (v) {
        is Switch -> listOf(v)
        is ViewGroup -> (0 until v.childCount).flatMap { switches(v.getChildAt(it)) }
        else -> emptyList()
    }

    private fun realSize(): android.graphics.Point = android.graphics.Point().also {
        @Suppress("DEPRECATION")
        (inst.targetContext.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).defaultDisplay.getRealSize(it)
    }

    // REQ-003: rotating during a break keeps the whole display covered
    @Test fun rotationDuringBreakStillCovers() {
        startTarget()
        testBreak(25)
        try {
            for (turn in listOf({ device.setOrientationLeft() }, { device.setOrientationNatural() })) {
                turn()
                Thread.sleep(1500)
                var w = 0
                var h = 0
                onMain { w = service().breakView.width; h = service().breakView.height }
                val real = realSize()
                assertTrue("still shown", breakShown())
                assertEquals("width after rotation", real.x, w)
                assertEquals("height after rotation", real.y, h)
            }
        } finally {
            device.setOrientationNatural()
            device.unfreezeRotation()
        }
    }

    private fun prefs() = inst.targetContext.getSharedPreferences(BreakService.PREFS, Context.MODE_PRIVATE)

    // Like a VoIP app: communication mode plus a voice stream (silence), which keeps the mode set.
    private fun withCallMode(block: () -> Unit) {
        val audio = inst.targetContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val rate = 16_000
        val track = android.media.AudioTrack.Builder()
            .setAudioAttributes(android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH).build())
            .setAudioFormat(android.media.AudioFormat.Builder().setSampleRate(rate)
                .setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO).build())
            .setTransferMode(android.media.AudioTrack.MODE_STATIC)
            .setBufferSizeInBytes(rate * 2).build()
        track.write(ShortArray(rate), 0, rate)
        track.setLoopPoints(0, rate, -1)
        audio.mode = AudioManager.MODE_IN_COMMUNICATION
        track.play()
        val modes = mutableListOf<Int>()
        val watcher = Thread {
            try { while (true) { modes += audio.mode; Thread.sleep(1000) } } catch (_: InterruptedException) {}
        }.also { it.start() }
        try {
            assertEquals("the phone is in a VoIP call mode", AudioManager.MODE_IN_COMMUNICATION, audio.mode)
            block()
        } catch (e: AssertionError) {
            throw AssertionError("${e.message}; audio modes seen each second: $modes", e)
        } finally {
            watcher.interrupt()
            track.stop()
            track.release()
            audio.mode = AudioManager.MODE_NORMAL
        }
    }

    // REQ-027, REQ-012: switch on, a VoIP call holds the break; it comes when the call ends
    @Test fun voipCallHoldsBreakWhenSwitchOn() {
        prefs().edit().putBoolean(BreakService.PREF_CALL_EXEMPTION, true).commit()
        withCallMode {
            startService("1")
            Thread.sleep(27_000) // past the 20 s work interval
            var phase: Phase? = null
            var held = false
            onMain { phase = service().scheduler.phase; held = service().held() }
            assertEquals("still work while the call goes on", Phase.WORK, phase)
            assertTrue("held", held)
            assertFalse("no break during the call", breakShown())
        }
        assertTrue("the break comes after the call", waitFor(5_000) { breakShown() || service().scheduler.phase == Phase.BREAK })
        prefs().edit().clear().commit()
    }

    // REQ-011: switch off, a VoIP call does not hold the break
    @Test fun voipCallIgnoredWhenSwitchOff() {
        prefs().edit().putBoolean(BreakService.PREF_CALL_EXEMPTION, false).commit()
        withCallMode {
            startService("1")
            assertTrue("the break comes during the call", waitFor(25_000) { breakShown() })
        }
    }

    // REQ-008, REQ-009, REQ-010: pause and cancel from the app screen; one pause a day, also after a restart
    @Test fun pauseAndCancelFromScreen() {
        prefs().edit().clear().commit()
        startService("0")
        val a = inst.startActivitySync(
            Intent(inst.targetContext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        inst.waitForIdleSync()
        Thread.sleep(1200)
        fun button(label: String): Button {
            var b: Button? = null
            onMain { b = buttons(a.window.decorView).first { it.text.toString() == label } }
            return b!!
        }
        fun status(): String {
            var t = ""
            onMain { t = allTexts(a.window.decorView)[1] }
            return t
        }
        assertTrue("pause enabled in work", button("Pause 30 min").isEnabled)
        assertFalse("cancel disabled in work", button("Cancel pause").isEnabled)
        button("Pause 30 min").let { b -> onMain { b.performClick() } }
        Thread.sleep(1200)
        var phase: Phase? = null
        onMain { phase = service().scheduler.phase }
        assertEquals(Phase.PAUSED, phase)
        assertTrue("status: ${status()}", status().startsWith("Paused until"))
        assertFalse("no second pause while paused", button("Pause 1 hour").isEnabled)
        assertTrue("cancel enabled while paused", button("Cancel pause").isEnabled)
        button("Cancel pause").let { b -> onMain { b.performClick() } }
        Thread.sleep(1200)
        onMain { phase = service().scheduler.phase }
        assertEquals(Phase.WORK, phase)
        assertTrue("status: ${status()}", status().startsWith("Next break at"))
        assertFalse("no second pause today", button("Pause 30 min").isEnabled)
        a.finish()
        startService("0")
        var can = true
        onMain { can = service().scheduler.canPause }
        assertFalse("still no second pause after the service restarts", can)
        prefs().edit().clear().commit()
    }
}
