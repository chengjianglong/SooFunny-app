package com.chengjianglong.soofunny.core.voice

import com.chengjianglong.soofunny.core.AppSettings
import com.chengjianglong.soofunny.core.WordDictionary
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import kotlin.math.sin

/** Ported from the iOS app's `NaturalVoiceTests` (the parts that don't need the model). */
class KokoroPhonemizerTest {
    companion object {
        val p: KokoroPhonemizer by lazy {
            val r = File("../../SooFunny/Voice/Resources")
            KokoroPhonemizer(File(r, "kokoro_lexicon.tsv").inputStream(), File(r, "kokoro_vocab.tsv").inputStream())
        }
    }

    @Test
    fun matchesMisakiForBuddySentences() {
        // Expected values come from the reference pipeline (misaki dictionaries + rules).
        assertEquals("ɐ lˈIən ɪz ɐ bˈɪɡ, stɹˈɔŋ kˈæt.", p.phonemize("A lion is a big, strong cat."))
        assertEquals("wˌʌt wʊd ju lˈIk tə nˈO əbˈWt lˈIən?", p.phonemize("What would you like to know about lion?"))
        assertEquals("lˈIənz ˈit mˈit. ðA hˈʌnt zˈibɹəz ænd wˈɪldəbˌist ˌɔn ðə səvˈænə!",
            p.phonemize("Lions eat meat. They hunt zebras and wildebeest on the savanna!"))
        assertEquals("ɡɹˈAt ʤˈɑb! ju ɡɑt ɪt.", p.phonemize("Great job! You got it."))
    }

    @Test
    fun functionWordsNumbersEndingsAndLetters() {
        assertEquals("'the' before a vowel is 'thee'", p.phonemize("thee apple").replace("ðˈi", "ði"), p.phonemize("the apple"))
        assertTrue(p.phonemize("the cat").startsWith("ðə "))
        assertEquals("digits become words", p.phonemize("twelve seven"), p.phonemize("12 + 7"))
        assertTrue("-ed after p sounds like t", p.phonemize("jumped").endsWith("t"))
        assertTrue(p.phonemize("painting").endsWith("ɾɪŋ") || p.phonemize("painting").endsWith("tɪŋ"))
        assertEquals("a single letter is said as its name", "bˈi", p.phonemize("B"))
        assertEquals("the letter a alone is 'ay', not 'uh'", "ˈA", p.phonemize("a"))
        assertFalse("unknown words are spelled out", p.phonemize("zxqv").isEmpty())
        assertTrue(p.phonemize("I can").startsWith("ˌI"))
        assertEquals("the app's name is said, not spelled", "sˈu fˈʌni", p.phonemize("SooFunny"))
        assertEquals("sˈu fˈʌni", p.phonemize("Soo Funny"))
        assertEquals("said as eye phone and eye pad", "ˈI fˈOn ænd ˈI pˈæd", p.phonemize("iPhone and iPad"))
    }

    @Test
    fun spellsNumbersLikeIcu() {
        assertEquals("twenty-one", KokoroPhonemizer.spellOut(21))
        assertEquals("one hundred five", KokoroPhonemizer.spellOut(105))
        assertEquals("one thousand two hundred thirty-four", KokoroPhonemizer.spellOut(1234))
        assertEquals("two million three", KokoroPhonemizer.spellOut(2_000_003))
        assertEquals("zero", KokoroPhonemizer.spellOut(0))
    }

    @Test
    fun everyWordInTheWordListCanBeSaid() {
        val categories = WordDictionary.parse(File("../../SooFunny/Words/kids_words.txt").readText())
        for (word in categories.flatMap { it.words }) {
            assertTrue(word.text, p.tokenIds(p.phonemize(word.text)).size > 2)
        }
    }

    @Test
    fun wordHighlightMovesThroughTheSentence() {
        val sentence = "Lions eat meat."
        assertEquals("Lions", sentence.substring(Kokoro.wordRange(sentence, 0.0)!!))
        assertEquals("eat", sentence.substring(Kokoro.wordRange(sentence, 0.5)!!))
        assertEquals("meat", sentence.substring(Kokoro.wordRange(sentence, 1.0)!!))
    }
}

class NaturalVoicePhraseTest {
    @Test
    fun shortSentencesStayWholeWithAPauseAfter() {
        val phrases = Kokoro.phrases("Lions eat meat.")
        assertEquals(listOf("Lions eat meat."), phrases.map { it.text })
        assertEquals(0.22, phrases.last().gap, 0.001)
    }

    @Test
    fun longSentencesSplitAtCommasIntoNaturalPhrases() {
        val sentence = "A lion is a big wild cat, with a fluffy mane, and it lives in Africa."
        val phrases = Kokoro.phrases(sentence)
        assertEquals(listOf("A lion is a big wild cat,", "with a fluffy mane,", "and it lives in Africa."), phrases.map { it.text })
        assertEquals(listOf(0.12, 0.12, 0.22), phrases.map { it.gap })
        for (phrase in phrases) assertTrue("highlighting finds ${phrase.text}", sentence.contains(phrase.text))
    }

    @Test
    fun tinyLastPhraseJoinsThePreviousOne() {
        val phrases = Kokoro.phrases("They like to eat zebras and other big animals, too.")
        assertEquals(listOf("They like to eat zebras and other big animals, too."), phrases.map { it.text })
    }

    @Test
    fun trimmingRemovesSilenceButKeepsTheSound() {
        val silence = FloatArray(9_000)
        val sound = FloatArray(2_400) { sin(it / 5f) * 0.3f }
        val trimmed = Kokoro.trimmingSilence(silence + sound + silence + silence)
        assertTrue("at most 0.1 s of padding is kept", trimmed.size < sound.size + 2_400)
        assertTrue(trimmed.size >= sound.size - 20)
    }

    @Test
    fun piecesKeepTheirPlaceInTheText() {
        val text = "Lions eat meat.  A lion is a big wild cat, with a fluffy mane, and it lives in Africa. 狮子吃肉。"
        val pieces = Kokoro.pieces(text)
        assertEquals(5, pieces.size)
        for (piece in pieces) assertEquals(piece.text, text.substring(piece.offset, piece.offset + piece.text.length))
    }

    @Test
    fun defaultSpeedIsLivelyNotDragging() {
        assertEquals("the default reads at about 1.05x", 1.05f, Kokoro.speed(AppSettings.DEFAULT_SPEECH_RATE), 0.01f)
        assertEquals(0.77f, Kokoro.speed(0.5f), 0.01f)
        assertEquals(1.195f, Kokoro.speed(1.5f), 0.01f)
    }
}
