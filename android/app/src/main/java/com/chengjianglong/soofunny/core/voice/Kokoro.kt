package com.chengjianglong.soofunny.core.voice

import java.text.BreakIterator
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * The parts of the natural voices that don't need ONNX Runtime or Android: constants, silence
 * trimming, how sentences are split into phrases (with natural pauses) and the estimated word
 * highlighting. Mirrors `KokoroTTS` / `NaturalVoice` in the iOS app.
 */
object Kokoro {
    const val SAMPLE_RATE = 24_000

    /** The Chinese voices offered in Settings, the first being the default. */
    val chineseVoices = listOf("zf_001", "zf_017", "zf_032", "zf_049", "zf_094")

    const val ENGLISH_VOICE = "af_heart"

    /** Kokoro reads at most 510 phoneme tokens at a time. */
    const val MAX_TOKENS = 510

    /** Pause after a sentence and after a phrase inside a sentence, in seconds. */
    const val SENTENCE_GAP = 0.22
    const val PHRASE_GAP = 0.12

    /**
     * Kokoro speed for the Settings speed slider ([AppSettings.speechRate], 0.5…1.5, normal 1.0).
     * Normal reads at about 1.05×, as on iOS; the ends match iOS's slowest (0.77) and fastest (1.195).
     */
    fun speed(rate: Float): Float {
        val r = rate.coerceIn(0.5f, 1.5f)
        return if (r < 1f) 1.05f - (1f - r) * 0.56f else 1.05f + (r - 1f) * 0.29f
    }

    /**
     * Removes the silence Kokoro puts around each clip (about 0.35 s before and 0.5 s after),
     * keeping a few milliseconds so words don't start or end abruptly.
     */
    fun trimmingSilence(samples: FloatArray, threshold: Float = 0.008f): FloatArray {
        val first = samples.indexOfFirst { abs(it) > threshold }
        if (first < 0) return FloatArray(0)
        val last = samples.indexOfLast { abs(it) > threshold }
        val lead = (SAMPLE_RATE * 0.03).toInt()
        val tail = (SAMPLE_RATE * 0.06).toInt()
        return samples.copyOfRange(max(0, first - lead), min(samples.size - 1, last + tail) + 1)
    }

    data class Phrase(val text: String, val gap: Double)

    private fun hasHan(s: String) = s.codePoints().anyMatch { Character.UnicodeScript.of(it) == Character.UnicodeScript.HAN }
    private fun wordCount(s: String) = s.split(Regex("\\s+")).count { it.isNotEmpty() }
    private fun trimSpaces(s: String) = s.trim { it == ' ' || it == '\t' || Character.getType(it) == Character.SPACE_SEPARATOR.toInt() }

    /**
     * Splits a sentence into phrases so speech can start before all of it is made. Long sentences
     * split at commas; each phrase gets a short pause after it, like a breath.
     */
    fun phrases(sentence: String): List<Phrase> {
        val trimmed = sentence.trim()
        if (trimmed.isEmpty()) return emptyList()
        if (hasHan(trimmed)) return chinesePhrases(trimmed)
        val words = wordCount(trimmed)
        val endGap = if (trimmed.last() in ".!?") SENTENCE_GAP else PHRASE_GAP
        if (words <= 8 || !trimmed.contains(",")) return listOf(Phrase(trimmed, endGap))
        val parts = trimmed.split(",")
        val phrases = mutableListOf<String>()
        var current = ""
        for ((i, part) in parts.withIndex()) {
            current += (if (current.isEmpty()) "" else ",") + part
            val isLast = i == parts.size - 1
            // Keep phrases at least four words long so the voice keeps a natural tune.
            if (isLast || wordCount(current) >= 4) {
                phrases += trimSpaces(current) + (if (isLast) "" else ",")
                current = ""
            }
        }
        if (phrases.size > 1 && wordCount(phrases.last()) < 3) {
            val last = phrases.removeAt(phrases.size - 1)
            phrases[phrases.size - 1] = phrases.last() + " " + last
        }
        return phrases.mapIndexed { i, p -> Phrase(p, if (i == phrases.size - 1) endGap else PHRASE_GAP) }
    }

    /** Chinese has no spaces: long sentences split at commas into phrases of at least eight characters. */
    fun chinesePhrases(sentence: String): List<Phrase> {
        val endGap = if (sentence.lastOrNull()?.let { it in "。！？.!?" } == true) SENTENCE_GAP else PHRASE_GAP
        if (sentence.codePointCount(0, sentence.length) <= 18) return listOf(Phrase(sentence, endGap))
        val phrases = mutableListOf<String>()
        val current = StringBuilder()
        var count = 0
        var i = 0
        while (i < sentence.length) {
            val cp = sentence.codePointAt(i)
            current.appendCodePoint(cp)
            count += 1
            i += Character.charCount(cp)
            if (cp < 0x10000 && cp.toChar() in "，,；;" && count >= 8) {
                phrases += current.toString()
                current.setLength(0)
                count = 0
            }
        }
        if (current.isNotEmpty()) {
            if (count < 4 && phrases.isNotEmpty()) phrases[phrases.size - 1] = phrases.last() + current else phrases += current.toString()
        }
        return phrases.mapIndexed { idx, p -> Phrase(p, if (idx == phrases.size - 1) endGap else PHRASE_GAP) }
    }

