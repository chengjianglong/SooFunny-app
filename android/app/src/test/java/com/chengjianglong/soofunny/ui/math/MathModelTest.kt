package com.chengjianglong.soofunny.ui.math

import com.chengjianglong.soofunny.core.LearningLanguage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import kotlin.random.Random

class MathModelTest {
    private val all = MathOperation.entries.toSet()

    @Test
    fun everyQuestionUsesAFocusNumberAndHasAWholeAnswer() {
        for (seed in 0 until 200) {
            val rng = Random(seed)
            val focus = MathSettings.numbers.filter { rng.nextBoolean() }.toSet().ifEmpty { setOf(seed % 13) }
            val ops = MathOperation.entries.filter { rng.nextBoolean() }.toSet().ifEmpty { setOf(MathOperation.DIVIDE) }
            val settings = MathSettings(operations = ops, focusNumbers = focus, questionCount = 30)
            val questions = MathQuestionMaker.questions(settings, Random(seed))
            assertEquals(30, questions.size)
            for (q in questions) {
                assertTrue("$q uses an operation picked", q.operation in ops)
                assertTrue("$q has a focus number", q.left in focus || q.right in focus)
                assertTrue("$q answer is not negative", q.answer >= 0)
                when (q.operation) {
                    MathOperation.SUBTRACT -> assertTrue(q.left >= q.right)
                    MathOperation.DIVIDE -> {
                        assertTrue("$q never divides by zero", q.right != 0)
                        assertEquals("$q comes out even", 0, q.left % q.right)
                    }
                    else -> {}
                }
            }
        }
    }

    @Test
    fun makeFollowsTheIosRules() {
        assertEquals(MathQuestion(3, 9, MathOperation.ADD), MathQuestionMaker.make(MathOperation.ADD, 3, 9, false))
        assertEquals(MathQuestion(9, 3, MathOperation.ADD), MathQuestionMaker.make(MathOperation.ADD, 3, 9, true))
        // The focus number is the one taken away.
        assertEquals(MathQuestion(12, 3, MathOperation.SUBTRACT), MathQuestionMaker.make(MathOperation.SUBTRACT, 3, 9, true))
        assertEquals(MathQuestion(4, 7, MathOperation.MULTIPLY), MathQuestionMaker.make(MathOperation.MULTIPLY, 4, 7, false))
        assertEquals(MathQuestion(7, 4, MathOperation.MULTIPLY), MathQuestionMaker.make(MathOperation.MULTIPLY, 4, 7, true))
        assertEquals(MathQuestion(28, 4, MathOperation.DIVIDE), MathQuestionMaker.make(MathOperation.DIVIDE, 4, 7, false))
        // 0 as the focus: 0 ÷ n with n at least 1.
        assertEquals(MathQuestion(0, 1, MathOperation.DIVIDE), MathQuestionMaker.make(MathOperation.DIVIDE, 0, 0, false))
        assertEquals(MathQuestion(0, 5, MathOperation.DIVIDE), MathQuestionMaker.make(MathOperation.DIVIDE, 0, 5, false))
        // Dividing by focus 1 and 0 as "other" is 0 ÷ 1.
        assertEquals(0, MathQuestionMaker.make(MathOperation.DIVIDE, 1, 0, false).answer)
    }

    @Test
    fun noQuestionsWithoutOperationsOrNumbers() {
        assertTrue(MathQuestionMaker.questions(MathSettings(operations = emptySet())).isEmpty())
        assertTrue(MathQuestionMaker.questions(MathSettings(focusNumbers = emptySet())).isEmpty())
        assertFalse(MathSettings(focusNumbers = emptySet()).isReady)
    }

    @Test
    fun repeatsAreRare() {
        val settings = MathSettings(operations = all, focusNumbers = MathSettings.numbers.toSet(), questionCount = 30)
        var repeats = 0
        repeat(100) { seed ->
            MathQuestionMaker.questions(settings, Random(seed)).zipWithNext().forEach { (a, b) -> if (a == b) repeats++ }
        }
        assertTrue("repeats: $repeats", repeats < 5)
    }

