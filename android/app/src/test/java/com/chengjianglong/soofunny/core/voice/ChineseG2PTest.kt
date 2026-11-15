package com.chengjianglong.soofunny.core.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Ported from the iOS app's `ChineseG2PTests` / `ChineseVoiceTests`. */
class ChineseG2PTest {
    companion object {
        val resources = File("../../SooFunny/Voice/Resources")
        val g2p: ChineseG2P by lazy { ChineseG2P({ File(resources, it).inputStream() }) { "<$it>" } }
    }

    /**
     * misaki's own output for every Chinese string in the app (plus some buddy-style sentences),
     * made with misaki 0.9.4. The port should say every one of them the same way.
     */
    @Test
    fun matchesMisakiOnAllAppText() {
        @Suppress("UNCHECKED_CAST")
        val expected = MiniJson.parse(File("../../SooFunnyTests/zh_g2p_expected.json").readText()) as Map<String, String>
        val wrong = mutableListOf<String>()
        for ((text, phonemes) in expected.toSortedMap()) {
            val got = g2p.phonemize(text)
            if (got != phonemes) wrong += "$text\n  misaki $phonemes\n  kotlin $got"
        }
        println("ChineseG2P: ${expected.size - wrong.size}/${expected.size} match")
        wrong.take(20).forEach(::println)
        assertTrue("${wrong.size} differ", wrong.isEmpty())
    }

    @Test
    fun numbersAndPunctuation() {
        assertEquals("一百七十五个", ChineseG2P.numbersToChinese("175个"))
        assertEquals("三点五", ChineseG2P.numbersToChinese("3.5"))
        assertEquals("百分之五十", ChineseG2P.numbersToChinese("50%"))
        assertEquals("一百零五", ChineseG2P.numbersToChinese("105"))
        assertEquals("你好, 世界.", ChineseG2P.mapPunctuation("你好，世界。"))
    }

    @Test
    fun syllables() {
        assertEquals("v2", ChineseG2P.splitSyllable("yu2").second)
        assertEquals("iou3", ChineseG2P.splitSyllable("you3").second)
        assertEquals("uei4", ChineseG2P.splitSyllable("wei4").second)
        assertEquals("v4", ChineseG2P.splitSyllable("ju4").second)
        assertEquals("uei4", ChineseG2P.splitSyllable("gui4").second)
        assertEquals("zh", ChineseG2P.splitSyllable("zhang1").first)
    }

    @Test
    fun speedForABuddySentence() {
        val start = System.nanoTime()
        repeat(10) { g2p.phonemize("狗狗摇尾巴是因为它们高兴或兴奋，我们一起去公园玩吧！") }
        println("ChineseG2P: ${(System.nanoTime() - start) / 10 / 1_000_000.0} ms per buddy sentence")
    }

    @Test
    fun chinesePhrasesSplitLongSentencesAtCommas() {
        val sentence = "小朋友们在公园里跑来跑去，玩得很开心，最后大家一起回家吃晚饭。"
        val phrases = Kokoro.phrases(sentence)
        assertTrue(phrases.size > 1)
        assertEquals(sentence, phrases.joinToString("") { it.text })
        assertEquals(listOf("狗"), Kokoro.phrases("狗").map { it.text })
    }
}
