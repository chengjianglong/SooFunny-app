package com.chengjianglong.soofunny.core.voice

import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.chengjianglong.soofunny.core.AppSettings
import com.chengjianglong.soofunny.core.BookLanguage
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.ModelFiles
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Deferred
import java.util.concurrent.Executors

/**
 * The natural (Kokoro) voices: whether they're installed and chosen, and the audio they make.
 * [Speech] uses them underneath; other features can make audio directly with [render].
 * Mirrors `NaturalVoiceEngine` in the iOS app.
 */
object NaturalVoices {
    private const val ENGLISH_VOICE_KEY = "englishVoice"
    private const val CHINESE_VOICE_KEY = "chineseVoice"

    /** The English voice choice in Settings. */
    enum class EnglishVoice(val key: String) { NATURAL("natural"), DEVICE("device") }

    private var context: Context? = null

    /** Whether this install has the English / Chinese voice model (the "voices" asset pack). */
    var englishInstalled by mutableStateOf(false)
        private set
    var chineseInstalled by mutableStateOf(false)
        private set

    private var englishChoiceState by mutableStateOf(EnglishVoice.NATURAL)
    private var chineseVoiceState by mutableStateOf(Kokoro.chineseVoices[0])

    /** Natural (the default) or the device's own text-to-speech for English. */
    var englishChoice: EnglishVoice
        get() = englishChoiceState
        set(value) {
            englishChoiceState = value
            runCatching { AppSettings.prefs().edit().putString(ENGLISH_VOICE_KEY, value.key).apply() }
            if (value == EnglishVoice.NATURAL) preload(BookLanguage.ENGLISH)
        }

    /** The natural Chinese voice chosen in Settings: one of [Kokoro.chineseVoices]. */
    var chineseVoice: String
        get() = chineseVoiceState
        set(value) {
            val v = value.takeIf { it in Kokoro.chineseVoices } ?: Kokoro.chineseVoices[0]
            chineseVoiceState = v
            runCatching { AppSettings.prefs().edit().putString(CHINESE_VOICE_KEY, v).apply() }
        }

    internal val english = NaturalVoiceEngine(BookLanguage.ENGLISH)
    internal val chinese = NaturalVoiceEngine(BookLanguage.CHINESE)

    internal fun engine(language: BookLanguage) = if (language == BookLanguage.ENGLISH) english else chinese

    /**
     * Finds the installed models, reads the saved choices and starts loading the voices the app
     * will use (English always, Chinese when the app isn't in English only), as on iOS.
     * Call once at app start, after [AppSettings.init].
     */
    fun init(context: Context) {
        if (this.context != null) return
        val app = context.applicationContext
        this.context = app
        runCatching {
            val p = AppSettings.prefs()
            englishChoiceState = EnglishVoice.entries.firstOrNull { it.key == p.getString(ENGLISH_VOICE_KEY, null) } ?: EnglishVoice.NATURAL
            chineseVoiceState = p.getString(CHINESE_VOICE_KEY, null)?.takeIf { it in Kokoro.chineseVoices } ?: Kokoro.chineseVoices[0]
        }
        englishInstalled = hasModel(app, ModelFiles.ENGLISH_VOICE)
        chineseInstalled = hasModel(app, ModelFiles.CHINESE_VOICE)
        preload(BookLanguage.ENGLISH)
        languageChanged(AppSettings.language)
    }

    private fun hasModel(context: Context, path: String): Boolean =
        runCatching { context.assets.openFd(path).use { true } }.getOrNull() ?: ModelFiles.hasVoice(context, path)

    /** Call when the app's language changes: Chinese is loaded once it will be needed. */
    fun languageChanged(language: LearningLanguage) {
        if (language != LearningLanguage.ENGLISH) preload(BookLanguage.CHINESE)
    }

    fun resetDefaults() {
        englishChoice = EnglishVoice.NATURAL
        chineseVoice = Kokoro.chineseVoices[0]
    }

    internal fun appContext(): Context? = context

    /** Whether [language] is read in a natural voice now (installed, chosen, and it loaded). */
    fun isAvailable(language: BookLanguage): Boolean = when (language) {
        BookLanguage.ENGLISH -> englishInstalled && englishChoice == EnglishVoice.NATURAL && !english.failed
        BookLanguage.CHINESE -> chineseInstalled && !chinese.failed
    }

    /** Kokoro speed for the Settings speed slider. */
    val speed: Float get() = Kokoro.speed(AppSettings.speechRate)

    internal fun voice(language: BookLanguage) = if (language == BookLanguage.ENGLISH) Kokoro.ENGLISH_VOICE else chineseVoice

    /** Loads the voice in the background, warms it up and prepares phrases the app says often. */
    fun preload(language: BookLanguage) {
        if (!isAvailable(language)) return
        prefetch(if (language == BookLanguage.ENGLISH) COMMON_PHRASES else COMMON_CHINESE_PHRASES, language)
    }

    /** Prepares speech for texts that will probably be said soon, so they play at once. */
    fun prefetch(texts: List<String>, language: BookLanguage) {
        if (!isAvailable(language)) return
        engine(language).prefetch(texts.flatMap { t -> Kokoro.pieces(t).map { it.text } })
    }

