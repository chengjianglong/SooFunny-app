package com.chengjianglong.soofunny.ui

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.AppSettings
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Speech
import kotlin.math.max
import kotlin.math.sin
import kotlin.random.Random

/** The iOS system colors the app uses, so both apps look alike. */
object KidColors {
    val Pink = Color(0xFFFF2D55)
    val Orange = Color(0xFFFF9500)
    val Yellow = Color(0xFFFFCC00)
    val Green = Color(0xFF34C759)
    val Mint = Color(0xFF00C7BE)
    val Teal = Color(0xFF30B0C7)
    val Cyan = Color(0xFF32ADE6)
    val Blue = Color(0xFF007AFF)
    val Indigo = Color(0xFF5856D6)
    val Purple = Color(0xFFAF52DE)
    val Red = Color(0xFFFF3B30)
    val Brown = Color(0xFFA2845E)
    val Gray = Color(0xFF8E8E93)
    val Rainbow = listOf(Pink, Orange, Yellow, Green, Teal, Blue, Indigo, Purple)

    /** A SwiftUI color name from the iOS data ("purple", "mint"…). */
    fun named(name: String): Color = when (name) {
        "pink" -> Pink; "orange" -> Orange; "yellow" -> Yellow; "green" -> Green; "mint" -> Mint
        "teal" -> Teal; "cyan" -> Cyan; "blue" -> Blue; "indigo" -> Indigo; "purple" -> Purple
        "red" -> Red; "brown" -> Brown; else -> Gray
    }
}

/** A lighter-to-darker gradient of [color], like SwiftUI's `.gradient`. */
fun Color.gradient(): Brush = Brush.verticalGradient(listOf(lerp(this, Color.White, 0.18f), this))

private fun lerp(a: Color, b: Color, t: Float) =
    Color(a.red + (b.red - a.red) * t, a.green + (b.green - a.green) * t, a.blue + (b.blue - a.blue) * t, a.alpha)

/** The current app language, observed by Compose. */
val language: LearningLanguage @Composable get() = AppSettings.language

/** Buttons squish a little when pressed. */
fun Modifier.squishClickable(enabled: Boolean = true, onClick: () -> Unit): Modifier = composed {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.93f else 1f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium), label = "squish")
    this.scale(scale).clickable(interactionSource = interaction, indication = null, enabled = enabled, onClick = onClick)
}

/** "SooFunny" with each letter gently bouncing in turn, at the top of every tab. */
@Composable
fun BouncyTitle(modifier: Modifier = Modifier, fontSize: Int = 54) {
    var t by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { t = it - start }
    }
    Row(modifier.semantics { heading(); contentDescription = "SooFunny" }) {
        "SooFunny".forEachIndexed { i, letter ->
            val phase = t / 1000.0 * 3 - i * 0.45
            val s = sin(phase)
            Text(
                letter.toString(),
                style = TextStyle(
                    fontSize = fontSize.sp, fontWeight = FontWeight.Black,
                    brush = KidColors.Rainbow[i % KidColors.Rainbow.size].gradient(),
                    shadow = Shadow(Color.Black.copy(alpha = 0.12f), Offset(4f, 6f), 0f),
                ),
                modifier = Modifier.graphicsLayer {
                    translationY = (-max(0.0, s) * 10 * density).toFloat()
                    rotationZ = (s * 4).toFloat()
                },
            )
        }
    }
}

/** Soft confetti dots behind a page. */
@Composable
fun FunBackground(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val rng = Random(42)
        val colors = listOf(KidColors.Pink, KidColors.Orange, KidColors.Yellow, KidColors.Green, KidColors.Blue, KidColors.Purple)
        repeat(60) {
            val x = rng.nextFloat() * size.width
            val y = rng.nextFloat() * size.height
            val r = (4 + rng.nextInt(10)) * density / 2
            drawCircle(colors[rng.nextInt(colors.size)].copy(alpha = 0.18f), r, Offset(x, y))
        }
    }
}

