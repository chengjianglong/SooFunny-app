package com.chengjianglong.soofunny.core

import android.content.Context
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.text.BreakIterator
import java.util.Locale
import java.util.UUID
import kotlin.coroutines.coroutineContext

/**
 * Makes an audiobook (`.m4a`, AAC) of a scanned book on the device, as on iOS: each page read
 * phrase by phrase, English in the English voice and Chinese in the Chinese voice, with a short
 * pause where the language changes inside a sentence, a longer one after each sentence and a
 * breath between pages. Uses the natural voices when they're installed, else the device's
 * text-to-speech voices.
 */
object AudiobookMaker {
    const val SAMPLE_RATE = 24_000

    /**
     * The natural voice, when available: renders text in one language to 24 kHz mono samples, or
     * null if it can't (then the device voice is used). Set by the natural-voice engine.
     */
    var naturalRender: (suspend (String, BookLanguage) -> FloatArray?)? =
        { text, language -> com.chengjianglong.soofunny.core.voice.NaturalVoices.render(text, language) }

    class NoVoiceException : Exception("nothing to read aloud")

    /** A stretch of a page read in one voice, and the pause (seconds) after it. */
    data class Part(val text: String, val language: BookLanguage, val gap: Double)

    fun sentences(text: String): List<String> {
        val it = BreakIterator.getSentenceInstance(Locale.ROOT).apply { setText(text) }
        val out = mutableListOf<String>()
        var start = it.first()
        var end = it.next()
        while (end != BreakIterator.DONE) {
            text.substring(start, end).trim().takeIf { s -> s.isNotEmpty() }?.let(out::add)
            start = end
            end = it.next()
        }
        return out
    }

    /** A page's words in reading order, split wherever the language changes. */
    fun parts(page: String): List<Part> = sentences(page).flatMap { sentence ->
        val runs = BookLanguage.runs(sentence).map { run ->
            if (run.language == BookLanguage.ENGLISH) run.copy(text = BookLanguage.withoutPinyin(run.text)) else run
        }.filter { run -> run.text.any { it.isLetterOrDigit() } }
        runs.mapIndexed { i, run -> Part(run.text.trim(), run.language, if (i == runs.lastIndex) 0.3 else 0.08) }
    }

    /** Writes [pages] to [out]; [progress] gets 0…1. Throws [NoVoiceException] if nothing could be said. */
    suspend fun make(context: Context, pages: List<String>, out: File, progress: (Float) -> Unit) = withContext(Dispatchers.Default) {
        val pageParts = pages.map(::parts)
        val total = pageParts.sumOf { it.size }.coerceAtLeast(1)
        val partial = File(out.parentFile, out.nameWithoutExtension + ".partial.m4a")
        partial.delete()
        val device = DeviceVoice(context)
        val encoder = AacWriter(partial)
        var spoken = 0
        var done = 0
        try {
            for (parts in pageParts) {
                for (part in parts) {
                    coroutineContext.ensureActive()
                    val samples = naturalRender?.invoke(part.text, part.language)?.takeIf { it.isNotEmpty() }
                        ?: device.render(part.text, part.language)
                    if (samples != null && samples.isNotEmpty()) {
                        encoder.write(samples)
                        encoder.silence(part.gap)
                        spoken++
                    }
                    done++
                    withContext(Dispatchers.Main) { progress(done.toFloat() / total) }
                }
                encoder.silence(0.8) // a breath between pages
            }
            encoder.finish()
        } catch (e: Throwable) {
            encoder.abandon()
            partial.delete()
            throw e
        } finally {
            device.shutdown()
        }
        if (spoken == 0) {
            partial.delete()
            throw NoVoiceException()
        }
        out.delete()
        partial.renameTo(out)
    }

    /** The device's text-to-speech, rendering to a WAV file and back into samples at 24 kHz. */
    private class DeviceVoice(private val context: Context) {
        private var tts: TextToSpeech? = null
        private val ready = CompletableDeferred<Boolean>()
        private val pending = mutableMapOf<String, CompletableDeferred<Boolean>>()

