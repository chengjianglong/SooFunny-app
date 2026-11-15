package com.chengjianglong.soofunny.ui.books

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.PageReader
import com.chengjianglong.soofunny.core.PageScan
import com.chengjianglong.soofunny.core.ScannedBook
import com.chengjianglong.soofunny.core.ScannedBookStore
import com.chengjianglong.soofunny.ui.KidButton
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.squishClickable
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

private val GroupedBackground = Color(0xFFF2F2F7)

/** Pages to read into a new book ([book] null) or into an existing one (new pages go at the end). */
data class ReviewRequest(val book: ScannedBook?, val scans: List<Uri>)

/** Scan with the system document scanner, or pick from Photos; [onPages] gets the page photos. */
class PageSources(val scan: () -> Unit, val photos: () -> Unit)

@Composable
fun rememberPageSources(onPages: (List<Uri>) -> Unit): PageSources {
    val context = LocalContext.current
    var scannerMissing by remember { mutableStateOf(false) }
    val scanLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val pages = GmsDocumentScanningResult.fromActivityResultIntent(result.data)?.pages.orEmpty().map { it.imageUri }
            if (pages.isNotEmpty()) onPages(pages)
        }
    }
    val photoLauncher = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(100)) { uris ->
        if (uris.isNotEmpty()) onPages(uris)
    }
    if (scannerMissing) {
        val lang = language
        AlertDialog(
            onDismissRequest = { scannerMissing = false },
            confirmButton = { TextButton(onClick = { scannerMissing = false }) { Text(lang.pick("OK", "好")) } },
            title = { Text(lang.pick("The scanner isn't available", "扫描功能用不了")) },
            text = { Text(lang.pick("This device can't scan right now. Take photos of the pages and add them From Photos instead.",
                "这台设备暂时不能扫描。可以先给书页拍照，再用“从照片添加”。")) },
        )
    }
    return remember(context) {
        PageSources(
            scan = {
                val activity = context.findActivity()
                if (activity == null) {
                    scannerMissing = true
                } else {
                    val options = GmsDocumentScannerOptions.Builder()
                        .setGalleryImportAllowed(false)
                        .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
                        .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
                        .build()
                    GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
                        .addOnSuccessListener { scanLauncher.launch(IntentSenderRequest.Builder(it).build()) }
                        .addOnFailureListener { scannerMissing = true }
                }
            },
            photos = { photoLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
        )
    }
}

private fun Context.findActivity(): Activity? {
    var c: Context? = this
    while (c is ContextWrapper) {
        if (c is Activity) return c
        c = c.baseContext
    }
    return null
}

/** "My books" on the Books shelf: what it is, and Scan a book / From Photos. */
@Composable
fun MyBooksHeader(onPages: (List<Uri>) -> Unit) {
    val lang = language
    val sources = rememberPageSources(onPages)
    Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(top = 12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("📷", fontSize = 28.sp)
            Text(lang.pick("My books", "我的书"), fontSize = 24.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.padding(start = 8.dp))
        }
        Text(
            lang.pick("Scan the pages of a book you own, in English, Chinese or both, as many pages as it has. SooFunny reads the words on your device and turns them into a read-along book.",
                "扫描你自己的书，英文、中文或双语都可以，想扫多少页都行。SooFunny 在设备上识别文字，把它变成能跟读的书。", "\n"),
            fontSize = 14.sp, color = Color.Gray,
        )
        Row(Modifier.widthIn(max = 560.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            KidButton(lang.pick("Scan a book", "扫描书本"), KidColors.Orange, Modifier.weight(1f).heightIn(min = 54.dp), emoji = "📄", onClick = sources.scan)
            KidButton(lang.pick("From Photos", "从照片添加"), KidColors.Pink, Modifier.weight(1f).heightIn(min = 54.dp), emoji = "🖼️", onClick = sources.photos)
        }
    }
}

/** A page photo from a file, decoded in the background. */
@Composable
fun PagePhoto(file: File, modifier: Modifier = Modifier, maxSize: Int = 1200, crop: Boolean = false) {
    var image by remember(file) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(file) {
        image = withContext(Dispatchers.IO) { decodeFile(file, maxSize)?.asImageBitmap() }
    }
    val shape = RoundedCornerShape(16.dp)
    Box(modifier.shadow(6.dp, shape).clip(shape).background(Color.White), contentAlignment = Alignment.Center) {
        val bitmap = image
        if (bitmap == null) CircularProgressIndicator(Modifier.padding(24.dp))
        else Image(bitmap, null, contentScale = if (crop) ContentScale.Crop else ContentScale.Fit,
            modifier = if (crop) Modifier.fillMaxSize() else Modifier.fillMaxWidth())
    }
}

