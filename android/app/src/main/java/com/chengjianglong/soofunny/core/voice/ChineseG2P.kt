package com.chengjianglong.soofunny.core.voice

import java.io.InputStream
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min

/**
 * Turns Chinese text into the phonemes Kokoro's Chinese model (v1.1-zh) reads: zhuyin-like
 * symbols with tone numbers, as misaki's `ZHG2P(version: "1.1")` makes them.
 *
 * A Kotlin port of the iOS app's `ChineseG2P`, a port of misaki's Chinese front end (itself adapted
 * from PaddleSpeech, Apache-2.0), with the parts it relies on: jieba's dictionary segmentation and
 * part-of-speech HMM, and pypinyin's readings (data MIT). `ChineseG2PTest` checks the result
 * matches misaki on all of the app's Chinese text.
 *
 * Text is handled one Unicode code point at a time (Swift works in grapheme clusters; the two only
 * differ for combined emoji and accents, which this never reads anyway).
 *
 * Loading takes a moment, so make one and keep it. Not thread-safe.
 *
 * @param open opens one of the data files (`zh_chars.tsv`, `zh_hmm.tsv`, `zh_phrases.tsv`,
 *   `zh_rules.json`, `zh_words.tsv`) by name.
 * @param english says English parts (the English voice's phonemizer).
 */
class ChineseG2P(open: (String) -> InputStream, private val english: (String) -> String) {
    private val chars = HashMap<String, String>(30_000)
    private val phrases = HashMap<String, List<String>>(60_000)
    private val maxPhrase: Int
    /** jieba's dictionary: frequency shl 8 or the tag's index (255 when there's no tag). */
    private val words = HashMap<String, Int>(700_000)
    private val tagNames = ArrayList<String>()
    private val logTotal: Double
    private val mustNeural: Set<String>
    private val mustNotNeural: Set<String>
    private val mustErhua: Set<String>
    private val notErhua: Set<String>
    private val hmm: Hmm

    init {
        fun lines(name: String, each: (String) -> Unit) =
            open(name).bufferedReader().useLines { seq -> seq.forEach { if (it.isNotEmpty()) each(it) } }

        lines("zh_chars.tsv") { line ->
            val f = fields(line)
            if (f.size == 2 && f[0].isNotEmpty()) chars[firstUnit(f[0])] = f[1]
        }
        var longest = 2
        lines("zh_phrases.tsv") { line ->
            val f = fields(line)
            if (f.size == 2) {
                phrases[f[0]] = f[1].split(' ').filter { it.isNotEmpty() }
                longest = max(longest, f[0].codePointCount(0, f[0].length))
            }
        }
        maxPhrase = longest
        val tagIndex = HashMap<String, Int>()
        var total = 0L
        lines("zh_words.tsv") { line ->
            val f = fields(line)
            val n = if (f.size == 3) f[1].toIntOrNull() else null
            if (n != null) {
                val word = f[0]
                val tag = tagIndex.getOrPut(f[2]) { tagNames += f[2]; tagNames.size - 1 }
                words[word] = (n shl 8) or tag
                total += n
                // jieba keeps every prefix of a word, with frequency 0, to know when to keep looking.
                val units = units(word)
                val prefix = StringBuilder()
                for (k in 0 until units.size - 1) {
                    prefix.append(units[k])
                    words.putIfAbsent(prefix.toString(), NO_TAG)
                }
            }
        }
        logTotal = ln(total.toDouble())
        @Suppress("UNCHECKED_CAST")
        val rules = MiniJson.parse(open("zh_rules.json").bufferedReader().use { it.readText() }) as Map<String, List<String>>
        mustNeural = rules["must_neural"].orEmpty().toHashSet()
        mustNotNeural = rules["must_not_neural"].orEmpty().toHashSet()
        mustErhua = rules["must_erhua"].orEmpty().toHashSet()
        notErhua = rules["not_erhua"].orEmpty().toHashSet()
        val hmmLines = ArrayList<String>(200_000)
        lines("zh_hmm.tsv") { hmmLines += it }
        hmm = Hmm(hmmLines)
    }

    private fun freq(w: String): Int? = words[w]?.let { it ushr 8 }
    private fun tag(w: String): String? = words[w]?.let { it and 255 }?.takeIf { it != 255 }?.let { tagNames[it] }

    // Whole text

