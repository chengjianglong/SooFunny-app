package com.chengjianglong.soofunny.ui.color

import android.graphics.Bitmap
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.chengjianglong.soofunny.engine.BitmapPixels
import com.chengjianglong.soofunny.engine.ColoringRenderer
import com.chengjianglong.soofunny.engine.ImageSegmenter
import com.chengjianglong.soofunny.engine.Palette
import com.chengjianglong.soofunny.engine.Rgb
import com.chengjianglong.soofunny.engine.SegmentDetail
import com.chengjianglong.soofunny.engine.Segmentation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** One picture being colored: holds its blocks, the chosen colors and the undo history. */
class ColoringSession(val source: Bitmap) {
    var detail by mutableStateOf(SegmentDetail.MEDIUM)
    var selectedColor by mutableIntStateOf(Palette.crayons[0])

    /** A color picked with More colors, kept beside the crayons. */
    var customColor by mutableStateOf<Int?>(null)
    var peek by mutableStateOf(false)

    var segmentation by mutableStateOf<Segmentation?>(null)
        private set
    /** The colored page, redrawn in place; [version] changes every time it does. */
    var canvas by mutableStateOf<Bitmap?>(null)
        private set
    var version by mutableIntStateOf(0)
        private set
    var isProcessing by mutableStateOf(false)
        private set
    var failed by mutableStateOf(false)
        private set
    var canUndo by mutableStateOf(false)
        private set

    private var fills = IntArray(0)
    private var pixels = IntArray(0)
    private val undoStack = ArrayDeque<IntArray>()
    private var strokeSaved = false
    private val segmenter = ImageSegmenter()

    /** Splits the picture into blocks (off the main thread) and starts with a blank page. */
    suspend fun prepare() {
        isProcessing = true
        val detail = detail
        val result = withContext(Dispatchers.Default) { BitmapPixels.segment(segmenter, source, detail) }
        if (detail != this.detail) return // a newer request is running
        segmentation = result
        failed = result == null
        fills = IntArray(result?.regionCount ?: 0) { Rgb.WHITE }
        undoStack.clear()
        canUndo = false
        canvas = result?.let { Bitmap.createBitmap(it.width, it.height, Bitmap.Config.ARGB_8888) }
        pixels = IntArray(result?.let { it.width * it.height } ?: 0)
        render()
        isProcessing = false
    }

    /**
     * Fills the block under a pixel with the selected color. A whole finger stroke counts as
     * one undo step. Returns true when something changed.
     */
    fun paint(x: Int, y: Int, startingStroke: Boolean): Boolean {
        if (startingStroke) strokeSaved = false
        val segmentation = segmentation ?: return false
        val region = segmentation.region(x, y) ?: return false
        if (region >= fills.size || fills[region] == selectedColor) return false
        if (!strokeSaved) {
            saveUndo()
            strokeSaved = true
        }
        fills[region] = selectedColor
        render()
        return true
    }

    fun undo() {
        val previous = undoStack.removeLastOrNull() ?: return
        fills = previous
        canUndo = undoStack.isNotEmpty()
        render()
    }

    /** Fills every block with a random crayon. */
    fun surprise() = replaceFills { Palette.crayons.random() }

    /** Colors each block with its average color from the original picture. */
    fun realColors() {
        val segmentation = segmentation ?: return
        replaceFills { segmentation.meanColors[it] }
    }

    fun clear() = replaceFills { Rgb.WHITE }

    private fun replaceFills(color: (Int) -> Int) {
        if (fills.isEmpty()) return
        saveUndo()
        fills = IntArray(fills.size) { color(it) }
        render()
    }

    private fun saveUndo() {
        undoStack.addLast(fills.copyOf())
        if (undoStack.size > 80) undoStack.removeFirst()
        canUndo = true
    }

    private fun render() {
        val segmentation = segmentation ?: return
        val bitmap = canvas ?: return
        ColoringRenderer.render(segmentation, fills, pixels)
        bitmap.setPixels(pixels, 0, segmentation.width, 0, 0, segmentation.width, segmentation.height)
        version++
    }
}
