package com.chengjianglong.soofunny.ui.sports

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Speech
import com.chengjianglong.soofunny.core.Sport
import com.chengjianglong.soofunny.core.SportSeason
import com.chengjianglong.soofunny.core.Sports
import com.chengjianglong.soofunny.core.rememberAssetImage
import com.chengjianglong.soofunny.ui.BouncyTitle
import com.chengjianglong.soofunny.ui.KidButton
import com.chengjianglong.soofunny.ui.buddy.BuddyScreen
import com.chengjianglong.soofunny.core.WordCategory
import com.chengjianglong.soofunny.core.WordEntry
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.ReadAlongText
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.gradient
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.squishClickable
import com.chengjianglong.soofunny.ui.words.EmojiTile
import com.chengjianglong.soofunny.ui.words.WordName

private val GroupedBackground = Color(0xFFF2F2F7)
private val sportTints = listOf(KidColors.Orange, KidColors.Pink, KidColors.Blue, KidColors.Green, KidColors.Purple, KidColors.Teal, KidColors.Red, KidColors.Indigo)
private fun sportTint(i: Int) = sportTints[i % sportTints.size]

/** The Sports tab: 51 summer and winter sports, each introduced in English, Chinese or both and read aloud. */
@Composable
fun SportsTab() {
    val context = LocalContext.current
    val all = remember { Sports.all(context) }
    var season by rememberSaveable { mutableStateOf(SportSeason.SUMMER) }
    var open by rememberSaveable { mutableStateOf<Int?>(null) }
    // Talking with the buddy about the open sport.
    var talking by rememberSaveable { mutableStateOf(false) }
    val sports = all.filter { it.season == season }

    val index = open
    if (index != null && talking) {
        val sport = sports[index]
        BuddyScreen(
            WordEntry(sport.english, sport.emoji, sport.chinese),
            WordCategory("${sport.season.english} sports", sport.season.emoji, "${sport.season.chinese}运动", emptyList()),
            facts = sport.aboutEnglish + " " + sport.aboutChinese,
            photoPaths = listOfNotNull(sport.photoPath),
            onClose = { talking = false; Speech.stop() },
        )
        return
    }
    if (index != null) {
        BackHandler { open = null; Speech.stop() }
        SportDetail(sports, season, index, onIndex = { open = it }, onTalk = { talking = true }, onBack = { open = null; Speech.stop() })
        return
    }

    val lang = language
    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar()
        LazyVerticalGrid(
            columns = GridCells.Adaptive(160.dp),
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    BouncyTitle()
                    Text(lang.pick("Discover summer and winter sports!", "认识夏季和冬季运动项目！", "\n"),
                        style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                        color = Color.Gray, textAlign = TextAlign.Center)
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        SportSeason.entries.forEach { option ->
                            SeasonChip(option, selected = option == season, count = all.count { it.season == option }, lang) { season = option }
                        }
                    }
                }
            }
            itemsIndexed(sports, key = { _, s -> s.id }) { i, sport ->
                Column(
                    Modifier.fillMaxWidth().heightIn(min = 190.dp).clip(RoundedCornerShape(18.dp)).background(Color.White)
                        .squishClickable { open = i }.padding(10.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
                ) {
                    SportPicture(sport, 96.dp, sportTint(i))
                    if (lang != LearningLanguage.CHINESE) Text(sport.english, fontWeight = FontWeight.Bold, fontSize = 17.sp, textAlign = TextAlign.Center, maxLines = 2)
                    if (lang != LearningLanguage.ENGLISH) Text(
                        sport.chinese, textAlign = TextAlign.Center,
                        fontWeight = if (lang == LearningLanguage.CHINESE) FontWeight.Bold else FontWeight.SemiBold,
                        fontSize = if (lang == LearningLanguage.CHINESE) 17.sp else 15.sp,
                        color = if (lang == LearningLanguage.CHINESE) Color.Unspecified else Color.Gray,
                    )
                }
            }
        }
    }
}

