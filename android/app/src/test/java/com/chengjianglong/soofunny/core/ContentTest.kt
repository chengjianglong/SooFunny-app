package com.chengjianglong.soofunny.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Checks the Android app reads the iOS app's shared content the same way. */
class ContentTest {
    private val ios = File("../../SooFunny")

    @Test
    fun parsesTheSharedWordList() {
        val categories = WordDictionary.parse(File(ios, "Words/kids_words.txt").readText())
        assertEquals(32, categories.size)
        assertEquals(754, categories.sumOf { it.words.size })
        val animals = categories.first()
        assertEquals("Animals", animals.name)
        assertEquals("动物", animals.chinese)
        assertEquals(WordEntry("dog", "🐶", "狗"), animals.words.first())
        assertTrue(categories.all { c -> c.words.all { it.chinese != null } })
    }

    @Test
    fun parsesEmptyEmoji() {
        val c = WordDictionary.parse("Category: Farm | 🚜 | 农场\nhay |  | 干草\n")
        assertNull(c[0].words[0].emoji)
        assertEquals("干草", c[0].words[0].chinese)
    }

    @Test
    fun photoNamesMatchIos() {
        assertEquals("words/photos/word-sports-ping-pong.jpg", WordPhotos.path("Sports", "ping pong"))
        assertEquals("words/photos/word-animals-dog-2.jpg", WordPhotos.path("Animals", "dog", 2))
        val photos = File(ios, "Words/Photos").list()!!.toSet()
        val categories = WordDictionary.parse(File(ios, "Words/kids_words.txt").readText())
        val found = categories.sumOf { c -> c.words.count { WordPhotos.path(c.name, it.text).removePrefix("words/photos/") in photos } }
        assertEquals(516, found)
    }

    @Test
    fun splitsMixedTextIntoLanguageRuns() {
        val runs = BookLanguage.runs("dog, 狗")
        assertEquals(listOf(BookLanguage.ENGLISH, BookLanguage.CHINESE), runs.map { it.language })
        assertEquals("狗", runs[1].text)
        assertEquals(5, runs[1].offset)
        val sentence = BookLanguage.runs("3 plus 4 equals? 三加四等于几？")
        assertEquals("三加四等于几？", sentence.last().text)
    }

    @Test
    fun bilingualSpokenText() {
        assertEquals("dog, 狗", LearningLanguage.BOTH.spoken("dog", "狗"))
        assertEquals("Next · 下一个", LearningLanguage.BOTH.pick("Next", "下一个"))
        assertEquals("狗", LearningLanguage.CHINESE.spoken("dog", "狗"))
    }
}