    /** Phonemes for text that may mix Chinese and English. */
    fun phonemize(text: String): String {
        if (text.trim().isEmpty()) return ""
        val mapped = mapPunctuation(numbersToChinese(text))
        val segments = mutableListOf<String>()
        // English runs (letters with spaces, apostrophes and hyphens) and everything else.
        for (m in SEGMENT.findAll(mapped)) {
            val en = m.groups[1]
            if (en != null) {
                val t = trimSpaces(en.value)
                if (t.isNotEmpty()) segments += english(t)
            } else {
                val t = trimSpaces(m.groups[2]!!.value)
                if (t.isNotEmpty()) segments += frontend(t)
            }
        }
        return segments.joinToString(" ")
    }

    // Chinese

    private class Token(val word: String, val tag: String, val phonemes: String?, var whitespace: String = "")

    private fun frontend(text: String): String {
        val tokens = ArrayList<Token>()
        for ((word, rawTag) in merge(posseg(text))) {
            var tag = rawTag
            val w = units(word)
            if (tag == "x" && w.isNotEmpty() && w.all { cmp(it, "一") >= 0 && cmp(it, "鿿") <= 0 }) {
                tag = "X"
            } else if (tag != "x" && w.size == 1 && w[0] in PUNCTUATION) {
                tag = "x"
            }
            if (tag in X_ENG) {
                if (!word.all { it.isWhitespace() }) {
                    val isPunc = tag == "x" && w.size == 1 && w[0] in PUNCTUATION
                    tokens += Token(word, tag, if (isPunc) word else null)
                } else if (tokens.isNotEmpty()) {
                    tokens.last().whitespace += word
                }
                continue
            } else if (tokens.isNotEmpty() && tokens.last().tag !in X_ENG && tokens.last().whitespace.isEmpty()) {
                tokens.last().whitespace = "/"
            }
            var initials = ArrayList<String>()
            var finals = ArrayList<String>()
            val py = pinyin(w)
            for (k in 0 until min(w.size, py.size)) {
                var (i, f) = splitSyllable(py[k])
                if (w[k] == "嗯") i = ""
                if (len(f) == 2 && f.startsWith("i")) {
                    if (i in listOf("z", "c", "s")) f = "ii" + f.takeLast(1)
                    else if (i in listOf("zh", "ch", "sh", "r")) f = "iii" + f.takeLast(1)
                }
                initials += i
                finals += f
            }
            for (k in w.indices) if (w[k] == "嗯" && k < finals.size) finals[k] = "n2"
            finals = ArrayList(modifiedTone(w, tag, finals))
            // 儿化
            if (finals.isNotEmpty() && w.lastOrNull() == "儿" && finals.last() == "er1") finals[finals.size - 1] = "er2"
            if ((word in mustErhua || !(word in notErhua || tag in listOf("a", "j", "nr"))) && finals.size == w.size) {
                val ni = ArrayList<String>()
                val nf = ArrayList<String>()
                for ((k, ph) in finals.withIndex()) {
                    if (k == finals.size - 1 && w[k] == "儿" && (ph == "er2" || ph == "er5") &&
                        w.takeLast(2).joinToString("") !in notErhua && nf.isNotEmpty()
                    ) {
                        val last = nf.last()
                        nf[nf.size - 1] = last.dropLast(1) + "R" + last.takeLast(1)
                    } else {
                        ni += initials[k]
                        nf += ph
                    }
                }
                initials = ni
                finals = nf
            }
            val phones = ArrayList<String>()
            for (k in 0 until min(initials.size, finals.size)) {
                val c = initials[k]
                val v = finals[k]
                if (c.isNotEmpty()) phones += c
                if (v.isNotEmpty() && (!(len(v) == 1 && v in PUNCTUATION) || v != c)) phones += v
            }
            var joined = phones.joinToString("_").replace("_eR", "_er").replace("R", "_R")
            joined = DIGIT.replace(joined, "_$1")
            val symbols = joined.split("_").joinToString("") { ZH_MAP[it] ?: "❓" }
            tokens += Token(word, tag, symbols)
        }
        return tokens.joinToString("") { (it.phonemes ?: "❓") + it.whitespace }
    }

    // Pinyin

    /** TONE3 syllables (5 for the neutral tone): phrases that read differently first, longest first. */
    private fun pinyin(word: List<String>): List<String> {
        val out = ArrayList<String>()
        var i = 0
        while (i < word.size) {
            var matched = false
            var n = min(maxPhrase, word.size - i)
            while (n >= 2) {
                val p = phrases[join(word, i, i + n)]
                if (p != null) {
                    out += p
                    i += n
                    matched = true
                    break
                }
                n -= 1
            }
            if (!matched) {
                out += chars[word[i]] ?: word[i]
                i += 1
            }
        }
        return out
    }

