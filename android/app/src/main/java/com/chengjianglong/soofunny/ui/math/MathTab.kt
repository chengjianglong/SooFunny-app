package com.chengjianglong.soofunny.ui.math

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.AppSettings
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Speech
import com.chengjianglong.soofunny.ui.BouncyTitle
import com.chengjianglong.soofunny.ui.KidButton
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.gradient
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.squishClickable
import kotlin.math.max
import kotlin.math.sin
import kotlin.random.Random

val MathOperation.color: Color
    get() = when (this) {
        MathOperation.ADD -> KidColors.Green
        MathOperation.SUBTRACT -> KidColors.Orange
        MathOperation.MULTIPLY -> KidColors.Blue
        MathOperation.DIVIDE -> KidColors.Purple
    }

internal sealed interface MathScreen {
    data class Setup(val mode: MathMode) : MathScreen
    data object Progress : MathScreen
    data object Settings : MathScreen
    data class Play(val session: MathSession) : MathScreen
}

/** Kept outside the composable so the Math tab keeps its place when the child switches tabs. */
internal object MathState {
    val stack = mutableStateListOf<MathScreen>()
    private var loaded = false
    var settings by mutableStateOf(MathSettings())
        private set

    fun load() {
        if (loaded) return
        loaded = true
        val prefs = AppSettings.prefs()
        settings = MathSettings.load(prefs)
        MathProgressStore.load(prefs)
    }

    fun update(new: MathSettings) {
        if (new == settings) return
        settings = new
        new.save(AppSettings.prefs())
    }

    fun push(screen: MathScreen) { stack.add(screen) }
    fun pop() { if (stack.isNotEmpty()) stack.removeAt(stack.lastIndex) }
}

/** The Math tab: flashcards, quizzes and progress reports for + − × ÷. Everything is offline. */
@Composable
fun MathTab() {
    remember { MathState.load(); true }
    val screen = MathState.stack.lastOrNull()
    if (screen != null) BackHandler {
        if (screen is MathScreen.Play) Speech.stop()
        MathState.pop()
    }
    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        when (screen) {
            null -> MathHome()
            is MathScreen.Setup -> MathSetupScreen(screen.mode)
            MathScreen.Progress -> MathProgressScreen()
            MathScreen.Settings -> MathSettingsScreen()
            is MathScreen.Play -> MathPlayScreen(screen.session, onClose = { retry ->
                Speech.stop()
                MathState.pop()
                if (!retry.isNullOrEmpty()) MathState.push(MathScreen.Play(MathSession(MathMode.QUIZ, retry, true)))
            })
        }
    }
}

internal fun startRound(mode: MathMode) {
    val settings = MathState.settings
    val questions = MathQuestionMaker.questions(settings)
    if (questions.isEmpty()) return
    MathState.push(MathScreen.Play(MathSession(mode, questions, settings.markQuestions)))
}

// MARK: Home

@Composable
private fun MathHome() {
    val lang = language
    val streak = MathStats.streak(MathProgressStore.results)
    Column(Modifier.fillMaxSize()) {
        SooTopBar(title = "")
        Box(Modifier.weight(1f).fillMaxWidth()) {
            MathBackground(Modifier.fillMaxSize())
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                BouncyTitle(Modifier.padding(top = 8.dp), fontSize = 46)
                MathTitle()
                if (streak > 0) {
                    Text(
                        lang.pick("🔥 $streak-day streak! Keep it up!", "🔥 连续${streak}天！继续加油！"),
                        fontWeight = FontWeight.Bold, fontSize = 17.sp, color = KidColors.Orange, textAlign = TextAlign.Center,
                    )
                }
                Column(Modifier.widthIn(max = 640.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                    MenuButton(lang.pick("Flashcard Game", "闪卡游戏"), lang.pick("Flip cards and check yourself", "翻开卡片，自己检查"),
                        "🃏", listOf(KidColors.Pink, KidColors.Orange)) { MathState.push(MathScreen.Setup(MathMode.FLASHCARDS)) }
                    MenuButton(lang.pick("Quiz", "测验"), lang.pick("Type the answers, beat the clock", "输入答案，和时间赛跑"),
                        "✏️", listOf(KidColors.Blue, KidColors.Teal)) { MathState.push(MathScreen.Setup(MathMode.QUIZ)) }
                    MenuButton(lang.pick("Progress Reports", "学习报告"), lang.pick("See how you're growing", "看看你的进步"),
                        "📊", listOf(KidColors.Green, KidColors.Mint)) { MathState.push(MathScreen.Progress) }
                    MenuButton(lang.pick("Math Settings", "数学设置"), lang.pick("Voice and timer", "朗读和计时"),
                        "⚙️", listOf(KidColors.Purple, KidColors.Indigo)) { MathState.push(MathScreen.Settings) }
                }
            }
        }
    }
}

