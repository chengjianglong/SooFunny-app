package com.chengjianglong.soofunny.core.voice

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.max

/**
 * Plays natural-voice phrases one after another with an [AudioTrack] (24 kHz mono), each followed
 * by its pause, and reports the word being said. Run it on the main thread: it only waits and
 * copies (writes never block), so cancelling it stops the sound at once.
 */
internal object NaturalPlayback {
    private class Segment(val start: Long, val frames: Int, val piece: Kokoro.Piece)

    /**
     * Says [pieces], whose audio is [audio] (being made in order). [onWord] gets the range, in the
     * pieces' offsets, of the word being said. A piece the natural voice couldn't make is given to
     * [fallback] (the device voice) after what's before it has been heard.
     */
    suspend fun play(
        pieces: List<Kokoro.Piece>,
        audio: List<Deferred<FloatArray?>>,
        onWord: (IntRange) -> Unit,
        fallback: suspend (Kokoro.Piece) -> Unit,
    ) {
        var track: AudioTrack? = null
        val segments = ArrayList<Segment>()
        var written = 0L
        try {
            coroutineScope {
                val ticker = launch {
                    var last: IntRange? = null
                    while (isActive) {
                        val t = track
                        if (t != null) {
                            val frame = t.playbackHeadPosition.toLong() and 0xFFFFFFFFL
                            val segment = segments.lastOrNull { it.start <= frame }
                            if (segment != null && frame < segment.start + segment.frames) {
                                val progress = (frame - segment.start).toDouble() / max(1, segment.frames)
                                val range = Kokoro.wordRange(segment.piece.text, progress)
                                if (range != null) {
                                    val shifted = (segment.piece.offset + range.first)..(segment.piece.offset + range.last)
                                    if (shifted != last) {
                                        last = shifted
                                        onWord(shifted)
                                    }
                                }
                            }
                        }
                        delay(33)
                    }
                }
                for ((i, piece) in pieces.withIndex()) {
                    val samples = audio[i].await()
                    if (samples == null || samples.isEmpty()) {
                        if (piece.text.none { it.isLetterOrDigit() }) continue
                        // The natural voice couldn't say it: let the device's voice say this phrase.
                        track?.let { drain(it, written); release(it) }
                        track = null
                        segments.clear()
                        written = 0
                        fallback(piece)
                        continue
                    }
                    val t = track ?: newTrack().also { track = it; it.play() }
                    segments += Segment(written, samples.size, piece)
                    write(t, samples)
                    val gap = FloatArray((Kokoro.SAMPLE_RATE * piece.gap).toInt())
                    write(t, gap)
                    written += samples.size + gap.size
                }
                track?.let { drain(it, written) }
                ticker.cancel()
            }
        } finally {
            track?.let { release(it) }
        }
    }

    private fun newTrack(): AudioTrack {
        val min = AudioTrack.getMinBufferSize(Kokoro.SAMPLE_RATE, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        return AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(Kokoro.SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(max(min * 2, Kokoro.SAMPLE_RATE / 5 * 4))
            .build()
    }

    /** Writes all of [samples], waiting (not blocking) while the track's buffer is full. */
    private suspend fun write(track: AudioTrack, samples: FloatArray) {
        var at = 0
        while (at < samples.size) {
            val n = track.write(samples, at, samples.size - at, AudioTrack.WRITE_NON_BLOCKING)
            if (n < 0) return
            at += n
            if (at < samples.size) delay(15)
        }
    }

    /** Waits until everything written has been heard (silence pushes the last of it through). */
    private suspend fun drain(track: AudioTrack, written: Long) {
        val padding = FloatArray(max(track.bufferSizeInFrames, Kokoro.SAMPLE_RATE / 10))
        val start = System.currentTimeMillis()
        var played = track.playbackHeadPosition.toLong() and 0xFFFFFFFFL
        val limit = (written - played) * 1000 / Kokoro.SAMPLE_RATE + 2_000
        var padded = 0
        while (played < written && System.currentTimeMillis() - start < limit) {
            if (padded < padding.size) {
                // Not written with write(): it would wait for room, and the end may already be playing.
                val n = track.write(padding, padded, padding.size - padded, AudioTrack.WRITE_NON_BLOCKING)
                if (n < 0) padded = padding.size else padded += n
            }
            delay(20)
            played = track.playbackHeadPosition.toLong() and 0xFFFFFFFFL
        }
    }

    private fun release(track: AudioTrack) {
        runCatching {
            track.pause()
            track.flush()
        }
        track.release()
    }
}