    private fun finalsOf(word: List<String>): List<String> {
        val fs = pinyin(word).map { splitSyllable(it).second }.toMutableList()
        for (i in word.indices) if (word[i] == "嗯" && i < fs.size) fs[i] = "n2"
        return fs
    }

    // jieba

    private fun dag(s: List<String>): List<List<Int>> {
        val out = ArrayList<List<Int>>(s.size)
        for (k in s.indices) {
            val tmp = ArrayList<Int>()
            var i = k
            val frag = StringBuilder(s[k])
            while (i < s.size) {
                val f = freq(frag.toString()) ?: break
                if (f > 0) tmp += i
                i += 1
                if (i < s.size) frag.append(s[i]) else break
            }
            out += if (tmp.isEmpty()) listOf(k) else tmp
        }
        return out
    }

    /** jieba's most likely route through the dictionary words: for each start, (score, end). */
    private fun route(s: List<String>): Array<Pair<Double, Int>> {
        val d = dag(s)
        val r = Array(s.size + 1) { 0.0 to 0 }
        for (idx in s.size - 1 downTo 0) {
            var best: Pair<Double, Int>? = null
            for (x in d[idx]) {
                val f = freq(join(s, idx, x + 1)) ?: 0
                val candidate = (ln((if (f == 0) 1 else f).toDouble()) - logTotal + r[x + 1].first) to x
                if (best == null || candidate.first > best.first || (candidate.first == best.first && candidate.second > best.second)) {
                    best = candidate
                }
            }
            r[idx] = best!!
        }
        return r
    }

    /** jieba.posseg's cut of a run of Chinese (and similar) characters: (word, tag). */
    private fun cutDag(s: List<String>): List<Pair<String, String>> {
        val r = route(s)
        val out = ArrayList<Pair<String, String>>()
        var x = 0
        val buf = ArrayList<String>()
        fun flush() {
            if (buf.size == 1) {
                out += buf[0] to (tag(buf[0]) ?: "x")
            } else if (buf.isNotEmpty() && (freq(buf.joinToString("")) ?: 0) == 0) {
                out += hmm.cut(buf)
            } else {
                for (c in buf) out += c to (tag(c) ?: "x")
            }
            buf.clear()
        }
        while (x < s.size) {
            val y = r[x].second + 1
            if (y - x == 1) {
                buf += s[x]
            } else {
                flush()
                val w = join(s, x, y)
                out += w to (tag(w) ?: "x")
            }
            x = y
        }
        flush()
        return out
    }

    private fun posseg(text: String): List<Pair<String, String>> {
        val out = ArrayList<Pair<String, String>>()
        val block = ArrayList<String>()
        var isHan: Boolean? = null
        fun flushBlock() {
            if (block.isEmpty()) return
            if (isHan == true) {
                out += cutDag(block)
            } else {
                for (c in block) {
                    out += when {
                        c.all { it.isWhitespace() } -> c to "x"
                        c.length == 1 && (c[0] in '0'..'9' || c[0] == '.') -> c to "m"
                        else -> c to "x"
                    }
                }
            }
            block.clear()
        }
        for (c in units(text)) {
            val han = isHanInternal(c)
            if (isHan != null && han != isHan) flushBlock()
            isHan = han
            block += c
        }
        flushBlock()
        return out
    }

    private fun cutForSearch(word: List<String>): List<String> {
        val out = ArrayList<String>()
        for ((w, _) in cutDag(word)) {
            val x = units(w)
            if (x.size > 2) {
                for (i in 0 until x.size - 1) {
                    val g = join(x, i, i + 2)
                    if ((freq(g) ?: 0) > 0) out += g
                }
            }
            if (x.size > 3) {
                for (i in 0 until x.size - 2) {
                    val g = join(x, i, i + 3)
                    if ((freq(g) ?: 0) > 0) out += g
                }
            }
            out += w
        }
        return out
    }

    // Tone sandhi (misaki / PaddleSpeech)

    private class Seg(var w: String, val p: String)

