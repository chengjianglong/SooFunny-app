package com.chengjianglong.soofunny.ui.color

import android.graphics.Bitmap
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.material3.TextButton
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.AlertDialog
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.engine.Palette
import com.chengjianglong.soofunny.engine.Rgb
import com.chengjianglong.soofunny.engine.SegmentDetail
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.squishClickable
import kotlin.math.min
import kotlin.math.roundToInt

/** The coloring screen: the picture split into blocks, the crayon box and the tools. */
@Composable
fun ColoringScreen(source: Bitmap, onClose: () -> Unit, picture: ShowcasePicture? = null) {
    val session = remember(source) { ColoringSession(source) }
    val context = LocalContext.current
    val lang = language
    var saved by remember { mutableStateOf<Boolean?>(null) }
    LaunchedEffect(session, session.detail) { session.prepare() }
    saved?.let { ok ->
        AlertDialog(
            onDismissRequest = { saved = null },
            confirmButton = { TextButton(onClick = { saved = null }) { Text(lang.pick("OK", "好")) } },
            title = { Text(if (ok) lang.pick("Saved to Photos!", "已保存到相册！") + " 🎉" else lang.pick("Couldn't save the picture", "保存失败")) },
            text = if (ok) {{ Text(lang.pick("Find it in Pictures › SooFunny.", "在“图片 › SooFunny”里可以找到。")) }} else null,
        )
    }

    Surface(Modifier.fillMaxSize(), color = Color(0xFFF2F2F7)) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            SooTopBar(
                title = picture?.title(lang) ?: lang.pick("My picture", "我的图片"),
                onBack = onClose, backLabel = lang.pick("Pictures", "图片"),
                actions = {
                    val canvas = session.canvas
                    if (canvas != null && !session.isProcessing) {
                        if (PictureFiles.canSave) {
                            val label = lang.pick("Save to Photos", "保存到相册")
                            IconButton(onClick = { saved = PictureFiles.saveToPhotos(context, canvas) },
                                modifier = Modifier.semantics { contentDescription = label }) { Text("💾", fontSize = 22.sp) }
                        }
                        val shareLabel = lang.pick("Share", "分享")
                        IconButton(onClick = { runCatching { PictureFiles.share(context, canvas, lang.pick("My SooFunny picture", "我的 SooFunny 画")) } },
                            modifier = Modifier.semantics { contentDescription = shareLabel }) { Text("📤", fontSize = 22.sp) }
                    }
                },
            )
            BoxWithConstraints(Modifier.fillMaxSize()) {
                // Tablet in landscape: tools beside the picture so the picture stays big.
                if (maxWidth > maxHeight && maxWidth >= 700.dp) {
                    Row(Modifier.fillMaxSize().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        CanvasView(session, Modifier.weight(1f).fillMaxSize())
                        Column(Modifier.width(320.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            DetailPicker(session)
                            ToolBar(session, columns = 2)
                            PaletteView(session, large = true)
                        }
                    }
                } else {
                    val large = maxWidth >= 600.dp
                    Column(Modifier.fillMaxSize().padding(top = 12.dp, bottom = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally) {
                        DetailPicker(session, Modifier.widthIn(max = 480.dp).padding(horizontal = 16.dp))
                        CanvasView(session, Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp))
                        ToolBar(session, columns = 5, modifier = Modifier.padding(horizontal = 12.dp))
                        PaletteView(session, large = large)
                    }
                }
            }
        }
    }
}

/** Block size choice, shown only for photos. */
@Composable
private fun DetailPicker(session: ColoringSession, modifier: Modifier = Modifier) {
    if (session.segmentation?.isLineArt != false) return
    val options = SegmentDetail.entries
    SingleChoiceSegmentedButtonRow(modifier.fillMaxWidth()) {
        options.forEachIndexed { index, detail ->
            SegmentedButton(
                selected = session.detail == detail,
                onClick = { session.detail = detail },
                shape = SegmentedButtonDefaults.itemShape(index, options.size),
                icon = {},
            ) {
                // In Bilingual the Chinese goes on a second line, so neither is cut off.
                Text(language.pick("${detail.title} blocks", detail.chineseTitle, "\n"), maxLines = 2, fontSize = 13.sp,
                    lineHeight = 15.sp, textAlign = TextAlign.Center)
            }
        }
    }
}

