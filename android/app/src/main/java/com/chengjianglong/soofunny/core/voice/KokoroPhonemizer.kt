package com.chengjianglong.soofunny.core.voice

import java.io.InputStream

/**
 * Turns English text into Kokoro's phonemes, entirely offline.
 *
 * A Kotlin port of the iOS app's `KokoroPhonemizer`, itself a compact port of the dictionary path
 * of misaki (Apache-2.0), Kokoro's own phonemizer: a 183k-word US pronunciation dictionary,
 * misaki's rules for small function words ("a", "the", "to", …) and for -s, -ed and -ing endings,
 * numbers spelled out, and unknown words spelled letter by letter. There's no part-of-speech
 * tagger, so words with several readings ("read") use their most common one.
 */
class KokoroPhonemizer(lexicon: InputStream, vocab: InputStream) {
    /** Kokoro's phoneme → token id table. */
    val vocab: Map<Char, Long> = loadVocab(vocab)
    private val lexicon: Map<String, String>

    init {
        val map = HashMap<String, String>(250_000)
        lexicon.bufferedReader().useLines { lines ->
            for (line in lines) {
                if (line.isEmpty()) continue
                val tab = line.indexOf('\t')
                if (tab < 0) continue
                map[line.substring(0, tab)] = line.substring(tab + 1)
            }
        }
        for ((k, v) in EXTRA_WORDS) map.putIfAbsent(k, v)
        this.lexicon = map
    }

    /** Phonemes for [text], using only symbols Kokoro knows. */
    fun phonemize(text: String): String {
        val tokens = tokens(expandNumbers(text))
        // A single letter is said as its name ("B" is "bee", "a" is "ay").
        if (tokens.size == 1 && tokens[0].length == 1 && isLetter(tokens[0][0])) {
            return filter(raw(tokens[0].uppercase()) ?: "")
        }
        val out = StringBuilder()
        for ((i, token) in tokens.withIndex()) {
            if (token.isNotEmpty() && token[0] in PUNCTUATION) {
                out.append(token)
                continue
            }
            val next = tokens.getOrNull(i + 1)
            if (out.isNotEmpty()) out.append(' ')
            out.append(word(token, next?.let { startsWithVowel(it) }))
        }
        return filter(out.toString())
    }

    /** Token ids for the model: phonemes wrapped in the boundary token 0. */
    fun tokenIds(phonemes: String): LongArray {
        val ids = ArrayList<Long>(phonemes.length + 2)
        ids += 0L
        for (c in phonemes) vocab[c]?.let { ids += it }
        ids += 0L
        return ids.toLongArray()
    }

    // Words

    private fun word(w: String, nextStartsWithVowel: Boolean?): String {
        val lower = w.lowercase()
        when (lower) {
            "a" -> return "ɐ"
            "an" -> return "ɐn"
            "the" -> return if (nextStartsWithVowel == true) "ði" else "ðə"
            "to" -> return if (nextStartsWithVowel == true) "tʊ" else "tə"
        }
        if (w == "I") return "ˌI"
        raw(w)?.let { return it }
        if (lower.endsWith("'s")) raw(lower.dropLast(2))?.let { return plural(it) }
        if (lower.length > 2 && lower.endsWith("s")) {
            raw(lower.dropLast(1))?.let { return plural(it) }
            if (lower.endsWith("ies")) raw(lower.dropLast(3) + "y")?.let { return plural(it) }
            if (lower.endsWith("es")) raw(lower.dropLast(2))?.let { return plural(it) }
        }
        if (lower.length > 3 && lower.endsWith("ed")) {
            raw(lower.dropLast(1))?.let { return past(it) }
            raw(lower.dropLast(2))?.let { return past(it) }
        }
        if (lower.length > 4 && lower.endsWith("ing")) {
            val base = lower.dropLast(3)
            for (candidate in listOf(base, base + "e", base.dropLast(1))) {
                raw(candidate)?.let { return continuous(it) }
            }
        }
        // Unknown word: say its letters.
        return lower.filter { isLetter(it) }.mapNotNull { raw(it.toString().uppercase()) }.joinToString("")
    }

