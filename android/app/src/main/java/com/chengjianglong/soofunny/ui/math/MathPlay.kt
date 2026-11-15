package com.chengjianglong.soofunny.ui.math

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Speech
import com.chengjianglong.soofunny.ui.KidButton
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.squishClickable
import kotlinx.coroutines.delay
import kotlin.math.sin
import kotlin.random.Random

private val Accent = KidColors.Blue

/** Results already saved, so a round is stored once even if its screen is shown again. */
private val savedResults = mutableSetOf<String>()

/** A flashcard round or quiz, then the results. [onClose] gets questions to practice again, if chosen. */
@Composable
internal fun MathPlayScreen(session: MathSession, onClose: (List<MathQuestion>?) -> Unit) {
    val lang = language
    val settings = MathState.settings
    val result = session.finishedResult

    LaunchedEffect(session, session.index, lang, result) {
        if (settings.readAloud && result == null) Speech.speak(session.current.spokenQuestion(lang))
    }
    LaunchedEffect(result) {
        if (result != null && savedResults.add(result.id)) MathProgressStore.add(result)
    }

    Column(Modifier.fillMaxSize()) {
        SooTopBar(
            title = session.mode.title(lang),
            actions = {
                if (result == null) {
                    TextButton(onClick = { onClose(null) }) { Text(lang.pick("Exit", "退出"), fontWeight = FontWeight.Bold, fontSize = 16.sp) }
                }
            },
        )
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
            when {
                result != null -> MathResultView(result, onAgain = { onClose(result.missed) }, onDone = { onClose(null) })
                session.mode == MathMode.FLASHCARDS -> Flashcard(session, lang)
                else -> Quiz(session, lang, settings)
            }
        }
    }
}

@Composable
private fun ProgressHeader(session: MathSession, lang: LearningLanguage, showTimer: Boolean) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(session.progressText(lang), fontWeight = FontWeight.Bold, fontSize = 17.sp)
            if (session.mode == MathMode.QUIZ && showTimer) {
                var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
                LaunchedEffect(Unit) {
                    while (true) {
                        now = System.currentTimeMillis()
                        delay(250)
                    }
                }
                Text("⏱ " + clock((now - session.startTime) / 1000), fontWeight = FontWeight.Bold, fontSize = 17.sp, color = Accent)
            }
        }
        LinearProgressIndicator(
            progress = { session.index.toFloat() / session.questions.size },
            modifier = Modifier.widthIn(max = 320.dp).fillMaxWidth().height(6.dp),
            color = KidColors.Green,
        )
    }
}

private fun clock(seconds: Long) = "%d:%02d".format(seconds / 60, seconds % 60)

// MARK: Flashcard

@Composable
private fun Flashcard(session: MathSession, lang: LearningLanguage) {
    val spin = remember(session.index) { Animatable(0f) }
    LaunchedEffect(session.index, session.revealed) {
        if (session.revealed) spin.animateTo(360f, spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessLow))
    }
    val q = session.current
    val cardLabel = if (session.revealed) "${q.spokenText} equals ${q.answer}" else "${q.spokenText}. Tap to see the answer"
    Column(
        Modifier.fillMaxSize().widthIn(max = 640.dp).padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        ProgressHeader(session, lang, false)
        Text(
            if (session.revealed) {
                if (session.markQuestions) lang.pick("Did you get it right?", "你答对了吗？")
                else lang.pick("Tap Next for another card", "点“下一个”换一张卡片")
            } else lang.pick("Think of the answer, then tap the card to check", "想一想答案，再点卡片看看"),
            fontWeight = FontWeight.Bold, fontSize = 17.sp, textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            // Fit four lines of numbers (plus the card's padding) in the space there is.
            val byHeight = (maxHeight.value - 56f - 18f) / 4.4f
            Box(
                Modifier
                    .widthIn(max = 520.dp).fillMaxWidth()
                    .graphicsLayer { rotationY = spin.value; cameraDistance = 16 * density }
                    .shadow(12.dp, RoundedCornerShape(28.dp))
                    .clip(RoundedCornerShape(28.dp))
                    .background(Color.White)
                    .squishClickable { session.reveal() }
                    .semantics { contentDescription = cardLabel }
                    .padding(vertical = 28.dp),
                contentAlignment = Alignment.Center,
            ) {
                VerticalProblem(q, session.revealed, maxFont = byHeight.coerceIn(24f, 96f))
            }
        }
        if (session.revealed) {
            if (session.markQuestions) {
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    BigButton(lang.pick("Not yet", "还没有"), "✗", KidColors.Red, Modifier.weight(1f)) { session.mark(false) }
                    BigButton(lang.pick("Got it!", "答对了！"), "✓", KidColors.Green, Modifier.weight(1f)) { session.mark(true) }
                }
            } else {
                BigButton(lang.pick("Next", "下一个"), "→", Accent) { session.mark(null) }
            }
        } else {
            BigButton(lang.pick("Show answer", "看答案"), "👀", Accent) { session.reveal() }
        }
    }
}

