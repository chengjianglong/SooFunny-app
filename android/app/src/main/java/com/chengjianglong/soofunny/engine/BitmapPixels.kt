package com.chengjianglong.soofunny.engine

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Android glue for the engine: Bitmaps in and out. Everything else in this package is plain
 * Kotlin so it can be unit tested on the JVM.
 */
object BitmapPixels {
    /**
     * Downscales [bitmap] so its longest side is at most [maxDimension] pixels, flattening
     * transparency onto white. Large reductions go in halving steps so detail isn't skipped.
     */
    fun pixelImage(bitmap: Bitmap, maxDimension: Int): PixelImage? {
        if (bitmap.width < 1 || bitmap.height < 1) return null
        var src = if (bitmap.config == Bitmap.Config.HARDWARE) bitmap.copy(Bitmap.Config.ARGB_8888, false) ?: return null else bitmap
        val factor = min(1f, maxDimension.toFloat() / max(src.width, src.height))
        val w = max(1, (src.width * factor).roundToInt())
        val h = max(1, (src.height * factor).roundToInt())
        while (src.width / 2 >= w * 2 && src.height / 2 >= h * 2) {
            src = Bitmap.createScaledBitmap(src, src.width / 2, src.height / 2, true)
        }
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        Canvas(out).apply {
            drawColor(Color.WHITE)
            drawBitmap(src, Rect(0, 0, src.width, src.height), Rect(0, 0, w, h), Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        }
        val pixels = IntArray(w * h)
        out.getPixels(pixels, 0, w, 0, 0, w, h)
        for (i in pixels.indices) pixels[i] = pixels[i] or (0xFF shl 24)
        return PixelImage(w, h, pixels)
    }

    /**
     * Splits a picture into blocks: drawings at up to [ImageSegmenter.lineArtMaxDimension],
     * photos at [ImageSegmenter.photoMaxDimension]. Slow; call off the main thread.
     *
     * Photos get more detail on their subject and a simpler background when ML Kit finds a
     * subject ([SubjectMask]); otherwise they're grouped as one picture.
     */
    fun segment(segmenter: ImageSegmenter, bitmap: Bitmap, detail: SegmentDetail): Segmentation? {
        val pixels = pixelImage(bitmap, segmenter.lineArtMaxDimension) ?: return null
        if (ImageSegmenter.looksLikeLineArt(pixels)) return segmenter.segment(pixels, detail)
        val photo = if (max(pixels.width, pixels.height) <= segmenter.photoMaxDimension) pixels
        else pixelImage(bitmap, segmenter.photoMaxDimension) ?: return null
        return segmenter.segment(photo, detail, subject = SubjectMask.compute(bitmap, photo))
    }
}
