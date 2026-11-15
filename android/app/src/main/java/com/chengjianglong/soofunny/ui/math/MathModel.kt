package com.chengjianglong.soofunny.ui.math

import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.chengjianglong.soofunny.core.LearningLanguage
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import kotlin.random.Random

/** + − × ÷, in this order (the order they sort in). Mirrors `MathOperation` on iOS. */
enum class MathOperation(
    val key: String,
    val symbol: String,
    /** How the sign is read aloud. */
    val spoken: String,
    /** How the sign is read aloud in Chinese. */
    val spokenChinese: String,
    val english: String,
    val chinese: String,
) {
    ADD("add", "+", "plus", "加", "Adding", "加法"),
    SUBTRACT("subtract", "−", "minus", "减", "Taking away", "减法"),
    MULTIPLY("multiply", "×", "times", "乘", "Times", "乘法"),
    DIVIDE("divide", "÷", "divided by", "除以", "Sharing", "除法");

    fun name(language: LearningLanguage): String = language.pick(english, chinese)

    companion object {
        fun fromKey(key: String?): MathOperation? = entries.firstOrNull { it.key == key }
    }
}

/** One problem, such as 9 + 0. Answers are always whole numbers of zero or more. */
data class MathQuestion(val left: Int, val right: Int, val operation: MathOperation) {
    val answer: Int
        get() = when (operation) {
            MathOperation.ADD -> left + right
            MathOperation.SUBTRACT -> left - right
            MathOperation.MULTIPLY -> left * right
            MathOperation.DIVIDE -> if (right == 0) 0 else left / right
        }

    val text: String get() = "$left ${operation.symbol} $right"
    val spokenText: String get() = "$left ${operation.spoken} $right"

    /** "三加四", with the numbers in words so a Chinese voice never reads them in English. */
    val spokenChinese: String
        get() = ChineseNumber.words(left) + operation.spokenChinese + ChineseNumber.words(right)

    /** The question read aloud: "3 plus 4 equals?", "三加四等于几？" or both. */
    fun spokenQuestion(language: LearningLanguage): String =
        language.spoken("$spokenText equals?", spokenChinese + "等于几？")

    /** The answer read aloud: "3 plus 4 is 7.", "三加四等于七。" or both. */
    fun spokenAnswer(language: LearningLanguage): String =
        language.spoken("$spokenText is $answer.", spokenChinese + "等于" + ChineseNumber.words(answer) + "。")
}

/** Numbers written in Chinese words: 12 → 十二, 105 → 一百零五, 144 → 一百四十四. */
object ChineseNumber {
    private const val DIGITS = "零一二三四五六七八九"

    fun words(number: Int): String {
        if (number < 0) return "负" + words(-number)
        if (number < 10) return DIGITS[number].toString()
        if (number < 20) return "十" + if (number % 10 == 0) "" else DIGITS[number % 10].toString()
        if (number >= 10_000) return number.toString()
        val text = StringBuilder()
        var zero = false
        for ((unit, name) in listOf(1000 to "千", 100 to "百", 10 to "十", 1 to "")) {
            val digit = number / unit % 10
            if (digit == 0) {
                zero = text.isNotEmpty()
            } else {
                if (zero) text.append("零")
                text.append(DIGITS[digit]).append(name)
                zero = false
            }
        }
        return text.toString()
    }
}

