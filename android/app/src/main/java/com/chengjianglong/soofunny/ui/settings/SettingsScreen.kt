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
import com.chengjianglong.soofunny.core.BuddyModel
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
                if (natural && NaturalVoices.tooSlow) {
                    Text(lang.pick(
                        "This phone is too slow to make the natural voices as they're needed (each word would take seconds). Words, sports, books and math still use the natural voices, made ahead of time; anything else, like the buddy's answers, uses the device's voice.",
                        "这部手机实时生成自然声音太慢（每个词都要等几秒）。单词、运动、绘本和数学仍然使用预先做好的自然声音；其他内容（比如小伙伴的回答）使用设备自带的声音。", "\n"),
                        fontSize = 15.sp, color = Color.Gray)
                    TextButton(onClick = { NaturalVoices.useNaturalAnyway() }) {
                        Text(lang.pick("Use the natural voices anyway", "仍然使用自然的声音"))
                    }
                } else if (natural) {
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

            BuddySection()

            Section("", footer = null) {
                TextButton(onClick = { AppSettings.resetDefaults(); NaturalVoices.resetDefaults() }) {
                    Text(lang.pick("Reset defaults", "恢复默认设置"), color = KidColors.Red, fontSize = 17.sp)
                }
            }

            Section(lang.pick("About", "关于"), footer = "© 2026 Soo X Intelligence LLC. All rights reserved.") {
                Pair(lang.pick("Version", "版本"), BuildConfigInfo.versionName(context)).let { (k, v) -> InfoRow(k, v) }
                InfoRow(lang.pick("Developers", "开发者"), "Chengjiang Long and Yao Xu")
                InfoRow(lang.pick("Contact", "联系我们"), "chengjiang.long@gmail.com")
                Text(lang.pick("SooFunny works offline: no accounts, no ads, and nothing you make or say leaves this device. The internet is used only to download the talking buddy.",
                    "SooFunny 离线使用：没有账号，没有广告，你做的和说的都不会离开这台设备。只有下载小伙伴时才会联网。", "\n"),
                    fontSize = 14.sp, color = Color.Gray, modifier = Modifier.padding(top = 6.dp))
            }
        }
    }
}

/** The talking buddy's downloaded model: its size, and a button to delete it. */
@Composable
private fun BuddySection() {
    val context = LocalContext.current
    val lang = language
    androidx.compose.runtime.LaunchedEffect(Unit) { BuddyModel.refresh(context) }
    val ready = BuddyModel.state is BuddyModel.State.Ready
    var confirm by remember { mutableStateOf(false) }
    Section(lang.pick("Talking buddy", "说话小伙伴"), footer = lang.pick(
        if (ready) "The buddy's AI model (Qwen 2.5) is on this device. Deleting it frees 1.1 GB; it can be downloaded again from the buddy screen."
        else "The buddy's AI model isn't downloaded. A grown-up can download it (1.1 GB) from the buddy screen in Words or Sports.",
        if (ready) "小伙伴的 AI 模型（Qwen 2.5）已在这台设备上。删除可腾出 1.1 GB，之后可以在小伙伴页面重新下载。"
        else "还没有下载小伙伴的 AI 模型。家长可以在“单词”或“运动”的小伙伴页面下载（1.1 GB）。", "\n")) {
        if (ready) {
            TextButton(onClick = { confirm = true }) {
                Text(lang.pick("Delete the buddy's model", "删除小伙伴的模型"), color = KidColors.Red, fontSize = 17.sp)
            }
        } else {
            InfoRow(lang.pick("Model", "模型"), lang.pick("Not downloaded", "未下载"))
        }
    }
    if (confirm) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text(lang.pick("Delete the buddy's model?", "删除小伙伴的模型？")) },
            text = { Text(lang.pick("The talking buddy won't work until it's downloaded again (1.1 GB).", "删除后，需要重新下载（1.1 GB）小伙伴才能说话。")) },
            confirmButton = {
                TextButton(onClick = { confirm = false; BuddyModel.delete(context); BuddyModel.refresh(context) }) {
                    Text(lang.pick("Delete", "删除"), color = KidColors.Red)
                }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text(lang.pick("Cancel", "取消")) } },
        )
    }
}

internal const val TRY_ENGLISH = "Hello! Let's learn some words."
internal const val TRY_CHINESE = "你好！我们一起来学习吧。"

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
