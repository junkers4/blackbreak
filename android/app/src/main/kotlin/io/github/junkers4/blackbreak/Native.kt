// The assembler core (core/aarch64/*.S), through JNI. Every value is a Long.
package io.github.junkers4.blackbreak

import java.nio.ByteBuffer

object Native {
    init {
        System.loadLibrary("blackbreak")
    }

    const val NONE = Long.MIN_VALUE

    external fun stateSize(): Long
    external fun init(buf: ByteBuffer, now: Long, scaleBits: Long, lastPauseDay: Long): Long
    external fun setTz(buf: ByteBuffer, offsetMs: Long): Long
    external fun update(buf: ByteBuffer, now: Long, idleMs: Long, flags: Long): Long
    external fun pause(buf: ByteBuffer, durationMs: Long, now: Long): Long
    external fun cancel(buf: ByteBuffer, now: Long): Long
    external fun get(buf: ByteBuffer, which: Long): Long
    external fun menu(buf: ByteBuffer): Long
    external fun tick(buf: ByteBuffer, now: Long, idleMs: Long, audioMode: Long, exemption: Long): Long
    external fun screenOn(buf: ByteBuffer, now: Long, offMs: Long): Long
    external fun held(buf: ByteBuffer, now: Long): Long
    external fun seconds(n: Long, slovak: Long): String
}