/** What to practice. Saved between launches. */
data class MathSettings(
    val operations: Set<MathOperation> = setOf(MathOperation.ADD, MathOperation.SUBTRACT),
    /** Every question uses at least one of these numbers. */
    val focusNumbers: Set<Int> = (1..10).toSet(),
    val questionCount: Int = 10,
    /** Flashcards: after seeing the answer, the child says whether they got it right. */
    val markQuestions: Boolean = true,
    /** Read each question aloud. */
    val readAloud: Boolean = true,
    /** Show the timer during quizzes. */
    val showTimer: Boolean = true,
) {
    val isReady: Boolean get() = operations.isNotEmpty() && focusNumbers.isNotEmpty()

    fun save(prefs: SharedPreferences) {
        prefs.edit()
            .putString(KEY, JSONObject().apply {
                put("operations", JSONArray(operations.sorted().map { it.key }))
                put("focusNumbers", JSONArray(focusNumbers.sorted()))
                put("questionCount", questionCount)
                put("markQuestions", markQuestions)
                put("readAloud", readAloud)
                put("showTimer", showTimer)
            }.toString())
            .apply()
    }

    companion object {
        val numbers = (0..12).toList()
        val counts = listOf(10, 20, 30)
        private const val KEY = "mathSettings"

        fun load(prefs: SharedPreferences): MathSettings = try {
            val json = prefs.getString(KEY, null)?.let(::JSONObject)
            if (json == null) MathSettings() else {
                val ops = json.getJSONArray("operations")
                val nums = json.getJSONArray("focusNumbers")
                MathSettings(
                    operations = (0 until ops.length()).mapNotNull { MathOperation.fromKey(ops.getString(it)) }.toSet(),
                    focusNumbers = (0 until nums.length()).map { nums.getInt(it) }.filter { it in 0..12 }.toSet(),
                    questionCount = json.optInt("questionCount", 10).takeIf { it in counts } ?: 10,
                    markQuestions = json.optBoolean("markQuestions", true),
                    readAloud = json.optBoolean("readAloud", true),
                    showTimer = json.optBoolean("showTimer", true),
                )
            }
        } catch (_: Exception) {
            MathSettings()
        }
    }
}

/** Makes practice questions that suit young children. Same rules as iOS `MathQuestionMaker`. */
object MathQuestionMaker {
    /**
     * [MathSettings.questionCount] questions using the chosen operations and focus numbers,
     * without the same question twice in a row.
     */
    fun questions(settings: MathSettings, rng: Random = Random.Default): List<MathQuestion> {
        val focus = settings.focusNumbers.sorted()
        val choices: List<Pair<MathOperation, List<Int>>> =
            if (focus.isEmpty()) emptyList() else settings.operations.sorted().map { it to focus }
        if (choices.isEmpty()) return emptyList()
        val possible = choices.sumOf { it.second.size }
        val questions = mutableListOf<MathQuestion>()
        while (questions.size < settings.questionCount) {
            val (op, numbers) = choices.random(rng)
            val f = numbers.random(rng)
            val other = rng.nextInt(0, 13)
            val question = make(op, f, other, rng.nextBoolean())
            // Try again on an immediate repeat, unless only one question is possible.
            if (question == questions.lastOrNull() && possible > 1 && rng.nextInt(0, 10) > 0) continue
            questions += question
        }
        return questions
    }

    /**
     * One question where the focus number [f] appears. Subtraction never goes below zero and
     * division always comes out even (and never divides by zero).
     */
    fun make(op: MathOperation, f: Int, n: Int, flip: Boolean): MathQuestion = when (op) {
        MathOperation.ADD -> if (flip) MathQuestion(n, f, op) else MathQuestion(f, n, op)
        // (f + n) − f = n: the focus number is the one taken away, so it's always shown.
        MathOperation.SUBTRACT -> MathQuestion(f + n, f, op)
        MathOperation.MULTIPLY -> if (flip) MathQuestion(n, f, op) else MathQuestion(f, n, op)
        MathOperation.DIVIDE ->
            // 0 ÷ n = 0, with n at least 1.
            if (f == 0) MathQuestion(0, maxOf(1, n), op) else MathQuestion(f * n, f, op)
    }
}

enum class MathMode(val key: String, val english: String, val chinese: String) {
    FLASHCARDS("flashcards", "Flashcards", "闪卡"),
    QUIZ("quiz", "Quiz", "测验");

    fun title(language: LearningLanguage): String = language.pick(english, chinese)

    companion object {
        fun fromKey(key: String?): MathMode = entries.firstOrNull { it.key == key } ?: QUIZ
    }
}

/** How one question went. */
data class MathAnswer(
    val question: MathQuestion,
    /** What the child typed (quiz only). */
    val given: Int?,
    /** Null when flashcards weren't marked. */
    val correct: Boolean?,
    val seconds: Double,
)

