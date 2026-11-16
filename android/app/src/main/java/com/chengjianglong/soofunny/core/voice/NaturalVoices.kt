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
    private const val TOO_SLOW_KEY = "naturalVoicesTooSlow"
    private const val FORCED_KEY = "naturalVoicesForced"

    /**
     * The natural voices take longer to make speech than it takes to play on this phone (as on
     * low-cost phones), so every word would wait: the device's voices are used instead. Measured
     * on the first phrases the app makes, and remembered.
     */
    var tooSlow by mutableStateOf(false)
        private set

    /** A grown-up chose the natural voices in Settings even though they're slow here. */
    private var forced = false

    /** Whether the device has a Chinese text-to-speech voice (set by [Speech]). */
    var deviceHasChinese: () -> Boolean = { true }

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
        runCatching {
            tooSlow = AppSettings.prefs().getBoolean(TOO_SLOW_KEY, false)
            forced = AppSettings.prefs().getBoolean(FORCED_KEY, false)
        }
        PremadeVoices.init(app)
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
        BookLanguage.ENGLISH -> englishInstalled && englishChoice == EnglishVoice.NATURAL && !english.failed && !tooSlow
        // Slow is still better than silent when the device has no Chinese voice.
        BookLanguage.CHINESE -> chineseInstalled && !chinese.failed && !(tooSlow && deviceHasChinese())
    }

    /**
     * Whether [text] (all in [language]) is said in the natural voice: when the voice can make it
     * now, or when every phrase of it was made ahead of time ([PremadeVoices]), as on a slow phone.
     */
    fun canSay(text: String, language: BookLanguage): Boolean {
        if (isAvailable(language)) return true
        if (language == BookLanguage.ENGLISH && englishChoice == EnglishVoice.DEVICE) return false
        val voice = voice(language)
        val speed = speed
        return Kokoro.pieces(text).all { piece ->
            piece.text.none { it.isLetterOrDigit() } || PremadeVoices.has(language, voice, speed, piece.text)
        }
    }

    /** How long making speech takes compared with playing it, above which the voice is too slow. */
    internal const val SLOW_RATIO = 0.8

    /** Called by an engine once it has timed a few phrases: [ratio] is making time ÷ audio time. */
    internal fun measured(language: BookLanguage, ratio: Double) {
        Log.d("NaturalVoice", "${language.name.lowercase()} makes speech at ${"%.2f".format(ratio)}× its length")
        if (ratio <= SLOW_RATIO || forced || tooSlow) return
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            if (forced || tooSlow) return@post
            tooSlow = true
            runCatching { AppSettings.prefs().edit().putBoolean(TOO_SLOW_KEY, true).apply() }
            // Free the CPU and memory: drop what was being prepared and unload the voices not used now.
            english.slowDown(unload = true)
            chinese.slowDown(unload = !isAvailable(BookLanguage.CHINESE))
        }
    }

    /** Settings: use the natural voices even though they're slow on this phone (or measure again). */
    fun useNaturalAnyway() {
        forced = true
        tooSlow = false
        runCatching { AppSettings.prefs().edit().putBoolean(TOO_SLOW_KEY, false).putBoolean(FORCED_KEY, true).apply() }
        preload(BookLanguage.ENGLISH)
        languageChanged(AppSettings.language)
    }

    /** Kokoro speed for the Settings speed slider. */
    val speed: Float get() = Kokoro.speed(AppSettings.speechRate)

    internal fun voice(language: BookLanguage) = if (language == BookLanguage.ENGLISH) Kokoro.ENGLISH_VOICE else chineseVoice

    /** Loads the voice in the background, warms it up and prepares phrases the app says often. */
    fun preload(language: BookLanguage) {
        if (!isAvailable(language)) return
        // On a slow phone, don't spend the CPU on phrases that may never be said.
        if (forced) return
        prefetch(if (language == BookLanguage.ENGLISH) COMMON_PHRASES else COMMON_CHINESE_PHRASES, language)
    }

    /** Prepares speech for texts that will probably be said soon, so they play at once. */
    fun prefetch(texts: List<String>, language: BookLanguage) {
        if (!isAvailable(language) || forced) return
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
        val key = key(text, speed, voice)
        synchronized(lock) { cache[key] }?.let { result.complete(it); return result }
        when {
            // Made ahead of time: decoded, not made by the model.
            PremadeVoices.has(language, voice, speed, text) -> PremadeVoices.load(language, voice, speed, text) { samples ->
                if (samples != null && samples.isNotEmpty()) {
                    remember(key, samples)
                    result.complete(samples)
                } else if (NaturalVoices.isAvailable(language)) {
                    enqueue(Job(key, text, speed, voice, result), priority)
                } else {
                    result.complete(null)
                }
            }
            // Too slow (or not chosen) here: the device voice says it.
            !NaturalVoices.isAvailable(language) -> result.complete(null)
            else -> enqueue(Job(key, text, speed, voice, result), priority)
        }
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
                    val t0 = System.nanoTime()
                    val raw = tts.synthesize(job.text, job.speed)
                    time(System.nanoTime() - t0, raw.size)
                    Kokoro.trimmingSilence(raw)
                } catch (e: Throwable) {
                    Log.w("NaturalVoice", "Couldn't say \"${job.text}\"", e)
                    null
                }
                samples?.let { remember(job.key, it) }
            }
        }
        job.result?.complete(samples)
    }

    private var timedNanos = 0L
    private var timedSamples = 0L
    private var timedCount = 0

    /**
     * Times the first phrases (on the executor). The first one includes warming up, so it's left
     * out; after [TIMED] more, tells [NaturalVoices] how fast this phone makes speech.
     */
    private fun time(nanos: Long, samples: Int) {
        if (samples == 0 || timedCount > TIMED) return
        timedCount++
        if (timedCount == 1) return
        timedNanos += nanos
        timedSamples += samples
        if (timedCount == TIMED + 1) {
            NaturalVoices.measured(language, timedNanos / 1e9 / (timedSamples.toDouble() / Kokoro.SAMPLE_RATE))
        }
    }

    /**
     * The voice is too slow on this phone: speech still waited for is answered with null (so the
     * device voice says it), prepared speech is dropped, and with [unload] the model is closed.
     */
    fun slowDown(unload: Boolean) {
        val waiting = synchronized(lock) {
            val all = nowJobs + laterJobs + prefetchJobs
            nowJobs.clear(); laterJobs.clear(); prefetchJobs.clear()
            all
        }
        waiting.forEach { it.result?.complete(null) }
        if (unload) executor.execute {
            runCatching { tts?.close() }
            tts = null
        }
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
            val t0 = System.nanoTime()
            KokoroTTS.create(context, language, NaturalVoices.voice(language)).also {
                tts = it
                Log.d("NaturalVoice", "${language.name.lowercase()} voice loaded in ${(System.nanoTime() - t0) / 1_000_000} ms")
            }
        } catch (e: Throwable) {
            Log.w("NaturalVoice", "Couldn't load the ${language.name.lowercase()} natural voice", e)
            failed = true
            null
        }
    }

    private companion object {
        const val CACHE_LIMIT = 400
        const val PREFETCH_LIMIT = 60
        /** Phrases timed after the first, to tell whether this phone is fast enough. */
        const val TIMED = 2
    }
}
