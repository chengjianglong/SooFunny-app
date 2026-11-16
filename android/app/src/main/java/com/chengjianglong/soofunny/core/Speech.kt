package com.chengjianglong.soofunny.core

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.chengjianglong.soofunny.core.voice.Kokoro
import com.chengjianglong.soofunny.core.voice.NaturalPlayback
import com.chengjianglong.soofunny.core.voice.NaturalVoices
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import java.util.Locale

/**
 * Reads text aloud, offline. Text with both languages ("dog, 狗") is split into runs and each run is
 * read in its own language, one after another:
 *  - English in the natural Kokoro voice ("Heart") when it's installed and chosen in Settings,
 *    Chinese in the natural Chinese voice chosen in Settings when it's installed ([NaturalVoices]);
 *  - otherwise in the device's own text-to-speech voices.
 */
object Speech {
    private var tts: TextToSpeech? = null
    private var ready = false
    /** Whether the device's text-to-speech has finished starting (working or not). */
    private var started = false
    private val main = Handler(Looper.getMainLooper())
    private val scope = MainScope()

    /** The text being spoken right now, to animate its speaker button. */
    var speaking by mutableStateOf<String?>(null)
        private set

    /** The character range of [speaking] being read now, for word highlighting. */
    var range by mutableStateOf<IntRange?>(null)
        private set

    private var deviceChinese by mutableStateOf(true)

    /** Whether Chinese can be read aloud (by the natural Chinese voice or an installed device voice). */
    val chineseAvailable: Boolean get() = NaturalVoices.chineseInstalled || deviceChinese

    private var session = 0
    private var job: Job? = null
    private var onFinished: (() -> Unit)? = null
    private var pending: Pair<String, (() -> Unit)?>? = null

    /** Device-voice utterances being said, by id: where their text starts, and their end. */
    private class Utterance(val text: String, val offset: Int, val done: CompletableDeferred<Unit>)
    private val utterances = HashMap<String, Utterance>()
    private var nextUtterance = 0

    fun init(context: Context) {
        if (tts != null) return
        NaturalVoices.deviceHasChinese = { deviceChinese }
        NaturalVoices.init(context)
        tts = TextToSpeech(context.applicationContext) { status ->
            main.post {
                started = true
                ready = status == TextToSpeech.SUCCESS
                if (ready) {
                    val zh = tts?.isLanguageAvailable(Locale.SIMPLIFIED_CHINESE) ?: TextToSpeech.LANG_NOT_SUPPORTED
                    deviceChinese = zh >= TextToSpeech.LANG_AVAILABLE
                }
                pending?.let { (text, done) -> speak(text, done) }
                pending = null
            }
        }.also { it.setOnUtteranceProgressListener(listener) }
    }

    /** Says [text]. [onFinished] runs when it has all been said (not when it's stopped). */
    fun speak(text: String, onFinished: (() -> Unit)? = null) {
        stopVoice()
        // Pinyin printed with the characters isn't read, nor stretches of only marks.
        val parts = BookLanguage.spokenRuns(text)
        val needsDevice = parts.any { !NaturalVoices.canSay(it.text, it.language) }
        if (needsDevice && tts != null && !started) {
            // The device voice is still starting: say it once it's ready.
            pending = text to onFinished
            speaking = text
            return
        }
        session += 1
        val mine = session
        speaking = text
        range = null
        this.onFinished = onFinished
        if (parts.isEmpty()) {
            finish(mine)
            return
        }
        job = scope.launch {
            // All the natural voice's phrases are asked for up front, so later ones are made while
            // earlier ones play.
            val plans = parts.map { part ->
                if (!NaturalVoices.canSay(part.text, part.language)) return@map null
                val engine = if (part.language == BookLanguage.ENGLISH) NaturalVoices.english else NaturalVoices.chinese
                val pieces = Kokoro.pieces(part.text).map { it.copy(offset = it.offset + part.offset) }
                pieces to pieces.map { engine.audio(it.text) }
            }
            try {
                for ((part, plan) in parts.zip(plans)) {
                    if (plan == null) {
                        deviceSay(part.text, part.language, part.offset)
                    } else {
                        NaturalPlayback.play(plan.first, plan.second,
                            onWord = { if (mine == session) range = it },
                            fallback = { piece -> deviceSay(piece.text, part.language, piece.offset) })
                    }
                }
                finish(mine)
            } finally {
                plans.forEach { plan -> plan?.second?.forEach(Deferred<FloatArray?>::cancel) }
            }
        }
    }

    fun stop() {
        stopVoice()
        speaking = null
        range = null
    }

    private fun stopVoice() {
        pending = null
        onFinished = null
        session += 1
        job?.cancel()
        job = null
        tts?.stop()
        utterances.values.forEach { it.done.complete(Unit) }
        utterances.clear()
    }

    private fun finish(forSession: Int) {
        if (forSession != session) return
        val done = onFinished
        onFinished = null
        speaking = null
        range = null
        done?.invoke()
    }

    /** Says [text] in the device's voice and waits until it's been said. */
    private suspend fun deviceSay(text: String, language: BookLanguage, offset: Int) {
        val engine = tts?.takeIf { ready } ?: return
        if (text.none { it.isLetterOrDigit() }) return
        val id = "u${nextUtterance++}"
        val utterance = Utterance(text, offset, CompletableDeferred())
        utterances[id] = utterance
        try {
            engine.setSpeechRate(AppSettings.speechRate)
            engine.language = if (language == BookLanguage.CHINESE) Locale.SIMPLIFIED_CHINESE else Locale.US
            if (engine.speak(text, TextToSpeech.QUEUE_ADD, Bundle(), id) != TextToSpeech.SUCCESS) return
            utterance.done.await()
        } finally {
            utterances.remove(id)
        }
    }

    private val listener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {
            main.post {
                val u = utterances[utteranceId] ?: return@post
                range = u.offset until u.offset + u.text.length
            }
        }

        override fun onRangeStart(utteranceId: String?, start: Int, end: Int, frame: Int) {
            main.post {
                val u = utterances[utteranceId] ?: return@post
                range = (u.offset + start) until (u.offset + end)
            }
        }

        override fun onDone(utteranceId: String?) {
            main.post { utterances[utteranceId]?.done?.complete(Unit) }
        }

        @Deprecated("Deprecated in Java")
        override fun onError(utteranceId: String?) = onDone(utteranceId)

        override fun onError(utteranceId: String?, errorCode: Int) = onDone(utteranceId)
    }
}
