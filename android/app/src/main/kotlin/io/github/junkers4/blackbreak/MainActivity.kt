// The one screen: status, pause, the call switch and the setup step.
package io.github.junkers4.blackbreak

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import io.github.junkers4.blackbreak.core.Phase
import java.text.DateFormat
import java.util.Date

class MainActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var status: TextView
    private lateinit var setup: Button
    private lateinit var pauses: List<Pair<Int, Button>>
    private lateinit var cancel: Button
    private lateinit var callSwitch: Switch
    private var updatingSwitch = false

    private val refresh = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val d = resources.displayMetrics.density
        fun dp(v: Int) = (v * d).toInt()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(32), dp(24), dp(24))
        }
        status = TextView(this).apply {
            textSize = 24f
            typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
            setPadding(0, 0, 0, dp(20))
        }
        column.addView(status)
        setup = Button(this).apply {
            text = "Turn on BlackBreak in Accessibility settings"
            setOnClickListener { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
        }
        column.addView(setup)
        pauses = listOf("Pause 30 min" to 30, "Pause 1 hour" to 60, "Pause 2 hours" to 120, "Pause 3 hours" to 180).map { (label, min) ->
            min to Button(this).apply {
                text = label
                setOnClickListener { BreakService.instance?.pause(min); refresh() }
            }
        }
        pauses.forEach { column.addView(it.second) }
        cancel = Button(this).apply {
            text = "Cancel pause"
            setOnClickListener { BreakService.instance?.cancelPause(); refresh() }
        }
        column.addView(cancel)
        callSwitch = Switch(this).apply {
            text = "Wait with the break while I'm in a call"
            setPadding(0, dp(24), 0, 0)
            setOnCheckedChangeListener { _, on ->
                if (!updatingSwitch) getSharedPreferences(BreakService.PREFS, Context.MODE_PRIVATE)
                    .edit().putBoolean(BreakService.PREF_CALL_EXEMPTION, on).apply()
            }
        }
        column.addView(callSwitch)
        column.addView(TextView(this).apply {
            text = "A break waits at most 3 hours. Phone calls always wait."
            textSize = 13f
            setPadding(0, dp(4), 0, 0)
        })
        setContentView(ScrollView(this).apply { addView(column) })
    }

    override fun onResume() {
        super.onResume()
        handler.post(refresh)
    }

    override fun onPause() {
        handler.removeCallbacks(refresh)
        super.onPause()
    }

    private fun serviceEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val me = ComponentName(this, BreakService::class.java).flattenToString()
        return flat.split(':').any { it.equals(me, ignoreCase = true) }
    }

    private fun refresh() {
        val svc = BreakService.instance
        val clock = DateFormat.getTimeInstance(DateFormat.SHORT)
        setup.visibility = if (serviceEnabled()) View.GONE else View.VISIBLE
        if (svc == null) {
            status.text = "BlackBreak is off"
            pauses.forEach { it.second.isEnabled = false }
            cancel.isEnabled = false
            callSwitch.isEnabled = false
            return
        }
        val s = svc.scheduler
        status.text = when (s.phase) {
            Phase.PAUSED -> "Paused until ${clock.format(Date(s.pauseEndsAt!!))}"
            Phase.BREAK -> "Break in progress"
            else -> "Next break at ${clock.format(Date(s.nextBreakAt!!))}"
        }
        pauses.forEach { it.second.isEnabled = s.canPause }
        cancel.isEnabled = s.phase == Phase.PAUSED
        callSwitch.isEnabled = s.phase == Phase.WORK && !svc.held()
        val on = getSharedPreferences(BreakService.PREFS, Context.MODE_PRIVATE).getBoolean(BreakService.PREF_CALL_EXEMPTION, false)
        if (callSwitch.isChecked != on) {
            updatingSwitch = true
            callSwitch.isChecked = on
            updatingSwitch = false
        }
    }
}
