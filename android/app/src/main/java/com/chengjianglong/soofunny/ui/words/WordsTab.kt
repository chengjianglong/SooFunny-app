package com.chengjianglong.soofunny.ui.words

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.AppSettings
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Speech
import com.chengjianglong.soofunny.core.WordCategory
import com.chengjianglong.soofunny.core.WordDictionary
import com.chengjianglong.soofunny.core.WordEntry
import com.chengjianglong.soofunny.core.WordPhotos
import com.chengjianglong.soofunny.core.rememberAssetImage
import com.chengjianglong.soofunny.ui.BouncyTitle
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.SpeakButton
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.squishClickable

private val GroupedBackground = Color(0xFFF2F2F7)
private val tints = listOf(KidColors.Pink, KidColors.Orange, KidColors.Yellow, KidColors.Green, KidColors.Teal, KidColors.Blue, KidColors.Indigo, KidColors.Purple)
fun tileColor(index: Int) = tints[index % tints.size]

/** The word browser: groups → words → one word. Back returns up a level. */
@Composable
fun WordsTab() {
    val context = LocalContext.current
    val categories = remember { runCatching { WordDictionary.load(context) }.getOrNull() }
    var categoryIndex by rememberSaveable { mutableStateOf<Int?>(null) }
    var wordIndex by rememberSaveable { mutableStateOf<Int?>(null) }

    if (categories == null) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(language.pick("Couldn't open the words", "打不开单词"))
        }
        return
    }
    val category = categoryIndex?.let { categories.getOrNull(it) }
    when {
        category != null && wordIndex != null -> {
            BackHandler { wordIndex = null; Speech.stop() }
            WordDetail(category, wordIndex!!, onIndex = { wordIndex = it }, onBack = { wordIndex = null; Speech.stop() })
        }
        category != null -> {
            BackHandler { categoryIndex = null; Speech.stop() }
            WordList(category, onOpen = { wordIndex = it }, onBack = { categoryIndex = null; Speech.stop() })
        }
        else -> CategoryGrid(categories, onOpen = { categoryIndex = it })
    }
}

@Composable
private fun CategoryGrid(categories: List<WordCategory>, onOpen: (Int) -> Unit) {
    val lang = language
    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar()
        LazyVerticalGrid(
            columns = GridCells.Adaptive(300.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    BouncyTitle()
                    Text(
                        lang.pick("Pick a group of words to explore!", "选一组词来学习吧！", "\n"),
                        style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                        color = Color.Gray, textAlign = TextAlign.Center,
                    )
                }
            }
            itemsIndexed(categories) { index, category ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White)
                        .clickable { onOpen(index) }.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    EmojiTile(category.emoji, category.name, 56.dp, tileColor(index))
                    Column(Modifier.weight(1f).padding(start = 14.dp)) {
                        WordName(category.name, category.chinese, lang, fontSize = 20, fontWeight = FontWeight.Bold)
                        Text(lang.pick("${category.words.size} words", "${category.words.size}个词"), color = Color.Gray, fontSize = 14.sp)
                    }
                    SpeakButton(lang.spoken(category.name, category.chinese), size = 18)
                    Text("›", fontSize = 26.sp, color = Color.LightGray)
                }
            }
        }
    }
}

@Composable
private fun WordList(category: WordCategory, onOpen: (Int) -> Unit, onBack: () -> Unit) {
    val lang = language
    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar(title = category.title(lang), onBack = onBack)
        LazyVerticalGrid(
            columns = GridCells.Adaptive(320.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            itemsIndexed(category.words) { index, word ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White)
                        .clickable { onOpen(index) }.padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("${index + 1}", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.widthIn(min = 26.dp))
                    WordPicture(category, word, 60.dp, tileColor(index))
                    WordName(word.text, word.chinese, lang, fontSize = 22, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f).padding(start = 12.dp), singleLine = true)
                    SpeakButton(lang.spoken(word.text, word.chinese))
                }
            }
        }
    }
}