/** Shows the colored picture and turns taps and finger strokes into fills. */
@Composable
private fun CanvasView(session: ColoringSession, modifier: Modifier) {
    val haptics = LocalHapticFeedback.current
    BoxWithConstraints(modifier, contentAlignment = Alignment.Center) {
        val segmentation = session.segmentation
        val canvas = session.canvas
        if (segmentation != null && canvas != null) {
            val density = LocalDensity.current
            val containerW = constraints.maxWidth.toFloat()
            val containerH = constraints.maxHeight.toFloat()
            val scale = min(containerW / segmentation.width, containerH / segmentation.height)
            val w = (segmentation.width * scale).roundToInt().coerceAtLeast(1)
            val h = (segmentation.height * scale).roundToInt().coerceAtLeast(1)
            val image = remember(canvas) { canvas.asImageBitmap() }
            val sourceImage = remember(session.source) { session.source.asImageBitmap() }
            val shape = RoundedCornerShape(12.dp)
            Box(
                Modifier
                    .size(with(density) { w.toDp() }, with(density) { h.toDp() })
                    .shadow(8.dp, shape)
                    .clip(shape)
                    .background(Color.White)
                    .semantics { contentDescription = "Coloring picture with ${segmentation.regionCount} blocks" }
                    .pointerInput(segmentation) {
                        fun paint(position: Offset, starting: Boolean) {
                            val x = (position.x / size.width * segmentation.width).toInt()
                            val y = (position.y / size.height * segmentation.height).toInt()
                            if (session.paint(x, y, starting)) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        }
                        awaitEachGesture {
                            val down = awaitFirstDown()
                            down.consume()
                            paint(down.position, true)
                            while (true) {
                                val event = awaitPointerEvent()
                                val change = event.changes.firstOrNull { it.id == down.id } ?: break
                                if (!change.pressed) break
                                change.consume()
                                paint(change.position, false)
                            }
                        }
                    },
            ) {
                Canvas(Modifier.fillMaxSize()) {
                    session.version // redraw whenever the page is repainted
                    val dst = IntSize(size.width.roundToInt(), size.height.roundToInt())
                    drawImage(image, srcSize = IntSize(image.width, image.height), dstSize = dst, filterQuality = FilterQuality.High)
                    if (session.peek) {
                        drawImage(sourceImage, srcOffset = IntOffset.Zero, srcSize = IntSize(sourceImage.width, sourceImage.height),
                            dstSize = dst, alpha = 0.5f, filterQuality = FilterQuality.High)
                    }
                }
            }
        } else if (session.failed && !session.isProcessing) {
            Text(language.pick("Couldn't open that picture", "打不开这张图片"), style = MaterialTheme.typography.titleMedium)
        }
        if (session.isProcessing) {
            Column(
                Modifier.clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.92f)).padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                CircularProgressIndicator()
                Text(language.pick("Making blocks…", "正在分色块……"), fontWeight = FontWeight.Bold, fontSize = 17.sp)
            }
        }
    }
}

