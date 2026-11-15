package com.chengjianglong.soofunny.core.buddy

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.chengjianglong.soofunny.core.BookLanguage
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Speech

/** Speaks sentences one after another. All calls and callbacks on the main thread. */
interface SentenceSpeaker {
    /** Called when every queued sentence has been spoken (not when stopped). */
    var onFinished: (() -> Unit)?
    fun enqueue(sentence: String)
    fun stop()
    val isSpeaking: Boolean
}

/** Hears the child and turns their speech into text. All calls and callbacks on the main thread. */
interface ChildListener {
    /** The language the child speaks in, English or Chinese. */
    var language: BookLanguage

    /**
     * Starts listening. [onPartial] gets the words so far; [onFinish] the final text, or null when
     * nothing was said; [onError] why listening couldn't happen. Throws [ListenError] if it can't start.
     */
    fun start(onPartial: (String) -> Unit, onFinish: (String?) -> Unit, onError: (ListenError) -> Unit)

    /** Ends listening now and submits what was heard. */
    fun finish()

    /** Ends listening and discards what was heard. */
    fun cancel()
}

class ListenError(val kind: Kind) : Exception(kind.name) {
    enum class Kind { MICROPHONE_NOT_ALLOWED, UNAVAILABLE, CHINESE_UNAVAILABLE }

    /** The message in the conversation's language. */
    fun message(language: LearningLanguage): String {
        val (english, chinese) = when (kind) {
            Kind.MICROPHONE_NOT_ALLOWED ->
                "To talk, allow the microphone for SooFunny in Settings → Apps → SooFunny → Permissions." to
                    "要说话，请在“设置”→“应用”→ SooFunny →“权限”里允许使用麦克风。"
            Kind.UNAVAILABLE ->
                "This device can't listen without the internet, and SooFunny only listens on the device. You can type a question instead." to
                    "这台设备离线时没法听你说话，而 SooFunny 只在设备上听。你可以直接输入问题。"
            Kind.CHINESE_UNAVAILABLE ->
                "This device can't listen in Chinese on the device yet. It has been asked to add Chinese; until then, type a question." to
                    "这台设备暂时不能在设备上听中文，已经请求添加中文。在那之前，请直接输入问题。"
        }
        return language.pick(english, chinese, "\n")
    }
}

/**
 * Reads the buddy's sentences one by one through [Speech] (so whichever voice the app uses reads
 * them, and [Speech.speaking] / [Speech.range] light up the word being said).
 */
class SpeechSentenceSpeaker : SentenceSpeaker {
    override var onFinished: (() -> Unit)? = null
    private val queue = ArrayDeque<String>()
    private var current: String? = null
    private var session = 0

    override val isSpeaking: Boolean get() = current != null

    override fun enqueue(sentence: String) {
        queue.addLast(sentence)
        if (current == null) next()
    }

    override fun stop() {
        session += 1
        queue.clear()
        if (current != null) Speech.stop()
        current = null
    }

    private fun next() {
        val sentence = queue.removeFirstOrNull()
        if (sentence == null) {
            if (current != null) {
                current = null
                onFinished?.invoke()
            }
            return
        }
        current = sentence
        val mine = ++session
        Speech.speak(sentence) { if (mine == session) next() }
    }
}

/**
 * Listens with Android's speech recognizer: the on-device recognizer where there is one (Android
 * 12+), otherwise the system recognizer asked to stay offline. A turn ends after a short pause,
 * after a long silence, or after twenty seconds, as on iOS. Nothing is recorded or saved.
 */
class SystemChildListener(context: Context, override var language: BookLanguage = BookLanguage.ENGLISH) : ChildListener {
    companion object {
        const val PAUSE_TO_FINISH_MS = 1_400L
        const val SILENCE_TO_GIVE_UP_MS = 8_000L
        const val LONGEST_TURN_MS = 20_000L
        private const val FINISHING_GRACE_MS = 1_500L

        /** Locales the on-device recognizer turned down, so later turns go straight to the system one. */
        private val onDeviceFailed = mutableSetOf<String>()
    }

    private val context = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var heard = ""
    private var startedAt = 0L
    private var lastChange = 0L
    private var finishing = false
    private var onPartial: ((String) -> Unit)? = null
    private var onFinish: ((String?) -> Unit)? = null
    private var onError: ((ListenError) -> Unit)? = null
    /** Bumped on every start and stop, so callbacks from an old recognizer are ignored. */
    private var turn = 0

    private val locale get() = if (language == BookLanguage.CHINESE) "zh-CN" else "en-US"