private fun decodeFile(file: File, maxSize: Int): android.graphics.Bitmap? = runCatching {
    val bounds = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
    android.graphics.BitmapFactory.decodeFile(file.path, bounds)
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSize) sample *= 2
    android.graphics.BitmapFactory.decodeFile(file.path, android.graphics.BitmapFactory.Options().apply { inSampleSize = sample })
}.getOrNull()

/** A scanned book on the shelf: its first page as the cover. */
@Composable
fun ScannedCover(book: ScannedBook, onClick: () -> Unit) {
    val lang = language
    val shape = RoundedCornerShape(20.dp)
    Column(Modifier.squishClickable(onClick = onClick).shadow(6.dp, shape).clip(shape).border(4.dp, Color.White, shape).background(Color.White)) {
        val first = book.pages.firstOrNull()
        Box(Modifier.fillMaxWidth().aspectRatio(0.9f).background(KidColors.Orange.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
            if (first != null) PagePhoto(ScannedBookStore.imageFile(book, first), Modifier.fillMaxSize(), maxSize = 400, crop = true)
            else Text("📖", fontSize = 60.sp)
        }
        Column(Modifier.fillMaxWidth().background(KidColors.Orange).padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(book.title, color = Color.White, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
            Text(lang.pick("${book.pages.size} ${if (book.pages.size == 1) "page" else "pages"}", "${book.pages.size}页"), color = Color.White, fontSize = 13.sp)
        }
    }
}

/** A saved book: read it along, add pages, fix the words or the page order, or delete it. */
@Composable
fun MyBookScreen(book: ScannedBook, onClose: () -> Unit) {
    val lang = language
    var reading by remember { mutableStateOf(false) }
    var review by remember { mutableStateOf<ReviewRequest?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    val sources = rememberPageSources { review = ReviewRequest(book, it) }

    review?.let { request ->
        BackHandler { review = null }
        ReviewScreen(request, onDone = { review = null })
        return
    }
    if (reading) {
        BackHandler { reading = false }
        ReaderScreen(
            title = book.title, color = KidColors.Orange,
            pages = book.pages.map { ReaderPage(it.text, image = ScannedBookStore.imageFile(book, it)) },
            showsLanguageSwitch = false, onClose = { reading = false },
        )
        return
    }
    BackHandler(onBack = onClose)
    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar(title = book.title, onBack = onClose)
        LazyColumn(
            Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                book.pages.firstOrNull()?.let { PagePhoto(ScannedBookStore.imageFile(book, it), Modifier.widthIn(max = 420.dp).fillMaxWidth().heightIn(max = 360.dp)) }
            }
            item { Text(book.title, fontSize = 28.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.Center) }
            item { Text(lang.pick("${book.pages.size} ${if (book.pages.size == 1) "page" else "pages"}", "${book.pages.size}页"), color = Color.Gray) }
            item {
                KidButton(lang.pick("Read along", "跟读"), KidColors.Orange, Modifier.widthIn(max = 480.dp).fillMaxWidth().heightIn(min = 56.dp),
                    emoji = "📖", enabled = book.pages.isNotEmpty()) { reading = true }
            }
            item { AudiobookSection(book) }
            item {
                Column(Modifier.widthIn(max = 480.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = sources.scan, modifier = Modifier.fillMaxWidth()) { Text("📄 " + lang.pick("Scan more pages", "继续扫描")) }
                    OutlinedButton(onClick = sources.photos, modifier = Modifier.fillMaxWidth()) { Text("🖼️ " + lang.pick("Add pages from Photos", "从照片添加页面")) }
                    OutlinedButton(onClick = { review = ReviewRequest(book, emptyList()) }, modifier = Modifier.fillMaxWidth()) {
                        Text("✏️ " + lang.pick("Fix the words or page order", "修改文字或页面顺序"))
                    }
                    TextButton(onClick = { confirmDelete = true }, modifier = Modifier.fillMaxWidth()) {
                        Text("🗑️ " + lang.pick("Delete book", "删除这本书"), color = KidColors.Red)
                    }
                }
            }
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text(lang.pick("Delete ${book.title}?", "删除《${book.title}》？")) },
            text = { Text(lang.pick("Its pages and audiobook will be removed from this device.", "它的页面和有声书会从这台设备上删除。")) },
            confirmButton = {
                TextButton(onClick = { confirmDelete = false; ScannedBookStore.delete(book); onClose() }) {
                    Text(lang.pick("Delete", "删除"), color = KidColors.Red)
                }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(lang.pick("Cancel", "取消")) } },
        )
    }
}

/** One page in the review list: a saved page, or a new scan. Its words can be fixed. */
private class ReviewItem(val page: ScannedBook.Page?, val scan: PageScan?, val image: File, text: String) {
    var text by mutableStateOf(text)
}

/**
 * Reads new pages on the device, then lets a grown-up name the book, fix the words, remove pages
 * and change their order before saving. With an existing book, its pages come first.
 */
