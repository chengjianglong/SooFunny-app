package com.chengjianglong.soofunny.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ImageSegmenterTest {
    /** A sky-blue picture with a red disc and a yellow square: a tiny "photo". */
    private fun photo(size: Int = 160): PixelImage {
        val pixels = IntArray(size * size) { i ->
            val x = i % size
            val y = i / size
            val dx = x - size * 0.35
            val dy = y - size * 0.4
            when {
                dx * dx + dy * dy < (size * 0.2) * (size * 0.2) -> Rgb.of(220, 40, 40)
                x > size * 0.6 && x < size * 0.9 && y > size * 0.55 && y < size * 0.85 -> Rgb.of(250, 210, 30)
                else -> Rgb.of(60 + (x % 3), 140, 220) // a little noise
            }
        }
        return PixelImage(size, size, pixels)
    }

    @Test
    fun photoBecomesAFewFillableBlocks() {
        val image = photo()
        assertFalse(ImageSegmenter.looksLikeLineArt(image))
        val seg = ImageSegmenter(outputDimension = 320).segment(image, SegmentDetail.MEDIUM)
        assertFalse(seg.isLineArt)
        assertEquals(320, seg.width)
        assertTrue("expected 3+ blocks, got ${seg.regionCount}", seg.regionCount in 3..SegmentDetail.MEDIUM.maxRegions)
        assertTrue(seg.labels.all { it in 0 until seg.regionCount })
        // Disc, square and sky are different blocks.
        val disc = seg.region((0.35 * 320).toInt(), (0.4 * 320).toInt())
        val square = seg.region((0.75 * 320).toInt(), (0.7 * 320).toInt())
        val sky = seg.region(10, 300)
        assertNotEquals(disc, square)
        assertNotEquals(disc, sky)
        assertNotEquals(square, sky)
        // Real colors come back roughly right.
        val red = seg.meanColors[disc!!]
        assertTrue(Rgb.r(red) > 180 && Rgb.g(red) < 90)
        // There are outlines.
        assertTrue(seg.ink.any { (it.toInt() and 0xFF) > 200 })

        val fills = IntArray(seg.regionCount) { Rgb.WHITE }
        fills[disc] = Palette.crayons[0]
        val out = IntArray(seg.width * seg.height)
        ColoringRenderer.render(seg, fills, out)
        assertEquals(Palette.crayons[0], out[(0.4 * 320).toInt() * 320 + (0.35 * 320).toInt()])
    }

    @Test
    fun lineArtSplitsAlongItsLines() {
        val size = 200
        val pixels = IntArray(size * size) { Rgb.WHITE }
        // A black square outline, 4px thick.
        for (y in 0 until size) for (x in 0 until size) {
            val onBorder = (x in 50..150 && y in 50..150) && !(x in 54..146 && y in 54..146)
            if (onBorder) pixels[y * size + x] = Rgb.of(0, 0, 0)
        }
        val image = PixelImage(size, size, pixels)
        assertTrue(ImageSegmenter.looksLikeLineArt(image))
        val seg = ImageSegmenter().segment(image, SegmentDetail.MEDIUM)
        assertTrue(seg.isLineArt)
        assertEquals(2, seg.regionCount)
        // Every pixel, even on the line, belongs to a block (taps on a line snap to the nearest block).
        assertTrue(seg.labels.all { it >= 0 })
        assertNotEquals(seg.region(100, 100), seg.region(10, 10))
        assertEquals(seg.region(10, 10), seg.region(51, 100))
    }
}
