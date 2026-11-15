package com.chengjianglong.soofunny.engine

import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/** An image in CIE L*a*b* (D65), where distances match how different colors look to people. */
class LabImage(val width: Int, val height: Int, val l: FloatArray, val a: FloatArray, val b: FloatArray) {
    val pixelCount: Int get() = width * height

    /**
     * Kuwahara filter: every pixel takes the average color of whichever of its four
     * neighboring windows is flattest. Texture and shading become flat areas while real
     * edges stay sharp, which is what makes a photo look like a drawing.
     */
    fun kuwahara(radius: Int): LabImage {
        val r = radius
        val w = width
        val h = height
        val stride = w + 1
        val size = stride * (h + 1)
        val sumL = DoubleArray(size)
        val sumL2 = DoubleArray(size)
        val sumA = DoubleArray(size)
        val sumB = DoubleArray(size)
        // Summed-area tables so every window average costs four lookups.
        for (y in 0 until h) {
            var rowL = 0.0
            var rowL2 = 0.0
            var rowA = 0.0
            var rowB = 0.0
            for (x in 0 until w) {
                val i = y * w + x
                val lv = l[i].toDouble()
                rowL += lv
                rowL2 += lv * lv
                rowA += a[i].toDouble()
                rowB += b[i].toDouble()
                val o = (y + 1) * stride + x + 1
                sumL[o] = sumL[o - stride] + rowL
                sumL2[o] = sumL2[o - stride] + rowL2
                sumA[o] = sumA[o - stride] + rowA
                sumB[o] = sumB[o - stride] + rowB
            }
        }

        fun box(s: DoubleArray, x0: Int, y0: Int, x1: Int, y1: Int): Double =
            s[y1 * stride + x1] - s[y0 * stride + x1] - s[y1 * stride + x0] + s[y0 * stride + x0]

        val outL = FloatArray(w * h)
        val outA = FloatArray(w * h)
        val outB = FloatArray(w * h)
        for (y in 0 until h) {
            for (x in 0 until w) {
                var bestVariance = Double.POSITIVE_INFINITY
                var bestL = 0.0
                var bestA = 0.0
                var bestB = 0.0
                for (q in 0 until 4) {
                    val qx = if (q and 1 == 0) x - r else x
                    val qy = if (q < 2) y - r else y
                    val x0 = max(0, qx)
                    val y0 = max(0, qy)
                    val x1 = min(w, qx + r + 1)
                    val y1 = min(h, qy + r + 1)
                    val count = ((x1 - x0) * (y1 - y0)).toDouble()
                    val mean = box(sumL, x0, y0, x1, y1) / count
                    val variance = box(sumL2, x0, y0, x1, y1) / count - mean * mean
                    if (variance < bestVariance) {
                        bestVariance = variance
                        bestL = mean
                        bestA = box(sumA, x0, y0, x1, y1) / count
                        bestB = box(sumB, x0, y0, x1, y1) / count
                    }
                }
                val i = y * w + x
                outL[i] = bestL.toFloat()
                outA[i] = bestA.toFloat()
                outB[i] = bestB.toFloat()
            }
        }
        return LabImage(w, h, outL, outA, outB)
    }

    companion object {
        private val linear = FloatArray(256) { v ->
            val c = v / 255f
            if (c <= 0.04045f) c / 12.92f else ((c + 0.055f) / 1.055f).pow(2.4f)
        }

        fun from(image: PixelImage): LabImage {
            val n = image.pixelCount
            val l = FloatArray(n)
            val a = FloatArray(n)
            val b = FloatArray(n)
            val out = FloatArray(3)
            for (i in 0 until n) {
                val c = image.pixels[i]
                lab(Rgb.r(c), Rgb.g(c), Rgb.b(c), out)
                l[i] = out[0]
                a[i] = out[1]
                b[i] = out[2]
            }
            return LabImage(image.width, image.height, l, a, b)
        }

        /** Writes L, a, b of an sRGB color into [out]. */
        fun lab(r: Int, g: Int, b: Int, out: FloatArray) {
            val rl = linear[r]
            val gl = linear[g]
            val bl = linear[b]
            val x = (0.4124f * rl + 0.3576f * gl + 0.1805f * bl) / 0.95047f
            val y = 0.2126f * rl + 0.7152f * gl + 0.0722f * bl
            val z = (0.0193f * rl + 0.1192f * gl + 0.9505f * bl) / 1.08883f
            val fx = f(x)
            val fy = f(y)
            val fz = f(z)
            out[0] = 116 * fy - 16
            out[1] = 500 * (fx - fy)
            out[2] = 200 * (fy - fz)
        }

        private fun f(t: Float): Float = if (t > 0.008856f) Math.cbrt(t.toDouble()).toFloat() else 7.787f * t + 16f / 116f
    }
}
