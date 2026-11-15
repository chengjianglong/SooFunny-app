package com.chengjianglong.soofunny.ui.buddy

import android.Manifest
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.AssetImages
import com.chengjianglong.soofunny.core.BookLanguage
import com.chengjianglong.soofunny.core.BuddyModel
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Speech
import com.chengjianglong.soofunny.core.WordCategory
import com.chengjianglong.soofunny.core.WordEntry
import com.chengjianglong.soofunny.core.WordPhotos
import com.chengjianglong.soofunny.core.buddy.ChatMessage
import com.chengjianglong.soofunny.core.buddy.SpeechSentenceSpeaker
import com.chengjianglong.soofunny.core.buddy.SystemChildListener
import com.chengjianglong.soofunny.core.buddy.WordBuddy
import com.chengjianglong.soofunny.ui.KidButton
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.ReadAlongText
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.books.ParentalGate
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.squishClickable
import com.chengjianglong.soofunny.ui.words.PhotoWithSticker
import com.chengjianglong.soofunny.ui.words.WordName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

private val GroupedBackground = Color(0xFFF2F2F7)

/**
 * Talk about one word (or a sport) with the on-device buddy: picture, conversation, and a big
 * Talk button. A port of `WordAssistantView.swift`. The first time, a grown-up downloads the
 * buddy's model here.
 *
 * [facts] is background the buddy keeps to (a sport's introduction); [photoPaths] are pictures to
 * show instead of the word's own photos.
 */
@Composable
fun BuddyScreen(
    word: WordEntry,
    category: WordCategory,
    facts: String? = null,
    photoPaths: List<String>? = null,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    val lang = language
    BackHandler(onBack = onClose)
    LaunchedEffect(Unit) {
        Speech.stop()
        BuddyModel.refresh(context)
    }
    Column(Modifier.fillMaxSize().background(GroupedBackground)) {
        SooTopBar(title = word.chinese?.let { lang.pick(word.text, it) } ?: word.text, onBack = onClose)
        if (BuddyModel.state is BuddyModel.State.Ready) {
            Conversation(word, category, facts, photoPaths)
        } else {
            Column(
                Modifier.fillMaxSize().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterVertically),
            ) {
                Pictures(category, word, photoPaths)
                DownloadCard()
            }
        }
    }
}

/** Keeps the model download going when the buddy's screen is closed. */
private object BuddyDownload {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var job: Job? = null

    fun start(context: Context) {
        if (job?.isActive == true) return
        val app = context.applicationContext
        job = scope.launch { BuddyModel.download(app) }
    }

    fun cancel() {
        job?.cancel()
        job = null
    }
}

/** For grown-ups: the one-time download of the buddy's model, with its progress. */
@Composable
private fun DownloadCard() {
    val context = LocalContext.current
    val lang = language
    val state = BuddyModel.state
    val needed = BuddyModel.SIZE + (200L shl 20)
    val lowSpace = remember(state) { context.filesDir.usableSpace < needed && state !is BuddyModel.State.Downloading }
    var gate by remember { mutableStateOf(false) }
    if (gate) {
        ParentalGate(
            reason = lang.pick("This downloads 1.1 GB from the internet.", "这会从网上下载 1.1 GB。", "\n"),
            onDismiss = { gate = false },
        ) {
            gate = false
            BuddyDownload.start(context)
        }
    }
    Column(
        Modifier.widthIn(max = 520.dp).fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(lang.pick("For grown-ups", "给家长"), fontSize = 14.sp, fontWeight = FontWeight.Bold, color = KidColors.Gray)
        Text(
            lang.pick("The talking buddy needs a one-time download (1.1 GB). Use Wi-Fi.",
                "小伙伴需要下载一次（1.1 GB）。请使用 Wi-Fi。", "\n"),
            fontSize = 18.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
        )
        when (state) {
            is BuddyModel.State.Downloading -> {
                val fraction = if (state.total > 0) state.bytes.toFloat() / state.total else 0f
                LinearProgressIndicator(progress = { fraction }, modifier = Modifier.fillMaxWidth(), color = KidColors.Green)
                Text(
                    lang.pick("${megabytes(state.bytes)} of ${megabytes(state.total)}",
                        "已下载 ${megabytes(state.bytes)}，共 ${megabytes(state.total)}"),
                    fontSize = 14.sp, color = KidColors.Gray,
                )
                TextButton(onClick = { BuddyDownload.cancel() }) {
                    Text(lang.pick("Cancel", "取消"), fontWeight = FontWeight.Bold)
                }
            }
            BuddyModel.State.Checking -> {
                LinearProgressIndicator(Modifier.fillMaxWidth(), color = KidColors.Green)
                Text(lang.pick("Checking the download…", "正在检查下载的文件……"), fontSize = 14.sp, color = KidColors.Gray)
            }
            is BuddyModel.State.Failed -> {
                Text(
                    lang.pick("The download didn't finish (${state.message}). Check the connection and try again.",
                        "下载没有完成（${state.message}）。请检查网络后再试。", "\n"),
                    fontSize = 15.sp, color = KidColors.Red, textAlign = TextAlign.Center,
                )
                KidButton(lang.pick("Try again", "重试"), KidColors.Blue, emoji = "🔄") { gate = true }
            }
            else -> {
                if (lowSpace) {
                    Text(
                        lang.pick("There isn't enough free space. Free up about 1.3 GB first.",
                            "设备空间不够。请先腾出大约 1.3 GB。", "\n"),
                        fontSize = 15.sp, color = KidColors.Red, textAlign = TextAlign.Center,
                    )
                }
                KidButton(lang.pick("Download", "下载"), KidColors.Blue, emoji = "⬇️") { gate = true }
            }
        }
        Text(
            lang.pick("Downloaded once from Hugging Face (Qwen 2.5). After that the buddy works without the internet.",
                "只需从 Hugging Face 下载一次（通义千问 Qwen 2.5），之后不用联网也能聊天。", "\n"),
            fontSize = 12.sp, color = KidColors.Gray, textAlign = TextAlign.Center,
        )
    }
}