    private fun merge(input: List<Pair<String, String>>): List<Pair<String, String>> {
        var seg = input.map { Seg(it.first, it.second) }
        // 不 joins the word after it.
        var new = ArrayList<Seg>()
        for ((i, s) in seg.withIndex()) {
            var w = s.w
            if (s.p !in X_ENG && i > 0 && seg[i - 1].w == "不") w = "不$w"
            val next = seg.getOrNull(i + 1)?.p
            if (w != "不" || next == null || next in X_ENG) new += Seg(w, s.p)
        }
        seg = new
        // 听一听, then 一 joins the word after it.
        new = ArrayList()
        var skip = false
        for ((i, s) in seg.withIndex()) {
            if (skip) { skip = false; continue }
            if (i > 0 && s.w == "一" && i + 1 < seg.size && seg[i - 1].w == seg[i + 1].w && seg[i - 1].p == "v" && seg[i + 1].p !in X_ENG) {
                new.last().w += "一" + seg[i + 1].w
                skip = true
            } else {
                new += Seg(s.w, s.p)
            }
        }
        seg = new
        new = ArrayList()
        for (s in seg) {
            val last = new.lastOrNull()
            if (last != null && last.w == "一" && s.p !in X_ENG) last.w += s.w else new += Seg(s.w, s.p)
        }
        seg = new
        // Reduplication: 看看.
        new = ArrayList()
        for (s in seg) {
            val last = new.lastOrNull()
            if (last != null && s.w == last.w && s.p !in X_ENG) last.w += s.w else new += Seg(s.w, s.p)
        }
        seg = new
        // Runs of third tones.
        for (first in listOf(true, false)) {
            val fl = seg.map { if (it.p in X_ENG) listOf("0") else finalsOf(units(it.w)) }
            new = ArrayList()
            val mergedLast = BooleanArray(seg.size)
            for ((i, s) in seg.withIndex()) {
                val cond = i > 0 && if (first) allThree(fl[i - 1]) && allThree(fl[i])
                else fl[i - 1].lastOrNull()?.lastOrNull() == '3' && fl[i].firstOrNull()?.lastOrNull() == '3'
                if (s.p !in X_ENG && cond && !mergedLast[i - 1]) {
                    if (!isReduplication(seg[i - 1].w) && len(seg[i - 1].w) + len(s.w) <= 3) {
                        new.last().w += s.w
                        mergedLast[i] = true
                    } else {
                        new += Seg(s.w, s.p)
                    }
                } else {
                    new += Seg(s.w, s.p)
                }
            }
            seg = new
        }
        // 儿 joins the word before it.
        new = ArrayList()
        for ((i, s) in seg.withIndex()) {
            val last = new.lastOrNull()
            if (i > 0 && s.w == "儿" && last != null && last.p !in X_ENG) last.w += s.w else new += Seg(s.w, s.p)
        }
        return new.map { it.w to it.p }
    }

    private fun splitWord(word: List<String>): List<List<String>> {
        val list = cutForSearch(word).withIndex().sortedWith(compareBy({ len(it.value) }, { it.index })).map { it.value }
        val first = units(list[0])
        val w = word.joinToString("")
        if (w.startsWith(list[0])) return listOf(first, word.drop(first.size))
        return listOf(word.dropLast(first.size), first)
    }

