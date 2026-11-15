package com.chengjianglong.soofunny.ui.sports

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import com.chengjianglong.soofunny.ui.KidColors

private fun rgb(r: Double, g: Double, b: Double) = Color(r.toFloat(), g.toFloat(), b.toFloat())
private fun white(v: Double) = Color(v.toFloat(), v.toFloat(), v.toFloat())
private fun Color.opacity(a: Double) = copy(alpha = alpha * a.toFloat())

/** The backgrounds the sport demos play on, drawn with simple shapes. Ported from the iOS app's DemoScenes.swift. */
sealed interface DemoScene {
    data class Pool(val lanes: Boolean, val goal: Boolean = false) : DemoScene
    data object DivingPool : DemoScene
    data class Track(val hurdles: List<Double> = emptyList()) : DemoScene
    data class Field(val color: Color, val goals: Boolean = true) : DemoScene
    data class Court(val color: Color, val floor: Color, val netHeight: Double) : DemoScene
    data object Basketball : DemoScene
    data object TableTennis : DemoScene
    data object Ring : DemoScene
    data class Mat(val color: Color, val edge: Color, val round: Boolean = false) : DemoScene
    data object Stage : DemoScene
    data class Sea(val wave: Boolean = false, val buoys: Boolean = false) : DemoScene
    data object River : DemoScene
    data class Range(val rings: Boolean = true) : DemoScene
    data object Road : DemoScene
    data class Equestrian(val fences: List<Double>) : DemoScene
    data object Piste : DemoScene
    data object Golf : DemoScene
    data object Beam : DemoScene
    data object Skatepark : DemoScene
    data object ClimbingWall : DemoScene
    data object Rugby : DemoScene
    data object Platform : DemoScene
    data object Triathlon : DemoScene
    data object Pentathlon : DemoScene
    data class Slope(val gates: Boolean) : DemoScene
    data object SnowHills : DemoScene
    data object IceChute : DemoScene
    data class Rink(val hockey: Boolean) : DemoScene
    data object Curling : DemoScene
    data object SkiJump : DemoScene
    data object Halfpipe : DemoScene
    data object Kicker : DemoScene
    data object Mountain : DemoScene
    data class Oval(val small: Boolean) : DemoScene
    data object Biathlon : DemoScene

    fun draw(scope: DrawScope) = ScenePainter(scope).paint(this)
}

/** Draws a scene in fractions of the stage, with line widths in points (dp) as on iOS. */
private class ScenePainter(val s: DrawScope) {
    val w = s.size.width.toDouble()
    val h = s.size.height.toDouble()
    val pt = s.density