    /**
     * Speech for [text], all in [language]'s natural voice (Chinese text may include English
     * words), as 24 kHz mono samples in -1…1 with the same pauses as when it's spoken: 0.22 s after
     * each sentence and 0.12 s after each phrase. Null when there's no natural voice for
     * [language] or it couldn't be made. Runs on the voice's own thread after anything being
     * spoken now; cancelling stops the work that hasn't started.
     */
    suspend fun render(text: String, language: BookLanguage, speed: Float = this.speed): FloatArray? {
        if (!isAvailable(language)) return null
        val engine = engine(language)
        val pieces = Kokoro.pieces(text)
        val audio = pieces.map { engine.audio(it.text, speed, priority = NaturalVoiceEngine.Priority.LATER) }
        try {
            val clips = ArrayList<FloatArray>()
            for ((i, piece) in pieces.withIndex()) {
                val samples = audio[i].await() ?: return null
                if (samples.isEmpty()) continue
                clips += samples
                clips += FloatArray((Kokoro.SAMPLE_RATE * piece.gap).toInt())
            }
            val out = FloatArray(clips.sumOf { it.size })
            var at = 0
            for (c in clips) { c.copyInto(out, at); at += c.size }
            return out
        } finally {
            audio.forEach { it.cancel() }
        }
    }

    /** Phrases the app says often. */
    val COMMON_PHRASES = listOf("Great job!", "You got it!", "Super!", "Awesome!", "Yes!", "Amazing! 🎉",
        "Great work! 🌟", "Good try! 💪", "Keep practicing! 🌱")
    val COMMON_CHINESE_PHRASES = listOf("真棒！", "答对了！", "太厉害了！", "好极了！", "对啦！", "太棒了！", "做得好！")
}

/**
 * Loads a Kokoro voice once and makes all its speech on one background thread, with a cache.
 * Speech that's needed now always goes before speech prepared in advance, and recent clips are
 * remembered so repeated words play instantly.
 */
class NaturalVoiceEngine internal constructor(val language: BookLanguage) {
    enum class Priority { NOW, LATER, PREFETCH }

    private class Job(val key: String, val text: String, val speed: Float, val voice: String, val result: CompletableDeferred<FloatArray?>?)

    private val executor = Executors.newSingleThreadExecutor { r ->
        Thread(r, if (language == BookLanguage.ENGLISH) "NaturalVoice" else "NaturalVoice.zh").apply { isDaemon = true }
    }
    private val lock = Any()
    private var tts: KokoroTTS? = null // only touched on the executor

    /** True once loading the voice has failed (then the device voice is used). */
    @Volatile var failed = false
        private set

    private val nowJobs = ArrayDeque<Job>()
    private val laterJobs = ArrayDeque<Job>()
    private val prefetchJobs = ArrayDeque<Job>()
    private val cache = LinkedHashMap<String, FloatArray>()

    private fun key(text: String, speed: Float, voice: String) = "$speed|$voice|$text"

    /** Speech for [text] (trimmed of silence), from the cache or made soon. Null means it couldn't be made. */
    fun audio(text: String, speed: Float = NaturalVoices.speed, priority: Priority = Priority.NOW): Deferred<FloatArray?> {
        val voice = NaturalVoices.voice(language)
        val result = CompletableDeferred<FloatArray?>()
        enqueue(Job(key(text, speed, voice), text, speed, voice, result), priority)
        return result
    }

    /** Prepares speech for texts that will probably be needed soon. */
    fun prefetch(texts: List<String>) {
        val speed = NaturalVoices.speed
        val voice = NaturalVoices.voice(language)
        for (text in texts) if (text.isNotBlank()) enqueue(Job(key(text, speed, voice), text, speed, voice, null), Priority.PREFETCH)
    }

    private fun enqueue(job: Job, priority: Priority) {
        synchronized(lock) {
            cache[job.key]?.let { cached ->
                job.result?.complete(cached)
                return
            }
            when (priority) {
                Priority.NOW -> nowJobs.addLast(job)
                Priority.LATER -> laterJobs.addLast(job)
                Priority.PREFETCH -> if (prefetchJobs.none { it.key == job.key }) {
                    prefetchJobs.addLast(job)
                    if (prefetchJobs.size > PREFETCH_LIMIT) prefetchJobs.removeFirst()
                }
            }
        }
        executor.execute { runNext() }
    }

    /** Does one job, always taking "now" jobs first. Jobs nobody waits for any more are skipped. */
    private fun runNext() {
        val job: Job
        val cached: FloatArray?
        synchronized(lock) {
            job = nowJobs.removeFirstOrNull() ?: laterJobs.removeFirstOrNull() ?: prefetchJobs.removeFirstOrNull() ?: return
            cached = cache[job.key]
        }
        if (job.result?.isCompleted == true) return
        var samples = cached
        if (samples == null) {
            val tts = loaded()
            if (tts != null) {
                samples = try {
                    tts.setVoice(job.voice)
                    Kokoro.trimmingSilence(tts.synthesize(job.text, job.speed))
                } catch (e: Throwable) {
                    Log.w("NaturalVoice", "Couldn't say \"${job.text}\"", e)
                    null
                }
                samples?.let { remember(job.key, it) }
            }
        }
        job.result?.complete(samples)
    }

    private fun remember(key: String, samples: FloatArray) = synchronized(lock) {
        cache.remove(key)
        cache[key] = samples
        while (cache.size > CACHE_LIMIT) cache.remove(cache.keys.first())
    }

    /** Call on the executor. Null if the voice can't be loaded (then the device voice is used). */
    private fun loaded(): KokoroTTS? {
        tts?.let { return it }
        if (failed) return null
        val context = NaturalVoices.appContext() ?: return null
        return try {
            KokoroTTS.create(context, language, NaturalVoices.voice(language)).also { tts = it }
        } catch (e: Throwable) {
            Log.w("NaturalVoice", "Couldn't load the ${language.name.lowercase()} natural voice", e)
            failed = true
            null
        }
    }

    private companion object {
        const val CACHE_LIMIT = 400
        const val PREFETCH_LIMIT = 60
    }
}
