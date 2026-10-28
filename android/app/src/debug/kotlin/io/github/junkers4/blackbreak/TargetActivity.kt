package io.github.junkers4.blackbreak

import android.app.Activity
import android.os.Bundle
import android.widget.Button

/** Debug builds only, for the instrumented tests: a full-screen button that counts the taps that reach it. */
class TargetActivity : Activity() {
    @Volatile var taps = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(Button(this).apply {
            text = "target"
            setOnClickListener { taps++ }
        })
    }
}