    fun r(x: Double, y: Double, rw: Double, rh: Double) =
        Rect((x * w).toFloat(), (y * h).toFloat(), ((x + rw) * w).toFloat(), ((y + rh) * h).toFloat())
    fun p(x: Double, y: Double) = Offset((x * w).toFloat(), (y * h).toFloat())
    fun fill(rect: Rect, color: Color) = s.drawRect(color, rect.topLeft, rect.size)
    fun strokeRect(rect: Rect, color: Color, width: Double) = s.drawRect(color, rect.topLeft, rect.size, style = Stroke((width * pt).toFloat()))
    fun line(a: Offset, b: Offset, color: Color, width: Double = 2.0, dash: FloatArray? = null) = s.drawLine(
        color, a, b, strokeWidth = (width * pt).toFloat(), cap = StrokeCap.Round,
        pathEffect = dash?.let { d -> PathEffect.dashPathEffect(FloatArray(d.size) { d[it] * pt }) },
    )
    fun shape(points: List<Pair<Double, Double>>, color: Color) {
        val path = Path()
        points.forEachIndexed { i, (x, y) -> val q = p(x, y); if (i == 0) path.moveTo(q.x, q.y) else path.lineTo(q.x, q.y) }
        path.close()
        s.drawPath(path, color)
    }
    fun oval(rect: Rect, color: Color, stroke: Double = 0.0) =
        if (stroke > 0) s.drawOval(color, rect.topLeft, rect.size, style = Stroke((stroke * pt).toFloat()))
        else s.drawOval(color, rect.topLeft, rect.size)
    /** A circle-ish oval of radius [radius] (fraction of the stage height) around (x, y). */
    fun circleRect(x: Double, y: Double, radius: Double) =
        Rect((x * w - radius * h).toFloat(), (y * h - radius * h).toFloat(), (x * w + radius * h).toFloat(), (y * h + radius * h).toFloat())
    fun strokePath(path: Path, color: Color, width: Float) = s.drawPath(path, color, style = Stroke(width))
    fun sky(to: Double = 1.0) {
        val rect = r(0.0, 0.0, 1.0, to)
        s.drawRect(Brush.linearGradient(listOf(rgb(0.55, 0.8, 1.0), rgb(0.85, 0.94, 1.0)), p(0.0, 0.0), p(0.0, to)), rect.topLeft, rect.size)
    }
    fun water(from: Double) {
        val rect = r(0.0, from, 1.0, 1 - from)
        s.drawRect(Brush.linearGradient(listOf(rgb(0.3, 0.7, 0.95), rgb(0.1, 0.45, 0.8)), p(0.0, from), p(0.0, 1.0)), rect.topLeft, rect.size)
    }
    fun waves(ys: List<Double>) {
        for (y in ys) {
            val path = Path()
            val start = p(0.0, y)
            path.moveTo(start.x, start.y)
            for (i in 0..20) { val q = p(i / 20.0, y + if (i % 2 == 0) 0.0 else 0.015); path.lineTo(q.x, q.y) }
            strokePath(path, Color.White.opacity(0.45), 1.5f * pt)
        }
    }
    fun snow(points: List<Pair<Double, Double>>) = shape(points + listOf(1.0 to 1.0, 0.0 to 1.0), Color.White)
    fun tree(x: Double, y: Double, size: Double = 0.1) {
        shape(listOf(x to y - size, x - size * 0.45 to y, x + size * 0.45 to y), rgb(0.1, 0.45, 0.25))
        fill(r(x - 0.008, y, 0.016, size * 0.25), KidColors.Brown)
    }
    fun goal(x: Double, y: Double, gw: Double, gh: Double) {
        val rect = r(x, y, gw, gh)
        val net = Path()
        for (i in 1 until 5) { val yy = rect.top + rect.height * i / 5; net.moveTo(rect.left, yy); net.lineTo(rect.right, yy) }
        for (i in 1 until 3) { val xx = rect.left + rect.width * i / 3; net.moveTo(xx, rect.top); net.lineTo(xx, rect.bottom) }
        strokePath(net, Color.White.opacity(0.6), 1 * pt)
        strokeRect(rect, Color.White, 3.0)
    }
    fun target(x: Double, y: Double, radius: Double) {
        listOf(Color.White, Color.Black, KidColors.Blue, KidColors.Red, KidColors.Yellow).forEachIndexed { i, color ->
            oval(circleRect(x, y, radius * (1 - i * 0.18)), color)
        }
    }
    fun flag(x: Double, y: Double, color: Color) {
        line(p(x, y), p(x, y - 0.14), KidColors.Gray, 2.0)
        shape(listOf(x to y - 0.14, x + 0.05 to y - 0.115, x to y - 0.09), color)
    }
    fun Path.to(x: Double, y: Double) { val q = p(x, y); lineTo(q.x, q.y) }
    fun Path.from(x: Double, y: Double) { val q = p(x, y); moveTo(q.x, q.y) }
    fun Path.quad(x: Double, y: Double, cx: Double, cy: Double) { val c = p(cx, cy); val q = p(x, y); quadraticTo(c.x, c.y, q.x, q.y) }
    fun Path.curve(x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double) {
        val a = p(c1x, c1y); val b = p(c2x, c2y); val q = p(x, y); cubicTo(a.x, a.y, b.x, b.y, q.x, q.y)
    }

    val grass = rgb(0.35, 0.7, 0.3)
    val ice = rgb(0.88, 0.95, 1.0)
    val dash86 = floatArrayOf(8f, 6f)