@Composable
fun ReviewScreen(request: ReviewRequest, onDone: (ScannedBook?) -> Unit) {
    val context = LocalContext.current
    val lang = language
    val scope = rememberCoroutineScope()
    val book = request.book
    val items = remember {
        mutableStateListOf<ReviewItem>().apply {
            book?.pages?.forEach { add(ReviewItem(it, null, ScannedBookStore.imageFile(book, it), it.text)) }
        }
    }
    var title by remember { mutableStateOf(book?.title ?: "") }
    var readCount by remember { mutableIntStateOf(0) }
    val reading = readCount < request.scans.size
    var saveFailed by remember { mutableStateOf(false) }
    val sources = rememberPageSources { uris ->
        scope.launch { uris.forEach { uri -> PageReader.read(context, uri)?.let { items += ReviewItem(null, it, it.file, it.text) } } }
    }

    LaunchedEffect(request) {
        request.scans.forEach { uri ->
            PageReader.read(context, uri)?.let { items += ReviewItem(null, it, it.file, it.text) }
            readCount += 1
        }
    }

    fun cancel() {
        items.mapNotNull { it.scan?.file }.forEach { it.delete() }
        onDone(null)
    }

    fun save() {
        runCatching {
            if (book == null) {
                ScannedBookStore.add(title, items.map { it.scan!!.copy(text = it.text) })
            } else {
                ScannedBookStore.update(book, title, items.map { item -> item.page?.copy(text = item.text) to item.scan?.copy(text = item.text) })
            }
        }.onSuccess { onDone(it) }.onFailure { saveFailed = true }
    }

    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar(
            title = if (book == null) lang.pick("New book", "新书") else lang.pick("Edit book", "编辑书"),
            onBack = ::cancel, backLabel = lang.pick("Cancel", "取消"),
            actions = {
                TextButton(onClick = ::save, enabled = !reading && items.isNotEmpty()) { Text(lang.pick("Save", "保存"), fontWeight = FontWeight.Bold) }
            },
        )
        LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (reading) item {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(lang.pick("Reading page ${readCount + 1} of ${request.scans.size}… The words are read on this device.",
                        "正在识别第${readCount + 1}页，共${request.scans.size}页……文字在设备上识别。", "\n"), fontSize = 14.sp)
                    LinearProgressIndicator(progress = { readCount.toFloat() / request.scans.size }, modifier = Modifier.fillMaxWidth())
                }
            }
            item {
                OutlinedTextField(title, { title = it }, label = { Text(lang.pick("Book name", "书名")) }, singleLine = true, modifier = Modifier.fillMaxWidth())
            }
            itemsIndexed(items, key = { _, item -> item.image.path }) { index, item ->
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White).padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(lang.pick("Page ${index + 1}", "第${index + 1}页"), fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                        TextButton(onClick = { items.add(index - 1, items.removeAt(index)) }, enabled = index > 0) { Text("↑") }
                        TextButton(onClick = { items.add(index + 1, items.removeAt(index)) }, enabled = index < items.lastIndex) { Text("↓") }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        PagePhoto(item.image, Modifier.size(96.dp), maxSize = 300, crop = true)
                        OutlinedTextField(
                            item.text, { item.text = it }, modifier = Modifier.weight(1f).heightIn(min = 96.dp),
                            placeholder = { Text(lang.pick("No words found. Type them here, or leave it as a picture page.", "没有找到文字。可以在这里输入，或者当作图画页。"), fontSize = 13.sp) },
                        )
                    }
                    TextButton(onClick = { items.removeAt(index); item.scan?.file?.delete() }) {
                        Text(lang.pick("Remove page", "删除这一页"), color = KidColors.Red)
                    }
                }
            }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = sources.scan, modifier = Modifier.fillMaxWidth()) { Text("📄 " + lang.pick("Scan more pages", "继续扫描")) }
                    OutlinedButton(onClick = sources.photos, modifier = Modifier.fillMaxWidth()) { Text("🖼️ " + lang.pick("Add pages from Photos", "从照片添加页面")) }
                    Text(lang.pick("Add as many pages as the book has. New pages go at the end; move them with ↑ and ↓.",
                        "书有多少页就加多少页。新页面放在最后，可以用 ↑ 和 ↓ 移动。", "\n"), fontSize = 13.sp, color = Color.Gray)
                }
            }
        }
    }
    if (saveFailed) {
        AlertDialog(
            onDismissRequest = { saveFailed = false },
            confirmButton = { TextButton(onClick = { saveFailed = false }) { Text(lang.pick("OK", "好")) } },
            title = { Text(lang.pick("Couldn't save the book", "保存不了这本书")) },
            text = { Text(lang.pick("Please check there's space on this device and try again.", "请检查设备空间，然后再试一次。")) },
        )
    }
}
