package com.chengjianglong.soofunny.ui.math

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.gradient
import com.chengjianglong.soofunny.ui.language
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlin.math.roundToInt

private val dateFormat = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)

@Composable
internal fun MathProgressScreen() {
    val lang = language
    val results = MathProgressStore.results.toList()
    val tricky = MathStats.trickyQuestions(results)
    val secondary = MaterialTheme.colorScheme.onSurfaceVariant
    Column(Modifier.fillMaxSize()) {
        SooTopBar(title = lang.pick("Progress Reports", "学习报告"), onBack = { MathState.pop() })
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Stat("${results.size}", lang.pick("rounds", "轮"), "🏁", Modifier.weight(1f))
                    Stat("${MathStats.totalQuestions(results)}", lang.pick("questions", "道题"), "🧮", Modifier.weight(1f))
                    Stat("${MathStats.streak(results)}", lang.pick("day streak", "连续天数"), "🔥", Modifier.weight(1f))
                }
            }
            item {
                Group(lang.pick("How you're doing", "学得怎么样")) {
                    MathStats.operationStats(results).forEach { stat ->
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(vertical = 4.dp)) {
                            Box(Modifier.size(44.dp).clip(CircleShape).background(stat.operation.color.gradient()), contentAlignment = Alignment.Center) {
                                Text(stat.operation.symbol, color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.ExtraBold)
                            }
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Row {
                                    Text(stat.operation.name(lang), Modifier.weight(1f), fontWeight = FontWeight.Bold, fontSize = 17.sp)
                                    Text(stat.accuracy?.let { "${(it * 100).roundToInt()}%" } ?: lang.pick("Not tried yet", "还没练习"),
                                        fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = secondary)
                                }
                                Box(Modifier.fillMaxWidth().height(12.dp).clip(RoundedCornerShape(6.dp)).background(secondary.copy(alpha = 0.15f))) {
                                    Box(Modifier.fillMaxWidth((stat.accuracy ?: 0.0).toFloat()).fillMaxHeight()
                                        .clip(RoundedCornerShape(6.dp)).background(stat.operation.color.gradient()))
                                }
                                if (stat.asked > 0) {
                                    Text(lang.pick("${stat.correct} of ${stat.asked} right", "${stat.asked}题答对${stat.correct}题"),
                                        fontSize = 12.sp, color = secondary)
                                }
                            }
                        }
                    }
                }
            }
            if (tricky.isNotEmpty()) {
                item {
                    Group(lang.pick("Tricky ones", "难题")) {
                        tricky.forEach { (q, misses) ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("${q.text} = ${q.answer}", Modifier.weight(1f), fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                                Text(lang.pick("missed $misses×", "错了${misses}次"), color = secondary)
                            }
                            HorizontalDivider()
                        }
                        TextButton(onClick = {
                            MathState.push(MathScreen.Play(MathSession(MathMode.QUIZ, tricky.map { it.first }, true)))
                        }) { Text("🎯 " + lang.pick("Practice tricky ones", "练习难题"), fontSize = 17.sp) }
                    }
                }
            }
            item {
                if (results.isEmpty()) {
                    Group(lang.pick("Recent rounds", "最近练习")) {
                        Text(lang.pick("No rounds yet. Try a flashcard game or a quiz!", "还没有练习。试试闪卡游戏或测验吧！"), color = secondary)
                    }
                } else {
                    SectionTitle(lang.pick("Recent rounds", "最近练习"))
                }
            }
            items(results.take(30), key = { it.id }) { result ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f))
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(if (result.mode == MathMode.QUIZ) "✏️" else "🃏", fontSize = 26.sp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(result.operations.joinToString(" ") { it.symbol } + "  ·  " + result.mode.title(lang),
                            fontWeight = FontWeight.Bold, fontSize = 17.sp)
                        Text(dateFormat.format(Instant.ofEpochMilli(result.date).atZone(ZoneId.systemDefault())), fontSize = 12.sp, color = secondary)
                    }
                    Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(if (result.score != null) "${result.correctCount}/${result.marked.size}" else lang.pick("${result.total} cards", "${result.total}张"),
                            fontWeight = FontWeight.Bold, fontSize = 17.sp)
                        Text("⭐".repeat(result.stars), fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun Stat(value: String, label: String, emoji: String, modifier: Modifier) {
    Column(
        modifier.heightIn(min = 110.dp).clip(RoundedCornerShape(20.dp)).background(MaterialTheme.colorScheme.surfaceVariant).padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
    ) {
        Text(emoji, fontSize = 28.sp)
        Text(value, fontSize = 28.sp, fontWeight = FontWeight.ExtraBold)
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
    }
}

@Composable
private fun Group(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionTitle(title)
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content,
        )
    }
}