private fun megabytes(bytes: Long): String =
    if (bytes >= 1_000_000_000L) "%.1f GB".format(bytes / 1e9) else "${bytes / 1_000_000} MB"

/** The word's photo with its emoji sticker, then its other photos, side by side. */
@Composable
private fun Pictures(category: WordCategory, word: WordEntry, photoPaths: List<String>?) {
    val context = LocalContext.current
    val paths = remember(category.name, word.text, photoPaths) {
        photoPaths ?: (1..3).map { WordPhotos.path(category.name, word.text, it) }.filter { AssetImages.exists(context, it) }
    }
    val size = if (paths.size > 1) 104.dp else 140.dp
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
        if (paths.isEmpty()) PhotoWithSticker(null, word.emoji, word.text, size, KidColors.Orange)
        paths.forEachIndexed { i, path ->
            PhotoWithSticker(path, if (i == 0) word.emoji else null, word.text, size, KidColors.Orange)
        }
    }
}

@Composable
private fun Conversation(word: WordEntry, category: WordCategory, facts: String?, photoPaths: List<String>?) {
    val context = LocalContext.current
    val lang = language
    val model = remember { BuddyModel.file(context) }
    // In Bilingual the child can talk in either language.
    var childSpeaksChinese by rememberSaveable { mutableStateOf(false) }
    // Switching language starts the conversation again in the new language.
    val buddy = remember(word, category, facts, lang) {
        WordBuddy(
            word.text, category.name, lang, word.chinese, category.chinese, facts,
            makeEngine = { WordBuddy.loadSharedEngine(model) },
            speaker = SpeechSentenceSpeaker(),
            listener = SystemChildListener(context),
        ).also {
            if (it.language == LearningLanguage.BOTH && childSpeaksChinese) it.listeningLanguage = BookLanguage.CHINESE
        }
    }
    DisposableEffect(buddy) { onDispose { buddy.end() } }

    // Ask for the microphone once up front, so the first listening turn isn't interrupted by a prompt.
    var permissionAsked by rememberSaveable { mutableStateOf(false) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { buddy.start() }
    LaunchedEffect(buddy) {
        val granted = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (granted || permissionAsked) {
            buddy.start()
        } else {
            permissionAsked = true
            permission.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    // Keep the screen awake while the buddy talks or listens.
    val view = LocalView.current
    val active = buddy.isActive
    DisposableEffect(active) {
        view.keepScreenOn = active
        onDispose { view.keepScreenOn = false }
    }

    val list = rememberLazyListState()
    val lastText = buddy.messages.lastOrNull()?.text
    LaunchedEffect(buddy.messages.size, lastText, buddy.heard) {
        val count = list.layoutInfo.totalItemsCount
        if (count > 0) list.animateScrollToItem(count - 1)
    }

    Column(Modifier.fillMaxSize().imePadding()) {
        LazyColumn(
            Modifier.weight(1f).fillMaxWidth(),
            state = list,
            horizontalAlignment = Alignment.CenterHorizontally,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item(key = "header") {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Pictures(category, word, photoPaths)
                    WordName(word.text, word.chinese, lang, fontSize = 36, fontWeight = FontWeight.ExtraBold, stacked = true)
                }
            }
            items(buddy.messages, key = { it.id }) { message -> Bubble(buddy, message) }
            if (buddy.heard.isNotEmpty()) {
                item(key = "heard") { Bubble(buddy, ChatMessage(ChatMessage.Speaker.CHILD, buddy.heard, id = -1), live = true) }
            }
        }
        Controls(buddy, childSpeaksChinese) { chinese ->
            childSpeaksChinese = chinese
            buddy.listeningLanguage = if (chinese) BookLanguage.CHINESE else BookLanguage.ENGLISH
            if (buddy.phase == WordBuddy.Phase.Listening) buddy.talk()
        }
    }
}

@Composable
private fun Bubble(buddy: WordBuddy, message: ChatMessage, live: Boolean = false) {
    val isChild = message.speaker == ChatMessage.Speaker.CHILD
    val say = buddy.language
    Column(
        Modifier.widthIn(max = 760.dp).fillMaxWidth(),
        horizontalAlignment = if (isChild) Alignment.End else Alignment.Start,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            if (isChild) say.pick("You", "你") else say.pick("Buddy", "小伙伴"),
            fontSize = 13.sp, fontWeight = FontWeight.Bold, color = if (isChild) KidColors.Blue else KidColors.Orange,
        )
        Column(
            Modifier.widthIn(max = 600.dp).clip(RoundedCornerShape(18.dp))
                .background(if (isChild) KidColors.Blue.copy(alpha = 0.14f) else Color.White)
                .padding(14.dp).alpha(if (live) 0.7f else 1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            if (isChild) {
                Text(message.text, fontSize = 20.sp)
            } else {
                // Each sentence lights up word by word while it's read aloud.
                message.sentences.forEach { ReadAlongText(it, fontSize = 20) }
            }
        }
        if (!isChild && !live) ReportAnswer(message.text)
    }
}

/**
 * Lets a grown-up report an answer that's wrong or not right for children (Google Play's rule
 * for AI-made content): after the grown-up check, opens an email to us with the answer in it.
 * Nothing is sent unless the grown-up sends that email.
 */
@Composable
private fun ReportAnswer(answer: String) {
    val context = LocalContext.current
    val lang = language
    var gate by remember { mutableStateOf(false) }
    Text(
        "⚑ " + lang.pick("Report", "举报"),
        fontSize = 13.sp, color = KidColors.Gray,
        modifier = Modifier.clip(RoundedCornerShape(8.dp)).squishClickable { gate = true }.padding(horizontal = 6.dp, vertical = 2.dp),
    )
    if (gate) {
        ParentalGate(
            reason = lang.pick("Tell us about an answer that's wrong or not right for children. This opens an email to SooFunny with the answer in it.",
                "如果回答有错或不适合孩子，请告诉我们。这会打开一封发给 SooFunny 的邮件，里面附有这条回答。", "\n"),
            onDismiss = { gate = false },
        ) {
            gate = false
            val body = "This talking buddy answer was wrong or not right for children:\n\n$answer\n\n" +
                "(SooFunny ${com.chengjianglong.soofunny.BuildConfigInfo.versionName(context)}, Android)\n"
            val mail = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
                .putExtra(Intent.EXTRA_EMAIL, arrayOf(REPORT_EMAIL))
                .putExtra(Intent.EXTRA_SUBJECT, "SooFunny: talking buddy answer")
                .putExtra(Intent.EXTRA_TEXT, body)
            runCatching { context.startActivity(Intent.createChooser(mail, lang.pick("Report", "举报"))) }
        }
    }
}

/** The contact address shown in Settings → About. */
private const val REPORT_EMAIL = "chengjiang.long@gmail.com"

@Composable
private fun Controls(buddy: WordBuddy, childSpeaksChinese: Boolean, onChildSpeaksChinese: (Boolean) -> Unit) {
    val say = buddy.language
    val phase = buddy.phase
    var typed by rememberSaveable { mutableStateOf("") }
    val focus = LocalFocusManager.current
    fun sendTyped() {
        val text = typed
        typed = ""
        focus.clearFocus()
        buddy.send(text)
    }

    Surface(color = Color.White, shadowElevation = 4.dp) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Column(
                Modifier.widthIn(max = 760.dp).fillMaxWidth().padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                val status = when (phase) {
                    WordBuddy.Phase.Preparing -> say.pick("Getting ready… (the first time takes a few seconds)", "准备中……（第一次需要几秒钟）")
                    WordBuddy.Phase.Speaking -> say.pick("Listen…", "听……")
                    WordBuddy.Phase.Listening -> say.pick("Listening — your turn!", "在听呢，轮到你了！")
                    WordBuddy.Phase.Thinking -> say.pick("Thinking about ${buddy.word}…", "正在想${buddy.chinese ?: buddy.word}……")
                    WordBuddy.Phase.Ready -> buddy.note ?: say.pick("Tap Talk to ask a question.", "点“说话”来提问吧。")
                    is WordBuddy.Phase.Failed -> phase.message
                }
                Text(
                    status, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                    color = if (phase is WordBuddy.Phase.Failed) KidColors.Red else KidColors.Gray,
                )
                if (phase == WordBuddy.Phase.Listening) {
                    Text(say.pick("Speak, then pause. Tap Done when you finish.", "说完停一下，或者点“好了”。"),
                        fontSize = 13.sp, color = KidColors.Gray)
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    val (title, emoji) = when (phase) {
                        WordBuddy.Phase.Listening -> say.pick("Done", "好了") to "✅"
                        WordBuddy.Phase.Thinking -> say.pick("Cancel", "取消") to "✖️"
                        WordBuddy.Phase.Speaking -> say.pick("Stop speaking", "停止") to "🔇"
                        WordBuddy.Phase.Preparing -> say.pick("Getting ready", "准备中") to "⏳"
                        else -> say.pick("Talk", "说话") to "🎤"
                    }
                    KidButton(
                        title, if (buddy.isActive || phase == WordBuddy.Phase.Preparing) KidColors.Green else KidColors.Blue,
                        modifier = Modifier.weight(1f).heightIn(min = 56.dp), emoji = emoji,
                        enabled = phase != WordBuddy.Phase.Preparing,
                    ) {
                        when (phase) {
                            WordBuddy.Phase.Listening -> buddy.doneListening()
                            WordBuddy.Phase.Thinking, WordBuddy.Phase.Speaking -> buddy.cancel()
                            WordBuddy.Phase.Preparing -> {}
                            else -> buddy.talk()
                        }
                    }
                    if (phase == WordBuddy.Phase.Listening) {
                        TextButton(onClick = { buddy.cancel() }) { Text(say.pick("Cancel", "取消"), fontWeight = FontWeight.Bold, fontSize = 17.sp) }
                    }
                }
                if (say == LearningLanguage.BOTH) {
                    Row(Modifier.widthIn(max = 360.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        SpeakChip("I speak English", selected = !childSpeaksChinese, Modifier.weight(1f)) { onChildSpeaksChinese(false) }
                        SpeakChip("我说中文", selected = childSpeaksChinese, Modifier.weight(1f)) { onChildSpeaksChinese(true) }
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        typed, { typed = it }, Modifier.weight(1f),
                        placeholder = { Text(say.pick("Type a question", "输入问题")) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                        keyboardActions = KeyboardActions(onSend = { if (canSend(typed, phase)) sendTyped() }),
                    )
                    val sendLabel = say.pick("Send", "发送")
                    val enabled = canSend(typed, phase)
                    Box(
                        Modifier.size(52.dp).clip(RoundedCornerShape(14.dp))
                            .background(if (enabled) KidColors.Blue else KidColors.Gray.copy(alpha = 0.3f))
                            .squishClickable(enabled) { sendTyped() }
                            .semantics { contentDescription = sendLabel },
                        contentAlignment = Alignment.Center,
                    ) { Text("➤", fontSize = 22.sp, color = Color.White, fontWeight = FontWeight.Bold) }
                }
                Text(
                    say.pick("The conversation stays on this device. The buddy can make mistakes.",
                        "对话只留在这台设备上。小伙伴也可能说错。"),
                    fontSize = 11.sp, color = KidColors.Gray, textAlign = TextAlign.Center,
                )
                Spacer(Modifier.size(0.dp))
            }
        }
    }
}

private fun canSend(typed: String, phase: WordBuddy.Phase) = typed.isNotBlank() && phase != WordBuddy.Phase.Preparing

@Composable
private fun SpeakChip(text: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Box(
        modifier.heightIn(min = 40.dp).clip(shape)
            .then(if (selected) Modifier.background(KidColors.Blue) else Modifier.background(Color.White).border(2.dp, KidColors.Blue.copy(alpha = 0.4f), shape))
            .squishClickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, color = if (selected) Color.White else KidColors.Blue, fontWeight = FontWeight.Bold, fontSize = 15.sp)
    }
}
