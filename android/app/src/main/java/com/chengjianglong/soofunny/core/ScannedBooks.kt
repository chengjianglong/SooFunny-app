package com.chengjianglong.soofunny.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import androidx.compose.runtime.mutableStateListOf
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** A book the family scanned or added from photos: page photos and the words read from them. */
data class ScannedBook(
    val id: String,
    val title: String,
    val created: Long,
    val pages: List<Page>,
    /** "zh" for a mostly-Chinese book, "en" otherwise: the voice for text with no letters. */
    val language: String,
) {
    /** [image] is the photo's file name inside the book's folder. */
    data class Page(val image: String, val text: String)

    val bookLanguage: BookLanguage get() = if (language == "zh") BookLanguage.CHINESE else BookLanguage.ENGLISH
}

/** A page photo waiting to become part of a book (saved as a JPEG in the cache) and its words. */
data class PageScan(val id: String = UUID.randomUUID().toString(), val file: File, val text: String)

/**
 * Scanned books, kept in the app's own files folder (`files/books/<id>/`), never in shared storage.
 */
object ScannedBookStore {
    val books = mutableStateListOf<ScannedBook>()
    private var root: File? = null

    fun init(context: Context) {
        if (root != null) return
        val dir = File(context.filesDir, "books").apply { mkdirs() }
        root = dir
        books.clear()
        books += dir.listFiles().orEmpty().mapNotNull { folder ->
            runCatching { fromJson(JSONObject(File(folder, "book.json").readText())) }.getOrNull()
        }.sortedByDescending { it.created }
    }

    private fun dir() = requireNotNull(root) { "ScannedBookStore.init was not called" }
    fun folder(book: ScannedBook) = File(dir(), book.id)
    fun imageFile(book: ScannedBook, page: ScannedBook.Page) = File(folder(book), page.image)
    fun book(id: String) = books.firstOrNull { it.id == id }
    /** The book's audiobook, once made; changing the book's words or pages removes it. */
    fun audioFile(book: ScannedBook) = File(folder(book), "audiobook.m4a")

    /** Saves a new book from page scans (photos are moved into the book's folder). */
    fun add(title: String, pages: List<PageScan>): ScannedBook {
        val id = UUID.randomUUID().toString()
        val folder = File(dir(), id).apply { mkdirs() }
        val saved = pages.map { scan -> ScannedBook.Page(store(scan.file, folder), scan.text) }
        val book = ScannedBook(id, title.ifBlank { "My book" }, System.currentTimeMillis(), saved, languageOf(saved))
        save(book)
        books.add(0, book)
        return book
    }

    /** Replaces a book's title, text and page order; pages left out are deleted, new scans added. */
    fun update(book: ScannedBook, title: String, pages: List<Pair<ScannedBook.Page?, PageScan?>>): ScannedBook {
        val folder = folder(book)
        val kept = pages.map { (page, scan) ->
            when {
                page != null -> page.copy(text = scan?.text ?: page.text)
                scan != null -> ScannedBook.Page(store(scan.file, folder), scan.text)
                else -> error("empty page")
            }
        }
        val keptImages = kept.map { it.image }.toSet()
        book.pages.filter { it.image !in keptImages }.forEach { File(folder, it.image).delete() }
        val updated = book.copy(title = title.ifBlank { book.title }, pages = kept, language = languageOf(kept))
        if (updated.pages != book.pages) audioFile(book).delete()
        save(updated)
        val i = books.indexOfFirst { it.id == book.id }
        if (i >= 0) books[i] = updated
        return updated
    }

    fun delete(book: ScannedBook) {
        folder(book).deleteRecursively()
        books.removeAll { it.id == book.id }
    }

    private fun store(file: File, folder: File): String {
        val name = "page-${UUID.randomUUID()}.jpg"
        val target = File(folder, name)
        if (!file.renameTo(target)) {
            file.copyTo(target, overwrite = true)
            file.delete()
        }
        return name
    }

    private fun languageOf(pages: List<ScannedBook.Page>) =
        if (BookLanguage.detect(pages.joinToString(" ") { it.text }) == BookLanguage.CHINESE) "zh" else "en"