        init {
            tts = TextToSpeech(context.applicationContext) { ready.complete(it == TextToSpeech.SUCCESS) }.also {
                it.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(id: String?) {}
                    override fun onDone(id: String?) { synchronized(pending) { pending.remove(id) }?.complete(true) }
                    @Deprecated("Deprecated in Java")
                    override fun onError(id: String?) { synchronized(pending) { pending.remove(id) }?.complete(false) }
                    override fun onError(id: String?, code: Int) { synchronized(pending) { pending.remove(id) }?.complete(false) }
                })
            }
        }

        suspend fun render(text: String, language: BookLanguage): FloatArray? {
            val engine = tts ?: return null
            if (withTimeoutOrNull(10_000) { ready.await() } != true) return null
            val id = UUID.randomUUID().toString()
            val file = File(context.cacheDir, "tts-$id.wav")
            val done = CompletableDeferred<Boolean>()
            synchronized(pending) { pending[id] = done }
            synchronized(engine) {
                engine.language = if (language == BookLanguage.CHINESE) Locale.SIMPLIFIED_CHINESE else Locale.US
                engine.setSpeechRate(AppSettings.speechRate)
                if (engine.synthesizeToFile(text, Bundle(), file, id) != TextToSpeech.SUCCESS) return null
            }
            val ok = withTimeoutOrNull(60_000) { done.await() } == true
            return try {
                if (ok) readWav(file) else null
            } finally {
                file.delete()
            }
        }

        fun shutdown() {
            tts?.shutdown()
            tts = null
        }
    }

    /** Reads a 16-bit PCM WAV into mono samples resampled to [SAMPLE_RATE]. */
    internal fun readWav(file: File): FloatArray? {
        val bytes = file.readBytes()
        if (bytes.size < 44) return null
        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var pos = 12
        var channels = 1
        var rate = SAMPLE_RATE
        var bits = 16
        while (pos + 8 <= bytes.size) {
            val id = String(bytes, pos, 4, Charsets.US_ASCII)
            val size = buf.getInt(pos + 4)
            val body = pos + 8
            if (id == "fmt ") {
                channels = buf.getShort(body + 2).toInt()
                rate = buf.getInt(body + 4)
                bits = buf.getShort(body + 14).toInt()
            } else if (id == "data") {
                if (bits != 16) return null
                val end = if (size <= 0 || body + size > bytes.size) bytes.size else body + size
                val frames = (end - body) / (2 * channels)
                val mono = FloatArray(frames) { f ->
                    var sum = 0f
                    for (c in 0 until channels) sum += buf.getShort(body + (f * channels + c) * 2) / 32768f
                    sum / channels
                }
                return resample(mono, rate, SAMPLE_RATE)
            }
            pos = body + size + (size and 1)
        }
        return null
    }

    internal fun resample(input: FloatArray, from: Int, to: Int): FloatArray {
        if (from == to || input.isEmpty()) return input
        val n = (input.size.toLong() * to / from).toInt()
        return FloatArray(n) { i ->
            val x = i.toDouble() * from / to
            val a = x.toInt().coerceAtMost(input.lastIndex)
            val b = (a + 1).coerceAtMost(input.lastIndex)
            val t = (x - a).toFloat()
            input[a] * (1 - t) + input[b] * t
        }
    }

    /** Encodes 24 kHz mono float samples to AAC-LC (64 kbit/s) in an MPEG-4 file. */
    private class AacWriter(file: File) {
        private val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        private val muxer = MediaMuxer(file.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        private var track = -1
        private var framesIn = 0L
        private val info = MediaCodec.BufferInfo()

        init {
            val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, 1).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 64_000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16_384)
            }
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
        }

        fun silence(seconds: Double) = write(FloatArray((SAMPLE_RATE * seconds).toInt()))

        fun write(samples: FloatArray) {
            var offset = 0
            while (offset < samples.size) {
                val index = codec.dequeueInputBuffer(10_000)
                if (index >= 0) {
                    val input = codec.getInputBuffer(index)!!.order(ByteOrder.LITTLE_ENDIAN)
                    input.clear()
                    val count = minOf(samples.size - offset, input.remaining() / 2)
                    for (i in 0 until count) {
                        input.putShort((samples[offset + i].coerceIn(-1f, 1f) * 32767f).toInt().toShort())
                    }
                    codec.queueInputBuffer(index, 0, count * 2, framesIn * 1_000_000L / SAMPLE_RATE, 0)
                    framesIn += count
                    offset += count
                }
                drain(false)
            }
        }

        fun finish() {
            while (true) {
                val index = codec.dequeueInputBuffer(10_000)
                if (index >= 0) {
                    codec.queueInputBuffer(index, 0, 0, framesIn * 1_000_000L / SAMPLE_RATE, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    break
                }
                drain(false)
            }
            drain(true)
            codec.stop()
            codec.release()
            if (track >= 0) muxer.stop()
            muxer.release()
        }

        fun abandon() {
            runCatching { codec.stop() }
            runCatching { codec.release() }
            runCatching { if (track >= 0) muxer.stop() }
            runCatching { muxer.release() }
        }

        private fun drain(toEnd: Boolean) {
            while (true) {
                val index = codec.dequeueOutputBuffer(info, if (toEnd) 10_000 else 0)
                when {
                    index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!toEnd) return
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                    }
                    index >= 0 -> {
                        val output = codec.getOutputBuffer(index)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0 && track >= 0) {
                            output.position(info.offset)
                            output.limit(info.offset + info.size)
                            muxer.writeSampleData(track, output, info)
                        }
                        codec.releaseOutputBuffer(index, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }
    }
}
