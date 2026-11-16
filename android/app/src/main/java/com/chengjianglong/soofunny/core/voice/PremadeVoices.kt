package com.chengjianglong.soofunny.core.voice

import android.content.Context
import android.media.MediaCodec
import android.media.MediaDataSource
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import com.chengjianglong.soofunny.core.AudiobookMaker
import com.chengjianglong.soofunny.core.BookLanguage
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.concurrent.thread

/**
 * Natural-voice clips made ahead of time, for everything SooFunny reads that's always the same:
 * words and their groups, letters, sports, the story books, math questions and cheers, and the
 * buddy's opening question. On phones too slow to run Kokoro as it's needed (see
 * [NaturalVoices.tooSlow]) these still play at once in the natural voice.
 *
 * The clips are made on a computer by `PremadeVoiceRenderer` (a unit test, see the README) with
 * the same Kokoro model and the same splitting into phrases as [com.chengjianglong.soofunny.core.Speech],
 * one AAC file per phrase, and ship in the "voices" asset pack under `premade/`.
 * Only the default voices at the normal speed are made; anything else is made on the phone.
 */
object PremadeVoices {
    const val DIR = "premade"
    const val INDEX = "$DIR/index.tsv"

    /** The speed the clips are made at: the Settings slider in the middle. */
    val SPEED: Float = Kokoro.speed(1f)

    /** The voices clips are made for. */
    val VOICES = mapOf(BookLanguage.ENGLISH to Kokoro.ENGLISH_VOICE, BookLanguage.CHINESE to Kokoro.chineseVoices[0])

    fun key(language: BookLanguage, voice: String, speed: Float, text: String) =
        "${language.name.lowercase()}|$voice|${String.format(Locale.ROOT, "%.3f", speed)}|$text"

    /** The clip's file name: short and the same on the computer that makes it and the phone. */
    fun fileName(key: String): String {
        val digest = MessageDigest.getInstance("SHA-1").digest(key.toByteArray(Charsets.UTF_8))
        return digest.take(10).joinToString("") { "%02x".format(it) } + ".m4a"
    }

    @Volatile private var files: Map<String, String> = emptyMap()
    private var context: Context? = null
    private val decoder = Executors.newSingleThreadExecutor { r -> Thread(r, "PremadeVoices").apply { isDaemon = true } }

    /** Reads the list of clips in the background. Call once at app start. */
    fun init(context: Context) {
        if (this.context != null) return
        val app = context.applicationContext
        this.context = app
        thread(name = "PremadeVoices.index", isDaemon = true) {
            files = runCatching {
                app.assets.open(INDEX).bufferedReader().useLines { lines ->
                    lines.mapNotNull { line ->
                        val tab = line.lastIndexOf('\t')
                        if (tab > 0) line.substring(0, tab) to line.substring(tab + 1) else null
                    }.toMap()
                }
            }.getOrDefault(emptyMap())
            Log.d("PremadeVoices", "${files.size} clips")
        }
    }

    val count: Int get() = files.size

    fun has(language: BookLanguage, voice: String, speed: Float, text: String) =
        key(language, voice, speed, text) in files

    /** Decodes the clip for [text] on a background thread; [done] gets 24 kHz samples or null. */
    fun load(language: BookLanguage, voice: String, speed: Float, text: String, done: (FloatArray?) -> Unit) {
        val name = files[key(language, voice, speed, text)]
        val app = context
        if (name == null || app == null) {
            done(null)
            return
        }
        decoder.execute {
            done(runCatching { decode(app.assets.open("$DIR/$name").use { it.readBytes() }) }
                .onFailure { Log.w("PremadeVoices", "Couldn't play \"$text\"", it) }
                .getOrNull())
        }
    }

    /** An AAC (MPEG-4) clip as mono samples in -1…1 at [Kokoro.SAMPLE_RATE]. */
    private fun decode(bytes: ByteArray): FloatArray? {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(object : MediaDataSource() {
                override fun readAt(position: Long, buffer: ByteArray, offset: Int, size: Int): Int {
                    if (position >= bytes.size) return -1
                    val n = minOf(size, bytes.size - position.toInt())
                    System.arraycopy(bytes, position.toInt(), buffer, offset, n)
                    return n
                }
                override fun getSize() = bytes.size.toLong()
                override fun close() {}
            })
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return null
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            val pcm = java.io.ByteArrayOutputStream()
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            try {
                codec.configure(format, null, null, 0)
                codec.start()
                val info = MediaCodec.BufferInfo()
                var inputDone = false
                while (true) {
                    if (!inputDone) {
                        val i = codec.dequeueInputBuffer(10_000)
                        if (i >= 0) {
                            val n = extractor.readSampleData(codec.getInputBuffer(i)!!, 0)
                            if (n < 0) {
                                codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(i, 0, n, extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }
                    val o = codec.dequeueOutputBuffer(info, 10_000)
                    if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        rate = codec.outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = codec.outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    } else if (o >= 0) {
                        val out = codec.getOutputBuffer(o)!!
                        val chunk = ByteArray(info.size)
                        out.position(info.offset)
                        out.get(chunk)
                        pcm.write(chunk)
                        codec.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                    }
                }
            } finally {
                runCatching { codec.stop() }
                codec.release()
            }
            val shorts = java.nio.ByteBuffer.wrap(pcm.toByteArray()).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
            val frames = shorts.remaining() / channels
            val mono = FloatArray(frames) { f ->
                var sum = 0f
                for (c in 0 until channels) sum += shorts.get(f * channels + c) / 32768f
                sum / channels
            }
            // The encoder's start-up silence is trimmed again, as Kokoro's own silence was.
            return Kokoro.trimmingSilence(AudiobookMaker.resample(mono, rate, Kokoro.SAMPLE_RATE))
        } finally {
            extractor.release()
        }
    }
}
