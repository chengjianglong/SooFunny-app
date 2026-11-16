package com.chengjianglong.soofunny.ui.books

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.itemsIndexed
import com.chengjianglong.soofunny.core.ScannedBookStore
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Speech
import com.chengjianglong.soofunny.core.StoryBook
import com.chengjianglong.soofunny.core.StoryLibrary
import com.chengjianglong.soofunny.ui.BouncyTitle
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.LanguageSwitch
import com.chengjianglong.soofunny.ui.ReadAlongText
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.gradient
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.squishClickable
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The Books tab: picture books that read themselves aloud, in English, Chinese or both. */
@Composable
fun BooksTab() {
    val context = LocalContext.current
    val lang = language
    var openId by rememberSaveable { mutableStateOf<String?>(null) }
    var myBookId by rememberSaveable { mutableStateOf<String?>(null) }
    val myBook = myBookId?.let { ScannedBookStore.book(it) }
    if (myBook != null) {
        MyBookScreen(myBook, onClose = { myBookId = null })
        return
    }
    if (myBookId != null) myBookId = null // deleted
    var review by remember { mutableStateOf<ReviewRequest?>(null) }
    review?.let { request ->
        BackHandler { review = null }
        ReviewScreen(request, onDone = { saved -> review = null; if (saved != null) myBookId = saved.id })
        return
    }
    val book = openId?.let { id -> StoryLibrary.books(context).firstOrNull { it.id == id } }
    if (book != null) {
        BackHandler { openId = null }
        // Switching language starts the book again from its first page in the new language.
        androidx.compose.runtime.key(lang) { BookReader(book, lang, onClose = { openId = null }) }
        return
    }
    val shelf = StoryLibrary.shelf(context, lang)
    Column(Modifier.fillMaxSize().background(Color.White)) {
        SooTopBar()
        LazyVerticalGrid(
            // As on iOS: covers at least 150 wide on phones and 200 on tablets, at least two per row.
            columns = com.chengjianglong.soofunny.ui.AtLeastColumns(
                if (androidx.compose.ui.platform.LocalConfiguration.current.screenWidthDp >= 600) 200.dp else 150.dp),
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    BouncyTitle()
                    Text(lang.pick("Pick a book and listen along!", "选一本书，一起听吧！", "\n"),
                        style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                        color = Color.Gray, textAlign = TextAlign.Center)
                }
            }
            item(span = { GridItemSpan(maxLineSpan) }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("📚", fontSize = 28.sp)
                    Text(lang.pick("Story time", "故事时间"), fontSize = 24.sp, fontWeight = FontWeight.ExtraBold,
                        modifier = Modifier.padding(start = 8.dp))
                }
            }
            itemsIndexed(shelf, key = { _, b -> b.id }) { i, b ->
                StoryCover(b, b.title(lang), tilt = if (i % 2 == 0) -2f else 2f) { openId = b.id }
            }
            item(span = { GridItemSpan(maxLineSpan) }) {
                MyBooksHeader(onPages = { pages -> review = ReviewRequest(book = null, scans = pages) })
            }
            items(ScannedBookStore.books, key = { "my-" + it.id }) { b ->
                ScannedCover(b) { myBookId = b.id }
            }
        }
    }
}

