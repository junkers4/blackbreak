package io.github.junkers4.blackbreak

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

// REQ-030. The seconds are the core's (core/test/run_core.py and the device tests).
class CopyTest {
    @Test fun `three lines in both languages, the middle one emphasised`() {
        for (sk in listOf(false, true)) {
            val l = Copy.lines(sk)
            assertEquals(3, l.size)
            assertTrue(l[1].accent.isNotEmpty())
        }
    }
}
