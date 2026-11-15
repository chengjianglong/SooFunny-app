package com.chengjianglong.soofunny.engine

import android.content.Context
import android.graphics.Bitmap
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import java.util.WeakHashMap
import java.util.concurrent.TimeUnit

/**
 * Finds the main subject of a photo (people, pets, objects) with ML Kit's on-device subject
 * segmentation, the Android counterpart of Apple Vision's subject lifting on iOS. Google Play
 * services installs its model once; until then (or on devices without Play services) photos are
 * simply segmented as one picture.
 */
object SubjectMask {
    private val segmenter by lazy {
        SubjectSegmentation.getClient(SubjectSegmenterOptions.Builder().enableForegroundConfidenceMask().build())
    }
    private val cache = WeakHashMap<Bitmap, Pair<Int, BooleanArray?>>()
    private var appContext: Context? = null

    /** Call once at start-up; asks Play services to install the model if it isn't there yet. */
    fun init(context: Context) {
        appContext = context.applicationContext
        Thread { runCatching { modelReady() } }.start()
    }

    /** Whether the model is installed. If not, asks for it in the background and says no for now. */
    private fun modelReady(): Boolean {
        val context = appContext ?: return false
        val client = ModuleInstall.getClient(context)
        val available = Tasks.await(client.areModulesAvailable(segmenter), 5, TimeUnit.SECONDS).areModulesAvailable()
        if (!available) client.installModules(ModuleInstallRequest.newBuilder().addApi(segmenter).build())
        return available
    }

    /**
     * One flag per pixel of [image], true for the subject; null when there's no clear subject or
     * the model isn't available. Blocks for up to a few seconds; call off the main thread.
     * Results are remembered per [source] picture, so changing the block size doesn't redo it.
     */
    fun compute(source: Bitmap, image: PixelImage): BooleanArray? {
        synchronized(cache) { cache[source]?.let { (size, mask) -> if (size == image.pixels.size) return mask } }
        if (runCatching { modelReady() }.getOrDefault(false) == false) return null // try again next picture
        val mask = runCatching { run(image) }.getOrNull()
        synchronized(cache) { cache[source] = image.pixels.size to mask }
        return mask
    }

    private fun run(image: PixelImage): BooleanArray? {
        val bitmap = Bitmap.createBitmap(image.pixels, image.width, image.height, Bitmap.Config.ARGB_8888)
        val result = Tasks.await(segmenter.process(InputImage.fromBitmap(bitmap, 0)), 10, TimeUnit.SECONDS)
        val confidence = result.foregroundConfidenceMask ?: return null
        confidence.rewind()
        val n = image.width * image.height
        if (confidence.remaining() < n) return null
        val mask = BooleanArray(n)
        var subjectPixels = 0
        for (i in 0 until n) {
            if (confidence.get(i) > 0.5f) {
                mask[i] = true
                subjectPixels++
            }
        }
        // A subject that fills almost nothing or almost everything doesn't help (as on iOS).
        val fraction = subjectPixels.toDouble() / n
        return if (fraction in 0.005..0.95) mask else null
    }
}
