package com.chengjianglong.soofunny.ui.books

import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import com.chengjianglong.soofunny.core.AudiobookMaker
import com.chengjianglong.soofunny.core.ScannedBook
import com.chengjianglong.soofunny.core.ScannedBookStore
import com.chengjianglong.soofunny.core.Speech
import com.chengjianglong.soofunny.ui.KidButton
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.language
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File
import kotlin.random.Random

/** A scanned book's audiobook: make it, listen to it, or (after the grown-up check) share it. */
@Composable
fun AudiobookSection(book: ScannedBook) {
    val context = LocalContext.current
    val lang = language
    val scope = rememberCoroutineScope()
    val file = ScannedBookStore.audioFile(book)
    var version by remember { mutableIntStateOf(0) } // bumps when the file changes
    val exists = remember(book, version) { file.exists() }
    var making by remember { mutableStateOf<Job?>(null) }
    var progress by remember { mutableFloatStateOf(0f) }
    var failed by remember { mutableStateOf(false) }
    var player by remember { mutableStateOf<MediaPlayer?>(null) }
    var gate by remember { mutableStateOf(false) }

    fun stop() {
        player?.release()
        player = null
    }
    DisposableEffect(book.id) { onDispose { stop(); making?.cancel() } }

    Column(
        Modifier.widthIn(max = 480.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("🎧 " + lang.pick("Audiobook", "有声书"), fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
        when {
            making != null -> {
                Text(lang.pick("Making the audiobook… ${(progress * 100).toInt()}%", "正在做有声书……${(progress * 100).toInt()}%"))
                LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth())
                TextButton(onClick = { making?.cancel(); making = null }) { Text(lang.pick("Cancel", "取消")) }
            }
            exists -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                KidButton(if (player != null) lang.pick("Stop", "停") else lang.pick("Listen", "听"), KidColors.Purple,
                    Modifier.weight(1f), emoji = if (player != null) "■" else "▶") {
                    if (player != null) stop() else {
                        Speech.stop()
                        player = runCatching {
                            MediaPlayer().apply {
                                setDataSource(file.path)
                                setOnCompletionListener { stop() }
                                prepare()
                                start()
                            }
                        }.getOrNull()
                    }
                }
                OutlinedButton(onClick = { gate = true }) { Text("📤 " + lang.pick("Share", "分享")) }
            }
            else -> {
                Text(lang.pick("Turn this book into an audio file, to listen to anytime.", "把这本书做成有声书，随时都能听。"),
                    fontSize = 14.sp, color = Color.Gray)
                KidButton(lang.pick("Make audiobook", "做成有声书"), KidColors.Purple, Modifier.fillMaxWidth(), emoji = "〰️") {
                    progress = 0f
                    making = scope.launch {
                        try {
                            AudiobookMaker.make(context, book.pages.map { it.text }, file) { progress = it }
                            version++
                        } catch (e: AudiobookMaker.NoVoiceException) {
                            failed = true
                        } catch (e: kotlinx.coroutines.CancellationException) {
                            throw e
                        } catch (e: Exception) {
                            failed = true
                        } finally {
                            making = null
                        }
                    }
                }
            }
        }
    }

    if (failed) {
        AlertDialog(
            onDismissRequest = { failed = false },
            confirmButton = { TextButton(onClick = { failed = false }) { Text(lang.pick("OK", "好")) } },
            title = { Text(lang.pick("Couldn't make the audiobook", "做不了有声书")) },
            text = { Text(lang.pick("There were no words to read aloud. Check them with Fix the words, then try again.",
                "没有可以朗读的文字。请用“修改文字”检查，然后再试一次。")) },
        )
    }
    if (gate) {
        ParentalGate(
            reason = lang.pick("Sharing sends the audiobook out of the app. Only share books you're allowed to copy.",
                "分享会把有声书发送到应用外。只分享你有权复制的书。", "\n"),
            onDismiss = { gate = false },
        ) {
            gate = false
            shareAudio(context, file, book.title)
        }
    }
}

private fun shareAudio(context: Context, file: File, title: String) {
    runCatching {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val send = Intent(Intent.ACTION_SEND).setType("audio/mp4").putExtra(Intent.EXTRA_STREAM, uri)
            .putExtra(Intent.EXTRA_TITLE, title).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.startActivity(Intent.createChooser(send, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}

/** "Ask a grown-up": a multiplication question young children can't answer, as on iOS. */
@Composable
fun ParentalGate(reason: String, onDismiss: () -> Unit, onPassed: () -> Unit) {
    val lang = language
    fun question() = Random.nextInt(12, 20) to Random.nextInt(6, 10)
    var q by remember { mutableStateOf(question()) }
    var answer by remember { mutableStateOf("") }
    var wrong by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(lang.pick("Ask a grown-up", "请家长来", "\n")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(reason, fontSize = 14.sp, color = Color.Gray)
                Text(lang.pick("What is ${q.first} × ${q.second}?", "${q.first} × ${q.second} 等于几？", "\n"), fontSize = 20.sp, fontWeight = FontWeight.Bold)
                OutlinedTextField(answer, { answer = it.filter(Char::isDigit) }, label = { Text(lang.pick("Answer", "答案")) },
                    singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
                if (wrong) Text(lang.pick("That's not right. Try this one.", "不对哦，换一题试试。"), color = KidColors.Red)
            }
        },
        confirmButton = {
            TextButton(enabled = answer.isNotEmpty(), onClick = {
                if (answer.toIntOrNull() == q.first * q.second) onPassed()
                else { wrong = true; answer = ""; q = question() }
            }) { Text(lang.pick("Continue", "继续")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(lang.pick("Cancel", "取消")) } },
    )
}
