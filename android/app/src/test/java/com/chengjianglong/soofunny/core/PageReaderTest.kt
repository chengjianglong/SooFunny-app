package com.chengjianglong.soofunny.core

import com.chengjianglong.soofunny.core.PageReader.OcrLine
import org.junit.Assert.assertEquals
import org.junit.Test

/** The reading-text clean-up for scanned pages, matching the iOS rules. */
class PageReaderTest {
    private fun line(text: String, top: Int, left: Int = 0, height: Int = 40, confidence: Float = 0.9f) =
        OcrLine(text, confidence, left, top, left + 400, top + height)

    @Test
    fun joinsLinesIntoSentencesAndDropsPageNumbers() {
        val text = PageReader.reflow(listOf(
            line("A little cloud floated", 100),
            line("over the hill.", 150),
            line("7", 900),
        ))
        assertEquals("A little cloud floated over the hill.", text)
    }

    @Test
    fun bigGapStartsParagraphAndHyphensRejoin() {
        val text = PageReader.reflow(listOf(
            line("The Little Cloud", 0, height = 60),
            line("It was won-", 200),
            line("derful.", 250),
        ))
        assertEquals("The Little Cloud\n\nIt was wonderful.", text)
    }

    @Test
    fun chineseLinesJoinWithoutSpaceAndScrapsAreDropped() {
        val text = PageReader.reflow(listOf(
            line("小云朵飘过小山。它想让花儿开", 100),
            line("心，就下了一场小雨。", 150),
            line("~~", 175, left = 500, confidence = 0.1f),
        ))
        assertEquals("小云朵飘过小山。它想让花儿开心，就下了一场小雨。", text)
    }

    @Test
    fun pinyinIsNotRead() {
        assertEquals("", BookLanguage.withoutPinyin("xiǎo yún duǒ").trim())
        assertEquals("café au lait", BookLanguage.withoutPinyin("café au lait"))
        assertEquals("Hello friends", BookLanguage.withoutPinyin("Hello friends nǐ hǎo"))
    }
}