/** One finished practice round, kept for Progress Reports. */
data class MathResult(
    val mode: MathMode,
    val operations: List<MathOperation>,
    val answers: List<MathAnswer>,
    val seconds: Double,
    val id: String = UUID.randomUUID().toString(),
    /** Milliseconds since 1970. */
    val date: Long = System.currentTimeMillis(),
) {
    val total: Int get() = answers.size
    val marked: List<MathAnswer> get() = answers.filter { it.correct != null }
    val correctCount: Int get() = answers.count { it.correct == true }

    /** Fraction right (0..1), or null when nothing was marked. */
    val score: Double? get() = marked.let { if (it.isEmpty()) null else correctCount.toDouble() / it.size }
    val missed: List<MathQuestion> get() = answers.filter { it.correct == false }.map { it.question }

    /** 0–3 stars for the score. */
    val stars: Int
        get() {
            val s = score ?: return 3
            return when {
                s >= 0.9 -> 3
                s >= 0.7 -> 2
                s >= 0.4 -> 1
                else -> 0
            }
        }
}

/** A flashcard round or quiz in progress. Compose-observable. */
class MathSession(val mode: MathMode, val questions: List<MathQuestion>, val markQuestions: Boolean) {
    var index by mutableStateOf(0); private set
    /** Flashcards: the answer is showing. */
    var revealed by mutableStateOf(false); private set
    /** Quiz: the digits typed so far. */
    var typed by mutableStateOf(""); private set
    /** Quiz: the result of the last Check, shown until Next. */
    var feedback by mutableStateOf<Boolean?>(null); private set
    val answers = mutableListOf<MathAnswer>()
    var finishedResult by mutableStateOf<MathResult?>(null); private set

    val startTime: Long = System.currentTimeMillis()
    private var questionStart = startTime

    val current: MathQuestion get() = questions[minOf(index, questions.size - 1)]
    val isFinished: Boolean get() = finishedResult != null

    fun progressText(language: LearningLanguage): String {
        val number = minOf(index + 1, questions.size)
        return language.pick("Question $number of ${questions.size}", "第${number}题，共${questions.size}题")
    }

    fun reveal() {
        if (mode != MathMode.FLASHCARDS || isFinished) return
        revealed = true
    }

    /** Flashcards: move on, recording whether the child got it (null when not marking). */
    fun mark(correct: Boolean?) {
        if (mode != MathMode.FLASHCARDS || !revealed || isFinished) return
        record(null, if (markQuestions) correct else null)
        advance()
    }

    fun type(digit: Int) {
        if (mode != MathMode.QUIZ || feedback != null || typed.length >= 3 || digit !in 0..9) return
        typed = if (typed == "0") digit.toString() else typed + digit
    }

    fun deleteDigit() {
        if (mode != MathMode.QUIZ || feedback != null || typed.isEmpty()) return
        typed = typed.dropLast(1)
    }

    /** Checks the typed answer. Returns whether it was right. */
    fun check(): Boolean? {
        if (mode != MathMode.QUIZ || feedback != null) return null
        val value = typed.toIntOrNull() ?: return null
        val right = value == current.answer
        feedback = right
        record(value, right)
        return right
    }

    fun next() {
        if (mode != MathMode.QUIZ || feedback == null) return
        advance()
    }

    private fun record(given: Int?, correct: Boolean?) {
        answers += MathAnswer(current, given, correct, (System.currentTimeMillis() - questionStart) / 1000.0)
    }

    private fun advance() {
        if (index + 1 >= questions.size) {
            finishedResult = MathResult(
                mode, questions.map { it.operation }.toSet().sorted(), answers.toList(),
                (System.currentTimeMillis() - startTime) / 1000.0,
            )
            return
        }
        index += 1
        revealed = false
        typed = ""
        feedback = null
        questionStart = System.currentTimeMillis()
    }
}

data class OperationStats(val operation: MathOperation, val asked: Int, val correct: Int) {
    val accuracy: Double? get() = if (asked == 0) null else correct.toDouble() / asked
}

/** Report numbers worked out from saved rounds (pure, so they can be unit tested). */
object MathStats {
    /** Right answers per operation, over every marked question. */
    fun operationStats(results: List<MathResult>): List<OperationStats> = MathOperation.entries.map { op ->
        val marked = results.flatMap { it.answers }.filter { it.question.operation == op && it.correct != null }
        OperationStats(op, marked.size, marked.count { it.correct == true })
    }