@Composable
private fun MathTitle() {
    val lang = language
    var t by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { t = it - start }
    }
    val title = lang.pick("Math Fun", "数学乐园")
    Column(
        Modifier.semantics(mergeDescendants = true) { heading(); contentDescription = title },
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            MathOperation.entries.forEachIndexed { i, op ->
                val seconds = t / 1000.0
                Box(
                    Modifier
                        .graphicsLayer {
                            rotationZ = (sin(seconds * 2 + i) * 8).toFloat()
                            translationY = (-max(0.0, sin(seconds * 3 - i * 0.7)) * 8 * density).toFloat()
                        }
                        .size(64.dp).clip(RoundedCornerShape(18.dp)).background(op.color.gradient()),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(op.symbol, color = Color.White, fontSize = 44.sp, fontWeight = FontWeight.Black)
                }
            }
        }
        Text(
            title,
            style = TextStyle(
                fontSize = 32.sp, fontWeight = FontWeight.Black,
                brush = Brush.horizontalGradient(listOf(KidColors.Green, KidColors.Orange, KidColors.Blue, KidColors.Purple)),
            ),
        )
    }
}

@Composable
private fun MenuButton(title: String, subtitle: String, emoji: String, colors: List<Color>, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .squishClickable(onClick = onClick)
            .shadow(8.dp, RoundedCornerShape(24.dp), ambientColor = colors[0], spotColor = colors[0])
            .clip(RoundedCornerShape(24.dp))
            .background(Brush.horizontalGradient(colors))
            .heightIn(min = 88.dp)
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(emoji, fontSize = 40.sp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
            Text(subtitle, color = Color.White.copy(alpha = 0.9f), fontSize = 15.sp, fontWeight = FontWeight.Medium)
        }
        Text("›", color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
    }
}

/** Faint + − × ÷ = 1 2 3 scattered behind the menu. */
@Composable
private fun MathBackground(modifier: Modifier = Modifier) {
    val measurer = rememberTextMeasurer()
    val ink = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.10f)
    Canvas(modifier) {
        val rng = Random(7)
        val symbols = listOf("+", "−", "×", "÷", "=", "1", "2", "3")
        repeat(40) {
            val x = rng.nextFloat() * size.width
            val y = rng.nextFloat() * size.height
            val symbol = symbols[rng.nextInt(symbols.size)]
            val fontSize = (22 + rng.nextInt(20)).sp
            val layout = measurer.measure(symbol, TextStyle(fontSize = fontSize, fontWeight = FontWeight.Bold, color = ink))
            drawText(layout, topLeft = androidx.compose.ui.geometry.Offset(x - layout.size.width / 2f, y - layout.size.height / 2f))
        }
    }
}

// MARK: Setup

@Composable
internal fun SectionTitle(text: String) {
    Text(text, fontWeight = FontWeight.Bold, fontSize = 17.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionTitle(title)
        content()
    }
}