    fun paint(scene: DemoScene) {
        when (scene) {
            is DemoScene.Pool -> {
                water(0.0)
                fill(r(0.0, 0.0, 0.03, 1.0), white(0.9)); fill(r(0.97, 0.0, 0.03, 1.0), white(0.9))
                if (scene.lanes) {
                    for (y in listOf(0.27, 0.5, 0.73)) line(p(0.03, y), p(0.97, y), KidColors.Red, 3.0, dash = dash86)
                } else {
                    waves(listOf(0.2, 0.45, 0.7, 0.9))
                }
                if (scene.goal) goal(0.88, 0.3, 0.09, 0.3)
            }
            DemoScene.DivingPool -> {
                sky(0.6)
                fill(r(0.0, 0.6, 1.0, 0.4), white(0.85))
                water(0.62)
                fill(r(0.04, 0.22, 0.12, 0.38), white(0.6))
                fill(r(0.04, 0.2, 0.26, 0.03), white(0.45))
                waves(listOf(0.75, 0.88))
            }
            is DemoScene.Track -> {
                fill(r(0.0, 0.0, 1.0, 1.0), grass)
                fill(r(0.0, 0.3, 1.0, 0.7), rgb(0.82, 0.35, 0.28))
                for (y in listOf(0.3, 0.55, 0.8, 0.999)) line(p(0.0, y), p(1.0, y), Color.White, 2.0)
                for (i in 0 until 8) fill(r(0.9, 0.3 + i * 0.0875, 0.02, 0.0875), if (i % 2 == 0) Color.White else Color.Black)
                for (x in scene.hurdles) {
                    line(p(x, 0.62), p(x, 0.78), Color.White, 3.0)
                    fill(r(x - 0.01, 0.6, 0.02, 0.03), Color.Black)
                }
            }
            is DemoScene.Field -> {
                fill(r(0.0, 0.0, 1.0, 1.0), scene.color)
                for (i in 0 until 10 step 2) fill(r(i / 10.0, 0.0, 0.1, 1.0), Color.White.opacity(0.06))
                line(p(0.5, 0.05), p(0.5, 0.95), Color.White.opacity(0.8))
                oval(r(0.42, 0.37, 0.16, 0.26), Color.White.opacity(0.8), stroke = 2.0)
                strokeRect(r(0.02, 0.05, 0.96, 0.9), Color.White.opacity(0.8), 2.0)
                if (scene.goals) { goal(0.94, 0.36, 0.05, 0.28); goal(0.01, 0.36, 0.05, 0.28) }
            }
            is DemoScene.Court -> {
                val nh = scene.netHeight
                fill(r(0.0, 0.0, 1.0, 1.0), scene.floor)
                fill(r(0.05, 0.55, 0.9, 0.35), scene.color)
                strokeRect(r(0.05, 0.55, 0.9, 0.35), Color.White, 2.0)
                line(p(0.5, 0.92), p(0.5, 0.9 - nh), white(0.3), 4.0)
                val net = Path()
                for (i in 0 until 6) { val y = 0.9 - nh + i * nh / 10; net.from(0.49, y); net.to(0.51, y) }
                strokePath(net, Color.White, 1 * pt)
                line(p(0.5, 0.9 - nh), p(0.5, 0.9 - nh / 2), Color.White, 3.0)
            }
            DemoScene.Basketball -> {
                fill(r(0.0, 0.0, 1.0, 1.0), rgb(0.86, 0.68, 0.45))
                for (i in 0 until 10) line(p(i / 10.0, 0.55), p(i / 10.0, 1.0), KidColors.Brown.opacity(0.25), 1.0)
                fill(r(0.0, 0.0, 1.0, 0.55), rgb(0.75, 0.85, 0.95))
                fill(r(0.95, 0.12, 0.02, 0.6), white(0.4))
                fill(r(0.92, 0.12, 0.015, 0.22), Color.White)
                strokeRect(r(0.92, 0.12, 0.015, 0.22), KidColors.Red, 2.0)
                line(p(0.82, 0.3), p(0.92, 0.3), KidColors.Orange, 4.0)
                val net = Path()
                for (i in 0..4) { net.from(0.82 + i * 0.025, 0.3); net.to(0.835 + i * 0.017, 0.4) }
                strokePath(net, Color.White, 1 * pt)
            }
            DemoScene.TableTennis -> {
                fill(r(0.0, 0.0, 1.0, 1.0), rgb(0.45, 0.2, 0.25))
                fill(r(0.12, 0.62, 0.76, 0.06), rgb(0.1, 0.35, 0.7))
                line(p(0.12, 0.62), p(0.88, 0.62), Color.White, 2.0)
                fill(r(0.2, 0.68, 0.02, 0.25), white(0.2)); fill(r(0.78, 0.68, 0.02, 0.25), white(0.2))
                fill(r(0.497, 0.55, 0.006, 0.07), Color.White)
            }
            DemoScene.Ring -> {
                fill(r(0.0, 0.0, 1.0, 1.0), rgb(0.15, 0.15, 0.25))
                shape(listOf(0.05 to 0.85, 0.95 to 0.85, 0.85 to 0.55, 0.15 to 0.55), rgb(0.25, 0.45, 0.85))
                listOf(KidColors.Red, Color.White, KidColors.Blue).forEachIndexed { i, color ->
                    val y = 0.3 + i * 0.08
                    line(p(0.05, y + 0.25), p(0.15, y), color, 3.0)
                    line(p(0.15, y), p(0.85, y), color, 3.0)
                    line(p(0.85, y), p(0.95, y + 0.25), color, 3.0)
                }
                fill(r(0.14, 0.25, 0.02, 0.32), KidColors.Red); fill(r(0.84, 0.25, 0.02, 0.32), KidColors.Blue)
            }
            is DemoScene.Mat -> {
                fill(r(0.0, 0.0, 1.0, 1.0), white(0.92))
                if (scene.round) {
                    oval(r(0.18, 0.12, 0.64, 0.84), scene.edge)
                    oval(r(0.24, 0.2, 0.52, 0.68), scene.color)
                    oval(r(0.46, 0.5, 0.08, 0.1), Color.White.opacity(0.7), stroke = 2.0)
                } else {
                    fill(r(0.1, 0.1, 0.8, 0.85), scene.edge)
                    fill(r(0.18, 0.18, 0.64, 0.7), scene.color)
                }
            }
            DemoScene.Stage -> {
                fill(r(0.0, 0.0, 1.0, 1.0), rgb(0.2, 0.1, 0.35))
                fill(r(0.0, 0.7, 1.0, 0.3), rgb(0.35, 0.25, 0.45))
                for ((x, color) in listOf(0.2 to KidColors.Pink, 0.5 to KidColors.Yellow, 0.8 to KidColors.Cyan)) {
                    shape(listOf(x - 0.03 to 0.0, x + 0.03 to 0.0, x + 0.15 to 0.85, x - 0.15 to 0.85), color.opacity(0.18))
                }
            }
            is DemoScene.Sea -> {
                sky(0.45)
                water(0.45)
                waves(listOf(0.55, 0.68, 0.82, 0.94))
                if (scene.wave) {
                    val path = Path()
                    path.from(0.0, 0.75)
                    path.curve(0.6, 0.3, 0.3, 0.75, 0.45, 0.25)
                    path.curve(0.75, 0.42, 0.7, 0.33, 0.74, 0.36)
                    path.curve(1.0, 0.75, 0.8, 0.6, 0.9, 0.75)
                    path.to(1.0, 1.0); path.to(0.0, 1.0); path.close()
                    s.drawPath(path, rgb(0.15, 0.55, 0.85))
                    oval(r(0.56, 0.27, 0.12, 0.07), Color.White)
                }
                if (scene.buoys) for ((x, y) in listOf(0.25 to 0.62, 0.75 to 0.62, 0.5 to 0.88)) oval(r(x - 0.02, y - 0.03, 0.04, 0.06), KidColors.Orange)
            }
            DemoScene.River -> {
                fill(r(0.0, 0.0, 1.0, 1.0), grass)
                fill(r(0.0, 0.15, 1.0, 0.75), rgb(0.25, 0.6, 0.85))
                waves(listOf(0.3, 0.5, 0.7))
                for ((x, color) in listOf(0.3 to KidColors.Green, 0.55 to KidColors.Red, 0.8 to KidColors.Green)) {
                    line(p(x, 0.1), p(x, 0.45), Color.White, 1.0)
                    fill(r(x - 0.008, 0.32, 0.016, 0.12), color)
                    line(p(x + 0.1, 0.1), p(x + 0.1, 0.45), Color.White, 1.0)
                    fill(r(x + 0.092, 0.32, 0.016, 0.12), color)
                }
            }
            is DemoScene.Range -> {
                sky(0.55)
                fill(r(0.0, 0.55, 1.0, 0.45), grass)
                if (scene.rings) {
                    fill(r(0.855, 0.6, 0.01, 0.25), KidColors.Brown)
                    target(0.86, 0.45, 0.16)
                }
            }
            DemoScene.Road -> {
                sky(0.55)
                shape(listOf(0.0 to 0.55, 0.25 to 0.35, 0.5 to 0.55), rgb(0.4, 0.65, 0.4))
                shape(listOf(0.35 to 0.55, 0.65 to 0.3, 0.95 to 0.55), rgb(0.3, 0.58, 0.35))
                fill(r(0.0, 0.55, 1.0, 0.45), grass)
                fill(r(0.0, 0.65, 1.0, 0.25), white(0.4))
                line(p(0.0, 0.775), p(1.0, 0.775), Color.White, 3.0, dash = floatArrayOf(16f, 12f))
            }
            is DemoScene.Equestrian -> {
                sky(0.4)
                fill(r(0.0, 0.4, 1.0, 0.6), grass)
                for (x in scene.fences) {
                    line(p(x - 0.04, 0.8), p(x - 0.04, 0.6), Color.White, 3.0)
                    line(p(x + 0.04, 0.8), p(x + 0.04, 0.6), Color.White, 3.0)
                    listOf(0.63, 0.7).forEachIndexed { i, y -> line(p(x - 0.04, y), p(x + 0.04, y), if (i == 0) KidColors.Red else Color.White, 5.0) }
                }
            }
            DemoScene.Piste -> {
                fill(r(0.0, 0.0, 1.0, 1.0), rgb(0.12, 0.15, 0.3))
                fill(r(0.0, 0.7, 1.0, 0.12), white(0.7))
                line(p(0.5, 0.7), p(0.5, 0.82), Color.White, 2.0)
                oval(r(0.05, 0.08, 0.08, 0.13), KidColors.Green.opacity(0.3)); oval(r(0.87, 0.08, 0.08, 0.13), KidColors.Red.opacity(0.3))
            }
            DemoScene.Golf -> {
                sky(0.45)
                fill(r(0.0, 0.45, 1.0, 0.55), rgb(0.4, 0.72, 0.35))
                oval(r(0.6, 0.6, 0.38, 0.18), rgb(0.5, 0.85, 0.45))
                oval(r(0.35, 0.78, 0.18, 0.1), rgb(0.95, 0.88, 0.65))
                oval(r(0.845, 0.65, 0.03, 0.025), Color.Black)
                flag(0.86, 0.67, KidColors.Red)
            }
            DemoScene.Beam -> {
                fill(r(0.0, 0.0, 1.0, 1.0), rgb(0.95, 0.9, 0.85))
                fill(r(0.0, 0.8, 1.0, 0.2), rgb(0.3, 0.45, 0.85))
                fill(r(0.08, 0.58, 0.84, 0.04), rgb(0.85, 0.7, 0.5))
                fill(r(0.15, 0.62, 0.02, 0.18), white(0.5)); fill(r(0.83, 0.62, 0.02, 0.18), white(0.5))
            }
            DemoScene.Skatepark -> {
                sky(1.0)
                val path = Path()
                path.from(0.0, 0.25)
                path.quad(0.3, 0.85, 0.02, 0.85)
                path.to(0.7, 0.85)
                path.quad(1.0, 0.25, 0.98, 0.85)
                path.to(1.0, 1.0); path.to(0.0, 1.0); path.close()
                s.drawPath(path, white(0.72))
                line(p(0.0, 0.25), p(0.06, 0.25), white(0.4), 4.0); line(p(0.94, 0.25), p(1.0, 0.25), white(0.4), 4.0)
            }
            DemoScene.ClimbingWall -> {
                fill(r(0.0, 0.0, 1.0, 1.0), rgb(0.75, 0.8, 0.85))
                fill(r(0.0, 0.93, 1.0, 0.07), rgb(0.3, 0.3, 0.4))
                val holds = listOf(
                    Triple(0.3, 0.82, KidColors.Red), Triple(0.42, 0.7, KidColors.Yellow), Triple(0.28, 0.6, KidColors.Green),
                    Triple(0.4, 0.47, KidColors.Purple), Triple(0.3, 0.36, KidColors.Orange), Triple(0.44, 0.24, KidColors.Blue),
                    Triple(0.34, 0.12, KidColors.Pink), Triple(0.72, 0.85, KidColors.Red), Triple(0.72, 0.6, KidColors.Red),
                    Triple(0.72, 0.35, KidColors.Red), Triple(0.72, 0.1, KidColors.Red),
                )
                for ((x, y, color) in holds) oval(r(x - 0.02, y - 0.025, 0.04, 0.05), color)
                line(p(0.6, 0.0), p(0.6, 0.93), Color.White.opacity(0.5), 2.0)
            }
            DemoScene.Rugby -> {
                fill(r(0.0, 0.0, 1.0, 1.0), grass)
                for (i in 0 until 10 step 2) fill(r(i / 10.0, 0.0, 0.1, 1.0), Color.White.opacity(0.06))
                line(p(0.85, 0.05), p(0.85, 0.95), Color.White, 3.0)
                line(p(0.9, 0.2), p(0.9, 0.7), Color.White, 4.0); line(p(0.96, 0.15), p(0.96, 0.65), Color.White, 4.0)
                line(p(0.9, 0.5), p(0.96, 0.45), Color.White, 4.0)
            }
            DemoScene.Platform -> {
                fill(r(0.0, 0.0, 1.0, 1.0), rgb(0.25, 0.25, 0.3))
                fill(r(0.2, 0.75, 0.6, 0.2), rgb(0.75, 0.55, 0.35))
                strokeRect(r(0.2, 0.75, 0.6, 0.2), Color.Black.opacity(0.4), 2.0)
            }
            DemoScene.Triathlon -> {
                sky(0.5)
                fill(r(0.0, 0.5, 0.34, 0.5), rgb(0.2, 0.55, 0.85))
                fill(r(0.34, 0.5, 0.66, 0.5), grass)
                fill(r(0.34, 0.66, 0.33, 0.2), white(0.4))
                fill(r(0.67, 0.66, 0.33, 0.2), rgb(0.82, 0.35, 0.28))
                val dash = floatArrayOf(5f, 4f)
                line(p(0.34, 0.45), p(0.34, 0.95), Color.White, 2.0, dash = dash); line(p(0.67, 0.45), p(0.67, 0.95), Color.White, 2.0, dash = dash)
            }
            DemoScene.Pentathlon -> {
                fill(r(0.0, 0.0, 1.0, 1.0), grass)
                fill(r(0.0, 0.6, 1.0, 0.3), rgb(0.82, 0.35, 0.28))
                fill(r(0.62, 0.4, 0.2, 0.2), white(0.85))
                for (i in 0 until 4) oval(r(0.64 + i * 0.045, 0.45, 0.035, 0.055), Color.Black)
            }
            is DemoScene.Slope -> {
                sky(1.0)
                snow(listOf(0.0 to 0.15, 1.0 to 0.75))
                tree(0.75, 0.42, 0.12); tree(0.88, 0.5, 0.1); tree(0.1, 0.12, 0.08)
                if (scene.gates) for ((x, color) in listOf(0.3 to KidColors.Red, 0.52 to KidColors.Blue, 0.74 to KidColors.Red)) flag(x, 0.15 + x * 0.6 + 0.12, color)
            }
            DemoScene.SnowHills -> {
                sky(1.0)
                snow(listOf(0.0 to 0.7, 0.2 to 0.55, 0.45 to 0.7, 0.7 to 0.5, 1.0 to 0.65))
                tree(0.15, 0.55, 0.12); tree(0.62, 0.5, 0.1); tree(0.88, 0.58, 0.12)
                val tracks = Path()
                tracks.from(0.0, 0.82); tracks.to(1.0, 0.8)
                strokePath(tracks, white(0.8), 2 * pt)
            }
            DemoScene.IceChute -> {
                sky(1.0)
                snow(listOf(0.0 to 0.5, 1.0 to 0.85))
                val path = Path()
                path.from(0.0, 0.12)
                path.curve(0.5, 0.55, 0.4, 0.05, 0.1, 0.55)
                path.curve(1.0, 0.75, 0.85, 0.55, 0.75, 0.85)
                strokePath(path, rgb(0.6, 0.8, 0.95), (0.16 * h).toFloat())
                strokePath(path, ice, (0.11 * h).toFloat())
            }
            is DemoScene.Rink -> {
                fill(r(0.0, 0.0, 1.0, 1.0), white(0.3))
                val rink = r(0.03, 0.08, 0.94, 0.84)
                s.drawRoundRect(ice, rink.topLeft, rink.size, CornerRadius((0.2 * h).toFloat()))
                if (scene.hockey) {
                    line(p(0.5, 0.08), p(0.5, 0.92), KidColors.Red, 3.0)
                    line(p(0.33, 0.08), p(0.33, 0.92), KidColors.Blue, 3.0); line(p(0.67, 0.08), p(0.67, 0.92), KidColors.Blue, 3.0)
                    oval(r(0.44, 0.4, 0.12, 0.2), KidColors.Blue, stroke = 2.0)
                    goal(0.9, 0.42, 0.04, 0.16)
                } else {
                    oval(r(0.35, 0.3, 0.3, 0.4), KidColors.Blue.opacity(0.3), stroke = 2.0)
                }
            }
            DemoScene.Curling -> {
                fill(r(0.0, 0.0, 1.0, 1.0), white(0.3))
                fill(r(0.0, 0.15, 1.0, 0.7), ice)
                for ((rr, color) in listOf(0.3 to KidColors.Blue, 0.2 to Color.White, 0.11 to KidColors.Red, 0.04 to Color.White)) {
                    oval(circleRect(0.82, 0.5, rr), color)
                }
                line(p(0.05, 0.5), p(0.97, 0.5), Color.Black.opacity(0.15), 1.0)
                line(p(0.35, 0.15), p(0.35, 0.85), KidColors.Red.opacity(0.6), 2.0)
            }
            DemoScene.SkiJump -> {
                sky(1.0)
                snow(listOf(0.0 to 0.9, 0.4 to 0.55, 0.75 to 0.95, 1.0 to 0.97))
                val ramp = Path()
                ramp.from(0.0, 0.08)
                ramp.quad(0.33, 0.45, 0.18, 0.45)
                strokePath(ramp, white(0.55), 8 * pt)
                strokePath(ramp, Color.White, 4 * pt)
                tree(0.9, 0.9, 0.1)
            }
            DemoScene.Halfpipe -> {
                sky(1.0)
                val path = Path()
                path.from(0.0, 0.2)
                path.quad(0.25, 0.85, 0.02, 0.85)
                path.to(0.75, 0.85)
                path.quad(1.0, 0.2, 0.98, 0.85)
                path.to(1.0, 1.0); path.to(0.0, 1.0); path.close()
                s.drawPath(path, Color.White)
                strokePath(path, rgb(0.7, 0.85, 1.0), 2 * pt)
            }
            DemoScene.Kicker -> {
                sky(1.0)
                snow(listOf(0.0 to 0.35, 0.35 to 0.7, 0.45 to 0.62, 0.47 to 0.7, 1.0 to 0.95))
                tree(0.85, 0.75, 0.12)
            }
            DemoScene.Mountain -> {
                sky(1.0)
                shape(listOf(0.0 to 1.0, 0.5 to 0.08, 1.0 to 1.0), rgb(0.55, 0.6, 0.7))
                shape(listOf(0.36 to 0.34, 0.5 to 0.08, 0.64 to 0.34, 0.55 to 0.3, 0.5 to 0.36, 0.44 to 0.3), Color.White)
                snow(listOf(0.0 to 0.9, 1.0 to 0.9))
                flag(0.5, 0.1, KidColors.Red)
            }
            is DemoScene.Oval -> {
                fill(r(0.0, 0.0, 1.0, 1.0), white(0.3))
                val rink = r(0.03, 0.08, 0.94, 0.84)
                s.drawRoundRect(ice, rink.topLeft, rink.size, CornerRadius((0.4 * h).toFloat()))
                val inset = if (scene.small) 0.22 else 0.16
                val inner = r(inset, 0.24, 1 - inset * 2, 0.52)
                s.drawRoundRect(KidColors.Blue.opacity(0.35), inner.topLeft, inner.size, CornerRadius((0.26 * h).toFloat()), style = Stroke(2 * pt))
                if (!scene.small) {
                    val outer = r(0.08, 0.14, 0.84, 0.72)
                    s.drawRoundRect(KidColors.Red.opacity(0.3), outer.topLeft, outer.size, CornerRadius((0.36 * h).toFloat()), style = Stroke(2 * pt))
                }
            }
            DemoScene.Biathlon -> {
                sky(1.0)
                snow(listOf(0.0 to 0.6, 1.0 to 0.6))
                fill(r(0.7, 0.3, 0.26, 0.18), white(0.85))
                for (i in 0 until 5) oval(r(0.72 + i * 0.048, 0.35, 0.04, 0.07), Color.Black)
                tree(0.1, 0.6, 0.12); tree(0.35, 0.58, 0.1)
            }
        }
    }
}