/** A problem written the school way: numbers stacked, with a line and the answer below. */
@Composable
private fun VerticalProblem(question: MathQuestion, showAnswer: Boolean, maxFont: Float = 96f) {
    BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal = 40.dp), contentAlignment = Alignment.Center) {
        // Widest line is "× 12" (symbol, a gap, up to 3 digits): shrink the type to fit.
        val digits = maxOf(question.left.toString().length, question.right.toString().length + 2, question.answer.toString().length)
        val fit = (maxWidth.value / (digits * 0.62f + 0.6f))
        val size = minOf(maxFont, fit).sp
        Column(Modifier.width(IntrinsicSize.Max), horizontalAlignment = Alignment.End) {
            Text("${question.left}", fontSize = size, fontWeight = FontWeight.ExtraBold, color = Color.Black, lineHeight = size)
            Row(horizontalArrangement = Arrangement.spacedBy(30.dp)) {
                Text(question.operation.symbol, fontSize = size, fontWeight = FontWeight.ExtraBold, color = question.operation.color, lineHeight = size)
                Text("${question.right}", fontSize = size, fontWeight = FontWeight.ExtraBold, color = Color.Black, lineHeight = size)
            }
            Box(Modifier.padding(vertical = 6.dp).fillMaxWidth().height(6.dp).background(Color.Black))
            Text(
                if (showAnswer) "${question.answer}" else "?", fontSize = size, fontWeight = FontWeight.ExtraBold, lineHeight = size,
                color = if (showAnswer) Accent else Color.Gray,
            )
        }
    }
}

// MARK: Quiz

private val cheers = listOf(
    "Great job!" to "真棒！", "You got it!" to "答对了！", "Super!" to "太厉害了！",
    "Awesome!" to "好极了！", "Yes!" to "对啦！",
)

@Composable
private fun Quiz(session: MathSession, lang: LearningLanguage, settings: MathSettings) {
    val haptics = LocalHapticFeedback.current
    val cheer = cheers[session.index % cheers.size]
    val q = session.current
    fun check() {
        val right = session.check() ?: return
        haptics.performHapticFeedback(if (right) HapticFeedbackType.Confirm else HapticFeedbackType.Reject)
        if (settings.readAloud) {
            Speech.speak(
                if (right) lang.spoken(cheer.first, cheer.second)
                else lang.spoken("Nice try.", "差一点。") + " " + q.spokenAnswer(lang),
            )
        }
    }
    Column(
        Modifier.fillMaxSize().widthIn(max = 560.dp).padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        ProgressHeader(session, lang, settings.showTimer)
        BoxWithConstraints(Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
            val chars = q.text.length + 2 + maxOf(session.typed.length, 2)
            val size = minOf(54f, maxWidth.value / (chars * 0.6f + 1.2f)).sp
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(q.text + " =", fontSize = size, fontWeight = FontWeight.ExtraBold, maxLines = 1)
                Box(
                    Modifier.clip(RoundedCornerShape(14.dp)).background(Accent.copy(alpha = 0.12f))
                        .widthIn(min = (size.value * 1.3f).dp).padding(horizontal = 10.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        session.typed.ifEmpty { "?" }, fontSize = size, fontWeight = FontWeight.ExtraBold, maxLines = 1,
                        color = if (session.typed.isEmpty()) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }

        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            val right = session.feedback
            if (right != null) {
                val pop = remember(session.index) { Animatable(0.2f) }
                LaunchedEffect(session.index) { pop.animateTo(1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMedium)) }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.scale(pop.value)) {
                    val color = if (right) KidColors.Green else KidColors.Red
                    Text(if (right) "✓" else "✗", fontSize = 90.sp, fontWeight = FontWeight.Black, color = color)
                    Text(
                        if (right) lang.pick(cheer.first, cheer.second) else lang.pick("It's ${q.answer}", "答案是${q.answer}"),
                        fontSize = 24.sp, fontWeight = FontWeight.Bold, color = color, textAlign = TextAlign.Center,
                    )
                }
            } else {
                NumberPad(onDigit = { session.type(it) }, onDelete = { session.deleteDigit() })
            }
        }

        if (session.feedback != null) {
            BigButton(lang.pick("Next", "下一个"), "→", Accent) { session.next() }
        } else {
            BigButton(lang.pick("Check", "检查"), "✓", KidColors.Green, enabled = session.typed.isNotEmpty()) { check() }
        }
    }
}

@Composable
private fun NumberPad(onDigit: (Int) -> Unit, onDelete: () -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        val gap = 12.dp
        val key: Dp = min(min((maxHeight - gap * 3) / 4, (min(maxWidth, 360.dp) - gap * 2) / 3), 80.dp)
        Column(verticalArrangement = Arrangement.spacedBy(gap)) {
            listOf(listOf(1, 2, 3), listOf(4, 5, 6), listOf(7, 8, 9)).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(gap)) { row.forEach { PadKey("$it", key) { onDigit(it) } } }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                Spacer(Modifier.size(key))
                PadKey("0", key) { onDigit(0) }
                PadKey("⌫", key, color = KidColors.Red, label = "Delete", onClick = onDelete)
            }
        }
    }
}