    @Test
    fun onlyOnePossibleQuestionStillFinishes() {
        val settings = MathSettings(operations = setOf(MathOperation.DIVIDE), focusNumbers = setOf(0), questionCount = 10)
        val qs = MathQuestionMaker.questions(settings, Random(1))
        assertEquals(10, qs.size)
        assertTrue(qs.all { it.left == 0 && it.right >= 1 })
    }

    @Test
    fun chineseNumbers() {
        val cases = mapOf(0 to "零", 7 to "七", 10 to "十", 12 to "十二", 20 to "二十", 21 to "二十一",
            100 to "一百", 105 to "一百零五", 110 to "一百一十", 144 to "一百四十四", 1001 to "一千零一", -3 to "负三")
        cases.forEach { (n, words) -> assertEquals("$n", words, ChineseNumber.words(n)) }
    }

    @Test
    fun spokenText() {
        val q = MathQuestion(3, 4, MathOperation.ADD)
        assertEquals("3 plus 4 equals?", q.spokenQuestion(LearningLanguage.ENGLISH))
        assertEquals("三加四等于几？", q.spokenQuestion(LearningLanguage.CHINESE))
        assertEquals("3 plus 4 equals? 三加四等于几？", q.spokenQuestion(LearningLanguage.BOTH))
        assertEquals("十二除以三等于四。", MathQuestion(12, 3, MathOperation.DIVIDE).spokenAnswer(LearningLanguage.CHINESE))
    }

    @Test
    fun starsAndStats() {
        fun result(right: Int, wrong: Int, daysAgo: Long = 0) = MathResult(
            MathMode.QUIZ, listOf(MathOperation.ADD),
            List(right) { MathAnswer(MathQuestion(1, 1, MathOperation.ADD), 2, true, 1.0) } +
                List(wrong) { MathAnswer(MathQuestion(2, it, MathOperation.ADD), 0, false, 1.0) },
            10.0, date = LocalDate.of(2026, 11, 15).minusDays(daysAgo).atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(),
        )
        assertEquals(3, result(9, 1).stars)
        assertEquals(2, result(7, 3).stars)
        assertEquals(1, result(4, 6).stars)
        assertEquals(0, result(3, 7).stars)
        val unmarked = MathResult(MathMode.FLASHCARDS, listOf(MathOperation.ADD),
            listOf(MathAnswer(MathQuestion(1, 1, MathOperation.ADD), null, null, 1.0)), 1.0)
        assertNull(unmarked.score)
        assertEquals(3, unmarked.stars)

        val results = listOf(result(1, 2), result(1, 1, daysAgo = 1), result(1, 0, daysAgo = 3))
        assertEquals(2, MathStats.streak(results, LocalDate.of(2026, 11, 15)))
        assertEquals(2, MathStats.streak(results, LocalDate.of(2026, 11, 16)))
        assertEquals(0, MathStats.streak(results, LocalDate.of(2026, 11, 17)))
        val add = MathStats.operationStats(results).first { it.operation == MathOperation.ADD }
        assertEquals(6, add.asked)
        assertEquals(3, add.correct)
        val tricky = MathStats.trickyQuestions(results)
        assertEquals(MathQuestion(2, 0, MathOperation.ADD) to 2, tricky.first())
        assertEquals(MathQuestion(2, 1, MathOperation.ADD) to 1, tricky[1])
    }

    @Test
    fun quizSession() {
        val s = MathSession(MathMode.QUIZ, listOf(MathQuestion(3, 4, MathOperation.ADD), MathQuestion(5, 5, MathOperation.SUBTRACT)), true)
        s.type(0); s.type(7)
        assertEquals("7", s.typed)
        assertEquals(true, s.check())
        s.type(1) // ignored while feedback shows
        assertEquals("7", s.typed)
        s.next()
        s.type(1); s.deleteDigit(); s.type(3)
        assertEquals(false, s.check())
        s.next()
        val r = s.finishedResult!!
        assertEquals(1, r.correctCount)
        assertEquals(listOf(MathQuestion(5, 5, MathOperation.SUBTRACT)), r.missed)
        assertEquals(listOf(MathOperation.ADD, MathOperation.SUBTRACT), r.operations)
    }
}
