// The two views the service puts above everything: the break screen and the warning notice.
package io.github.junkers4.blackbreak

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

private fun overlayParams(width: Int, height: Int, flags: Int) =
    WindowManager.LayoutParams(width, height, WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY, flags, PixelFormat.TRANSLUCENT)

class BreakOverlay(private val context: Context, private val wm: WindowManager) {
    private val slovak = java.util.Locale.getDefault().language == "sk"
    private val cream = Color.parseColor("#ECE8E1")
    private val accent = Color.parseColor("#C9B99A")
    private val serif = Typeface.create("serif", Typeface.NORMAL)

    private fun dp(v: Int) = (v * context.resources.displayMetrics.density).toInt()

    private val countdown = TextView(context).apply {
        setTextColor(Color.parseColor("#7B756B"))
        textSize = 14f
    }
    private val root = FrameLayout(context).apply {
        setBackgroundColor(Color.parseColor("#0D0C0B"))
        isClickable = true // consumes every touch
        isFocusable = false
        val height = context.resources.displayMetrics.heightPixels
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            for (line in Copy.lines(slovak)) addView(TextView(context).apply {
                typeface = serif
                textSize = 27f
                setTextColor(cream)
                setLineSpacing(0f, 1.1f)
                text = SpannableStringBuilder(line.plain).apply {
                    if (line.accent.isNotEmpty()) {
                        val start = length
                        append(line.accent)
                        setSpan(StyleSpan(Typeface.ITALIC), start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        setSpan(ForegroundColorSpan(accent), start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    }
                }
            })
        }
        addView(column, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = height * 22 / 100
            marginStart = dp(26)
            marginEnd = dp(26)
        })
        addView(countdown, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.BOTTOM or Gravity.START
            marginStart = dp(26)
            bottomMargin = height * 9 / 100
        })
    }
    var shown = false
        private set

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
        countdown.text = Copy.seconds(slovak, secondsLeft.coerceAtLeast(0))
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
        setTextColor(Color.parseColor("#ECE8E1"))
        textSize = 15f
        gravity = Gravity.CENTER
        val pad = (context.resources.displayMetrics.density * 12).toInt()
        setPadding(pad * 2, pad, pad * 2, pad)
        background = GradientDrawable().apply {
            setColor(Color.parseColor("#EB1F1D1A"))
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
