package com.chengjianglong.soofunny.ui.settings

import android.content.Context
import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.BuildConfigInfo
import com.chengjianglong.soofunny.core.AppSettings
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Speech
import com.chengjianglong.soofunny.core.voice.Kokoro
import com.chengjianglong.soofunny.core.voice.NaturalVoices
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.language
import org.json.JSONArray

private val GroupedBackground = Color(0xFFF2F2F7)

/** App settings: the language for every tab, the reading voice and its speed, credits and About. */
@Composable
fun SettingsScreen(onClose: () -> Unit) {
    var showCredits by remember { mutableStateOf(false) }
    if (showCredits) {
        BackHandler { showCredits = false }
        PhotoCredits(onBack = { showCredits = false })
        return
    }
    val lang = language
    val context = LocalContext.current
    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar(title = lang.pick("Settings", "设置"), onBack = onClose, backLabel = lang.pick("Done", "完成"))
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Section("Language 语言", footer = lang.pick(
                "Color, Words, Sports, Books and Math are shown and read aloud in English, in Chinese, or in both. You can also switch with the globe button at the top.",
                "涂色、词语、运动、图书和数学都可以用英文、中文或双语显示和朗读，也可以用顶部的地球按钮切换。", "\n")) {
                LearningLanguage.entries.forEach { option ->
                    Row(Modifier.fillMaxWidth().clickable { AppSettings.language = option }.padding(vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = lang == option, onClick = { AppSettings.language = option })
                        Text(option.label, fontSize = 17.sp)
                    }
                }
            }

            val natural = NaturalVoices.englishInstalled
            Section(lang.pick("English voice", "英文声音"), footer = lang.pick(
                if (natural) "The natural voice runs on this device and works offline. The device voice is this device's text-to-speech; add or change voices in Android Settings → Text-to-speech."
                else "Words are read by this device's text-to-speech voices and work offline once the voices are installed. Add or change voices in Android Settings → Text-to-speech.",
                if (natural) "自然的声音在设备上运行，离线可用。设备声音来自本设备的文字转语音，可以在安卓“设置 → 文字转语音”里添加或更换。"
                else "朗读使用本设备的文字转语音声音，安装后可以离线使用。可以在安卓“设置 → 文字转语音”里添加或更换声音。", "\n")) {
                if (natural) {
                    val naturalName = when (lang) {
                        LearningLanguage.ENGLISH -> "Natural · Heart (recommended)"
                        LearningLanguage.CHINESE -> "自然 · Heart（推荐）"
                        LearningLanguage.BOTH -> "Natural · Heart（推荐）"
                    }
                    ChoiceRow(naturalName, NaturalVoices.englishChoice == NaturalVoices.EnglishVoice.NATURAL) {
                        NaturalVoices.englishChoice = NaturalVoices.EnglishVoice.NATURAL
                    }
                    ChoiceRow(lang.pick("Device voice", "设备声音"), NaturalVoices.englishChoice == NaturalVoices.EnglishVoice.DEVICE) {
                        NaturalVoices.englishChoice = NaturalVoices.EnglishVoice.DEVICE
                    }
                }
                Text(lang.pick("Speed", "语速"), fontSize = 17.sp, modifier = Modifier.padding(top = 4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("🐢", fontSize = 20.sp)
                    Slider(value = AppSettings.speechRate, onValueChange = { AppSettings.speechRate = it },
                        valueRange = 0.5f..1.5f, modifier = Modifier.weight(1f).padding(horizontal = 8.dp))
                    Text("🐇", fontSize = 20.sp)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = { Speech.speak(TRY_ENGLISH) }) { Text("🔈 " + lang.pick("Try the voice", "试听")) }
                    if (!NaturalVoices.chineseInstalled) {
                        TextButton(onClick = { Speech.speak(TRY_CHINESE) }) { Text("🔈 " + lang.pick("Try Chinese", "试听中文")) }
                    }
                }
                if (!Speech.chineseAvailable) {
                    Text(lang.pick("No Chinese voice is installed yet, so Chinese can't be read aloud.", "还没有安装中文声音，所以中文暂时不能朗读。"),
                        color = KidColors.Red, fontSize = 15.sp)
                }
                TextButton(onClick = { openTtsSettings(context) }) { Text(lang.pick("Text-to-speech settings", "文字转语音设置")) }
            }

            if (NaturalVoices.chineseInstalled) {
                Section(lang.pick("Chinese voice", "中文声音"), footer = lang.pick(
                    "Chinese is read in a natural voice that runs on this device and works offline.",
                    "中文用自然的声音朗读，在设备上运行，离线可用。", "\n")) {
                    Kokoro.chineseVoices.forEachIndexed { i, voice ->
                        val name = lang.pick("Voice ${i + 1}" + (if (i == 0) " (recommended)" else ""), "声音${i + 1}" + (if (i == 0) "（推荐）" else ""))
                        ChoiceRow(name, NaturalVoices.chineseVoice == voice) {
                            if (NaturalVoices.chineseVoice != voice) {
                                NaturalVoices.chineseVoice = voice
                                Speech.speak(TRY_CHINESE)
                            }
                        }
                    }
                    TextButton(onClick = { Speech.speak(TRY_CHINESE) }) { Text("🔈 " + lang.pick("Try the voice", "试听")) }
                }
            }

            Section("", footer = null) {
                Row(Modifier.fillMaxWidth().clickable { showCredits = true }.padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("🖼️  " + lang.pick("Photo credits", "照片来源"), fontSize = 17.sp, modifier = Modifier.weight(1f))
                    Text("›", fontSize = 22.sp, color = Color.LightGray)
                }
            }

            Section("", footer = null) {
                TextButton(onClick = { AppSettings.resetDefaults(); NaturalVoices.resetDefaults() }) {
                    Text(lang.pick("Reset defaults", "恢复默认设置"), color = KidColors.Red, fontSize = 17.sp)
                }
            }

            Section(lang.pick("About", "关于"), footer = "© 2026 Soo X Intelligence LLC. All rights reserved.") {
                Pair(lang.pick("Version", "版本"), BuildConfigInfo.versionName(context)).let { (k, v) -> InfoRow(k, v) }
                InfoRow(lang.pick("Developers", "开发者"), "Chengjiang Long and Yao Xu")
                InfoRow(lang.pick("Contact", "联系我们"), "chengjiang.long@gmail.com")
                Text(lang.pick("SooFunny works offline: no accounts, no ads, and nothing leaves this device.",
                    "SooFunny 离线使用：没有账号，没有广告，任何内容都不会离开这台设备。", "\n"),
                    fontSize = 14.sp, color = Color.Gray, modifier = Modifier.padding(top = 6.dp))
            }
        }
    }
}

