// The one screen: status, pause, the call switch and the setup step.
package io.github.junkers4.blackbreak

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
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
        actionBar?.hide() // the screen draws its own title
        val d = resources.displayMetrics.density
        fun dp(v: Int) = (v * d).toInt()
        val night = resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val page = Color.parseColor(if (night) "#0D0C0B" else "#FAF7F2")
        val surface = Color.parseColor(if (night) "#1F1D1A" else "#EFE9DF")
        val ink = Color.parseColor(if (night) "#ECE8E1" else "#1D1B18")
        val muted = Color.parseColor(if (night) "#9A9488" else "#6F695E")
        val serif = Typeface.create(Typeface.SERIF, 400, false)

        fun card(): LinearLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(18), dp(20), dp(18))
            background = GradientDrawable().apply {
                setColor(surface)
                cornerRadius = dp(28).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(12) }
        }
        fun pill(label: String, onClick: () -> Unit) = Button(this).apply {
            text = label
            isAllCaps = false
            setTextColor(ink)
            stateListAnimator = null
            background = GradientDrawable().apply {
                setColor(if (night) Color.parseColor("#2B2824") else Color.parseColor("#E2DACB"))
                cornerRadius = dp(24).toFloat()
            }
            setOnClickListener { onClick() }
        }

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(48), dp(16), dp(24))
        }
        column.addView(TextView(this).apply {
            text = "BlackBreak"
            textSize = 34f
            typeface = serif
            setTextColor(ink)
            setPadding(dp(8), 0, 0, dp(20))
        })

        val statusCard = card()
        status = TextView(this).apply {
            textSize = 24f
            typeface = serif
            setTextColor(ink)
        }
        statusCard.addView(status)
        setup = pill("Turn on BlackBreak in Accessibility settings") {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
        statusCard.addView(setup, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(14) })
        column.addView(statusCard)

        val pauseCard = card()
        pauseCard.addView(TextView(this).apply {
            text = "One pause per day"
            textSize = 13f
            setTextColor(muted)
            setPadding(0, 0, 0, dp(8))
        })
        pauses = listOf("Pause 30 min" to 30, "Pause 1 hour" to 60, "Pause 2 hours" to 120, "Pause 3 hours" to 180).map { (label, min) ->
            min to pill(label) { BreakService.instance?.pause(min); refresh() }
        }
        pauses.forEach { pauseCard.addView(it.second, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(6) }) }
        cancel = pill("Cancel pause") { BreakService.instance?.cancelPause(); refresh() }
        pauseCard.addView(cancel, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(6) })
        column.addView(pauseCard)

        val callCard = card()
        callSwitch = Switch(this).apply {
            text = "Wait with the break while I'm in a call"
            setTextColor(ink)
            setOnCheckedChangeListener { _, on ->
                if (!updatingSwitch) getSharedPreferences(BreakService.PREFS, Context.MODE_PRIVATE)
                    .edit().putBoolean(BreakService.PREF_CALL_EXEMPTION, on).apply()
            }
        }
        callCard.addView(callSwitch)
        callCard.addView(TextView(this).apply {
            text = "A break waits at most 3 hours. Phone calls always wait."
            textSize = 13f
            setTextColor(muted)
            setPadding(0, dp(6), 0, 0)
        })
        column.addView(callCard)
        setContentView(ScrollView(this).apply {
            setBackgroundColor(page)
            addView(column)
        })
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
