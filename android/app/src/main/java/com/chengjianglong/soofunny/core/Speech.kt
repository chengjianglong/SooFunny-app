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
import java.util.Locale

/**
 * Reads text aloud with the device's own text-to-speech engine, offline when the engine's voices
 * are installed. Text with both languages ("dog, 狗") is split into runs and each run is read in
 * its own language, one after another.
 *
 * (The iOS app uses the Kokoro neural voices; on Android that's a later phase. See the README.)
 */
object Speech {
    private var tts: TextToSpeech? = null
    private var ready = false
    private val main = Handler(Looper.getMainLooper())

    /** The text being spoken right now, to animate its speaker button. */
    var speaking by mutableStateOf<String?>(null)
        private set

    /** The character range of [speaking] being read now, for word highlighting (when the engine reports it). */
    var range by mutableStateOf<IntRange?>(null)
        private set

    /** Whether a Chinese voice is installed. */
    var chineseAvailable by mutableStateOf(true)
        private set

    private var session = 0
    private var parts: List<BookLanguage.Run> = emptyList()
    private var onFinished: (() -> Unit)? = null
    private var pending: Pair<String, (() -> Unit)?>? = null

    fun init(context: Context) {
        if (tts != null) return
        tts = TextToSpeech(context.applicationContext) { status ->
            main.post {
                ready = status == TextToSpeech.SUCCESS
                if (ready) {
                    val zh = tts?.isLanguageAvailable(Locale.SIMPLIFIED_CHINESE) ?: TextToSpeech.LANG_NOT_SUPPORTED
                    chineseAvailable = zh >= TextToSpeech.LANG_AVAILABLE
                    pending?.let { (text, done) -> speak(text, done) }
                }
                pending = null
            }
        }.also { it.setOnUtteranceProgressListener(listener) }
    }

    /** Says [text]. [onFinished] runs when it has all been said (not when it's stopped). */
    fun speak(text: String, onFinished: (() -> Unit)? = null) {
        stopVoice()
        val engine = tts
        if (engine == null || !ready) {
            pending = text to onFinished
            speaking = text
            return
        }
        session += 1
        speaking = text
        range = null
        this.onFinished = onFinished
        // Pinyin printed with the characters isn't read, nor stretches of only marks.
        parts = BookLanguage.runs(text).map { run ->
            if (run.language == BookLanguage.ENGLISH) run.copy(text = BookLanguage.withoutPinyin(run.text)) else run
        }.filter { run -> run.text.any { it.isLetterOrDigit() } }
        if (parts.isEmpty()) {
            finish(session)
            return
        }
        engine.setSpeechRate(AppSettings.speechRate)
        parts.forEachIndexed { index, part ->
            engine.language = if (part.language == BookLanguage.CHINESE) Locale.SIMPLIFIED_CHINESE else Locale.US
            engine.speak(part.text, TextToSpeech.QUEUE_ADD, Bundle(), "$session:$index")
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
        tts?.stop()
    }

    private fun finish(forSession: Int) {
        if (forSession != session) return
        val done = onFinished
        onFinished = null
        speaking = null
        range = null
        done?.invoke()
    }

    private fun parse(id: String?): Pair<Int, Int>? {
        val (s, i) = id?.split(":")?.takeIf { it.size == 2 } ?: return null
        return (s.toIntOrNull() ?: return null) to (i.toIntOrNull() ?: return null)
    }

    private val listener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {
            main.post {
                val (s, i) = parse(utteranceId) ?: return@post
                if (s == session) parts.getOrNull(i)?.let { range = it.offset until it.offset + it.text.length }
            }
        }

        override fun onRangeStart(utteranceId: String?, start: Int, end: Int, frame: Int) {
            main.post {
                val (s, i) = parse(utteranceId) ?: return@post
                val part = parts.getOrNull(i) ?: return@post
                if (s == session) range = (part.offset + start) until (part.offset + end)
            }
        }

        override fun onDone(utteranceId: String?) {
            main.post {
                val (s, i) = parse(utteranceId) ?: return@post
                if (s == session && i == parts.lastIndex) finish(s)
            }
        }

        @Deprecated("Deprecated in Java")
        override fun onError(utteranceId: String?) = onDone(utteranceId)

        override fun onError(utteranceId: String?, errorCode: Int) = onDone(utteranceId)
    }
}
