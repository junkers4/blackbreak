package io.github.junkers4.blackbreak

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class CopyTest {
    @Test fun `english seconds`() {
        assertEquals("1 second", Copy.seconds(false, 1))
        assertEquals("30 seconds", Copy.seconds(false, 30))
    }

    @Test fun `slovak seconds`() {
        assertEquals("1 sekunda", Copy.seconds(true, 1))
        assertEquals("3 sekundy", Copy.seconds(true, 3))
        assertEquals("30 sekúnd", Copy.seconds(true, 30))
    }

    @Test fun `three lines in both languages`() {
        assertEquals(3, Copy.lines(false).size)
        assertEquals(3, Copy.lines(true).size)
    }
}
