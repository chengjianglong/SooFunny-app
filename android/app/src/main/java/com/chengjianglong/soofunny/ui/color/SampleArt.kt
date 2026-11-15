package com.chengjianglong.soofunny.ui.color

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Built-in coloring pages, drawn in code so the app works with no photos and no network. */
class SampleArt(val id: String, val name: String, private val body: (Canvas, Pen) -> Unit) {

    /** Draws the picture at [size] x [size] pixels (1600 for coloring, smaller for thumbnails). */
    fun draw(size: Int = 1600): Bitmap {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        canvas.scale(size / CANVAS, size / CANVAS)
        body(canvas, Pen())
        return bitmap
    }

    /** Black 10-unit round strokes, like the iOS drawing context. */
    class Pen {
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK
            style = Paint.Style.STROKE
            strokeWidth = 10f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK; style = Paint.Style.FILL }
    }

    companion object {
        private const val CANVAS = 800f

        val all: List<SampleArt> = listOf(
            SampleArt("house", "House", ::house),
            SampleArt("fish", "Fish", ::fish),
            SampleArt("flower", "Flower", ::flower),
            SampleArt("rocket", "Rocket", ::rocket),
        )

        private fun Canvas.polygon(pen: Pen, vararg points: Float) {
            val path = Path()
            path.moveTo(points[0], points[1])
            var i = 2
            while (i < points.size) { path.lineTo(points[i], points[i + 1]); i += 2 }
            path.close()
            drawPath(path, pen.stroke)
        }

        private fun Canvas.polygon(pen: Pen, points: List<Pair<Double, Double>>) =
            polygon(pen, *points.flatMap { listOf(it.first.toFloat(), it.second.toFloat()) }.toFloatArray())

        private fun Canvas.circle(pen: Pen, x: Double, y: Double, r: Double) =
            drawCircle(x.toFloat(), y.toFloat(), r.toFloat(), pen.stroke)

        private fun Canvas.line(pen: Pen, x1: Double, y1: Double, x2: Double, y2: Double) =
            drawLine(x1.toFloat(), y1.toFloat(), x2.toFloat(), y2.toFloat(), pen.stroke)

        private fun Canvas.rect(pen: Pen, x: Double, y: Double, w: Double, h: Double) =
            drawRect(x.toFloat(), y.toFloat(), (x + w).toFloat(), (y + h).toFloat(), pen.stroke)

        private fun Canvas.ellipse(paint: Paint, x: Double, y: Double, w: Double, h: Double) =
            drawOval(RectF(x.toFloat(), y.toFloat(), (x + w).toFloat(), (y + h).toFloat()), paint)

        private fun house(cg: Canvas, pen: Pen) = with(cg) {
            line(pen, 30.0, 700.0, 770.0, 700.0)
            rect(pen, 520.0, 200.0, 60.0, 120.0)
            rect(pen, 180.0, 390.0, 440.0, 310.0)
            polygon(pen, 140f, 400f, 400f, 170f, 660f, 400f)
            rect(pen, 350.0, 530.0, 100.0, 170.0)
            circle(pen, 432.0, 620.0, 8.0)
            for (x in listOf(220.0, 480.0)) {
                rect(pen, x, 440.0, 100.0, 90.0)
                line(pen, x + 50, 440.0, x + 50, 530.0)
                line(pen, x, 485.0, x + 100, 485.0)
            }
            circle(pen, 120.0, 120.0, 60.0)
            for (i in 0 until 8) {
                val a = i * PI / 4
                line(pen, 120 + cos(a) * 80, 120 + sin(a) * 80, 120 + cos(a) * 110, 120 + sin(a) * 110)
            }
            for ((x, r) in listOf(560.0 to 40.0, 610.0 to 55.0, 670.0 to 40.0)) circle(pen, x, 110.0, r)
            var x = 60.0
            while (x <= 740.0) {
                if (x < 170 || x > 630) polygon(pen, listOf(x - 18 to 700.0, x to 655.0, x + 18 to 700.0))
                x += 70
            }
        }

        private fun fish(cg: Canvas, pen: Pen) = with(cg) {
            ellipse(pen.stroke, 150.0, 250.0, 450.0, 300.0)
            polygon(pen, 585f, 400f, 740f, 270f, 740f, 530f)
            polygon(pen, 330f, 262f, 400f, 170f, 470f, 268f)
            polygon(pen, 360f, 470f, 420f, 520f, 330f, 520f)
            circle(pen, 250.0, 360.0, 32.0)
            ellipse(pen.fill, 238.0, 348.0, 24.0, 24.0)
            for (x in listOf(340f, 430f, 520f)) {
                drawPath(Path().apply { moveTo(x, 262f); quadTo(x + 50, 400f, x, 538f) }, pen.stroke)
            }
            for ((x, y, r) in listOf(Triple(110.0, 220.0, 22.0), Triple(80.0, 140.0, 30.0), Triple(130.0, 70.0, 18.0))) {
                circle(pen, x, y, r)
            }
            val waves = Path().apply {
                moveTo(20f, 700f)
                for (i in 0 until 8) {
                    val x = 20f + i * 95f
                    quadTo(x + 47, 650f, x + 95, 700f)
                }
            }
            drawPath(waves, pen.stroke)
            for (x in listOf(120f, 650f)) {
                drawPath(Path().apply { moveTo(x, 690f); cubicTo(x - 40, 650f, x + 40, 600f, x, 560f) }, pen.stroke)
            }
        }

        private fun flower(cg: Canvas, pen: Pen) = with(cg) {
            polygon(pen, 290f, 620f, 510f, 620f, 470f, 770f, 330f, 770f)
            line(pen, 290.0, 660.0, 510.0, 660.0)
            line(pen, 400.0, 400.0, 400.0, 620.0)
            for (side in listOf(-1f, 1f)) {
                val leaf = Path().apply {
                    moveTo(400f, 540f)
                    quadTo(400 + side * 60, 450f, 400 + side * 150, 480f)
                    quadTo(400 + side * 110, 560f, 400f, 540f)
                }
                drawPath(leaf, pen.stroke)
            }
            for (i in 0 until 6) {
                save()
                translate(400f, 280f)
                rotate(i * 60f)
                ellipse(pen.stroke, 50.0, -50.0, 170.0, 100.0)
                restore()
            }
            circle(pen, 400.0, 280.0, 75.0)
            circle(pen, 680.0, 110.0, 50.0)
            for ((x, y) in listOf(110.0 to 120.0, 680.0 to 420.0)) {
                ellipse(pen.stroke, x - 45, y - 25, 40.0, 50.0)
                ellipse(pen.stroke, x + 5, y - 25, 40.0, 50.0)
            }
        }

        private fun rocket(cg: Canvas, pen: Pen) = with(cg) {
            polygon(pen, 330f, 260f, 400f, 100f, 470f, 260f)
            rect(pen, 330.0, 260.0, 140.0, 320.0)
            circle(pen, 400.0, 360.0, 45.0)
            circle(pen, 400.0, 360.0, 25.0)
            line(pen, 330.0, 470.0, 470.0, 470.0)
            polygon(pen, 330f, 470f, 250f, 600f, 330f, 580f)
            polygon(pen, 470f, 470f, 550f, 600f, 470f, 580f)
            polygon(pen, 350f, 580f, 400f, 740f, 450f, 580f)
            polygon(pen, 375f, 590f, 400f, 680f, 425f, 590f)
            val stars = listOf(
                Triple(140.0, 140.0, 40.0), Triple(660.0, 220.0, 32.0),
                Triple(160.0, 520.0, 28.0), Triple(650.0, 620.0, 44.0),
            )
            for ((x, y, r) in stars) {
                val points = (0 until 10).map { i ->
                    val a = i * PI / 5 - PI / 2
                    val radius = if (i % 2 == 0) r else r * 0.45
                    (x + cos(a) * radius) to (y + sin(a) * radius)
                }
                polygon(pen, points)
            }
            circle(pen, 620.0, 420.0, 60.0)
            ellipse(pen.stroke, 530.0, 405.0, 180.0, 30.0)
        }
    }
}