private const val TRY_ENGLISH = "Hello! Let's learn some words."
private const val TRY_CHINESE = "你好！我们一起来学习吧。"

/** One choice of several, with a radio button. */
@Composable
private fun ChoiceRow(label: String, selected: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
        RadioButton(selected = selected, onClick = onClick)
        Text(label, fontSize = 17.sp)
    }
}

private fun openTtsSettings(context: Context) {
    runCatching {
        context.startActivity(Intent("com.android.settings.TTS_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
        Text(label, fontSize = 17.sp, modifier = Modifier.weight(1f))
        Text(value, fontSize = 17.sp, color = Color.Gray)
    }
}

@Composable
private fun Section(title: String, footer: String?, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.widthIn(max = 700.dp).fillMaxWidth().padding(bottom = 12.dp)) {
        if (title.isNotEmpty()) Text(title.uppercase(), fontSize = 13.sp, color = Color.Gray, modifier = Modifier.padding(start = 16.dp, bottom = 6.dp))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White).padding(horizontal = 16.dp, vertical = 8.dp), content = content)
        if (footer != null) Text(footer, fontSize = 13.sp, color = Color.Gray, modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 6.dp))
    }
}

private data class Credit(val title: String, val author: String, val license: String, val source: String)

private fun loadCredits(context: Context, path: String): List<Credit> = runCatching {
    val a = JSONArray(context.assets.open(path).bufferedReader().use { it.readText() })
    (0 until a.length()).map { a.getJSONObject(it) }.map {
        Credit(it.optString("title"), it.optString("author"), it.optString("license"), it.optString("source").removePrefix("File:"))
    }
}.getOrDefault(emptyList())

/** Who took the photos (all CC0 or public domain, from Wikimedia Commons). */
@Composable
private fun PhotoCredits(onBack: () -> Unit) {
    val context = LocalContext.current
    val lang = language
    val sections = remember {
        listOf(
            "Color pictures" to loadCredits(context, "showcase/credits.json"),
            "Word photos" to loadCredits(context, "words/photos/word_photo_credits.json"),
        )
    }
    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar(title = lang.pick("Photo credits", "照片来源"), onBack = onBack)
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
            item {
                Text("Thank you to these photographers for sharing their photos freely (CC0 or public domain) on Wikimedia Commons.",
                    fontSize = 14.sp, color = Color.Gray, modifier = Modifier.padding(vertical = 12.dp))
            }
            sections.forEach { (title, credits) ->
                item { Text(title, fontWeight = FontWeight.Bold, fontSize = 20.sp, modifier = Modifier.padding(vertical = 8.dp)) }
                items(credits) { c ->
                    Column(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                        Text(c.title, fontWeight = FontWeight.SemiBold)
                        Text("${c.author} · ${c.license}", fontSize = 14.sp, color = Color.Gray)
                        Text("Wikimedia Commons: ${c.source}", fontSize = 12.sp, color = Color.Gray)
                    }
                }
            }
        }
    }
}
