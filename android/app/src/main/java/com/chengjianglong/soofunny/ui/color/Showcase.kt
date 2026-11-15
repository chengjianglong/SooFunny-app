package com.chengjianglong.soofunny.ui.color

import android.content.Context
import android.graphics.Bitmap
import androidx.compose.ui.graphics.Color
import com.chengjianglong.soofunny.core.AssetImages
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.ui.KidColors
import org.json.JSONArray

/** The kinds of built-in pictures on the Color page. */
enum class PictureKind(val key: String, val title: String, val chineseTitle: String, val emoji: String, val color: Color) {
    ALL("all", "All", "全部", "🌈", KidColors.Purple),
    ANIMALS("animals", "Animals", "动物", "🐾", KidColors.Orange),
    PORTRAITS("portraits", "Faces", "笑脸", "😄", KidColors.Pink),
    PEOPLE("people", "People", "人物", "🧒", KidColors.Blue),
    OUTDOORS("outdoors", "Outdoors", "户外", "🌳", KidColors.Green),
    DRAWINGS("drawings", "Drawings", "简笔画", "✏️", KidColors.Indigo);

    fun title(language: LearningLanguage): String = language.pick(title, chineseTitle)

    companion object {
        fun fromKey(key: String): PictureKind? = entries.firstOrNull { it.key == key }
    }
}

/** One built-in picture: a bundled photo (`showcase/<file>`) or a drawing made in code. */
class ShowcasePicture(
    val id: String,
    val title: String,
    val kind: PictureKind,
    private val assetPath: String? = null,
    private val art: SampleArt? = null,
) {
    /** The picture's name in Chinese, when there is one. */
    val chineseTitle: String? get() = Showcase.chineseTitles[title]

    fun title(language: LearningLanguage): String = chineseTitle?.let { language.pick(title, it) } ?: title

    /** The picture at about [maxSize] pixels. Slow; call off the main thread. */
    fun load(context: Context, maxSize: Int = 1600): Bitmap? = when {
        assetPath != null -> AssetImages.load(context, assetPath, maxSize)
        art != null -> if (maxSize >= 1600) art.draw(1600) else Showcase.drawingThumbnail(art, maxSize)
        else -> null
    }
}

object Showcase {
    @Volatile private var cached: List<ShowcasePicture>? = null
    private val thumbnails = HashMap<String, Bitmap>()

    /** Every picture: the photos from `showcase/credits.json` (all CC0 from Wikimedia Commons), then the drawings. */
    fun all(context: Context): List<ShowcasePicture> {
        cached?.let { return it }
        val photos = try {
            val json = context.assets.open("showcase/credits.json").bufferedReader().use { it.readText() }
            val array = JSONArray(json)
            (0 until array.length()).mapNotNull { i ->
                val credit = array.getJSONObject(i)
                val kind = PictureKind.fromKey(credit.optString("category")) ?: return@mapNotNull null
                val file = credit.getString("file")
                ShowcasePicture(file, credit.getString("title"), kind, assetPath = "showcase/$file")
            }
        } catch (_: Exception) {
            emptyList()
        }
        val drawings = SampleArt.all.map { ShowcasePicture("drawing-${it.id}", it.name, PictureKind.DRAWINGS, art = it) }
        return (photos + drawings).also { cached = it }
    }

    fun pictures(context: Context, kind: PictureKind): List<ShowcasePicture> =
        all(context).let { list -> if (kind == PictureKind.ALL) list else list.filter { it.kind == kind } }

    internal fun drawingThumbnail(art: SampleArt, size: Int): Bitmap = synchronized(thumbnails) {
        thumbnails.getOrPut("${art.id}@$size") { art.draw(size) }
    }

    /** Chinese names for the pictures, by their English name. */
    val chineseTitles: Map<String, String> = mapOf(
        "Bulldog" to "斗牛犬", "Kitty" to "小猫咪", "Giraffe" to "长颈鹿", "Parrot" to "鹦鹉", "Elephants" to "大象",
        "Goldfish" to "金鱼", "Big Smile" to "大大的笑", "Bunny Ears" to "兔耳朵", "Market Grin" to "集市笑脸",
        "Champions!" to "冠军！", "Kick It" to "踢球", "Beach Day" to "海滩日", "Picnic Fun" to "快乐野餐",
        "Flower Friends" to "花朵朋友", "Hand in Hand" to "手拉手", "Pinwheel" to "风车", "Skate Pals" to "滑板伙伴",
        "Baby Books" to "宝宝看书", "Lighthouse" to "灯塔", "Tulips" to "郁金香", "Red Barn" to "红色谷仓",
        "House" to "房子", "Fish" to "鱼", "Flower" to "花", "Rocket" to "火箭",
    )
}