@Composable
private fun StoryCover(book: StoryBook, title: String, tilt: Float, onClick: () -> Unit) {
    val color = KidColors.named(book.color)
    val shape = RoundedCornerShape(20.dp)
    Column(
        Modifier.rotate(tilt).squishClickable(onClick = onClick).shadow(6.dp, shape, ambientColor = color, spotColor = color)
            .clip(shape).border(4.dp, Color.White, shape).background(Color.White),
    ) {
        Box(
            Modifier.fillMaxWidth().heightIn(min = 140.dp)
                .background(Brush.verticalGradient(listOf(color.copy(alpha = 0.45f), color.copy(alpha = 0.15f)))),
            contentAlignment = Alignment.Center,
        ) { Text(book.cover, fontSize = 72.sp) }
        Box(Modifier.fillMaxWidth().heightIn(min = 56.dp).background(color.gradient()).padding(horizontal = 8.dp, vertical = 6.dp),
            contentAlignment = Alignment.Center) {
            Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp, textAlign = TextAlign.Center,
                maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
    }
}

/**
 * A picture book, full screen: swipe or tap the arrows to turn pages, and tap Read to me to hear
 * it with each word lighting up. While reading, pages turn by themselves.
 */
@Composable
private fun BookReader(book: StoryBook, lang: LearningLanguage, onClose: () -> Unit) =
    ReaderScreen(
        title = book.title(lang).replace("\n", " · "), color = KidColors.named(book.color),
        pages = book.pages.indices.map { ReaderPage(book.pageText(it, lang), scene = book.pages[it].scene) },
        showsLanguageSwitch = true, onClose = onClose,
    )

/** One page in the reader: the words, and either an emoji picture or a scanned photo. */
data class ReaderPage(val text: String, val scene: String? = null, val image: java.io.File? = null)

@Composable
fun ReaderScreen(title: String, color: Color, pages: List<ReaderPage>, showsLanguageSwitch: Boolean, onClose: () -> Unit) {
    val lang = language
    val pager = rememberPagerState { pages.size }
    val scope = rememberCoroutineScope()
    var playing by remember { mutableStateOf(false) }
    var finished by remember { mutableStateOf(false) }
    val index = pager.currentPage

    fun readPage(i: Int) {
        Speech.speak(pages[i].text) {
            if (!playing) return@speak
            if (i < pages.lastIndex) {
                scope.launch { delay(800); if (playing) pager.animateScrollToPage(i + 1) }
            } else {
                playing = false
                finished = true
            }
        }
    }

    // Turning the page reads the new one while playing, and stops the voice otherwise.
    LaunchedEffect(index) {
        finished = false
        if (playing) readPage(index) else Speech.stop()
    }
    DisposableEffect(Unit) { onDispose { Speech.stop() } }

    Column(Modifier.fillMaxSize().background(color.copy(alpha = 0.12f))) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(44.dp).clip(RoundedCornerShape(50)).background(color.copy(alpha = 0.25f)).squishClickable(onClick = onClose),
                contentAlignment = Alignment.Center) { Text("✕", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = color) }
            Text(title, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center, modifier = Modifier.weight(1f).padding(horizontal = 8.dp))
            Text("${index + 1}/${pages.size}", fontWeight = FontWeight.Bold, color = Color.Gray)
            if (showsLanguageSwitch) LanguageSwitch()
        }
        HorizontalPager(pager, Modifier.weight(1f)) { page ->
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(24.dp),
            ) {
                val shape = RoundedCornerShape(32.dp)
                val photo = pages[page].image
                if (photo != null) {
                    PagePhoto(photo, Modifier.widthIn(max = 760.dp).fillMaxWidth().heightIn(max = 420.dp))
                } else Box(
                    Modifier.widthIn(max = 760.dp).fillMaxWidth().heightIn(min = 240.dp)
                        .shadow(10.dp, shape, ambientColor = color, spotColor = color).clip(shape)
                        .background(Color.White).background(Brush.verticalGradient(listOf(color.copy(alpha = 0.35f), color.copy(alpha = 0.12f))))
                        .border(5.dp, Color.White, shape).padding(24.dp),
                    contentAlignment = Alignment.Center,
                ) { Text(pages[page].scene ?: "📖", fontSize = 80.sp, maxLines = 1, softWrap = false) }
                ReadAlongText(
                    pages[page].text, fontSize = 26, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.widthIn(max = 760.dp).fillMaxWidth()
                        .clickable(remember { MutableInteractionSource() }, null) { playing = true; finished = false; readPage(page) },
                )
                AnimatedVisibility(finished && page == pages.lastIndex, enter = scaleIn() + fadeIn()) {
                    Text(lang.pick("The End", "完") + " 🎉", fontSize = 40.sp, fontWeight = FontWeight.ExtraBold, color = color)
                }
            }
        }
        Surface(color = Color.White.copy(alpha = 0.9f)) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedButton(onClick = { scope.launch { pager.animateScrollToPage(index - 1) } }, enabled = index > 0,
                    modifier = Modifier.size(56.dp), contentPadding = PaddingValues(0.dp)) { Text("←", fontSize = 22.sp, fontWeight = FontWeight.Bold) }
                Button(
                    onClick = {
                        if (playing) { playing = false; Speech.stop() } else { playing = true; finished = false; readPage(index) }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = color),
                    modifier = Modifier.widthIn(max = 320.dp).weight(1f, fill = false).heightIn(min = 56.dp),
                ) {
                    Text(
                        if (playing) "■ " + lang.pick("Stop", "停") else "▶ " + lang.pick("Read to me", "读给我听", "\n"),
                        fontSize = if (lang == LearningLanguage.BOTH) 16.sp else 20.sp, fontWeight = FontWeight.ExtraBold,
                        textAlign = TextAlign.Center,
                    )
                }
                OutlinedButton(onClick = { scope.launch { pager.animateScrollToPage(index + 1) } }, enabled = index < pages.lastIndex,
                    modifier = Modifier.size(56.dp), contentPadding = PaddingValues(0.dp)) { Text("→", fontSize = 22.sp, fontWeight = FontWeight.Bold) }
            }
        }
    }
}