/** A row of choices, like an iOS segmented picker. */
@Composable
internal fun <T> Segmented(options: List<Pair<T, String>>, selected: T, onSelect: (T) -> Unit) {
    val primary = MaterialTheme.colorScheme.primary
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant).padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        options.forEach { (value, label) ->
            val on = value == selected
            Box(
                Modifier.weight(1f).clip(RoundedCornerShape(10.dp))
                    .background(if (on) primary else Color.Transparent)
                    .squishClickable { onSelect(value) }
                    .semantics { this.selected = on }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(label, fontWeight = FontWeight.Bold, fontSize = 17.sp,
                    color = if (on) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** Choose operations, the numbers to practice, how many questions, and marking. */
@Composable
private fun MathSetupScreen(mode: MathMode) {
    val lang = language
    val settings = MathState.settings
    val primary = MaterialTheme.colorScheme.primary
    val cardColor = MaterialTheme.colorScheme.surfaceVariant
    Column(Modifier.fillMaxSize()) {
        SooTopBar(
            title = if (mode == MathMode.FLASHCARDS) lang.pick("Flashcard Game", "闪卡游戏") else lang.pick("Quiz", "测验"),
            onBack = { MathState.pop() },
        )
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            Section(lang.pick("Choose operations", "选择运算")) {
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    MathOperation.entries.forEach { op ->
                        val on = op in settings.operations
                        val name = op.name(lang)
                        Box(
                            Modifier.size(70.dp)
                                .squishClickable {
                                    MathState.update(settings.copy(operations = if (on) settings.operations - op else settings.operations + op))
                                }
                                .clip(CircleShape)
                                .background(if (on) op.color.gradient() else Brush.linearGradient(listOf(cardColor, cardColor)))
                                .border(3.dp, op.color, CircleShape)
                                .semantics { contentDescription = name; selected = on },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(op.symbol, fontSize = 38.sp, fontWeight = FontWeight.ExtraBold, color = if (on) Color.White else op.color)
                        }
                    }
                }
            }

            Section(lang.pick("Choose numbers to focus on", "选择要练习的数字")) {
                MathSettings.numbers.chunked(7).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { n ->
                            val on = n in settings.focusNumbers
                            Box(
                                Modifier.weight(1f).aspectRatio(1f)
                                    .squishClickable {
                                        MathState.update(settings.copy(focusNumbers = if (on) settings.focusNumbers - n else settings.focusNumbers + n))
                                    }
                                    .clip(CircleShape)
                                    .background(if (on) primary.gradient() else Brush.linearGradient(listOf(cardColor, cardColor)))
                                    .border(2.dp, if (on) Color.Transparent else primary.copy(alpha = 0.4f), CircleShape)
                                    .semantics { selected = on },
                                contentAlignment = Alignment.Center,
                            ) {
                                Text("$n", fontSize = 20.sp, fontWeight = FontWeight.Bold,
                                    color = if (on) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface)
                            }
                        }
                        repeat(7 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedButton(onClick = { MathState.update(settings.copy(focusNumbers = MathSettings.numbers.toSet())) }) {
                        Text(lang.pick("All", "全部"))
                    }
                    OutlinedButton(onClick = { MathState.update(settings.copy(focusNumbers = (1..5).toSet())) }) {
                        Text(lang.pick("1 to 5", "1到5"))
                    }
                    OutlinedButton(onClick = { MathState.update(settings.copy(focusNumbers = emptySet())) }) {
                        Text(lang.pick("None", "清空"))
                    }
                }
            }

            Section(lang.pick("Number of questions", "题目数量")) {
                Segmented(MathSettings.counts.map { it to "$it" }, settings.questionCount) {
                    MathState.update(settings.copy(questionCount = it))
                }
            }
            if (mode == MathMode.FLASHCARDS) {
                Section(lang.pick("Mark questions?", "记录对错？")) {
                    Segmented(listOf(true to lang.pick("Yes", "是"), false to lang.pick("No", "否")), settings.markQuestions) {
                        MathState.update(settings.copy(markQuestions = it))
                    }
                }
            }

            if (!settings.isReady) {
                Text(lang.pick("Pick at least one operation and one number.", "至少选一种运算和一个数字。"),
                    fontWeight = FontWeight.Bold, fontSize = 17.sp, color = KidColors.Red)
            }
            KidButton(lang.pick("Start", "开始"), primary, Modifier.fillMaxWidth().heightIn(min = 60.dp), enabled = settings.isReady) {
                startRound(mode)
            }
        }
    }
}

// MARK: Settings

@Composable
private fun MathSettingsScreen() {
    val lang = language
    val settings = MathState.settings
    var confirmReset by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize()) {
        SooTopBar(title = lang.pick("Math Settings", "数学设置"), onBack = { MathState.pop() }, backLabel = lang.pick("Done", "完成"))
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            SettingsCard {
                SectionTitle(lang.pick("Language", "语言"))
                Segmented(LearningLanguage.entries.map { it to it.shortLabel }, AppSettings.language) { AppSettings.language = it }
                ToggleRow(lang.pick("Read questions aloud", "朗读题目"), settings.readAloud) {
                    MathState.update(settings.copy(readAloud = it))
                }
                ToggleRow(lang.pick("Show timer in quizzes", "测验时显示计时"), settings.showTimer) {
                    MathState.update(settings.copy(showTimer = it))
                }
            }
            Footer(lang.pick("Questions are read with the voice chosen in the app's Settings. Everything works offline.",
                "英文用 App 设置里选的声音朗读，中文用中文声音朗读。全部离线可用。"))
            SettingsCard {
                TextButton(onClick = { confirmReset = true }, enabled = MathProgressStore.results.isNotEmpty()) {
                    Text(lang.pick("Reset progress", "清除进度"), color = if (MathProgressStore.results.isNotEmpty()) KidColors.Red else Color.Gray,
                        fontSize = 17.sp)
                }
            }
            Footer(lang.pick("Progress is saved only on this device.", "进度只保存在这台设备上。"))
        }
    }
    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            title = { Text(lang.pick("Erase all math progress?", "要清除所有数学进度吗？")) },
            confirmButton = {
                TextButton(onClick = { MathProgressStore.clear(); confirmReset = false }) {
                    Text(lang.pick("Erase progress", "清除进度"), color = KidColors.Red)
                }
            },
            dismissButton = { TextButton(onClick = { confirmReset = false }) { Text(lang.pick("Cancel", "取消")) } },
        )
    }
}

@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
    )
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), fontSize = 17.sp)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun Footer(text: String) {
    Text(text, Modifier.padding(horizontal = 8.dp), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

