// The words of the break screen, in English or Slovak.
package io.github.junkers4.blackbreak

/** A line is the plain part and an emphasised part, which is set in italic. */
data class Line(val plain: String, val accent: String = "")

object Copy {
    fun lines(slovak: Boolean): List<Line> = if (slovak) {
        listOf(Line("Odlož oči."), Line("Pozri von oknom, ", "čo najďalej."), Line("Potom sa natiahni."))
    } else {
        listOf(Line("Rest your eyes."), Line("Look out of the window, ", "as far as you can."), Line("Then stretch."))
    }

    fun seconds(slovak: Boolean, n: Long): String = when {
        !slovak -> if (n == 1L) "1 second" else "$n seconds"
        n == 1L -> "1 sekunda"
        n in 2..4 -> "$n sekundy"
        else -> "$n sekúnd"
    }
}
