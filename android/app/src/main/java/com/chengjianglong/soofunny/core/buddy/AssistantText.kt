package com.chengjianglong.soofunny.core.buddy

import com.chengjianglong.soofunny.core.LearningLanguage
import java.util.concurrent.atomic.AtomicLong

/** One turn of the conversation. A buddy turn keeps its sentences, so each can light up as it's read. */
data class ChatMessage(
    val speaker: Speaker,
    val text: String,
    val sentences: List<String> = listOf(text),
    val id: Long = ids.incrementAndGet(),
) {
    enum class Speaker { CHILD, BUDDY }

    private companion object {
        val ids = AtomicLong()
    }
}

/**
 * Prompts for Qwen, in its chat format (ChatML): the buddy's rules are the system message, then
 * the conversation so far as alternating turns. A port of `AssistantPrompts` in the iOS app.
 */
object AssistantPrompts {
    const val REPLY_TOKEN_LIMIT = 160

    /** Bilingual says everything twice, so it gets more room. */
    fun tokenLimit(language: LearningLanguage): Int =
        if (language == LearningLanguage.BOTH) REPLY_TOKEN_LIMIT * 2 else REPLY_TOKEN_LIMIT

    /** The word in the language the conversation is in: "lion", "狮子" (lion in English) or "lion" ("狮子" in Chinese). */
    private fun topic(word: String, chinese: String?, language: LearningLanguage): String {
        if (chinese.isNullOrEmpty()) return "\"$word\""
        return when (language) {
            LearningLanguage.ENGLISH -> "\"$word\""
            LearningLanguage.CHINESE -> "\"$chinese\" ($word in English)"
            LearningLanguage.BOTH -> "\"$word\" (\"$chinese\" in Chinese)"
        }
    }

    private fun rules(word: String, category: String, language: LearningLanguage, chinese: String?, facts: String?): String {
        val about = topic(word, chinese, language)
        // What the child has just read about it (a sport's introduction), so answers match it.
        val background = facts?.let { "\nWhat the child just read about it: $it" } ?: ""
        val languageRules = when (language) {
            LearningLanguage.ENGLISH ->
                "about the English word $about from the group \"$category\". Your words are read aloud.\n" +
                    "Rules: Use short, simple sentences and easy words. Say at most three sentences and no more " +
                    "than forty words."
            LearningLanguage.CHINESE ->
                "about the Chinese word $about from the group \"$category\". Your words are read aloud.\n" +
                    "Rules: Always answer only in simple Mandarin Chinese with simplified characters (简体中文), " +
                    "even if the child speaks English. Never add an English translation. Use short, simple sentences and easy words. Say at most three " +
                    "sentences and no more than sixty Chinese characters. For example: 猫是一种小宠物。猫喜欢睡觉。"
            LearningLanguage.BOTH ->
                "about the word $about from the group \"$category\". The child is learning English and " +
                    "Chinese. Your words are read aloud.\n" +
                    "Rules: Say each sentence in simple English first, then the same sentence in simple Mandarin " +
                    "Chinese with simplified characters (简体中文). Use short, simple sentences and easy words. Say " +
                    "at most two sentences, each in both languages. For example: A cat is a small pet. 猫是一种小宠物。 " +
                    "Cats like to sleep. 猫喜欢睡觉。"
        }
        return "You are a cheerful learning buddy talking with a young child (about 4 to 8 years old) " +
            "$languageRules Write plain spoken text only: no lists, no markdown, no emojis, no labels, " +
            "no pinyin. Write numbers as words. Be kind, curious and encouraging. Stay on topic and keep everything " +
            "safe for children. If you are not sure about something, say so simply. End by asking one " +
            "short question the child might enjoy answering, unless the child wants to stop; then say a " +
            "short friendly goodbye. Never start with \"Okay\" or a greeting." + background
    }

    /**
     * The opening turn: a short explanation of the word. The app adds the question itself,
     * because a small model doesn't reliably ask it word for word.
     */
    fun introduction(
        word: String, category: String, language: LearningLanguage = LearningLanguage.ENGLISH,
        chinese: String? = null, facts: String? = null,
    ): String {
        val ask = when (language) {
            LearningLanguage.ENGLISH ->
                "In one or two short sentences, tell the child what \"$word\" is. Start directly with the word \"$word\"."
            LearningLanguage.CHINESE -> {
                val name = chinese ?: word
                "In one or two short sentences in Chinese, tell the child what \"$name\" is. Start directly with the word \"$name\"."
            }
            LearningLanguage.BOTH ->
                "In one short English sentence, tell the child what \"$word\" is, then say the same " +
                    "sentence in Chinese. Start directly with the word \"$word\"."
        }
        return chat(
            rules(word, category, language, chinese, facts),
            listOf(ChatMessage.Speaker.CHILD to "$ask Do not greet and do not ask a question."),
        )
    }