    private fun modifiedTone(w: List<String>, pos: String, input: List<String>): List<String> {
        var fs = input.toMutableList()
        val word = w.joinToString("")
        if (fs.size != w.size) return fs
        // 不
        if (w.size == 3 && w[1] == "不") {
            fs[1] = setTone(fs[1], '5')
        } else {
            for (i in w.indices) if (w[i] == "不" && i + 1 < w.size && fs[i + 1].lastOrNull() == '4') fs[i] = setTone(fs[i], '2')
        }
        // 一
        if (w.contains("一") && w.filter { it != "一" }.all { isNumeric(it) }) {
            // a number: unchanged
        } else if (w.size == 3 && w[1] == "一" && w[0] == w[2]) {
            fs[1] = setTone(fs[1], '5')
        } else if (word.startsWith("第一")) {
            fs[1] = setTone(fs[1], '1')
        } else {
            for (i in w.indices) {
                if (w[i] != "一" || i + 1 >= w.size) continue
                if (fs[i + 1].last() in "45") fs[i] = setTone(fs[i], '2')
                else if (w[i + 1] !in PUNCTUATION) fs[i] = setTone(fs[i], '4')
            }
        }
        // Neutral tones.
        if (word !in mustNotNeural) {
            val p0 = pos.firstOrNull()
            if (p0 != null && p0 in "nva") {
                for (j in 1 until max(1, w.size)) if (w[j] == w[j - 1]) fs[j] = setTone(fs[j], '5')
            }
            val ge = w.indexOf("个")
            val last = w[w.size - 1]
            val lastTwo = w.takeLast(2).joinToString("")
            val end = fs.size - 1
            if ("吧呢啊呐噻嘛吖嗨呐哦哒滴哩哟喽啰耶喔诶".contains(last) || "的地得".contains(last)) {
                fs[end] = setTone(fs[end], '5')
            } else if (w.size == 1 && "了着过".contains(last) && pos in listOf("ul", "uz", "ug")) {
                fs[end] = setTone(fs[end], '5')
            } else if (w.size > 1 && "们子".contains(last) && pos in listOf("r", "n")) {
                fs[end] = setTone(fs[end], '5')
            } else if (w.size > 1 && "上下".contains(last) && pos in listOf("s", "l", "f")) {
                fs[end] = setTone(fs[end], '5')
            } else if (w.size > 1 && "来去".contains(last) && "上下进出回过起开".contains(w[w.size - 2])) {
                fs[end] = setTone(fs[end], '5')
            } else if ((ge >= 1 && (isNumeric(w[ge - 1]) || "几有两半多各整每做是".contains(w[ge - 1]))) || word == "个") {
                val at = max(0, ge)
                fs[at] = setTone(fs[at], '5')
            } else if (word in mustNeural || lastTwo in mustNeural) {
                fs[end] = setTone(fs[end], '5')
            }
            val parts = splitWord(w)
            val lists = mutableListOf(fs.take(parts[0].size).toMutableList(), fs.drop(parts[0].size).toMutableList())
            for ((i, p) in parts.withIndex()) {
                if (lists[i].isEmpty()) continue
                if (p.joinToString("") in mustNeural || p.takeLast(2).joinToString("") in mustNeural) {
                    val l = lists[i]
                    l[l.size - 1] = setTone(l[l.size - 1], '5')
                }
            }
            fs = (lists[0] + lists[1]).toMutableList()
        }
        // Third tones.
        if (w.size == 2 && allThree(fs)) {
            fs[0] = setTone(fs[0], '2')
        } else if (w.size == 3) {
            val parts = splitWord(w)
            if (allThree(fs)) {
                if (parts[0].size == 2) {
                    fs[0] = setTone(fs[0], '2')
                    fs[1] = setTone(fs[1], '2')
                } else if (parts[0].size == 1) {
                    fs[1] = setTone(fs[1], '2')
                }
            } else {
                val lists = mutableListOf(fs.take(parts[0].size).toMutableList(), fs.drop(parts[0].size).toMutableList())
                for (i in 0 until 2) {
                    val sub = lists[i].toList()
                    if (allThree(sub) && sub.size == 2) {
                        lists[i][0] = setTone(lists[i][0], '2')
                    } else if (i == 1 && !allThree(sub) && sub.firstOrNull()?.lastOrNull() == '3' && lists[0].lastOrNull()?.lastOrNull() == '3') {
                        lists[0][lists[0].size - 1] = setTone(lists[0][lists[0].size - 1], '2')
                    }
                    fs = (lists[0] + lists[1]).toMutableList()
                }
            }
        } else if (w.size == 4) {
            val out = ArrayList<String>()
            for (part in listOf(fs.take(2).toMutableList(), fs.drop(2).toMutableList())) {
                if (allThree(part)) part[0] = setTone(part[0], '2')
                out += part
            }
            fs = out
        }
        return fs
    }

    // jieba's part-of-speech HMM

    /** Splits runs of characters jieba doesn't know into words, and tags them. */
    private class Hmm(lines: List<String>) {
        private val bmes = ArrayList<Char>()
        private val tags = ArrayList<String>()
        private val start = ArrayList<Double>()
        private val trans = ArrayList<HashMap<Int, Double>>()
        private val emit = ArrayList<HashMap<String, Double>>()
        private val charStates = HashMap<String, List<Int>>()

