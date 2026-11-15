package com.chengjianglong.soofunny.core

import android.content.Context
import org.json.JSONArray

data class WordEntry(val text: String, val emoji: String?, val chinese: String?)

data class WordCategory(val name: String, val emoji: String?, val chinese: String?, val words: List<WordEntry>) {
    fun title(language: LearningLanguage): String = chinese?.let { language.pick(name, it) } ?: name
}

/**
 * The kids' word list, `kids_words.txt`, shared with the iOS app. Format: blank-line-separated
 * sections, each starting with `Category: <name>`, one word per line; either may end with
 * `| <emoji>` and then `| <Chinese>` (`hay |  | 干草` when there's no emoji).
 */
object WordDictionary {
    const val ASSET = "words/kids_words.txt"

    fun parse(text: String): List<WordCategory> {
        val categories = mutableListOf<WordCategory>()
        var current: Triple<String, String?, String?>? = null
        val words = mutableListOf<WordEntry>()

        fun finish() {
            current?.let {
                require(words.isNotEmpty()) { "Empty category ${it.first}" }
                categories += WordCategory(it.first, it.second, it.third, words.toList())
            }
            current = null
            words.clear()
        }

        text.removePrefix("﻿").lines().forEachIndexed { index, raw ->
            val line = raw.trim()
            when {
                line.isEmpty() -> finish()
                line.startsWith("Category:") -> {
                    finish()
                    val parts = split(line.removePrefix("Category:"))
                    require(parts.first.isNotEmpty()) { "Empty category name on line ${index + 1}" }
                    current = parts
                }
                else -> {
                    require(current != null) { "Word before category on line ${index + 1}" }
                    val (word, emoji, chinese) = split(line)
                    words += WordEntry(word, emoji, chinese)
                }
            }
        }
        finish()
        require(categories.isNotEmpty()) { "No categories" }
        return categories
    }

    /** "cat | 🐱 | 猫" → ("cat", "🐱", "猫"); "hay |  | 干草" → ("hay", null, "干草"). */
    private fun split(text: String): Triple<String, String?, String?> {
        val parts = text.split("|", limit = 3).map { it.trim() }
        fun part(i: Int) = parts.getOrNull(i)?.takeIf { it.isNotEmpty() }
        return Triple(parts.firstOrNull() ?: "", part(1), part(2))
    }

    @Volatile private var cached: List<WordCategory>? = null

    fun load(context: Context): List<WordCategory> =
        cached ?: context.assets.open(ASSET).bufferedReader().use { parse(it.readText()) }.also { cached = it }
}

/** Real photos for the words, `words/photos/word-<group>-<word>[-2|-3].jpg`, as on iOS. */
object WordPhotos {
    fun slug(text: String): String =
        text.lowercase().map { if (it.isLetterOrDigit()) it else '-' }.joinToString("")
            .split('-').filter { it.isNotEmpty() }.joinToString("-")

    fun path(category: String, word: String, n: Int = 1): String =
        "words/photos/word-${slug(category)}-${slug(word)}${if (n > 1) "-$n" else ""}.jpg"
}

enum class SportSeason(val english: String, val chinese: String, val emoji: String) {
    SUMMER("Summer", "夏季", "☀️"), WINTER("Winter", "冬季", "❄️")
}

data class Sport(
    val id: String, val season: SportSeason, val emoji: String, val english: String, val chinese: String,
    val aboutEnglish: String, val aboutChinese: String, val photoWord: String?,
) {
    val photoPath: String? get() = photoWord?.let { WordPhotos.path("Sports", it) }
}

/** The 51 sports, exported from `SooFunny/Sports/OlympicSports.swift` by `tools/export_ios_data.py`. */
object Sports {
    @Volatile private var cached: List<Sport>? = null

    fun all(context: Context): List<Sport> = cached ?: run {
        val array = JSONArray(context.assets.open("data/sports.json").bufferedReader().use { it.readText() })
        (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            Sport(
                o.getString("id"), if (o.getString("season") == "winter") SportSeason.WINTER else SportSeason.SUMMER,
                o.getString("emoji"), o.getString("english"), o.getString("chinese"),
                o.getString("aboutEnglish"), o.getString("aboutChinese"),
                o.optJSONObject("photo")?.getString("word"),
            )
        }.also { cached = it }
    }
}

data class StoryPage(val scene: String, val text: String)

/**
 * A built-in picture book in its own language, with its translation page by page, from
 * `SooFunny/Books/StoryBooks.swift` and `StoryTranslations.swift`.
 */
data class StoryBook(
    val id: String, val title: String, val cover: String, val color: String,
    val language: BookLanguage, val pages: List<StoryPage>,
    val translatedTitle: String, val translatedPages: List<String>,
) {
    private fun english(i: Int) = if (language == BookLanguage.ENGLISH) pages[i].text else translatedPages[i]
    private fun chinese(i: Int) = if (language == BookLanguage.CHINESE) pages[i].text else translatedPages[i]
    val englishTitle get() = if (language == BookLanguage.ENGLISH) title else translatedTitle
    val chineseTitle get() = if (language == BookLanguage.CHINESE) title else translatedTitle

    fun title(lang: LearningLanguage) = when (lang) {
        LearningLanguage.ENGLISH -> englishTitle
        LearningLanguage.CHINESE -> chineseTitle
        LearningLanguage.BOTH -> "$englishTitle\n$chineseTitle"
    }

    /** The page's text in the chosen language: in Bilingual, the English and then the Chinese. */
    fun pageText(i: Int, lang: LearningLanguage) = lang.pick(english(i), chinese(i), "\n\n")
}

object StoryLibrary {
    /** The Chinese retelling of a story that's also in the library in English: only one is on the shelf. */
    private val retellings = mapOf("tortoise-and-hare-zh" to "tortoise-and-hare")

    /** The books on the shelf for this language: the Chinese retelling in 中文, the English one otherwise. */
    fun shelf(context: Context, lang: LearningLanguage): List<StoryBook> = books(context).filter { book ->
        when {
            book.id in retellings -> lang == LearningLanguage.CHINESE
            book.id in retellings.values -> lang != LearningLanguage.CHINESE
            else -> true
        }
    }

    @Volatile private var cached: List<StoryBook>? = null

    fun books(context: Context): List<StoryBook> = cached ?: run {
        val array = JSONArray(context.assets.open("data/books.json").bufferedReader().use { it.readText() })
        (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            val pages = o.getJSONArray("pages").let { p -> (0 until p.length()).map { p.getJSONObject(it) } }
                .map { StoryPage(it.getString("scene"), it.getString("text")) }
            val t = o.getJSONObject("translation")
            val tPages = t.getJSONArray("pages").let { p -> (0 until p.length()).map { p.getString(it) } }
            StoryBook(
                o.getString("id"), o.getString("title"), o.getString("cover"), o.getString("color"),
                if (o.getString("language") == "chinese") BookLanguage.CHINESE else BookLanguage.ENGLISH,
                pages, t.getString("title"), tPages,
            )
        }.also { cached = it }
    }
}
