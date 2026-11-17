package com.chengjianglong.soofunny.ui

import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.chengjianglong.soofunny.core.AppUpdate
import com.chengjianglong.soofunny.ui.books.ParentalGate
import com.chengjianglong.soofunny.ui.settings.findActivity

/**
 * The reminder, as on iOS: "A new SooFunny is ready!", with Update (after the grown-up check) and
 * Not now (hides this version for 3 days). Shown over any screen while [AppUpdate.available] is set.
 */
@Composable
fun UpdateReminder(launcher: ActivityResultLauncher<IntentSenderRequest>) {
    if (AppUpdate.available == null) return
    val lang = language
    val context = LocalContext.current
    var showGate by remember { mutableStateOf(false) }
    Dialog(onDismissRequest = { AppUpdate.snooze() }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxSize().background(Color.White).statusBarsPadding().navigationBarsPadding()) {
            Box(Modifier.fillMaxWidth()) {
                TextButton(onClick = { AppUpdate.snooze() }, modifier = Modifier.align(Alignment.CenterStart).padding(horizontal = 8.dp)) {
                    Text(lang.pick("Close", "关闭"), fontSize = 17.sp)
                }
            }
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
            ) {
                Column(Modifier.widthIn(max = 520.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(18.dp)) {
                    Text("🎉", fontSize = 56.sp)
                    Text(lang.pick("A new SooFunny is ready!", "SooFunny 有新版本啦！", "\n"),
                        fontSize = 28.sp, fontWeight = FontWeight.Black, textAlign = TextAlign.Center)
                    Text(lang.pick("Update for the newest fun and fixes.", "更新一下，体验最新的内容和改进。", "\n"),
                        fontSize = 17.sp, color = Color.Gray, textAlign = TextAlign.Center)
                    Button(onClick = { showGate = true }, colors = ButtonDefaults.buttonColors(containerColor = KidColors.Blue)) {
                        Text(lang.pick("Update", "更新"), fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    }
                    TextButton(onClick = { AppUpdate.snooze() }) {
                        Text(lang.pick("Not now", "以后再说"), fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
        if (showGate) {
            ParentalGate(
                reason = lang.pick("Updating opens Google Play.", "更新会打开 Google Play。", "\n"),
                onDismiss = { showGate = false },
                onPassed = {
                    showGate = false
                    context.findActivity()?.let { AppUpdate.update(it, launcher) }
                },
            )
        }
    }
}