@Composable
private fun PadKey(text: String, size: Dp, color: Color = MaterialTheme.colorScheme.onSurface, label: String? = null, onClick: () -> Unit) {
    Box(
        Modifier.size(size)
            .squishClickable(onClick = onClick)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .border(2.dp, Accent.copy(alpha = 0.35f), CircleShape)
            .then(if (label != null) Modifier.semantics { contentDescription = label } else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, fontSize = (size.value * 0.42f).sp, fontWeight = FontWeight.Bold, color = color)
    }
}

@Composable
internal fun BigButton(title: String, emoji: String, color: Color, modifier: Modifier = Modifier.fillMaxWidth(), enabled: Boolean = true, onClick: () -> Unit) {
    KidButton(title, color, modifier.heightIn(min = 60.dp), emoji = emoji, enabled = enabled, onClick = onClick)
}

// MARK: Results

@Composable
private fun MathResultView(result: MathResult, onAgain: () -> Unit, onDone: () -> Unit) {
    val lang = language
    val praise = when (result.stars) {
        3 -> "Amazing!" to "太棒了！"
        2 -> "Great work!" to "做得好！"
        1 -> "Good try!" to "不错的尝试！"
        else -> "Keep practicing!" to "继续练习！"
    }
    val emoji = listOf("🌱", "💪", "🌟", "🎉")[result.stars.coerceIn(0, 3)]
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(result.id) {
        shown = true
        Speech.speak(lang.spoken(praise.first, praise.second))
    }
    val s = result.seconds.toInt()
    val time = if (s < 60) lang.pick("$s seconds", "${s}秒") else lang.pick("${s / 60} min ${s % 60} s", "${s / 60}分${s % 60}秒")

    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Column(Modifier.widthIn(max = 560.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Text(lang.pick(praise.first, praise.second) + " " + emoji, fontSize = 38.sp, fontWeight = FontWeight.Black,
                    textAlign = TextAlign.Center, lineHeight = 44.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    repeat(3) { i ->
                        var go by remember { mutableStateOf(false) }
                        LaunchedEffect(shown) { if (shown) { delay(i * 200L); go = true } }
                        val scale by animateFloatAsState(
                            if (go) 1f else 0.2f,
                            spring(dampingRatio = 0.4f, stiffness = Spring.StiffnessLow), label = "star$i",
                        )
                        Text(if (i < result.stars) "⭐" else "☆", fontSize = 50.sp, color = KidColors.Yellow,
                            modifier = Modifier.scale(scale))
                    }
                }
                Text(
                    if (result.score != null) lang.pick("${result.correctCount} of ${result.marked.size} right", "${result.marked.size}题答对${result.correctCount}题")
                    else lang.pick("${result.total} cards practiced", "练习了${result.total}张卡片"),
                    fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center,
                )
                Text("⏱ $time", fontWeight = FontWeight.Bold, fontSize = 17.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

                val missed = result.missed
                if (missed.isNotEmpty()) {
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(MaterialTheme.colorScheme.surfaceVariant).padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(lang.pick("Let's practice these again", "再练练这些吧"), fontWeight = FontWeight.Bold, fontSize = 17.sp)
                        missed.chunked(2).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                row.forEach { q ->
                                    Text(
                                        "${q.text} = ${q.answer}",
                                        Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).background(KidColors.Orange.copy(alpha = 0.15f)).padding(10.dp),
                                        fontSize = 20.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center, maxLines = 1,
                                    )
                                }
                                if (row.size == 1) Spacer(Modifier.weight(1f))
                            }
                        }
                    }
                    BigButton(lang.pick("Practice missed ones", "练习做错的题"), "🔁", KidColors.Orange, onClick = onAgain)
                }
                OutlinedButton(onClick = onDone, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
                    Text(lang.pick("Done", "完成"), fontSize = 20.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
        if (result.stars == 3) Confetti(Modifier.fillMaxSize())
    }
}

/** Falling confetti for a perfect round. Doesn't take touches. */
@Composable
private fun Confetti(modifier: Modifier = Modifier) {
    var t by remember { mutableStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameMillis { it }
        while (t < 4f) withFrameMillis { t = (it - start) / 1000f }
    }
    val colors = listOf(KidColors.Pink, KidColors.Orange, KidColors.Yellow, KidColors.Green, KidColors.Blue, KidColors.Purple)
    Canvas(modifier) {
        if (t >= 4f) return@Canvas
        val rng = Random(3)
        repeat(90) {
            val x0 = rng.nextFloat() * size.width
            val speed = (180 + rng.nextInt(260)) * density
            val sway = rng.nextInt(60) * density
            val y = -20 * density + speed * t
            val x = x0 + sin(t * 3 + x0) * sway
            val color = colors[rng.nextInt(colors.size)]
            drawRoundRect(
                color.copy(alpha = (1 - t / 4).coerceIn(0f, 1f)), Offset(x, y), Size(10 * density, 14 * density),
                CornerRadius(3 * density),
            )
        }
    }
}
