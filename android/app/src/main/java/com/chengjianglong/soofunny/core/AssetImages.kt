package com.chengjianglong.soofunny.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.runtime.Composable
import androidx.compose.runtime.produceState
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException

/** Photos bundled in the APK's assets (copied from the iOS app at build time), decoded off the main thread and cached. */
object AssetImages {
    private val cache = object : LruCache<String, Bitmap>(48 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }
    private val missing = mutableSetOf<String>()
    private var names: Map<String, Set<String>> = emptyMap()

    /** Whether an asset exists, without decoding it. */
    fun exists(context: Context, path: String): Boolean {
        val dir = path.substringBeforeLast('/', "")
        val listing = synchronized(this) {
            names[dir] ?: (context.assets.list(dir)?.toSet() ?: emptySet()).also { names = names + (dir to it) }
        }
        return path.substringAfterLast('/') in listing
    }

    /** Decodes [path] so its longer side is about [maxSize] pixels (never upscaled). Null if missing. */
    fun load(context: Context, path: String, maxSize: Int = 512): Bitmap? {
        val key = "$path@$maxSize"
        cache.get(key)?.let { return it }
        if (path in missing || !exists(context, path)) return null
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.assets.open(path).use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSize) sample *= 2
            val bitmap = context.assets.open(path).use {
                BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
            }
            bitmap?.also { cache.put(key, it) }
        } catch (_: IOException) {
            synchronized(missing) { missing += path }
            null
        }
    }

    /** The full-size picture (capped at [maxSize]), e.g. for coloring. */
    fun loadFull(context: Context, path: String, maxSize: Int = 1600): Bitmap? = load(context, path, maxSize)
}

/** Loads an asset photo in the background; null while loading or when there's no such photo. */
@Composable
fun rememberAssetImage(path: String?, maxSize: Int = 512): ImageBitmap? {
    val context = LocalContext.current
    return produceState<ImageBitmap?>(null, path, maxSize) {
        value = path?.let { withContext(Dispatchers.IO) { AssetImages.load(context, it, maxSize)?.asImageBitmap() } }
    }.value
}