@Composable
private fun SeasonChip(option: SportSeason, selected: Boolean, count: Int, lang: LearningLanguage, onClick: () -> Unit) {
    val color = if (option == SportSeason.SUMMER) KidColors.Orange else KidColors.Blue
    val shape = RoundedCornerShape(50)
    Column(
        Modifier.heightIn(min = 56.dp).clip(shape)
            .then(if (selected) Modifier.background(color.gradient()) else Modifier.background(Color.White).border(2.dp, color.copy(alpha = 0.5f), shape))
            .squishClickable(onClick = onClick).padding(horizontal = 18.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
    ) {
        val fg = if (selected) Color.White else Color.Black
        val (top, bottom) = when (lang) {
            LearningLanguage.ENGLISH -> "${option.emoji} ${option.english}" to "$count sports"
            LearningLanguage.CHINESE -> "${option.emoji} ${option.chinese}" to "${count}项"
            LearningLanguage.BOTH -> "${option.emoji} ${option.english}" to "${option.chinese} · $count"
        }
        Text(top, color = fg, fontWeight = FontWeight.Bold, fontSize = 17.sp)
        Text(bottom, color = fg, fontSize = 14.sp)
    }
}

/** The sport's photo with its emoji as a sticker, or just the emoji on a colored tile. */
@Composable
private fun SportPicture(sport: Sport, size: Dp, tint: Color) {
    val photo = rememberAssetImage(sport.photoPath, if (size > 120.dp) 600 else 300)
    if (photo == null) {
        EmojiTile(sport.emoji, sport.english, size, tint)
        return
    }
    Box {
        Image(photo, null, contentScale = ContentScale.Crop, modifier = Modifier.size(size).clip(RoundedCornerShape(size * 0.2f)))
        Box(
            Modifier.align(Alignment.BottomEnd).offset(x = size * 0.06f, y = size * 0.06f).clip(CircleShape).background(Color.White).padding(size * 0.04f),
        ) { Text(sport.emoji, fontSize = (size.value * 0.22f).sp) }
    }
}

/**
 * One sport: its picture and names, then what it is. The name and then the introduction are read
 * aloud as soon as the page opens, with the words lighting up. Previous / Next move through the season.
 */
@Composable
private fun SportDetail(sports: List<Sport>, season: SportSeason, index: Int, onIndex: (Int) -> Unit, onTalk: () -> Unit, onBack: () -> Unit) {
    val lang = language
    val sport = sports[index]
    val about = when (lang) {
        LearningLanguage.ENGLISH -> sport.aboutEnglish
        LearningLanguage.CHINESE -> sport.aboutChinese
        LearningLanguage.BOTH -> sport.aboutEnglish + "\n\n" + sport.aboutChinese
    }
    val name = lang.spoken(sport.english, sport.chinese)
    fun readAll() = Speech.speak(name) { Speech.speak(about) }
    LaunchedEffect(sport.id, lang) { readAll() }
    val reading = Speech.speaking == name || Speech.speaking == about

    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar(title = lang.pick(sport.english, sport.chinese), onBack = onBack)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            SportPicture(sport, 150.dp, sportTint(index))
            Row(verticalAlignment = Alignment.CenterVertically) {
                WordName(sport.english, sport.chinese, lang, fontSize = 38, fontWeight = FontWeight.ExtraBold, stacked = true,
                    modifier = Modifier.weight(1f, fill = false))
                Box(Modifier.size(52.dp).squishClickable { if (reading) Speech.stop() else readAll() }, contentAlignment = Alignment.Center) {
                    Text(if (reading) "🔊" else "🔈", fontSize = 26.sp)
                }
            }
            KidButton(lang.pick("Talk about ${sport.english}", "聊聊${sport.chinese}"), KidColors.Purple, emoji = "✨", onClick = onTalk)
            SportDemos.demo(sport.id)?.let { demo ->
                Column(
                    Modifier.widthIn(max = 700.dp).fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        if (lang == LearningLanguage.BOTH) "Watch it! 看一看！" else lang.pick("Watch it!", "看一看！"),
                        fontSize = 20.sp, fontWeight = FontWeight.ExtraBold, color = KidColors.Orange,
                    )
                    // Keyed on the sport, so the loop starts over on each sport's page.
                    key(sport.id) {
                        SportDemoView(demo, lang.pick("Animation of ${sport.english}", "${sport.chinese}动画"))
                    }
                }
            }
            Column(
                Modifier.widthIn(max = 700.dp).fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    if (lang == LearningLanguage.BOTH) "What is it? 这是什么运动？" else lang.pick("What is it?", "这是什么运动？"),
                    fontSize = 20.sp, fontWeight = FontWeight.ExtraBold,
                    color = if (lang == LearningLanguage.CHINESE) KidColors.Red else KidColors.Blue,
                )
                ReadAlongText(about, fontSize = 22)
            }
            Row(Modifier.widthIn(max = 520.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                OutlinedButton(onClick = { onIndex(index - 1) }, enabled = index > 0, modifier = Modifier.weight(1f)) {
                    Text("← " + lang.pick("Previous", "上一个"), fontWeight = FontWeight.Bold)
                }
                OutlinedButton(onClick = { onIndex(index + 1) }, enabled = index < sports.lastIndex, modifier = Modifier.weight(1f)) {
                    Text(lang.pick("Next", "下一个") + " →", fontWeight = FontWeight.Bold)
                }
            }
            Text(
                lang.pick("${index + 1} of ${sports.size} · ${season.english} sports",
                    "${season.chinese}运动：第${index + 1}个，共${sports.size}个"),
                fontSize = 13.sp, color = Color.Gray,
            )
        }
    }
}