        init {
            for (line in lines) {
                val f = line.split('\t')
                when (f.first()) {
                    "S" -> {
                        bmes += f[2][0]
                        tags += f[3]
                        start += f[4].toDoubleOrNull() ?: MIN_FLOAT
                        trans += HashMap()
                        emit += HashMap()
                    }
                    "T" -> trans[f[1].toInt()][f[2].toInt()] = f[3].toDouble()
                    "E" -> {
                        val e = emit[f[1].toInt()]
                        for (k in 2 until f.size) {
                            val x = f[k]
                            if (x.isEmpty()) continue
                            val n = Character.charCount(x.codePointAt(0))
                            e[x.substring(0, n)] = x.substring(n).toDouble()
                        }
                    }
                    "C" -> charStates[firstUnit(f[1])] = f[2].split(',').map { it.toInt() }
                }
            }
        }

        private val all = (0 until bmes.size).toList()

        /** Whether a is less than b: by score, then by state (B < E < M < S, then tag). */
        private fun less(a: Pair<Double, Int>, b: Pair<Double, Int>): Boolean {
            if (a.first != b.first) return a.first < b.first
            val sa = a.second
            val sb = b.second
            return if (bmes[sa] != bmes[sb]) bmes[sa] < bmes[sb] else tags[sa] < tags[sb]
        }

        fun viterbi(obs: List<String>): IntArray {
            val v = ArrayList<HashMap<Int, Double>>()
            val mem = ArrayList<HashMap<Int, Int>>()
            v += HashMap()
            mem += HashMap()
            for (y in charStates[obs[0]] ?: all) {
                v[0][y] = start[y] + (emit[y][obs[0]] ?: MIN_FLOAT)
                mem[0][y] = -1
            }
            for (t in 1 until obs.size) {
                v += HashMap()
                mem += HashMap()
                val prev = mem[t - 1].keys.filter { trans[it].isNotEmpty() }
                val expect = HashSet<Int>()
                for (x in prev) expect += trans[x].keys
                var obsStates: Set<Int> = (charStates[obs[t]] ?: all).toHashSet().apply { retainAll(expect) }
                if (obsStates.isEmpty()) obsStates = if (expect.isEmpty()) all.toHashSet() else expect
                for (y in obsStates) {
                    var best: Pair<Double, Int>? = null
                    for (y0 in prev) {
                        val p = v[t - 1][y0]!! + (trans[y0][y] ?: Double.NEGATIVE_INFINITY) + (emit[y][obs[t]] ?: MIN_FLOAT)
                        val candidate = p to y0
                        if (best == null || less(best, candidate)) best = candidate
                    }
                    if (best != null) {
                        v[t][y] = best.first
                        mem[t][y] = best.second
                    }
                }
            }
            var last: Pair<Double, Int>? = null
            for (y in mem[obs.size - 1].keys) {
                val c = v[obs.size - 1][y]!! to y
                if (last == null || less(last, c)) last = c
            }
            val route = IntArray(obs.size)
            var state = last?.second ?: return route
            for (i in obs.size - 1 downTo 0) {
                route[i] = state
                state = mem[i][state] ?: -1
                if (state < 0 && i > 0) state = 0
            }
            return route
        }

        fun cut(s: List<String>): List<Pair<String, String>> {
            val out = ArrayList<Pair<String, String>>()
            // Chinese runs go through the HMM; anything else is numbers, letters or marks.
            fun han(c: String) = c.codePointAt(0) in 0x4E00..0x9FD5
            var i = 0
            while (i < s.size) {
                var j = i
                if (han(s[i])) {
                    while (j < s.size && han(s[j])) j += 1
                    val blk = s.subList(i, j)
                    val pl = viterbi(blk)
                    var begin = 0
                    var next = 0
                    for ((k, c) in blk.withIndex()) {
                        val st = pl[k]
                        when (bmes[st]) {
                            'B' -> begin = k
                            'E' -> { out += join(blk, begin, k + 1) to tags[st]; next = k + 1 }
                            'S' -> { out += c to tags[st]; next = k + 1 }
                        }
                    }
                    if (next < blk.size) out += join(blk, next, blk.size) to tags[pl[next]]
                } else {
                    while (j < s.size && !han(s[j])) j += 1
                    for (c in s.subList(i, j)) {
                        val ch = if (c.length == 1) c[0] else ' '
                        val tag = when {
                            c.length == 1 && (ch in '0'..'9' || ch == '.') -> "m"
                            c.length == 1 && (ch in 'a'..'z' || ch in 'A'..'Z') -> "eng"
                            else -> "x"
                        }
                        out += c to tag
                    }
                }
                i = j
            }
            return out
        }
    }