    fun totalQuestions(results: List<MathResult>): Int = results.sumOf { it.total }

    /** Questions answered wrong most often (most misses first, then by text), at most 8. */
    fun trickyQuestions(results: List<MathResult>): List<Pair<MathQuestion, Int>> {
        val misses = LinkedHashMap<MathQuestion, Int>()
        for (answer in results.flatMap { it.answers }) if (answer.correct == false) {
            misses[answer.question] = (misses[answer.question] ?: 0) + 1
        }
        return misses.entries
            .sortedWith(compareByDescending<Map.Entry<MathQuestion, Int>> { it.value }.thenBy { it.key.text })
            .take(8).map { it.key to it.value }
    }

    /** Days in a row (ending today or yesterday) with at least one round. */
    fun streak(results: List<MathResult>, today: LocalDate = LocalDate.now(), zone: ZoneId = ZoneId.systemDefault()): Int {
        val days = results.map { Instant.ofEpochMilli(it.date).atZone(zone).toLocalDate() }.toSet()
        var day = today
        if (day !in days) day = day.minusDays(1)
        var count = 0
        while (day in days) {
            count += 1
            day = day.minusDays(1)
        }
        return count
    }
}

/** Saved rounds for Progress Reports, kept on this device only (in SharedPreferences). */
object MathProgressStore {
    private const val KEY = "mathProgress"
    private var loaded = false
    private var prefs: SharedPreferences? = null

    /** Newest first. */
    val results = mutableStateListOf<MathResult>()

    fun load(prefs: SharedPreferences) {
        if (loaded) return
        loaded = true
        this.prefs = prefs
        results.clear()
        results.addAll(decode(prefs.getString(KEY, null)))
    }

    fun add(result: MathResult) {
        results.add(0, result)
        while (results.size > 300) results.removeAt(results.lastIndex)
        save()
    }

    fun clear() {
        results.clear()
        save()
    }

    private fun save() {
        prefs?.edit()?.putString(KEY, encode(results))?.apply()
    }

    private fun encodeQuestion(q: MathQuestion) = JSONObject().put("left", q.left).put("right", q.right).put("operation", q.operation.key)

    private fun decodeQuestion(o: JSONObject): MathQuestion? {
        val op = MathOperation.fromKey(o.optString("operation")) ?: return null
        return MathQuestion(o.getInt("left"), o.getInt("right"), op)
    }

    private fun encode(list: List<MathResult>): String = JSONArray().apply {
        list.forEach { r ->
            put(JSONObject().apply {
                put("id", r.id)
                put("date", r.date)
                put("mode", r.mode.key)
                put("operations", JSONArray(r.operations.map { it.key }))
                put("seconds", r.seconds)
                put("answers", JSONArray().apply {
                    r.answers.forEach { a ->
                        put(JSONObject().apply {
                            put("question", encodeQuestion(a.question))
                            a.given?.let { put("given", it) }
                            a.correct?.let { put("correct", it) }
                            put("seconds", a.seconds)
                        })
                    }
                })
            })
        }
    }.toString()

    private fun decode(text: String?): List<MathResult> {
        if (text.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(text)
            (0 until array.length()).mapNotNull { i ->
                val o = array.getJSONObject(i)
                val ops = o.getJSONArray("operations")
                val ans = o.getJSONArray("answers")
                MathResult(
                    mode = MathMode.fromKey(o.optString("mode")),
                    operations = (0 until ops.length()).mapNotNull { MathOperation.fromKey(ops.getString(it)) },
                    answers = (0 until ans.length()).mapNotNull { j ->
                        val a = ans.getJSONObject(j)
                        val q = decodeQuestion(a.getJSONObject("question")) ?: return@mapNotNull null
                        MathAnswer(
                            q,
                            if (a.has("given")) a.getInt("given") else null,
                            if (a.has("correct")) a.getBoolean("correct") else null,
                            a.optDouble("seconds", 0.0),
                        )
                    },
                    seconds = o.optDouble("seconds", 0.0),
                    id = o.optString("id", UUID.randomUUID().toString()),
                    date = o.optLong("date", System.currentTimeMillis()),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