/** The 🌐 English / 中文 / Bilingual switch, kept in the top bar of every tab. */
@Composable
fun LanguageSwitch() {
    var open by remember { mutableStateOf(false) }
    val current = AppSettings.language
    Box {
        TextButton(onClick = { open = true }, modifier = Modifier.semantics { contentDescription = "Language: ${current.label}" }) {
            Text("🌐 ${current.shortLabel}", fontWeight = FontWeight.Bold, fontSize = 15.sp)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            LearningLanguage.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.label) },
                    leadingIcon = { Text(if (option == current) "✓" else "  ", fontWeight = FontWeight.Bold) },
                    onClick = { AppSettings.language = option; open = false },
                )
            }
        }
    }
}

/** Speaker button that pulses while its text is being read. */
@Composable
fun SpeakButton(text: String, modifier: Modifier = Modifier, size: Int = 22, tint: Color = MaterialTheme.colorScheme.primary) {
    val isSpeaking = Speech.speaking == text
    var tick by remember { mutableLongStateOf(0L) }
    LaunchedEffect(isSpeaking) { while (isSpeaking) withFrameMillis { tick = it } }
    val pulse = if (isSpeaking) 1f + 0.12f * sin(tick / 120.0).toFloat() else 1f
    IconButton(
        onClick = { if (isSpeaking) Speech.stop() else Speech.speak(text) },
        modifier = modifier.size((size * 2).dp).semantics { contentDescription = if (isSpeaking) "Stop" else "Say $text" },
    ) {
        Text(if (isSpeaking) "🔊" else "🔈", fontSize = size.sp, modifier = Modifier.scale(pulse), color = tint)
    }
}

/**
 * A tab's top bar: optional Back on the left (or [leading]), the title, then the language switch
 * and any [actions].
 */
@Composable
fun SooTopBar(
    title: String = "",
    onBack: (() -> Unit)? = null,
    backLabel: String? = null,
    leading: (@Composable RowScope.() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Surface(color = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f), shadowElevation = 1.dp) {
        Row(
            Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (onBack != null) {
                TextButton(onClick = onBack) {
                    Text("‹ ", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    Text(backLabel ?: language.pick("Back", "返回"), maxLines = 1, overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.widthIn(max = 140.dp))
                }
            }
            leading?.invoke(this)
            Text(
                title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
            )
            Row(horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
                actions()
                LanguageSwitch()
            }
        }
    }
}

/** Gear button that opens Settings. */
@Composable
fun SettingsButton(onClick: () -> Unit) {
    val label = language.pick("Settings", "设置")
    IconButton(onClick = onClick, modifier = Modifier.semantics { contentDescription = label }) { Text("⚙️", fontSize = 22.sp) }
}

/** A big, colorful, rounded button. */
@Composable
fun KidButton(text: String, color: Color, modifier: Modifier = Modifier, emoji: String? = null, enabled: Boolean = true, onClick: () -> Unit) {
    Box(
        modifier
            .squishClickable(enabled, onClick)
            .alpha(if (enabled) 1f else 0.45f)
            .clip(RoundedCornerShape(18.dp))
            .background(color.gradient())
            .padding(horizontal = 18.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            listOfNotNull(emoji, text).joinToString("  "),
            color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, maxLines = 2,
        )
    }
}

/**
 * Grid columns as on iOS (`GridItem(.adaptive(minimum:))`): as many as fit at [minSize] each, but
 * never fewer than [minCount], so a narrow phone still shows two cards per row.
 */
class AtLeastColumns(private val minSize: androidx.compose.ui.unit.Dp, private val minCount: Int = 2) :
    androidx.compose.foundation.lazy.grid.GridCells {
    override fun androidx.compose.ui.unit.Density.calculateCrossAxisCellSizes(availableSize: Int, spacing: Int): List<Int> {
        val count = maxOf(minCount, (availableSize + spacing) / (minSize.roundToPx() + spacing))
        val total = availableSize - spacing * (count - 1)
        return List(count) { total / count + if (it < total % count) 1 else 0 }
    }

    override fun equals(other: Any?) = other is AtLeastColumns && other.minSize == minSize && other.minCount == minCount
    override fun hashCode() = minSize.hashCode() * 31 + minCount
}