    override fun start(onPartial: (String) -> Unit, onFinish: (String?) -> Unit, onError: (ListenError) -> Unit) {
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            throw ListenError(ListenError.Kind.MICROPHONE_NOT_ALLOWED)
        }
        cancel()
        this.onPartial = onPartial
        this.onFinish = onFinish
        this.onError = onError
        heard = ""
        finishing = false
        startedAt = now()
        lastChange = startedAt
        // Only the on-device recognizer is used, so what the child says never leaves the device
        // (as on iOS). Without one, the child can type instead.
        val onDevice = Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        if (!onDevice) throw ListenError(ListenError.Kind.UNAVAILABLE)
        if (locale in onDeviceFailed) {
            requestOnDeviceModel()
            throw ListenError(if (language == BookLanguage.CHINESE) ListenError.Kind.CHINESE_UNAVAILABLE else ListenError.Kind.UNAVAILABLE)
        }
        begin(onDevice = true)
        main.postDelayed(ticker, 200)
    }

    private fun begin(onDevice: Boolean) {
        turn += 1
        val current = turn
        val recognizer = try {
            if (onDevice && Build.VERSION.SDK_INT >= 31) SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            else throw ListenError(ListenError.Kind.UNAVAILABLE) // never the server recognizer
        } catch (_: Exception) {
            throw ListenError(ListenError.Kind.UNAVAILABLE)
        }
        this.recognizer = recognizer
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}

            override fun onPartialResults(partialResults: Bundle?) {
                if (turn != current) return
                val text = best(partialResults) ?: return
                if (text.isNotBlank() && text != heard) {
                    heard = text
                    lastChange = now()
                    onPartial?.invoke(text)
                }
            }

            override fun onResults(results: Bundle?) {
                if (turn != current) return
                best(results)?.takeIf { it.isNotBlank() }?.let { heard = it }
                complete(submit = true)
            }

            override fun onError(error: Int) {
                if (turn != current) return
                when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> fail(ListenError.Kind.MICROPHONE_NOT_ALLOWED)
                    SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED, SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> {
                        if (onDevice && heard.isEmpty()) {
                            // The on-device recognizer doesn't have this language (yet): ask for it
                            // to be fetched for next time. The server recognizer is never used.
                            onDeviceFailed += locale
                            requestOnDeviceModel()
                            fail(if (language == BookLanguage.CHINESE) ListenError.Kind.CHINESE_UNAVAILABLE else ListenError.Kind.UNAVAILABLE)
                        } else {
                            fail(if (language == BookLanguage.CHINESE) ListenError.Kind.CHINESE_UNAVAILABLE else ListenError.Kind.UNAVAILABLE)
                        }
                    }
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY, SpeechRecognizer.ERROR_CLIENT ->
                        if (heard.isEmpty() && !finishing) fail(ListenError.Kind.UNAVAILABLE) else complete(submit = true)
                    // No match, speech timeout, network and so on: submit whatever was heard.
                    else -> complete(submit = true)
                }
            }
        })
        recognizer.startListening(intent(onDevice))
    }

    private fun intent(onDevice: Boolean) = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        // A child's voice should stay on the device.
        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
        // Hints; many recognizers end on their own pause detection, and the ticker below backs it up.
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, PAUSE_TO_FINISH_MS)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, PAUSE_TO_FINISH_MS)
        if (!onDevice) putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 0L)
    }

    private fun requestOnDeviceModel() {
        if (Build.VERSION.SDK_INT < 33) return
        runCatching {
            val r = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            r.triggerModelDownload(intent(onDevice = true))
            main.postDelayed({ r.destroy() }, 5_000)
        }
    }

    private fun best(bundle: Bundle?): String? =
        bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.trim()

    private val ticker = object : Runnable {
        override fun run() {
            if (onFinish == null) return
            val t = now()
            when {
                finishing -> {}
                heard.isEmpty() && t - startedAt > SILENCE_TO_GIVE_UP_MS -> return complete(submit = false)
                heard.isNotEmpty() && t - lastChange > PAUSE_TO_FINISH_MS -> return complete(submit = true)
                t - startedAt > LONGEST_TURN_MS -> return finish()
            }
            main.postDelayed(this, 200)
        }
    }

    /** Asks the recognizer for its final words, then submits (or submits what's heard after a moment). */
    override fun finish() {
        val recognizer = recognizer ?: return complete(submit = true)
        if (finishing) return
        finishing = true
        runCatching { recognizer.stopListening() }
        val current = turn
        main.postDelayed({ if (turn == current) complete(submit = true) }, FINISHING_GRACE_MS)
    }

    override fun cancel() {
        onPartial = null
        onFinish = null
        onError = null
        teardown()
    }

    private fun complete(submit: Boolean) {
        val callback = onFinish
        val text = heard.trim()
        cancel()
        callback?.invoke(if (submit && text.isNotEmpty()) text else null)
    }

    private fun fail(kind: ListenError.Kind) {
        val callback = onError
        cancel()
        callback?.invoke(ListenError(kind))
    }

    private fun teardown() {
        turn += 1
        main.removeCallbacks(ticker)
        destroyRecognizer()
        finishing = false
    }

    private fun destroyRecognizer() {
        recognizer?.let { runCatching { it.cancel() }; runCatching { it.destroy() } }
        recognizer = null
    }

    private fun now() = android.os.SystemClock.elapsedRealtime()
}
