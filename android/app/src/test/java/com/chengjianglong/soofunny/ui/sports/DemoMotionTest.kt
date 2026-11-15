package com.chengjianglong.soofunny.ui.sports

import org.junit.Assert.assertEquals
import org.junit.Test

class DemoMotionTest {
    private val eps = 1e-9

    @Test fun holdsBeforeFirstAndAfterLastKey() {
        val m = DemoMotion(listOf(DemoKey(0.2, 0.1, 0.1, 10.0), DemoKey(0.8, 0.9, 0.5, 90.0)))
        assertEquals(DemoPlace(0.1, 0.1, 10.0), m.place(0.0))
        assertEquals(DemoPlace(0.9, 0.5, 90.0), m.place(0.95))
    }

    @Test fun passesThroughEveryKey() {
        val keys = listOf(DemoKey(0.0, 0.0, 0.5), DemoKey(0.3, 0.4, 0.2), DemoKey(0.6, 0.7, 0.8), DemoKey(1.0, 1.0, 0.5))
        val m = DemoMotion(keys)
        for (key in keys.dropLast(1)) {
            val p = m.place(key.t)
            assertEquals(key.x, p.x, eps)
            assertEquals(key.y, p.y, eps)
        }
    }

    @Test fun straightLinesInterpolateLinearly() {
        val m = DemoMotion(listOf(DemoKey(0.0, 0.0, 0.0, 0.0), DemoKey(0.5, 1.0, 0.5, 100.0), DemoKey(1.0, 0.0, 1.0)), smooth = false)
        val p = m.place(0.25)
        assertEquals(0.5, p.x, eps)
        assertEquals(0.25, p.y, eps)
        assertEquals(50.0, p.turn, eps)
    }

    @Test fun catmullRomMatchesFormula() {
        // Evenly spaced collinear keys: Catmull-Rom reproduces the straight line in the middle segment.
        val m = DemoMotion(listOf(DemoKey(0.0, 0.0, 0.0), DemoKey(1.0 / 3, 0.25, 0.0), DemoKey(2.0 / 3, 0.5, 0.0), DemoKey(1.0, 0.75, 0.0)))
        assertEquals(0.375, m.place(0.5).x, eps)
        // On the first segment the missing neighbor is the first key itself: cr(0, 0, 0.25, 0.5) at u = 0.5.
        val u = 0.5
        val expected = 0.5 * (2 * 0.0 + (-0.0 + 0.25) * u + (2 * 0.0 - 5 * 0.0 + 4 * 0.25 - 0.5) * u * u + (-0.0 + 3 * 0.0 - 3 * 0.25 + 0.5) * u * u * u)
        assertEquals(expected, m.place(1.0 / 6).x, eps)
    }

    @Test fun fadesInAndOutOfItsWindow() {
        val m = DemoMotion(listOf(DemoKey(0.0, 0.5, 0.5)), visibleFrom = 0.4, visibleTo = 0.6)
        assertEquals(0.0, m.opacity(0.3), eps)
        assertEquals(0.5, m.opacity(0.42), eps)
        assertEquals(1.0, m.opacity(0.5), eps)
        assertEquals(0.25, m.opacity(0.59), eps)
        assertEquals(0.0, m.opacity(0.7), eps)
    }

    @Test fun moversFadeAtLoopEnds() {
        val mover = DemoMotion(listOf(DemoKey(0.0, 0.0, 0.5), DemoKey(1.0, 1.0, 0.5)))
        assertEquals(0.5, mover.opacity(0.02), eps)
        assertEquals(1.0, mover.opacity(0.5), eps)
        assertEquals(0.5, mover.opacity(0.98), eps)
        val looper = DemoMotion(listOf(DemoKey(0.0, 0.2, 0.5), DemoKey(0.5, 0.8, 0.5), DemoKey(1.0, 0.2, 0.5)))
        assertEquals(1.0, looper.opacity(0.0), eps)
    }

    @Test fun ovalAndLineKeys() {
        val oval = ovalKeys(cx = 0.5, cy = 0.5, rx = 0.2, ry = 0.1, from = 90.0, steps = 4)
        assertEquals(5, oval.size)
        assertEquals(0.5, oval[0].x, eps)
        assertEquals(0.6, oval[0].y, eps)
        assertEquals(1.0, oval.last().t, eps)
        val line = lineKeys(from = 0.0 to 0.5, to = 1.0 to 0.5, hops = 1, hop = 0.2, steps = 2)
        assertEquals(0.3, line[1].y, eps)
        assertEquals(0.5, line[1].x, eps)
    }
}