@Composable
private fun ToolBar(session: ColoringSession, columns: Int, modifier: Modifier = Modifier) {
    val lang = language
    // Tool names are short, so in Bilingual the Chinese goes on a second line.
    fun name(english: String, chinese: String) = lang.pick(english, chinese, "\n")
    val ready = session.segmentation != null
    val tools = listOf(
        Tool("↩️", name("Undo", "撤销"), KidColors.Blue, ready && session.canUndo) { session.undo() },
        Tool("🪄", name("Magic", "魔法"), KidColors.Purple, ready) { session.surprise() },
        Tool("🖼️", name("Real", "真实"), KidColors.Orange, ready) { session.realColors() },
        if (session.peek) Tool("🙈", name("Hide", "隐藏"), KidColors.Teal, ready) { session.peek = false }
        else Tool("👀", name("Peek", "偷看"), KidColors.Teal, ready) { session.peek = true },
        Tool("🗑️", name("Clear", "清除"), KidColors.Red, ready) { session.clear() },
    )
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        tools.chunked(columns).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { ToolButton(it, Modifier.weight(1f)) }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

private class Tool(val emoji: String, val title: String, val tint: Color, val enabled: Boolean, val action: () -> Unit)

@Composable
private fun ToolButton(tool: Tool, modifier: Modifier) {
    Column(
        modifier
            .squishClickable(tool.enabled, tool.action)
            .alpha(if (tool.enabled) 1f else 0.4f)
            .clip(RoundedCornerShape(12.dp))
            .background(tool.tint.copy(alpha = 0.15f))
            .heightIn(min = 52.dp)
            .padding(vertical = 6.dp, horizontal = 2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(tool.emoji, fontSize = 20.sp)
        Text(tool.title, color = tool.tint, fontWeight = FontWeight.Bold, fontSize = 12.sp, lineHeight = 14.sp,
            textAlign = TextAlign.Center, maxLines = 2)
    }
}

/** The crayon box. Scrolls sideways on phones, wraps on tablets. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PaletteView(session: ColoringSession, large: Boolean) {
    val size = if (large) 54.dp else 44.dp
    if (large) {
        FlowRow(
            Modifier.widthIn(max = 900.dp).padding(horizontal = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) { Swatches(session, size) }
    } else {
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) { Swatches(session, size) }
    }
}

@Composable
private fun Swatches(session: ColoringSession, size: androidx.compose.ui.unit.Dp) {
    Palette.crayons.forEach { color ->
        Swatch(Color(color), selected = session.selectedColor == color, size = size, label = "Crayon") {
            session.selectedColor = color
        }
    }
    Swatch(Color.White, selected = session.selectedColor == Rgb.WHITE, size = size, label = "Eraser", emoji = "🧽") {
        session.selectedColor = Rgb.WHITE
    }
    // More colors: a color of your own, picked with hue / brightness sliders.
    var picking by remember { mutableStateOf(false) }
    val custom = session.customColor
    Swatch(if (custom != null) Color(custom) else Color.White, selected = custom != null && session.selectedColor == custom,
        size = size, label = "More colors", emoji = if (custom == null) "🎨" else null) {
        if (custom != null && session.selectedColor != custom) session.selectedColor = custom else picking = true
    }
    if (picking) {
        ColorPickerDialog(initial = custom ?: session.selectedColor, onDismiss = { picking = false }) { color ->
            session.customColor = color
            session.selectedColor = color
            picking = false
        }
    }
}

/** A simple color picker: hue, how colorful, and how light, with a preview. */
@Composable
private fun ColorPickerDialog(initial: Int, onDismiss: () -> Unit, onPick: (Int) -> Unit) {
    val hsv = remember { FloatArray(3).also { android.graphics.Color.colorToHSV(initial, it) } }
    var hue by remember { mutableFloatStateOf(hsv[0]) }
    var sat by remember { mutableFloatStateOf(hsv[1].coerceAtLeast(0.2f)) }
    var value by remember { mutableFloatStateOf(hsv[2].coerceAtLeast(0.3f)) }
    val color = android.graphics.Color.HSVToColor(floatArrayOf(hue, sat, value))
    val lang = language
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(lang.pick("More colors", "更多颜色")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.fillMaxWidth().heightIn(min = 64.dp).clip(RoundedCornerShape(16.dp)).background(Color(color)))
                Text("🌈", fontSize = 18.sp)
                Box(Modifier.fillMaxWidth().heightIn(min = 12.dp).clip(RoundedCornerShape(6.dp))
                    .background(androidx.compose.ui.graphics.Brush.horizontalGradient(
                        (0..6).map { Color(android.graphics.Color.HSVToColor(floatArrayOf(it * 60f, 1f, 1f))) })))
                Slider(value = hue, onValueChange = { hue = it }, valueRange = 0f..360f)
                Text(lang.pick("Colorful", "鲜艳"), fontSize = 14.sp)
                Slider(value = sat, onValueChange = { sat = it }, valueRange = 0f..1f)
                Text(lang.pick("Light", "亮度"), fontSize = 14.sp)
                Slider(value = value, onValueChange = { value = it }, valueRange = 0.15f..1f)
            }
        },
        confirmButton = { TextButton(onClick = { onPick(color) }) { Text(lang.pick("Use this color", "用这个颜色")) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(lang.pick("Cancel", "取消")) } },
    )
}

@Composable
private fun Swatch(color: Color, selected: Boolean, size: androidx.compose.ui.unit.Dp, label: String, emoji: String? = null, onClick: () -> Unit) {
    val scale by animateFloatAsState(if (selected) 1.1f else 1f, label = "swatch")
    Box(
        Modifier
            .size(size + 8.dp)
            .scale(scale)
            .squishClickable(onClick = onClick)
            .semantics { contentDescription = label }
            .border(3.dp, if (selected) Color(0xFF222222) else Color.Transparent, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .size(size)
                .shadow(2.dp, CircleShape)
                .clip(CircleShape)
                .background(color)
                .border(3.dp, if (emoji != null && !selected) Color.Gray.copy(alpha = 0.3f) else Color.White, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (emoji != null) Text(emoji, fontSize = (size.value * 0.42f).sp, modifier = Modifier.offset(y = 0.dp))
        }
    }
}