    companion object {
        private const val NO_TAG = 255
        private const val MIN_FLOAT = -3.14e100
        private val SEGMENT = Regex("([A-Za-z '-]*[A-Za-z][A-Za-z '-]*)|([^A-Za-z]+)")
        private val DIGIT = Regex("([0-9])")
        private val PUNCTUATION: Set<String> = ";:,.!?—…\"()“”".map { it.toString() }.toSet()
        private val X_ENG = setOf("x", "eng")
        private val INITIALS = listOf("zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "r", "z", "c", "s")
        private val DIGITS = listOf("零", "一", "二", "三", "四", "五", "六", "七", "八", "九")

        private val ZH_MAP: Map<String, String> = HashMap<String, String>().apply {
            putAll(
                mapOf(
                    "b" to "ㄅ", "p" to "ㄆ", "m" to "ㄇ", "f" to "ㄈ", "d" to "ㄉ", "t" to "ㄊ", "n" to "ㄋ", "l" to "ㄌ", "g" to "ㄍ",
                    "k" to "ㄎ", "h" to "ㄏ", "j" to "ㄐ", "q" to "ㄑ", "x" to "ㄒ", "zh" to "ㄓ", "ch" to "ㄔ", "sh" to "ㄕ", "r" to "ㄖ",
                    "z" to "ㄗ", "c" to "ㄘ", "s" to "ㄙ", "a" to "ㄚ", "o" to "ㄛ", "e" to "ㄜ", "ie" to "ㄝ", "ai" to "ㄞ", "ei" to "ㄟ",
                    "ao" to "ㄠ", "ou" to "ㄡ", "an" to "ㄢ", "en" to "ㄣ", "ang" to "ㄤ", "eng" to "ㄥ", "er" to "ㄦ", "i" to "ㄧ",
                    "u" to "ㄨ", "v" to "ㄩ", "ii" to "ㄭ", "iii" to "十", "ve" to "月", "ia" to "压", "ian" to "言", "iang" to "阳",
                    "iao" to "要", "in" to "阴", "ing" to "应", "iong" to "用", "iou" to "又", "ong" to "中", "ua" to "穵", "uai" to "外",
                    "uan" to "万", "uang" to "王", "uei" to "为", "uen" to "文", "ueng" to "瓮", "uo" to "我", "van" to "元", "vn" to "云",
                ),
            )
            for (p in ";:,.!?/—…\"()“” 12345R") put(p.toString(), p.toString())
        }

        /** The text's code points, each as a string. */
        internal fun units(s: String): List<String> {
            val out = ArrayList<String>(s.length)
            var i = 0
            while (i < s.length) {
                val n = Character.charCount(s.codePointAt(i))
                out += s.substring(i, i + n)
                i += n
            }
            return out
        }

        private fun firstUnit(s: String) = s.substring(0, Character.charCount(s.codePointAt(0)))
        private fun len(s: String) = s.codePointCount(0, s.length)
        private fun join(u: List<String>, from: Int, to: Int): String {
            val b = StringBuilder()
            for (k in from until to) b.append(u[k])
            return b.toString()
        }

        /** Compares by code points, as Swift compares single-scalar characters. */
        private fun cmp(a: String, b: String): Int {
            var i = 0
            var j = 0
            while (i < a.length && j < b.length) {
                val x = a.codePointAt(i)
                val y = b.codePointAt(j)
                if (x != y) return x.compareTo(y)
                i += Character.charCount(x)
                j += Character.charCount(y)
            }
            return (a.length - i).compareTo(b.length - j)
        }

        /** Swift's `String.split(separator: "\t")`: empty fields are dropped. */
        private fun fields(line: String) = line.split('\t').filter { it.isNotEmpty() }

        private fun trimSpaces(s: String) =
            s.trim { it == ' ' || it == '\t' || Character.getType(it) == Character.SPACE_SEPARATOR.toInt() }

        private fun isHanInternal(c: String): Boolean {
            if (c.isEmpty() || Character.charCount(c.codePointAt(0)) != c.length) return false
            val u = c.codePointAt(0)
            if (u in 0x4E00..0x9FD5) return true
            val ch = c[0]
            return u < 128 && (ch.isLetterOrDigit() || ch in "+#&._")
        }

        private fun allThree(fs: List<String>) = fs.all { it.lastOrNull() == '3' }
        private fun isReduplication(w: String): Boolean = units(w).let { it.size == 2 && it[0] == it[1] }
        private fun setTone(f: String, t: Char): String = f.dropLast(1) + t
        private fun isNumeric(c: String): Boolean {
            var i = 0
            while (i < c.length) {
                val cp = c.codePointAt(i)
                if (!KokoroPhonemizer.isNumber(cp)) return false
                i += Character.charCount(cp)
            }
            return true
        }

        fun mapPunctuation(text: String): String {
            var t = text
            for ((a, b) in listOf(
                "、" to ", ", "，" to ", ", "。" to ". ", "．" to ". ", "！" to "! ", "：" to ": ", "；" to "; ", "？" to "? ",
                "«" to " “", "»" to "” ", "《" to " “", "》" to "” ", "「" to " “", "」" to "” ", "【" to " “", "】" to "” ",
                "（" to " (", "）" to ") ",
            )) {
                t = t.replace(a, b)
            }
            return t.trim()
        }

        /** Swift's `Int(string)`: ASCII digits only. */
        private fun swiftInt(s: String): Long? = if (s.isNotEmpty() && s.all { it in '0'..'9' }) s.toLongOrNull() else null

        private val PERCENT = Regex("(\\p{Nd}+)%")
        private val NUMBER = Regex("\\p{Nd}+(?:\\.\\p{Nd}+)?")

        /** Arabic numbers in Chinese words, as cn2an does: 175 → 一百七十五, 3.5 → 三点五, 50% → 百分之五十. */
        fun numbersToChinese(text: String): String {
            var t = PERCENT.replace(text) { m -> "百分之" + chineseNumber(swiftInt(m.groupValues[1]) ?: 0) }
            t = NUMBER.replace(t) { m ->
                val parts = m.value.split('.').filter { it.isNotEmpty() }
                var words = chineseNumber(swiftInt(parts[0]) ?: 0)
                if (parts.size > 1) words += "点" + parts[1].map { DIGITS[swiftInt(it.toString())?.toInt() ?: 0] }.joinToString("")
                words
            }
            return t
        }

        fun chineseNumber(n: Long): String {
            if (n == 0L) return "零"
            if (n < 0) return "负" + chineseNumber(-n)
            for ((unit, name) in listOf(100_000_000L to "亿", 10_000L to "万")) {
                if (n >= unit) {
                    val hi = n / unit
                    val lo = n % unit
                    return chineseNumber(hi) + name + if (lo == 0L) "" else (if (lo < unit / 10) "零" else "") + chineseNumber(lo)
                }
            }
            val out = StringBuilder()
            var zero = false
            for ((unit, name) in listOf(1000L to "千", 100L to "百", 10L to "十", 1L to "")) {
                val d = (n / unit % 10).toInt()
                if (d == 0) {
                    zero = out.isNotEmpty()
                } else {
                    if (zero) out.append("零")
                    out.append(DIGITS[d]).append(name)
                    zero = false
                }
            }
            return out.toString()
        }

        /** pypinyin's strict initial and final (with tone) for one TONE3 syllable. */
        fun splitSyllable(py: String): Pair<String, String> {
            if (py.isEmpty()) return "" to py
            val toneCp = py.codePointBefore(py.length)
            if (!KokoroPhonemizer.isNumber(toneCp)) return "" to py
            val tone = String(Character.toChars(toneCp))
            val s = py.substring(0, py.length - tone.length)
            val initial = INITIALS.firstOrNull { s.startsWith(it) } ?: ""
            var rest = s.substring(initial.length)
            if (initial.isEmpty()) {
                if (s.startsWith("y")) {
                    rest = s.substring(1)
                    if (rest.startsWith("u")) rest = "v" + rest.substring(1)
                    else if (!rest.startsWith("i")) rest = "i$rest"
                    if (rest == "iu" || rest == "iou") rest = "iou"
                } else if (s.startsWith("w")) {
                    rest = s.substring(1)
                    if (!rest.startsWith("u")) rest = "u$rest"
                    rest = mapOf("ui" to "uei", "un" to "uen", "uei" to "uei")[rest] ?: rest
                } else {
                    rest = s
                }
            } else {
                if (initial in listOf("j", "q", "x") && rest.startsWith("u")) rest = "v" + rest.substring(1)
                rest = rest.replace("ü", "v")
                rest = mapOf("iu" to "iou", "ui" to "uei", "un" to "uen")[rest] ?: rest
            }
            if (rest == "ue") rest = "ve"
            return initial to rest + tone
        }
    }
}
