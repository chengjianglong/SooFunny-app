package com.chengjianglong.soofunny.core.voice

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import com.chengjianglong.soofunny.core.BookLanguage
import com.chengjianglong.soofunny.core.ModelFiles
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.nio.channels.FileChannel
import kotlin.math.min

/**
 * Kokoro-82M (Apache-2.0), a natural-sounding neural voice, run on the device with ONNX Runtime.
 * Makes 24 kHz mono audio from text, offline. English uses Kokoro v1.0 with the "Heart" voice;
 * Chinese uses Kokoro v1.1-zh with a voice chosen in Settings. As `KokoroTTS` in the iOS app.
 *
 * The model comes from the "voices" asset pack ([ModelFiles]); the small data files (dictionaries,
 * voice styles) are app assets under `voice/`.
 *
 * Not thread-safe: use it from one thread ([NaturalVoiceEngine] does).
 */
class KokoroTTS private constructor(
    val language: BookLanguage,
    /** Reads a voice's styles by name (from the app's assets, or files when rendering on a computer). */
    private val styleLoader: (String) -> FloatArray,
    private val english: KokoroPhonemizer,
    private val chinese: ChineseG2P?,
    private val chineseVocab: Map<Char, Long>,
    private val session: OrtSession,
    voice: String,
) : AutoCloseable {
    /** The voice in use, and its style: one 256-number style per possible input length (510 × 256). */
    var voice: String = voice
        private set
    private var styles: FloatArray = styleLoader(voice)

    /** Switches to another voice for the same language (the Chinese voice picker). */
    fun setVoice(name: String) {
        if (name == voice) return
        styles = styleLoader(name)
        voice = name
    }

    /** The model's tokens for [text]. */
    fun tokenIds(text: String): LongArray {
        val g2p = chinese ?: return english.tokenIds(english.phonemize(text))
        // A few English symbols aren't in the Chinese model's set; say them the nearest way.
        val phonemes = g2p.phonemize(text).replace("ɚ", "əɹ").replace("ꭧ", "ʈʃ")
        val ids = ArrayList<Long>(phonemes.length + 2)
        ids += 0L
        for (c in phonemes) chineseVocab[c]?.let { ids += it }
        ids += 0L
        return ids.toLongArray()
    }

    /** Speech for [text] as samples in -1…1. [speed] 1 is normal; below 1 is slower. */
    fun synthesize(text: String, speed: Float = 1f): FloatArray {
        var ids = tokenIds(text)
        if (ids.size <= 2) return FloatArray(0)
        if (ids.size > Kokoro.MAX_TOKENS + 2) ids = ids.copyOf(Kokoro.MAX_TOKENS + 2).also { it[Kokoro.MAX_TOKENS + 1] = 0 }
        val styleIndex = min(ids.size - 2, styles.size / 256 - 1)
        val style = styles.copyOfRange(styleIndex * 256, styleIndex * 256 + 256)
        val env = OrtEnvironment.getEnvironment()
        OnnxTensor.createTensor(env, LongBuffer.wrap(ids), longArrayOf(1, ids.size.toLong())).use { idTensor ->
            OnnxTensor.createTensor(env, FloatBuffer.wrap(style), longArrayOf(1, 256)).use { styleTensor ->
                OnnxTensor.createTensor(env, FloatBuffer.wrap(floatArrayOf(speed)), longArrayOf(1)).use { speedTensor ->
                    val inputs = mapOf("input_ids" to idTensor, "style" to styleTensor, "speed" to speedTensor)
                    session.run(inputs, setOf("waveform")).use { result ->
                        val out = result.get("waveform").orElse(null) as? OnnxTensor ?: throw IOException("Kokoro: no waveform")
                        val buffer = out.floatBuffer
                        return FloatArray(buffer.remaining()).also { buffer.get(it) }
                    }
                }
            }
        }
    }

    override fun close() = session.close()

    companion object {
        private const val DATA = "voice/"

        fun modelPath(language: BookLanguage) =
            if (language == BookLanguage.ENGLISH) ModelFiles.ENGLISH_VOICE else ModelFiles.CHINESE_VOICE

        @Volatile private var sharedEnglish: KokoroPhonemizer? = null

        /** The English phonemizer, loaded once and shared (it's read-only once made). */
        fun englishPhonemizer(context: Context): KokoroPhonemizer = sharedEnglish ?: synchronized(this) {
            sharedEnglish ?: KokoroPhonemizer(context.assets.open(DATA + "kokoro_lexicon.tsv"), context.assets.open(DATA + "kokoro_vocab.tsv"))
                .also { sharedEnglish = it }
        }

        /** Loads the model and data for [language]. Throws if anything is missing. Slow: call off the main thread. */
        fun create(context: Context, language: BookLanguage, voice: String? = null): KokoroTTS {
            val app = context.applicationContext
            val v = voice ?: if (language == BookLanguage.ENGLISH) Kokoro.ENGLISH_VOICE else Kokoro.chineseVoices[0]
            val english = englishPhonemizer(app)
            var chinese: ChineseG2P? = null
            var zhVocab: Map<Char, Long> = emptyMap()
            if (language == BookLanguage.CHINESE) {
                zhVocab = app.assets.open(DATA + "kokoro_vocab_zh.tsv").use { KokoroPhonemizer.loadVocab(it) }
                // English words inside Chinese text are said with the English voice's pronunciations.
                chinese = ChineseG2P({ app.assets.open(DATA + it) }) { english.phonemize(it) }
            }
            val options = OrtSession.SessionOptions().apply {
                // As measured on iPhone: more threads aren't faster; leave cores free for the buddy and the UI.
                setIntraOpNumThreads(2)
                setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            }
            val session = options.use { openSession(app, modelPath(language), it) }
            return try {
                KokoroTTS(language, { loadStyles(app, it) }, english, chinese, zhVocab, session, v)
            } catch (e: Exception) {
                session.close()
                throw e
            }
        }

        /**
         * Opens the model without a second copy in the Java heap: memory-mapped from the APK or
         * asset pack when it's stored uncompressed, otherwise copied once into the app's files.
         */
        private fun openSession(context: Context, path: String, options: OrtSession.SessionOptions): OrtSession {
            val env = OrtEnvironment.getEnvironment()
            // SooFunny sends nothing off the device: turn off ONNX Runtime's usage telemetry.
            runCatching { env.setTelemetry(false) }
            val mapped: ByteBuffer? = try {
                context.assets.openFd(path).use { fd ->
                    FileInputStream(fd.fileDescriptor).channel.use { channel ->
                        channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
                    }
                }
            } catch (_: IOException) {
                null
            }
            if (mapped != null) return env.createSession(mapped, options)
            return env.createSession(copiedModel(context, path).path, options)
        }

        /** A compressed asset, copied to the app's own storage (again only after an app update). */
        private fun copiedModel(context: Context, path: String): File {
            val file = File(context.noBackupFilesDir, path)
            val stamp = File(file.path + ".stamp")
            val version = runCatching { context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime.toString() }.getOrDefault("0")
            if (file.exists() && stamp.exists() && stamp.readText() == version) return file
            file.parentFile?.mkdirs()
            val part = File(file.path + ".part")
            val input = ModelFiles.openVoice(context, path) ?: throw IOException("Missing $path")
            input.use { i -> part.outputStream().use { o -> i.copyTo(o, 1 shl 20) } }
            if (!part.renameTo(file)) throw IOException("Can't save $path")
            stamp.writeText(version)
            return file
        }

        /**
         * Loads a voice on a computer, from the voice data folder (`SooFunny/Voice/Resources`) and
         * a model file: for making the pre-made clips ([PremadeVoices]) at build time.
         */
        fun createFromFiles(data: File, model: File, language: BookLanguage, voice: String, threads: Int = 2): KokoroTTS {
            fun open(name: String) = File(data, name).inputStream()
            val english = KokoroPhonemizer(open("kokoro_lexicon.tsv"), open("kokoro_vocab.tsv"))
            var chinese: ChineseG2P? = null
            var zhVocab: Map<Char, Long> = emptyMap()
            if (language == BookLanguage.CHINESE) {
                zhVocab = open("kokoro_vocab_zh.tsv").use { KokoroPhonemizer.loadVocab(it) }
                chinese = ChineseG2P({ open(it) }) { english.phonemize(it) }
            }
            val options = OrtSession.SessionOptions().apply {
                setIntraOpNumThreads(threads)
                setInterOpNumThreads(1)
                setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            }
            val session = options.use { OrtEnvironment.getEnvironment().createSession(model.path, it) }
            return KokoroTTS(language, { styles(File(data, "kokoro_$it.bin").readBytes()) }, english, chinese, zhVocab, session, voice)
        }

        private fun loadStyles(context: Context, voice: String): FloatArray =
            styles(context.assets.open(DATA + "kokoro_$voice.bin").use { it.readBytes() })

        private fun styles(bytes: ByteArray): FloatArray {
            val floats = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer()
            return FloatArray(floats.remaining()).also { floats.get(it) }
        }
    }
}
