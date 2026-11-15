package com.chengjianglong.soofunny.ui

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.Speech

/**
 * Text with the word being read aloud lit up in yellow, when [Speech] is reading exactly this
 * text and the voice reports where it is.
 */
@Composable
fun ReadAlongText(
    text: String,
    modifier: Modifier = Modifier,
    fontSize: Int = 22,
    fontWeight: FontWeight = FontWeight.Medium,
    color: Color = Color.Unspecified,
) {
    val range = if (Speech.speaking == text) Speech.range else null
    val annotated = buildAnnotatedString {
        if (range == null || range.first < 0 || range.last >= text.length || range.isEmpty()) {
            append(text)
        } else {
            append(text.substring(0, range.first))
            withStyle(SpanStyle(background = Color(0xC0FFE066), color = Color.Black)) {
                append(text.substring(range.first, range.last + 1))
            }
            append(text.substring(range.last + 1))
        }
    }
    Text(annotated, modifier = modifier, fontSize = fontSize.sp, fontWeight = fontWeight,
        lineHeight = (fontSize * 1.45).sp, color = color)
}
