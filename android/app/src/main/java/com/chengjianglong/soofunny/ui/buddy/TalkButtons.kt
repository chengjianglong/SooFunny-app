package com.chengjianglong.soofunny.ui.buddy

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.material3.Text
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.ui.squishClickable

/** The small ✨ button on a word row that opens the talking buddy about that word. */
@Composable
fun TalkSparkle(label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier.size(44.dp).squishClickable(onClick = onClick)
            .semantics { contentDescription = label; role = Role.Button },
        contentAlignment = Alignment.Center,
    ) { Text("✨", fontSize = 22.sp) }
}
