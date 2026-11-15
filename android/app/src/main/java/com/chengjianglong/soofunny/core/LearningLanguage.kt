package com.chengjianglong.soofunny.core

/**
 * The language the app is shown and read aloud in: one setting for the whole app, so switching
 * it on one tab switches it everywhere. Mirrors `LearningLanguage` in the iOS app.
 */
enum class LearningLanguage(val key: String, val label: String, val shortLabel: String) {
    ENGLISH("english", "English", "EN"),
    CHINESE("chinese", "中文", "中文"),
    BOTH("both", "Bilingual 双语", "EN+中");

    /** Text on screen: "Next", "下一个" or "Next · 下一个". Pass "\n" for a sentence. */
    fun pick(english: String, chinese: String, separator: String = " · "): String = when (this) {
        ENGLISH -> english
        CHINESE -> chinese
        BOTH -> english + separator + chinese
    }

    /** What to say aloud: in Bilingual, English and then Chinese. Text with no Chinese is always English. */
    fun spoken(english: String, chinese: String?): String {
        if (chinese.isNullOrEmpty()) return english
        return when (this) {
            ENGLISH -> english
            CHINESE -> chinese
            BOTH -> {
                // "dog, 狗", but "3 plus 4 equals? 三加四等于几？"
                val joiner = if (english.lastOrNull()?.let { it in ".!?" } == true) " " else ", "
                english + joiner + chinese
            }
        }
    }

    val showsEnglish: Boolean get() = this != CHINESE
    val showsChinese: Boolean get() = this != ENGLISH

    companion object {
        fun fromKey(key: String?): LearningLanguage = entries.firstOrNull { it.key == key } ?: ENGLISH
    }
}

/** The script a run of text is in, to pick its voice. */
enum class BookLanguage { ENGLISH, CHINESE;

    companion object {
        fun isHan(c: Int): Boolean = Character.UnicodeScript.of(c) == Character.UnicodeScript.HAN

        /** Mostly Chinese characters means a Chinese page. */
        fun detect(text: String): BookLanguage {
            val letters = text.codePoints().filter { Character.isLetter(it) }.toArray()
            if (letters.isEmpty()) return ENGLISH
            val han = letters.count { isHan(it) }
            return if (han.toDouble() / letters.size > 0.3) CHINESE else ENGLISH
        }

        /**
         * Splits text into runs by script: Han characters (and the punctuation around them) are
         * Chinese, everything else English. Each run keeps its start offset in [text].
         */
        fun runs(text: String): List<Run> {
            val out = mutableListOf<Run>()
            var start = 0
            var current: BookLanguage? = null
            var i = 0
            while (i < text.length) {
                val cp = text.codePointAt(i)
                val lang = when {
                    isHan(cp) || isChinesePunctuation(cp) -> CHINESE
                    Character.isLetterOrDigit(cp) -> ENGLISH
                    else -> null // spaces and ASCII punctuation join the run they're in
                }
                if (lang != null && current != null && lang != current) {
                    out += Run(text.substring(start, i), current, start)
                    start = i
                }
                if (lang != null) current = lang
                i += Character.charCount(cp)
            }
            if (start < text.length) out += Run(text.substring(start), current ?: ENGLISH, start)
            return out.filter { it.text.isNotBlank() }
        }

        /**
         * Leaves out pinyin, as printed under the characters in bilingual books: words with tone
         * marks and the toneless little words (de, le, ma) between them. Only text with a tone mark
         * French doesn't use (ā, ǎ) counts as pinyin, so "café" is still read. As on iOS.
         */
        fun withoutPinyin(text: String): String {
            val toneMarks = "āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ".toSet()
            val pinyinOnly = "āǎēěīǐōǒūǔǖǘǚǜ".toSet()
            if (text.lowercase().none { it in pinyinOnly }) return text
            val words = text.split(Regex("\\s+")).filter { it.isNotEmpty() }
            val toned = words.map { w -> w.lowercase().any { it in toneMarks } }
            return words.indices.filter { i ->
                if (toned[i]) return@filter false
                val particle = words[i].length <= 4 && words[i].all { it.isLowerCase() }
                val near = (i > 0 && toned[i - 1]) || (i + 1 < words.size && toned[i + 1])
                !(particle && near)
            }.joinToString(" ") { words[it] }
        }

        private fun isChinesePunctuation(cp: Int): Boolean =
            cp in 0x3000..0x303F || cp in 0xFF00..0xFFEF
    }

    data class Run(val text: String, val language: BookLanguage, val offset: Int)
}