    private fun save(book: ScannedBook) {
        val json = JSONObject()
            .put("id", book.id).put("title", book.title).put("created", book.created).put("language", book.language)
            .put("pages", JSONArray(book.pages.map { JSONObject().put("image", it.image).put("text", it.text) }))
        val file = File(folder(book).apply { mkdirs() }, "book.json")
        val tmp = File(file.parentFile, "book.json.tmp")
        tmp.writeText(json.toString())
        tmp.renameTo(file)
    }

    private fun fromJson(o: JSONObject): ScannedBook {
        val pages = o.getJSONArray("pages").let { a -> (0 until a.length()).map { a.getJSONObject(it) } }
            .map { ScannedBook.Page(it.getString("image"), it.getString("text")) }
        return ScannedBook(o.getString("id"), o.getString("title"), o.getLong("created"), pages, o.optString("language", "en"))
    }
}

/** Reads the words on a page photo, on the device, with ML Kit's bundled Chinese-and-Latin model. */
object PageReader {
    private val recognizer by lazy { TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build()) }

    /** Copies a picked or scanned photo into the cache (at most 2000 px) and reads its words. */
    suspend fun read(context: Context, uri: Uri): PageScan? = withContext(Dispatchers.IO) {
        val bitmap = decode(context, uri) ?: return@withContext null
        val dir = File(context.cacheDir, "pages").apply { mkdirs() }
        val file = File(dir, "scan-${UUID.randomUUID()}.jpg")
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 85, it) }
        PageScan(file = file, text = text(bitmap))
    }

    suspend fun text(bitmap: Bitmap): String = suspendCancellableCoroutine { cont ->
        recognizer.process(InputImage.fromBitmap(bitmap, 0))
            .addOnSuccessListener { result ->
                val lines = result.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                    line.boundingBox?.let { OcrLine(line.text, line.confidence, it.left, it.top, it.right, it.bottom) }
                }
                cont.resume(reflow(lines))
            }
            .addOnFailureListener { cont.resume("") }
    }

    private fun decode(context: Context, uri: Uri, maxSize: Int = 2000): Bitmap? = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri)) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val longest = max(info.size.width, info.size.height)
                if (longest > maxSize) {
                    val scale = maxSize.toFloat() / longest
                    decoder.setTargetSize((info.size.width * scale).toInt(), (info.size.height * scale).toInt())
                }
            }
        } else {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSize) sample *= 2
            context.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
            }
        }
    }.getOrNull()

    /** A recognized line; the box is in pixels with the origin at the top left. */
    data class OcrLine(val text: String, val confidence: Float, val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val height get() = bottom - top
        val midY get() = (top + bottom) / 2f
    }

    /**
     * Turns recognized lines into reading text, as on iOS: top to bottom, lines joined into
     * sentences, hyphenated words put back together, page numbers and low-confidence scraps
     * dropped, a big gap starting a new paragraph, and Chinese lines joined without a space.
     */
    fun reflow(lines: List<OcrLine>): String {
        val kept = lines
            .filter { it.confidence >= 0.3f || it.confidence == 0f }
            .filter { line -> !line.text.trim().all { it.isDigit() } }
            .sortedWith { a, b ->
                if (abs(a.midY - b.midY) > min(a.height, b.height) / 2f) a.midY.compareTo(b.midY) else a.left.compareTo(b.left)
            }
        val result = StringBuilder()
        var previous: OcrLine? = null
        for (line in kept) {
            val text = line.text.trim()
            if (text.isEmpty()) continue
            val prev = previous
            if (prev == null) {
                result.append(text)
            } else {
                val gap = line.top - prev.bottom
                val last = result.lastOrNull()
                when {
                    gap > max(prev.height, line.height) * 1.2 -> result.append("\n\n").append(text)
                    last == '-' && text.first().isLowerCase() -> { result.setLength(result.length - 1); result.append(text) }
                    (last != null && BookLanguage.isHan(last.code)) || BookLanguage.isHan(text.codePointAt(0)) ||
                        (last != null && last in "，。！？；：、」』）") -> result.append(text)
                    else -> result.append(' ').append(text)
                }
            }
            previous = line
        }
        return result.toString()
    }
}