    /** Dictionary lookup, trying the word as written, lowercase and capitalized. */
    private fun raw(w: String): String? = lexicon[w] ?: lexicon[w.lowercase()] ?: lexicon[capitalized(w)]

    private fun startsWithVowel(w: String): Boolean? {
        val first = w.firstOrNull() ?: return null
        if (!isLetter(first)) return null
        val p = (raw(w) ?: "").filter { it != 'ˈ' && it != 'ˌ' }
        val sound = p.firstOrNull() ?: return null
        return sound in VOWELS
    }

    private fun filter(s: String): String = s.filter { vocab.containsKey(it) }

    companion object {
        private const val VOWELS = "AIOQWYaiuæɑɒɔəɛɜɪʊʌᵻ"
        private const val TAUS = "AIOWYiuæɑəɛɪɹʊʌ"
        internal const val PUNCTUATION = ";:,.!?—…\"()“”"

        /**
         * Words the dictionary doesn't have that should be said, not spelled: the app's name is
         * "Soo Funny" ("Soo" rhymes with "zoo"), and "iPhone" and "iPad" are "eye phone" and "eye pad".
         */
        private val EXTRA_WORDS = mapOf("soo" to "sˈu", "soofunny" to "sˈu fˈʌni", "iphone" to "ˈI fˈOn", "ipad" to "ˈI pˈæd")

        /** A Kokoro model's symbols and their token ids, one "symbol<tab>id" per line. */
        fun loadVocab(input: InputStream): Map<Char, Long> {
            val vocab = HashMap<Char, Long>()
            // Don't trim lines: one of the phonemes is the space character.
            for (line in input.bufferedReader().readText().split('\n')) {
                if (line.isEmpty()) continue
                val parts = line.split('\t')
                if (parts.size != 2 || parts[0].isEmpty()) continue
                val id = parts[1].toLongOrNull() ?: continue
                vocab[parts[0][0]] = id
            }
            return vocab
        }

        /** Like Swift's `Character.isLetter` (Unicode Alphabetic). */
        internal fun isLetter(c: Char) = Character.isAlphabetic(c.code)

        /** Like Swift's `Character.isNumber` (any Unicode numeric type, Han numerals too). */
        internal fun isNumber(cp: Int): Boolean = when (Character.getType(cp)) {
            Character.DECIMAL_DIGIT_NUMBER.toInt(), Character.LETTER_NUMBER.toInt(), Character.OTHER_NUMBER.toInt() -> true
            else -> cp in HAN_NUMERIC
        }

        /** Letters with a Unicode numeric value that aren't number characters: 一, 二, 万, 零, 壹… */
        private val HAN_NUMERIC: Set<Int> = intArrayOf(
            0x3405, 0x3483, 0x382a, 0x3b4d, 0x4e00, 0x4e03, 0x4e07, 0x4e09, 0x4e24, 0x4e5d, 0x4e8c, 0x4e94, 0x4e96, 0x4eac,
            0x4ebf, 0x4ec0, 0x4edf, 0x4ee8, 0x4f0d, 0x4f70, 0x4fe9, 0x5006, 0x5104, 0x5146, 0x5169, 0x516b, 0x516d, 0x5341,
            0x5343, 0x5344, 0x5345, 0x534c, 0x53c1, 0x53c2, 0x53c3, 0x53c4, 0x56db, 0x58f1, 0x58f9, 0x5e7a, 0x5efe, 0x5eff,
            0x5f0c, 0x5f0d, 0x5f0e, 0x5f10, 0x62d0, 0x62fe, 0x634c, 0x67d2, 0x6d1e, 0x6f06, 0x7396, 0x767e, 0x7695, 0x79ed,
            0x8086, 0x842c, 0x8cae, 0x8cb3, 0x8d30, 0x920e, 0x94a9, 0x9621, 0x9646, 0x964c, 0x9678, 0x96f6, 0xf96b, 0xf973,
            0xf978, 0xf9b2, 0xf9d1, 0xf9d3, 0xf9fd, 0x20001, 0x20064, 0x200e2, 0x20121, 0x2092a, 0x20983, 0x2098c, 0x2099c,
            0x20aea, 0x20afd, 0x20b19, 0x22390, 0x22998, 0x23b1b, 0x2626d, 0x2f890,
        ).toHashSet()

        /** Swift's `String.capitalized` for one word: first letter upper, the rest lower. */
        private fun capitalized(w: String): String =
            if (w.isEmpty()) w else w.substring(0, 1).uppercase() + w.substring(1).lowercase()

        private fun plural(stem: String): String {
            val last = stem.lastOrNull() ?: return stem
            if (last in "ptkfθ") return stem + "s"
            if (last in "szʃʒʧʤ") return stem + "ᵻz"
            return stem + "z"
        }

        private fun past(stem: String): String {
            val last = stem.lastOrNull() ?: return stem
            if (last in "pkfθʃsʧ") return stem + "t"
            if (last == 'd') return stem + "ᵻd"
            if (last != 't') return stem + "d"
            if (stem.length > 1 && stem[stem.length - 2] in TAUS) return stem.dropLast(1) + "ɾᵻd"
            return stem + "ᵻd"
        }

        private fun continuous(stem: String): String {
            if (stem.length > 1 && stem.last() == 't' && stem[stem.length - 2] in TAUS) return stem.dropLast(1) + "ɾɪŋ"
            return stem + "ɪŋ"
        }

        /** Words (with apostrophes), numbers and punctuation, in order. */
        fun tokens(text: String): List<String> {
            val tokens = mutableListOf<String>()
            val current = StringBuilder()
            fun flush() {
                if (current.isNotEmpty()) tokens += current.toString()
                current.setLength(0)
            }
            for ((i, c) in text.withIndex()) {
                if (isLetter(c) || isNumber(c.code)) {
                    current.append(c)
                } else if ((c == '\'' || c == '’') && current.isNotEmpty() && i + 1 < text.length && isLetter(text[i + 1])) {
                    current.append('\'')
                } else {
                    flush()
                    if (c in PUNCTUATION) tokens += c.toString()
                }
            }
            flush()
            return tokens
        }

        /** Writes whole numbers as words: "12" → "twelve", "21" → "twenty one". */
        fun expandNumbers(text: String): String {
            val result = StringBuilder()
            val digits = StringBuilder()
            fun flush() {
                val n = digits.toString().toLongOrNull()
                if (n != null) result.append(' ').append(spellOut(n).replace('-', ' ')).append(' ') else result.append(digits)
                digits.setLength(0)
            }
            for (c in text) {
                if (c in '0'..'9') {
                    digits.append(c)
                } else {
                    if (digits.isNotEmpty()) flush()
                    result.append(c)
                }
            }
            if (digits.isNotEmpty()) flush()
            return result.toString()
        }

        private val ONES = listOf(
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
            "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
        )
        private val TENS = listOf("", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety")
        private val SCALES = listOf(
            1_000_000_000_000_000_000L to "quintillion", 1_000_000_000_000_000L to "quadrillion",
            1_000_000_000_000L to "trillion", 1_000_000_000L to "billion", 1_000_000L to "million", 1_000L to "thousand",
        )

        /** US English number words as ICU's spell-out makes them: 1234 → "one thousand two hundred thirty-four". */
        fun spellOut(n: Long): String {
            if (n < 0) return "minus " + spellOut(-n)
            if (n < 20) return ONES[n.toInt()]
            if (n < 100) return TENS[(n / 10).toInt()] + if (n % 10 != 0L) "-" + ONES[(n % 10).toInt()] else ""
            if (n < 1000) return ONES[(n / 100).toInt()] + " hundred" + if (n % 100 != 0L) " " + spellOut(n % 100) else ""
            for ((unit, name) in SCALES) {
                if (n >= unit) {
                    val rest = n % unit
                    return spellOut(n / unit) + " " + name + if (rest != 0L) " " + spellOut(rest) else ""
                }
            }
            return n.toString()
        }
    }
}