    /** Said after the introduction, like the buddy in the demo. */
    fun introductionQuestion(word: String, language: LearningLanguage = LearningLanguage.ENGLISH, chinese: String? = null): String {
        val english = "What would you like to know about $word?"
        val inChinese = "关于${chinese ?: word}，你想知道什么？"
        return when (language) {
            LearningLanguage.ENGLISH -> english
            LearningLanguage.CHINESE -> inChinese
            LearningLanguage.BOTH -> "$english $inChinese"
        }
    }

    /** A follow-up: the last eight turns plus the child's new question. */
    fun reply(
        word: String, category: String, history: List<ChatMessage>, question: String,
        language: LearningLanguage = LearningLanguage.ENGLISH, chinese: String? = null, facts: String? = null,
    ): String {
        val turns = history.takeLast(8).map { it.speaker to it.text.prefixChars(600) } +
            (ChatMessage.Speaker.CHILD to question.prefixChars(400))
        return chat(rules(word, category, language, chinese, facts), turns)
    }

    /** The child speaks as the user and the buddy as the assistant; the prompt ends where the buddy's next reply begins. */
    private fun chat(system: String, turns: List<Pair<ChatMessage.Speaker, String>>): String {
        val prompt = StringBuilder("<|im_start|>system\n$system<|im_end|>\n")
        for ((speaker, text) in turns) {
            // Keep the child's words from closing the turn early.
            val clean = text.replace("<|", "<")
            val role = if (speaker == ChatMessage.Speaker.CHILD) "user" else "assistant"
            prompt.append("<|im_start|>$role\n$clean<|im_end|>\n")
        }
        return prompt.append("<|im_start|>assistant\n").toString()
    }

    /** At most [n] characters, without splitting an emoji in half. */
    private fun String.prefixChars(n: Int): String {
        if (codePointCount(0, length) <= n) return this
        return substring(0, offsetByCodePoints(0, n))
    }
}

/** Splits streamed text into complete sentences, so speech can start before the reply ends. */
class SentenceStream {
    private var buffer = ""

    /** Adds text and returns any sentences it completed. */
    fun append(text: String): List<String> {
        buffer += text
        val sentences = mutableListOf<String>()
        while (true) {
            val end = sentenceEnd(buffer) ?: break
            val sentence = AssistantCleanup.clean(buffer.substring(0, end))
            buffer = buffer.substring(end)
            if (sentence.isNotEmpty()) sentences += sentence
        }
        return sentences
    }

    /** Whatever is left once the reply has finished. */
    fun finish(): List<String> {
        val rest = AssistantCleanup.clean(buffer)
        buffer = ""
        return if (rest.isEmpty()) emptyList() else listOf(rest)
    }

    /**
     * The index just past a sentence-ending mark that is followed by whitespace, or just past a
     * Chinese one (。！？), which needs no space after it (but something must follow it).
     */
    private fun sentenceEnd(text: String): Int? {
        for (i in text.indices) {
            val next = i + 1
            if (next >= text.length) return null
            val c = text[i]
            if (c in "。！？") return next
            if (c in ".!?" && text[next].isWhitespace()) return next
        }
        return null
    }
}

object AssistantCleanup {
    private val labels = listOf("Buddy:", "Qwen:", "Model:", "Assistant:")
    private val pinyin = Regex("\\s*[(（][^()（）]*[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ][^()（）]*[)）]")
    private val spaces = Regex("\\s+")
    private val spaceInChinese = Regex("(?<=[\\p{IsHan}，。！？、：；]) (?=[\\p{IsHan}，。！？、：；])")

    /** Removes markdown, emojis and speaker labels a small model sometimes adds. */
    fun clean(text: String): String {
        var s = text
        for (label in labels) {
            if (s.trim().startsWith(label)) s = s.trim().removePrefix(label)
        }
        // Pinyin the model adds in brackets, "狗 (gǒu)": the characters are already there.
        s = pinyin.replace(s, "")
        val kept = StringBuilder()
        var i = 0
        while (i < s.length) {
            val cp = s.codePointAt(i)
            if (cp.toChar() !in "*_#`~>" || cp > 0xFFFF) {
                if (!isEmoji(cp)) kept.appendCodePoint(cp)
            }
            i += Character.charCount(cp)
        }
        return spaceInChinese.replace(spaces.replace(kept, " "), "").trim()
    }

    /** Emoji (and their joiners and variation selectors), but not plain marks like © or digits. */
    internal fun isEmoji(cp: Int): Boolean = when (cp) {
        in 0x1F000..0x1FAFF, in 0x2600..0x27BF, in 0xE0020..0xE007F -> true
        0x200D, 0xFE0F, 0x20E3, 0x203C, 0x2049, 0x2122, 0x2139, 0x24C2, 0x25B6, 0x25C0, 0x2B50, 0x2B55,
        0x3030, 0x303D, 0x3297, 0x3299, 0x2328, 0x23CF -> true
        in 0x2194..0x2199, in 0x21A9..0x21AA, in 0x231A..0x231B, in 0x23E9..0x23F3, in 0x23F8..0x23FA,
        in 0x25AA..0x25AB, in 0x25FB..0x25FE, in 0x2934..0x2935, in 0x2B05..0x2B07, in 0x2B1B..0x2B1C -> true
        else -> false
    }
}
