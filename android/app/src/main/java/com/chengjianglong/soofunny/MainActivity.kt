package com.chengjianglong.soofunny

import android.graphics.Bitmap
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.AppSettings
import com.chengjianglong.soofunny.core.ScannedBookStore
import com.chengjianglong.soofunny.core.Speech
import com.chengjianglong.soofunny.engine.SubjectMask
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.books.BooksTab
import com.chengjianglong.soofunny.ui.color.ColorTab
import com.chengjianglong.soofunny.ui.color.ColoringScreen
import com.chengjianglong.soofunny.ui.color.ShowcasePicture
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.math.MathTab
import com.chengjianglong.soofunny.ui.settings.SettingsScreen
import com.chengjianglong.soofunny.ui.sports.SportsTab
import com.chengjianglong.soofunny.ui.words.WordsTab

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppSettings.init(this)
        Speech.init(this)
        ScannedBookStore.init(this)
        SubjectMask.init(this)
        enableEdgeToEdge()
        setContent {
            MaterialTheme(colorScheme = lightColorScheme(primary = KidColors.Blue, secondary = KidColors.Pink)) {
                SooFunnyApp()
            }
        }
    }

    override fun onStop() {
        super.onStop()
        Speech.stop()
    }
}

/** The five tabs, in the iOS order. */
enum class Tab(val emoji: String, val english: String, val chinese: String) {
    COLOR("🎨", "Color", "涂色"),
    WORDS("🔤", "Words", "单词"),
    SPORTS("🏃", "Sports", "运动"),
    BOOKS("📚", "Books", "绘本"),
    MATH("➕", "Math", "数学"),
}

@Composable
fun SooFunnyApp() {
    var tab by rememberSaveable { mutableStateOf(Tab.COLOR) }
    var showSettings by rememberSaveable { mutableStateOf(false) }
    var coloring by remember { mutableStateOf<Pair<Bitmap, ShowcasePicture?>?>(null) }
    // Each tab keeps its place (open group, word, book…) while another tab is shown.
    val tabStates = rememberSaveableStateHolder()

    coloring?.let { (source, picture) ->
        BackHandler { coloring = null }
        ColoringScreen(source = source, picture = picture, onClose = { coloring = null })
        return
    }
    if (showSettings) {
        BackHandler { showSettings = false }
        SettingsScreen(onClose = { showSettings = false })
        return
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                Tab.entries.forEach { item ->
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = { tab = item; Speech.stop() },
                        icon = { Text(item.emoji, fontSize = 22.sp) },
                        label = { Text(language.pick(item.english, item.chinese, " ")) },
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            tabStates.SaveableStateProvider(tab.name) {
                when (tab) {
                    Tab.COLOR -> ColorTab(onPick = { bitmap, picture -> coloring = bitmap to picture }, onSettings = { showSettings = true })
                    Tab.WORDS -> WordsTab()
                    Tab.SPORTS -> SportsTab()
                    Tab.BOOKS -> BooksTab()
                    Tab.MATH -> MathTab()
                }
            }
        }
    }
}
