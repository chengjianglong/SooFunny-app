package com.chengjianglong.soofunny.ui.color

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.ui.BouncyTitle
import com.chengjianglong.soofunny.ui.FunBackground
import com.chengjianglong.soofunny.ui.KidButton
import com.chengjianglong.soofunny.ui.KidColors
import com.chengjianglong.soofunny.ui.SettingsButton
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.gradient
import com.chengjianglong.soofunny.ui.language
import com.chengjianglong.soofunny.ui.squishClickable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.max

/**
 * The Color page: a playful gallery of pictures to color (animals, faces, people, outdoors and
 * drawings), a Surprise button, and Photos at the bottom for your own pictures.
 */
@Composable
fun ColorTab(onPick: (Bitmap, ShowcasePicture?) -> Unit, onSettings: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var kind by rememberSaveable { mutableStateOf(PictureKind.ALL) }
    var loadFailed by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(false) }
    val pictures = remember { Showcase.all(context) }

    fun open(picture: ShowcasePicture? = null, load: suspend () -> Bitmap?) {
        if (loading) return
        loading = true
        scope.launch {
            val bitmap = withContext(Dispatchers.IO) { runCatching { load() }.getOrNull() }
            loading = false
            if (bitmap != null) onPick(bitmap, picture) else loadFailed = true
        }
    }

    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) open { decodePhoto(context, uri) }
    }
    val cameraAvailable = remember { PictureFiles.cameraAvailable(context) }
    var cameraUri by rememberSaveable { mutableStateOf<String?>(null) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        val uri = cameraUri?.let(Uri::parse)
        if (saved && uri != null) open { decodePhoto(context, uri) }
    }

    Column(Modifier.fillMaxSize()) {
        SooTopBar(actions = { SettingsButton(onSettings) })
        Box(Modifier.weight(1f).fillMaxWidth().background(MaterialTheme.colorScheme.background)) {
            FunBackground(Modifier.fillMaxSize())
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(
                    Modifier.widthIn(max = 1000.dp).fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    BouncyTitle(Modifier.padding(top = 8.dp))
                    Text(
                        language.pick("Pick a picture and color it in!", "选一张图片来涂色吧！", "\n"),
                        fontSize = 20.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    SurpriseButton {
                        val choice = pictures.filter { kind == PictureKind.ALL || it.kind == kind }.randomOrNull()
                        if (choice != null) open(choice) { delay(350); choice.load(context) }
                    }
                    KindPicker(kind) { kind = it }
                    if (kind == PictureKind.ALL) {
                        PictureKind.entries.filter { it != PictureKind.ALL }.forEach { section ->
                            GallerySection(section, pictures.filter { it.kind == section }, showHeader = true,
                                onSeeAll = { kind = section }) { picture -> open(picture) { picture.load(context) } }
                        }
                    } else {
                        GallerySection(kind, pictures.filter { it.kind == kind }, showHeader = false, onSeeAll = {}) { picture ->
                            open(picture) { picture.load(context) }
                        }
                    }
                }
            }
            if (loading) {
                CircularProgressIndicator(Modifier.align(Alignment.Center))
            }
        }
        // Bottom bar: your own photos.
        Surface(color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f), shadowElevation = 2.dp) {
            Row(
                Modifier.widthIn(max = 560.dp).fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                KidButton(
                    text = language.pick("Photos", "照片"), color = KidColors.Pink, emoji = "🖼️",
                    modifier = Modifier.weight(1f).heightIn(min = 54.dp),
                ) {
                    photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }
                if (cameraAvailable) {
                    KidButton(
                        text = language.pick("Camera", "相机"), color = KidColors.Blue, emoji = "📷",
                        modifier = Modifier.weight(1f).heightIn(min = 54.dp),
                    ) {
                        val uri = PictureFiles.newCameraUri(context)
                        cameraUri = uri.toString()
                        runCatching { camera.launch(uri) }.onFailure { loadFailed = true }
                    }
                }
            }
        }
    }

    if (loadFailed) {
        AlertDialog(
            onDismissRequest = { loadFailed = false },
            confirmButton = { TextButton(onClick = { loadFailed = false }) { Text(language.pick("OK", "好")) } },
            title = { Text(language.pick("Couldn't open that picture", "打不开这张图片")) },
            text = { Text(language.pick("Try another photo, or pick one from the gallery.", "换一张照片，或者从图库里选一张。")) },
        )
    }
}

