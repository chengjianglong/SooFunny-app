package com.chengjianglong.soofunny.ui.sports

import android.graphics.Paint
import android.provider.Settings
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.squishClickable
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.min

// A tiny animation engine for the Sports tab: each sport has a looping demo made of a scene
// (pool, track, court, slope…) drawn with shapes, and actors (emoji, balls, arrows) that move
// along keyframed paths. Everything is drawn in one Canvas, so it stays smooth and needs no
// image files. Positions are fractions of the stage (0…1 across, 0…1 down). Ported from the iOS
// app's SportDemo.swift; the path and timing math lives in DemoMotion.kt.

/** What an actor looks like. */
sealed interface DemoGlyph {
    data class Emoji(val emoji: String) : DemoGlyph
    /** A plain ball (shuttlecock, golf ball, puck…): color and diameter as a fraction of the stage height. */
    data class Ball(val color: Color, val diameter: Double) : DemoGlyph
    /** A flying arrow, pointing the way it's going. */
    data object Arrow : DemoGlyph
    /** A short flash of light, like a laser shot, from the actor's position to ([toX], [toY]). */
    data class Beam(val color: Color, val toX: Double, val toY: Double) : DemoGlyph
}

/** Which way an emoji looks when drawn normally, so movers can be turned to face forward. */
enum class DemoFacing { LEFT, RIGHT }

class DemoActor(
    val glyph: DemoGlyph,
    val motion: DemoMotion,
    /** Height of the emoji as a fraction of the stage height. */
    val size: Double = 0.2,
    /** Turn the emoji to face the way it's moving. */
    val facing: DemoFacing? = null,
    /** Always mirror the emoji (for a player on the other side). */
    val mirrored: Boolean = false,
    /** Bobbing up and down: how far (fraction of the stage height) and how many times per loop. */
    val bob: Double = 0.0,
    val bobs: Double = 6.0,
)

class SportDemo(
    val scene: DemoScene,
    /** Seconds for one loop. */
    val duration: Double,
    val actors: List<DemoActor>,
)

/** The animated demo, with a play / pause button. It starts paused when animations are turned off. */
@Composable
fun SportDemoView(demo: SportDemo, label: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val reduceMotion = remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
    var playing by remember { mutableStateOf(!reduceMotion) }
    // Loop time shown now; while paused it stays where it stopped.
    var t by remember { mutableDoubleStateOf(if (reduceMotion) 0.18 else 0.0) }

    LaunchedEffect(playing) {
        if (!playing) return@LaunchedEffect
        val from = t
        var origin = -1L
        while (true) {
            withFrameNanos { now ->
                if (origin < 0) origin = now
                val loops = from + (now - origin) / 1e9 / demo.duration
                t = loops - kotlin.math.floor(loops)
            }
        }
    }

    Box(modifier.fillMaxWidth().aspectRatio(16f / 10f).clip(RoundedCornerShape(18.dp))) {
        val paint = remember { Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER } }
        Canvas(Modifier.fillMaxSize().semantics { contentDescription = label }) {
            demo.scene.draw(this)
            for (actor in demo.actors) drawActor(actor, t, paint)
        }
        Box(
            Modifier.align(Alignment.BottomEnd).padding(10.dp).size(44.dp).clip(CircleShape)
                .background(Color.White.copy(alpha = 0.7f))
                .squishClickable { playing = !playing }
                .semantics {
                    role = Role.Button
                    contentDescription = if (playing) "Pause the animation" else "Play the animation"
                },
            contentAlignment = Alignment.Center,
        ) {
            Text(if (playing) "⏸️" else "▶️", fontSize = 20.sp)
        }
    }
}

/** Draws one actor at loop time [t]. */
private fun DrawScope.drawActor(actor: DemoActor, t: Double, paint: Paint) {
    val alpha = actor.motion.opacity(t).toFloat()
    if (alpha <= 0f) return
    val w = size.width
    val h = size.height
    val place = actor.motion.place(t)
    val px = (place.x * w).toFloat()
    val py = ((place.y - bobLift(actor.bob, actor.bobs, t)) * h).toFloat()
    val turn = place.turn
    val pt = density

    // Which way it's heading, to face movers forward and point arrows.
    val ahead = actor.motion.place(min(t + 0.01, 0.999))
    val behind = actor.motion.place(max(t - 0.01, 0.0))
    val dx = (ahead.x - behind.x) * w
    val dy = (ahead.y - behind.y) * h

    when (val glyph = actor.glyph) {
        is DemoGlyph.Emoji -> {
            var flip = actor.mirrored
            if (actor.facing != null && abs(dx) > 0.5 * pt) flip = (actor.facing == DemoFacing.LEFT) == (dx > 0)
            withTransform({
                translate(px, py)
                if (flip) scale(-1f, 1f, pivot = Offset.Zero)
                rotate((if (flip) -turn else turn).toFloat(), pivot = Offset.Zero)
            }) {
                paint.textSize = (actor.size * h).toFloat()
                paint.alpha = (alpha * 255).toInt()
                val metrics = paint.fontMetrics
                drawContext.canvas.nativeCanvas.drawText(glyph.emoji, 0f, -(metrics.ascent + metrics.descent) / 2, paint)
            }
        }
        is DemoGlyph.Ball -> {
            val r = (glyph.diameter * h / 2).toFloat()
            drawCircle(glyph.color, r, Offset(px, py), alpha = alpha)
            drawCircle(Color.Black.copy(alpha = 0.35f), r, Offset(px, py), alpha = alpha, style = Stroke(1 * pt))
        }
        DemoGlyph.Arrow -> withTransform({
            translate(px, py)
            rotate(Math.toDegrees(atan2(dy, if (dx == 0.0) 1.0 else dx)).toFloat(), pivot = Offset.Zero)
        }) {
            val l = (0.16 * h).toFloat()
            drawLine(KidColors.Brown, Offset(-l, 0f), Offset.Zero, strokeWidth = 3 * pt, alpha = alpha)
            val head = Path().apply {
                moveTo(6 * pt, 0f); lineTo(-6 * pt, -5 * pt); lineTo(-6 * pt, 5 * pt); close()
            }
            drawPath(head, KidColors.Gray, alpha = alpha)
            drawLine(KidColors.Red, Offset(-l, 0f), Offset(-l - 7 * pt, -6 * pt), strokeWidth = 2 * pt, alpha = alpha)
            drawLine(KidColors.Red, Offset(-l, 0f), Offset(-l - 7 * pt, 6 * pt), strokeWidth = 2 * pt, alpha = alpha)
        }
        is DemoGlyph.Beam -> {
            val start = Offset(px, py)
            val end = Offset((glyph.toX * w).toFloat(), (glyph.toY * h).toFloat())
            drawLine(glyph.color.copy(alpha = 0.35f), start, end, strokeWidth = 8 * pt, alpha = alpha)
            drawLine(glyph.color, start, end, strokeWidth = 3 * pt, alpha = alpha)
        }
    }
}
