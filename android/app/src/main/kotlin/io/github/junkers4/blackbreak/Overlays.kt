// The two views the service puts above everything: the break screen and the warning notice.
package io.github.junkers4.blackbreak

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

private val LINES = listOf(
    "Look at something far away — at least 6 m (20 ft).",
    "Stretch your arms and your back.",
    "Sit up straight, shoulders back.",
    "Slowly turn and tilt your head to stretch your neck.",
)

private fun overlayParams(width: Int, height: Int, flags: Int) =
    WindowManager.LayoutParams(width, height, WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY, flags, PixelFormat.TRANSLUCENT)

class BreakOverlay(private val context: Context, private val wm: WindowManager) {
    private val countdown = TextView(context).apply {
        setTextColor(Color.parseColor("#5A5A5A"))
        textSize = 15f
        typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
        gravity = Gravity.CENTER
        setPadding(0, dp(18), 0, 0)
    }
    private val root = FrameLayout(context).apply {
        setBackgroundColor(Color.BLACK)
        isClickable = true // consumes every touch
        isFocusable = false
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(28), 0, dp(28), 0)
            for (line in LINES) addView(TextView(context).apply {
                text = line
                setTextColor(Color.parseColor("#9A9A9A"))
                textSize = 19f
                typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
                gravity = Gravity.CENTER
                setPadding(0, dp(7), 0, dp(7))
            })
            addView(countdown)
        }
        addView(column, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
    }
    var shown = false
        private set

    private fun dp(v: Int) = (v * context.resources.displayMetrics.density).toInt()

    fun show(secondsLeft: Long) {
        update(secondsLeft)
        if (shown) return
        val params = overlayParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
        ).apply {
            format = PixelFormat.OPAQUE
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            fitInsetsTypes = 0
        }
        wm.addView(root, params)
        shown = true
    }

    fun update(secondsLeft: Long) {
        countdown.text = secondsLeft.coerceAtLeast(0).toString()
    }

    fun hide() {
        if (!shown) return
        shown = false
        runCatching { wm.removeViewImmediate(root) }
    }
}

class NoticeOverlay(private val context: Context, private val wm: WindowManager) {
    private val view = TextView(context).apply {
        text = "Break in 10 s"
        setTextColor(Color.parseColor("#E6E6E6"))
        textSize = 15f
        gravity = Gravity.CENTER
        val pad = (context.resources.displayMetrics.density * 12).toInt()
        setPadding(pad * 2, pad, pad * 2, pad)
        background = GradientDrawable().apply {
            setColor(Color.parseColor("#EB2B2B2B"))
            cornerRadius = 1000f
        }
    }
    private var shown = false

    fun show() {
        if (shown) return
        val params = overlayParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = (context.resources.displayMetrics.density * 56).toInt()
        }
        wm.addView(view, params)
        shown = true
    }

    fun hide() {
        if (!shown) return
        shown = false
        runCatching { wm.removeViewImmediate(view) }
    }
}