@Composable
private fun SurpriseButton(onClick: () -> Unit) {
    var spin by remember { mutableFloatStateOf(0f) }
    val rotation by animateFloatAsState(spin, spring(dampingRatio = 0.5f, stiffness = 200f), label = "dice")
    val label = language.pick("Surprise me with a random picture", "随机给我一张图片")
    Row(
        Modifier
            .squishClickable { spin += 360f; onClick() }
            .semantics { contentDescription = label }
            .shadow(8.dp, RoundedCornerShape(50), ambientColor = KidColors.Pink, spotColor = KidColors.Pink)
            .clip(RoundedCornerShape(50))
            .background(Brush.horizontalGradient(listOf(KidColors.Pink, KidColors.Orange, KidColors.Yellow, KidColors.Green, KidColors.Blue, KidColors.Purple)))
            .heightIn(min = 60.dp)
            .padding(horizontal = 28.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("🎲", fontSize = 30.sp, modifier = Modifier.rotate(rotation))
        Text(language.pick("Surprise me!", "给我惊喜！"), color = Color.White, fontSize = 22.sp,
            fontWeight = FontWeight.ExtraBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun KindPicker(kind: PictureKind, onSelect: (PictureKind) -> Unit) {
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 4.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        PictureKind.entries.forEach { option ->
            val selected = option == kind
            val shape = RoundedCornerShape(50)
            Row(
                Modifier
                    .squishClickable { onSelect(option) }
                    .semantics { this.selected = selected }
                    .clip(shape)
                    .then(if (selected) Modifier.background(option.color.gradient()) else Modifier.background(MaterialTheme.colorScheme.surface.copy(alpha = 0.85f)))
                    .border(2.dp, if (selected) Color.Transparent else option.color.copy(alpha = 0.5f), shape)
                    .heightIn(min = 44.dp)
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(option.emoji, fontSize = 17.sp)
                Text(option.title(language), fontWeight = FontWeight.Bold, fontSize = 17.sp,
                    color = if (selected) Color.White else MaterialTheme.colorScheme.onSurface)
            }
        }
    }
}

@Composable
private fun GallerySection(
    section: PictureKind, pictures: List<ShowcasePicture>, showHeader: Boolean,
    onSeeAll: () -> Unit, onPick: (ShowcasePicture) -> Unit,
) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (showHeader) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(section.emoji, fontSize = 28.sp)
                Text(section.title(language), fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.weight(1f))
                TextButton(onClick = onSeeAll) {
                    Text(language.pick("See all", "全部"), color = section.color, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            val minWidth = if (maxWidth >= 600.dp) 200.dp else 150.dp
            val columns = max(1, ((maxWidth + 16.dp) / (minWidth + 16.dp)).toInt())
            Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                pictures.withIndex().chunked(columns).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        row.forEach { (index, picture) ->
                            PictureCard(picture, tilt = if (index % 2 == 0) -2f else 2f, Modifier.weight(1f)) { onPick(picture) }
                        }
                        repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }
}

/** A picture on a card, like a sticker: slightly tilted, with a colored frame and a label. */
@Composable
private fun PictureCard(picture: ShowcasePicture, tilt: Float, modifier: Modifier, onClick: () -> Unit) {
    val context = LocalContext.current
    val thumbnail by produceState<ImageBitmap?>(null, picture.id) {
        value = withContext(Dispatchers.IO) { picture.load(context, 420)?.asImageBitmap() }
    }
    val title = picture.title(language)
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier
            .rotate(tilt)
            .squishClickable(onClick = onClick)
            .semantics { contentDescription = title }
            .shadow(6.dp, shape, ambientColor = picture.kind.color, spotColor = picture.kind.color)
            .clip(shape)
            .border(4.dp, Color.White, shape),
    ) {
        Box(Modifier.fillMaxWidth().height(150.dp).background(Color.White), contentAlignment = Alignment.Center) {
            val image = thumbnail
            if (image != null) {
                Image(image, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            } else {
                CircularProgressIndicator()
            }
        }
        Row(
            Modifier.fillMaxWidth().heightIn(min = 40.dp).background(picture.kind.color.gradient()).padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        ) {
            Text(picture.kind.emoji, fontSize = 16.sp)
            Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

/** Decodes a picked photo upright, capped at about 2048 pixels. */
private fun decodePhoto(context: Context, uri: Uri, maxSize: Int = 2048): Bitmap? {
    if (Build.VERSION.SDK_INT >= 28) {
        val source = ImageDecoder.createSource(context.contentResolver, uri)
        return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            val longest = max(info.size.width, info.size.height)
            var sample = 1
            while (longest / (sample * 2) >= maxSize) sample *= 2
            decoder.setTargetSampleSize(sample)
        }
    }
    val resolver = context.contentResolver
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) } ?: return null
    var sample = 1
    while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSize) sample *= 2
    val bitmap = resolver.openInputStream(uri)?.use {
        BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
    } ?: return null
    val orientation = resolver.openInputStream(uri)?.use {
        ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
    } ?: ExifInterface.ORIENTATION_NORMAL
    val degrees = when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90 -> 90f
        ExifInterface.ORIENTATION_ROTATE_180 -> 180f
        ExifInterface.ORIENTATION_ROTATE_270 -> 270f
        else -> 0f
    }
    if (degrees == 0f) return bitmap
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, Matrix().apply { postRotate(degrees) }, true)
}
