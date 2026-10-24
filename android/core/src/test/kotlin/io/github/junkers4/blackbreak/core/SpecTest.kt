package io.github.junkers4.blackbreak.core

import java.io.File
import kotlinx.serialization.json.*
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.DynamicTest.dynamicTest
import org.junit.jupiter.api.TestFactory
import org.junit.jupiter.api.Assertions.*

private fun load(file: String): List<JsonObject> =
    Json.parseToJsonElement(File(System.getProperty("blackbreak.spec"), file).readText()).jsonArray.map { it.jsonObject }

private fun dayKey(ms: Long) = Math.floorDiv(ms, 86_400_000L).toString()

private fun JsonObject.has(k: String) = containsKey(k)
private fun JsonObject.long(k: String, d: Long = 0) = (this[k] as? JsonPrimitive)?.takeIf { it !is JsonNull }?.long ?: d
private fun JsonObject.bool(k: String) = (this[k] as? JsonPrimitive)?.booleanOrNull ?: false
private fun JsonObject.str(k: String) = (this[k] as? JsonPrimitive)?.takeIf { it.isString }?.content
private fun JsonElement.nullableLong(): Long? = if (this is JsonNull) null else jsonPrimitive.long

private fun phaseName(p: Phase) = p.name.lowercase()

class ScenarioTest {
    @TestFactory
    fun scenarios(): List<DynamicTest> = load("scenarios.json").map { sc ->
        val name = sc.str("name")!!
        dynamicTest(name) {
            val startS = sc.long("start")
            val s = Scheduler(startS * 1000, 1.0, ::dayKey, sc.str("lastPauseDay"))
            val steps = sc["steps"]!!.jsonArray.map { it.jsonObject }
            val expects = sc["expect"]!!.jsonArray.map { it.jsonObject }
            val maxT = expects.maxOf { it.long("t") }
            var idle = 0L
            var inCall = false
            var inPhone = false
            for (t in startS..maxT) {
                val step = steps.firstOrNull { it.long("t") == t }
                if (step != null) {
                    idle = step.long("idle")
                    inCall = step.bool("inCall")
                    inPhone = step.bool("inPhoneCall")
                }
                var result: Boolean? = null
                val act = step?.str("do")
                if (act != null && act.startsWith("pause:")) result = s.pause(act.substring(6).toLong() * 1000, t * 1000)
                else if (act == "cancelPause") result = s.cancelPause(t * 1000)
                s.update(t * 1000, idle * 1000, inCall, inPhone)
                for (e in expects.filter { it.long("t") == t }) {
                    val where = "$name @${t}s"
                    assertEquals(e.str("phase"), phaseName(s.phase), "$where phase")
                    if (e.has("canPause")) assertEquals(e.bool("canPause"), s.canPause, "$where canPause")
                    if (e.has("pauseResult")) assertEquals(e.bool("pauseResult"), result, "$where pauseResult")
                }
            }
        }
    }
}

class TraceTest {
    @TestFactory
    fun traces(): List<DynamicTest> = load("traces.json").map { tr ->
        val name = tr.str("name")!!
        dynamicTest(name) {
            val start = tr.long("start")
            val s = Scheduler(start, (tr["scale"] as? JsonPrimitive)?.double ?: 1.0, ::dayKey, tr.str("lastPauseDay"))
            var last = start
            var result: Boolean? = null
            fun update(now: Long, idle: Long = 0, call: Boolean = false, phone: Boolean = false) {
                s.update(now, idle, call, phone)
                last = now
            }
            tr["events"]!!.jsonArray.forEachIndexed { i, el ->
                val ev = el.jsonObject
                val w = "$name #$i"
                assertTrue(listOf("now", "walk", "do").count { ev.has(it) } <= 1, "$w: more than one action")
                if (ev.has("now")) {
                    update(ev.long("now"), ev.long("idle"), ev.bool("inCall"), ev.bool("inPhoneCall"))
                } else if (ev.has("walk")) {
                    val every = ev.long("every", 60_000)
                    val to = ev.long("walk")
                    var n = last + every
                    while (n < to) { update(n); n += every }
                    update(to)
                } else if (ev.has("do")) {
                    assertTrue(ev.has("at"), "$w: do needs at")
                    val d = ev.str("do")!!
                    val at = ev.long("at")
                    result = when {
                        d.startsWith("pause:") -> s.pause(d.substring(6).toLong(), at)
                        d == "cancelPause" -> s.cancelPause(at)
                        else -> fail("$w: unknown do $d")
                    }
                }
                val ex = ev["expect"]?.jsonObject ?: return@forEachIndexed
                for ((k, v) in ex) {
                    val m = "$w $k"
                    when (k) {
                        "phase" -> assertEquals(v.jsonPrimitive.content, phaseName(s.phase), m)
                        "canPause" -> assertEquals(v.jsonPrimitive.boolean, s.canPause, m)
                        "result" -> {
                            assertNotNull(result, "$w: no do yet")
                            assertEquals(v.jsonPrimitive.boolean, result, m)
                        }
                        "lastPauseDay" -> assertEquals(if (v is JsonNull) null else v.jsonPrimitive.content, s.lastPauseDay, m)
                        "nextBreakAt" -> assertEquals(v.nullableLong(), s.nextBreakAt, m)
                        "breakEndsAt" -> assertEquals(v.nullableLong(), s.breakEndsAt, m)
                        "warningEndsAt" -> assertEquals(v.nullableLong(), s.warningEndsAt, m)
                        "pauseEndsAt" -> assertEquals(v.nullableLong(), s.pauseEndsAt, m)
                        else -> fail("$m: unknown expect key")
                    }
                }
            }
        }
    }
}