/** One word, big: its picture, the word to hear, and its letters to tap one by one. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun WordDetail(category: WordCategory, index: Int, onIndex: (Int) -> Unit, onBack: () -> Unit) {
    val lang = language
    val words = category.words
    val word = words[index]
    val spoken = lang.spoken(word.text, word.chinese)
    // Say the word on opening, on Previous / Next, and again in a newly picked language.
    LaunchedEffect(index, lang) { Speech.speak(spoken) }

    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar(title = category.title(lang), onBack = onBack)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            AnimatedContent(targetState = index, label = "word") { i ->
                Box(Modifier.squishClickable { Speech.speak(lang.spoken(words[i].text, words[i].chinese)) }) {
                    WordPicture(category, words[i], 240.dp, tileColor(i))
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                WordName(word.text, word.chinese, lang, fontSize = 52, fontWeight = FontWeight.ExtraBold, stacked = true,
                    modifier = Modifier.weight(1f, fill = false))
                SpeakButton(spoken, size = 30)
            }
            if (lang != LearningLanguage.CHINESE || word.chinese == null) FlowLetters(word.text)
            if (lang != LearningLanguage.ENGLISH && word.chinese != null) FlowLetters(word.chinese)
            Row(Modifier.widthIn(max = 480.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                OutlinedButton(onClick = { onIndex(index - 1) }, enabled = index > 0, modifier = Modifier.weight(1f)) {
                    Text("← " + lang.pick("Previous", "上一个"), fontWeight = FontWeight.Bold)
                }
                OutlinedButton(onClick = { onIndex(index + 1) }, enabled = index < words.lastIndex, modifier = Modifier.weight(1f)) {
                    Text(lang.pick("Next", "下一个") + " →", fontWeight = FontWeight.Bold)
                }
            }
            Text(
                lang.pick("${index + 1} of ${words.size} in ${category.name}",
                    "${category.chinese ?: category.name}：第${index + 1}个，共${words.size}个"),
                fontSize = 13.sp, color = Color.Gray,
            )
        }
    }
}

/** Each letter (or Chinese character) can be heard on its own. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FlowLetters(text: String) {
    FlowRow(
        Modifier.widthIn(max = 520.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        var offset = 0
        text.codePoints().toArray().forEach { cp ->
            val letter = String(Character.toChars(cp))
            val i = offset++
            if (Character.isLetter(cp)) {
                Box(
                    Modifier.size(52.dp).clip(RoundedCornerShape(12.dp)).background(tileColor(i).copy(alpha = 0.25f))
                        .squishClickable { Speech.speak(letter.lowercase()) },
                    contentAlignment = Alignment.Center,
                ) { Text(letter.uppercase(), fontSize = 28.sp, fontWeight = FontWeight.Bold) }
            } else {
                Spacer(Modifier.size(52.dp))
            }
        }
    }
}

/** A word or group name in the chosen language: English, Chinese, or both (stacked on a word's own page). */
@Composable
fun WordName(
    english: String, chinese: String?, lang: LearningLanguage,
    modifier: Modifier = Modifier, fontSize: Int = 20, fontWeight: FontWeight = FontWeight.Bold,
    stacked: Boolean = false, singleLine: Boolean = false,
) {
    val text = when {
        chinese != null && lang == LearningLanguage.CHINESE -> chinese
        chinese != null && lang == LearningLanguage.BOTH -> if (stacked) "$english\n$chinese" else "$english  $chinese"
        else -> english
    }
    Text(
        text, modifier = modifier, fontSize = fontSize.sp, fontWeight = fontWeight, lineHeight = (fontSize * 1.15).sp,
        textAlign = if (stacked) TextAlign.Center else TextAlign.Start,
        maxLines = if (singleLine) 1 else 3, overflow = TextOverflow.Ellipsis,
    )
}

/** The word's emoji, or its first letter on a colored tile when there is none. */
@Composable
fun EmojiTile(emoji: String?, word: String, size: Dp, tint: Color) {
    Box(
        Modifier.size(size).clip(RoundedCornerShape(size * 0.24f)).background(tint.copy(alpha = 0.18f)),
        contentAlignment = Alignment.Center,
    ) {
        if (emoji != null) Text(emoji, fontSize = (size.value * 0.55f).sp)
        else Text(word.take(1).uppercase(), fontSize = (size.value * 0.5f).sp, fontWeight = FontWeight.ExtraBold, color = tint)
    }
}

/** The word's real photo with its emoji stuck on the corner like a sticker; the emoji tile when there's no photo. */
@Composable
fun WordPicture(category: WordCategory, word: WordEntry, size: Dp, tint: Color) =
    PhotoWithSticker(WordPhotos.path(category.name, word.text), word.emoji, word.text, size, tint)

@Composable
fun PhotoWithSticker(photoPath: String?, emoji: String?, word: String, size: Dp, tint: Color) {
    val photo = rememberAssetImage(photoPath, maxSize = if (size > 120.dp) 900 else 256)
    if (photo == null) {
        EmojiTile(emoji, word, size, tint)
        return
    }
    val hasSticker = emoji != null
    Box(Modifier.padding(end = if (hasSticker) size * 0.1f else 0.dp, bottom = if (hasSticker) size * 0.08f else 0.dp)) {
        Image(
            photo, contentDescription = null, contentScale = ContentScale.Crop,
            modifier = Modifier.size(size).shadow(size * 0.04f, RoundedCornerShape(size * 0.2f))
                .clip(RoundedCornerShape(size * 0.2f))
                .border(maxOf(2.dp, size * 0.03f), Color.White, RoundedCornerShape(size * 0.2f)),
        )
        if (hasSticker) {
            Box(
                Modifier.align(Alignment.BottomEnd).offset(x = size * 0.1f, y = size * 0.08f).rotate(8f)
                    .clip(RoundedCornerShape(size * 0.1f)).background(Color.White),
            ) { EmojiTile(emoji, word, size * 0.42f, tint) }
        }
    }
}
