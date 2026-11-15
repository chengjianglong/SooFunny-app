package com.chengjianglong.soofunny.engine

/**
 * Opaque colors packed as Android-style ARGB ints (0xFFRRGGBB). Mirrors `RGBA` in the iOS app.
 * Plain Kotlin, so the engine runs in JVM unit tests.
 */
object Rgb {
    const val WHITE: Int = -0x1 // 0xFFFFFFFF
    val INK: Int = of(34, 34, 40)

    fun of(r: Int, g: Int, b: Int): Int = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
    fun hex(hex: Int): Int = (0xFF shl 24) or (hex and 0xFFFFFF)
    fun r(c: Int): Int = (c shr 16) and 0xFF
    fun g(c: Int): Int = (c shr 8) and 0xFF
    fun b(c: Int): Int = c and 0xFF

    /** Perceived brightness in 0..1. */
    fun luminance(c: Int): Double = (0.299 * r(c) + 0.587 * g(c) + 0.114 * b(c)) / 255
}

/** A bitmap as one opaque ARGB int per pixel (alpha ignored). */
class PixelImage(val width: Int, val height: Int, val pixels: IntArray) {
    init {
        require(pixels.size == width * height) { "pixel data does not match size" }
    }

    val pixelCount: Int get() = width * height

    operator fun get(index: Int): Int = pixels[index]
}

/** Small deterministic random number generator (same sequence as the iOS `SplitMix64`). */
class SplitMix64(seed: Long) {
    private var state = seed

    fun next(): Long {
        state += 0x9E3779B97F4A7C15uL.toLong()
        var z = state
        z = (z xor (z ushr 30)) * 0xBF58476D1CE4E5B9uL.toLong()
        z = (z xor (z ushr 27)) * 0x94D049BB133111EBuL.toLong()
        return z xor (z ushr 31)
    }

    /** `next() % n` with the value treated as unsigned, like Swift's UInt64. */
    fun nextMod(n: Int): Int = java.lang.Long.remainderUnsigned(next(), n.toLong()).toInt()
}
