package com.chengjianglong.soofunny.ui.sports

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

// The timing and path math behind the sport demos, kept free of Compose so it can be unit tested.
// Positions are fractions of the stage (0…1 across, 0…1 down); times are fractions of one loop.

/** One moment on an actor's path: when (0…1 through the loop), where, and how far it's turned (degrees). */
data class DemoKey(val t: Double, val x: Double, val y: Double, val turn: Double = 0.0)

/** Where an actor is at some moment, and how far it's turned (degrees). */
data class DemoPlace(val x: Double, val y: Double, val turn: Double)

/**
 * How an actor moves through a loop: its keyframed path (with smooth Catmull-Rom curves or straight
 * lines) and the part of the loop it's shown in (fading in and out at the ends).
 */
class DemoMotion(
    val keys: List<DemoKey>,
    val smooth: Boolean = true,
    val visibleFrom: Double = 0.0,
    val visibleTo: Double = 1.0,
) {
    /** Where the actor is at loop time [t]. */
    fun place(t: Double): DemoPlace {
        val first = keys.firstOrNull() ?: return DemoPlace(0.0, 0.0, 0.0)
        if (keys.size == 1 || t <= first.t) return DemoPlace(first.x, first.y, first.turn)
        val last = keys.last()
        if (t >= last.t) return DemoPlace(last.x, last.y, last.turn)
        val i = max(keys.indexOfLast { it.t <= t }, 0)
        val a = keys[i]
        val b = keys[i + 1]
        val u = if (b.t > a.t) (t - a.t) / (b.t - a.t) else 1.0
        val turn = a.turn + (b.turn - a.turn) * u
        if (!smooth) return DemoPlace(a.x + (b.x - a.x) * u, a.y + (b.y - a.y) * u, turn)
        // Catmull-Rom through the neighbors, so paths bend gently through every point.
        val p0 = keys[max(i - 1, 0)]
        val p3 = keys[min(i + 2, keys.size - 1)]
        fun cr(v0: Double, v1: Double, v2: Double, v3: Double): Double {
            val u2 = u * u
            val u3 = u2 * u
            return 0.5 * (2 * v1 + (-v0 + v2) * u + (2 * v0 - 5 * v1 + 4 * v2 - v3) * u2 + (-v0 + 3 * v1 - 3 * v2 + v3) * u3)
        }
        return DemoPlace(cr(p0.x, a.x, b.x, p3.x), cr(p0.y, a.y, b.y, p3.y), turn)
    }

    /** How visible the actor is at loop time [t] (fades in and out at the ends of its window). */
    fun opacity(t: Double): Double {
        if (t < visibleFrom || t > visibleTo) return 0.0
        val fade = 0.04
        var value = 1.0
        if (visibleFrom > 0) value = min(value, (t - visibleFrom) / fade)
        if (visibleTo < 1) value = min(value, (visibleTo - t) / fade)
        // Movers that jump back to the start fade at the loop's ends instead of popping.
        val a = keys.firstOrNull()
        val b = keys.lastOrNull()
        if (a != null && b != null && hypot(a.x - b.x, a.y - b.y) > 0.05) {
            if (visibleFrom == 0.0) value = min(value, t / fade)
            if (visibleTo == 1.0) value = min(value, (1 - t) / fade)
        }
        return value.coerceIn(0.0, 1.0)
    }
}

/** How far an actor bobs up (fraction of the stage height) at loop time [t]. */
fun bobLift(bob: Double, bobs: Double, t: Double): Double = if (bob > 0) bob * abs(sin(t * PI * bobs)) else 0.0

/** Keys around an oval: center, radii, start angle (degrees, 0 = right, 90 = down) and turns. */
fun ovalKeys(
    cx: Double, cy: Double, rx: Double, ry: Double, from: Double = 0.0, turns: Double = 1.0,
    steps: Int = 16, t0: Double = 0.0, t1: Double = 1.0, lean: Double = 0.0,
): List<DemoKey> = (0..steps).map { i ->
    val f = i.toDouble() / steps
    val a = (from + 360 * turns * f) * PI / 180
    DemoKey(t0 + (t1 - t0) * f, cx + rx * cos(a), cy + ry * sin(a), lean)
}

/** Keys along a straight line, with an optional series of hops ([hops] jumps of height [hop]). */
fun lineKeys(
    from: Pair<Double, Double>, to: Pair<Double, Double>, t0: Double = 0.0, t1: Double = 1.0,
    hops: Int = 0, hop: Double = 0.0, steps: Int = 12,
): List<DemoKey> = (0..steps).map { i ->
    val f = i.toDouble() / steps
    val lift = if (hops > 0) hop * abs(sin(f * PI * hops)) else 0.0
    DemoKey(t0 + (t1 - t0) * f, from.first + (to.first - from.first) * f, from.second + (to.second - from.second) * f - lift)
}