    /**
     * Splits a run of text into sentences (at . ! ? 。 ！ ？ and line breaks), each with its offset
     * in [text], so a long page is said sentence by sentence. Sentences are trimmed.
     */
    fun sentences(text: String): List<Pair<String, Int>> {
        val out = mutableListOf<Pair<String, Int>>()
        var start = 0
        fun cut(end: Int) {
            val piece = text.substring(start, end)
            val lead = piece.indexOfFirst { !it.isWhitespace() }
            if (lead >= 0) out += piece.trim() to start + lead
            start = end
        }
        var i = 0
        while (i < text.length) {
            val c = text[i]
            if (c == '\n') {
                cut(i + 1)
            } else if (c in ".!?。！？…") {
                var j = i + 1
                while (j < text.length && text[j] in ".!?。！？…\"'”’)）」』") j++
                if (j >= text.length || text[j].isWhitespace() || c in "。！？") {
                    cut(j)
                    i = j
                    continue
                }
            }
            i++
        }
        if (start < text.length) cut(text.length)
        return out
    }

    /** A phrase to say, with where it is in the whole text (for word highlighting). */
    data class Piece(val text: String, val gap: Double, val offset: Int)

    /** [text] as phrases to say one after another, each with its offset in [text]. */
    fun pieces(text: String): List<Piece> {
        val out = mutableListOf<Piece>()
        for ((sentence, offset) in sentences(text)) {
            var cursor = 0
            for (p in phrases(sentence)) {
                val at = sentence.indexOf(p.text, cursor).takeIf { it >= 0 } ?: cursor
                out += Piece(p.text, p.gap, offset + at)
                cursor = min(sentence.length, at + p.text.length)
            }
        }
        return out
    }

    /** The words of [sentence] (letters or digits) with their ranges, as the system finds them. */
    fun words(sentence: String): List<IntRange> {
        val it = BreakIterator.getWordInstance()
        it.setText(sentence)
        val out = mutableListOf<IntRange>()
        var start = it.first()
        var end = it.next()
        while (end != BreakIterator.DONE) {
            if ((start until end).any { k -> sentence[k].isLetterOrDigit() }) out += start until end
            start = end
            end = it.next()
        }
        return out
    }

    /**
     * Estimates the word being spoken from how far through its phrase's audio playback is. Kokoro
     * gives no word timings, so each word gets a share of the audio by its length.
     */
    fun wordRange(sentence: String, progress: Double): IntRange? {
        val words = words(sentence).map { r -> r to sentence.codePointCount(r.first, r.last + 1) + 2 }
        if (words.isEmpty()) return null
        val p = progress.coerceIn(0.0, 1.0)
        val total = words.sumOf { it.second }.toDouble()
        var acc = 0.0
        for ((range, weight) in words) {
            acc += weight / total
            if (p <= acc) return range
        }
        return words.last().first
    }
}

/** A tiny JSON reader for the voice data: objects, arrays, strings, numbers, true/false/null. */
internal object MiniJson {
    fun parse(text: String): Any? = Parser(text).run { skip(); value() }

    private class Parser(val s: String) {
        var i = 0
        fun skip() { while (i < s.length && s[i].isWhitespace()) i++ }
        fun value(): Any? {
            skip()
            return when (val c = s[i]) {
                '{' -> obj()
                '[' -> arr()
                '"' -> string()
                't' -> { i += 4; true }
                'f' -> { i += 5; false }
                'n' -> { i += 4; null }
                else -> {
                    val start = i
                    while (i < s.length && (s[i].isDigit() || s[i] in "+-.eE")) i++
                    if (i == start) error("Bad JSON at $i: $c")
                    s.substring(start, i).toDouble()
                }
            }
        }

        fun obj(): Map<String, Any?> {
            i++
            val m = LinkedHashMap<String, Any?>()
            skip()
            if (s[i] == '}') { i++; return m }
            while (true) {
                skip()
                val k = string()
                skip(); i++ // the colon
                m[k] = value()
                skip()
                if (s[i++] == '}') return m
            }
        }

        fun arr(): List<Any?> {
            i++
            val l = ArrayList<Any?>()
            skip()
            if (s[i] == ']') { i++; return l }
            while (true) {
                l += value()
                skip()
                if (s[i++] == ']') return l
            }
        }

        fun string(): String {
            require(s[i] == '"') { "Expected a string at $i" }
            i++
            val b = StringBuilder()
            while (true) {
                val c = s[i++]
                when (c) {
                    '"' -> return b.toString()
                    '\\' -> when (val e = s[i++]) {
                        'n' -> b.append('\n'); 't' -> b.append('\t'); 'r' -> b.append('\r')
                        'b' -> b.append('\b'); 'f' -> b.append('\u000C')
                        'u' -> { b.append(s.substring(i, i + 4).toInt(16).toChar()); i += 4 }
                        else -> b.append(e)
                    }
                    else -> b.append(c)
                }
            }
        }
    }
}
