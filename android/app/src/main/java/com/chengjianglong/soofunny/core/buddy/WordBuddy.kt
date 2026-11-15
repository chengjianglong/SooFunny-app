package com.chengjianglong.soofunny.core.buddy

import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.chengjianglong.soofunny.core.BookLanguage
import com.chengjianglong.soofunny.core.LearningLanguage
import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * One spoken conversation about a word, like a patient buddy: it introduces the word, asks what
 * the child wants to know, listens, and answers. A port of `WordAssistant.swift`.
 *
 * Turn flow: preparing → speaking → listening → thinking → speaking → listening …
 * The child can stop at any point; Talk starts a new turn with the conversation so far.
 *
 * Use it from the main thread; the model runs on [worker], one generation at a time.
 */
class WordBuddy(
    val word: String,
    val category: String,
    language: LearningLanguage = LearningLanguage.ENGLISH,
    /** The word and its group in Chinese. */
    val chinese: String? = null,
    val chineseCategory: String? = null,
    /** Background the buddy should keep to, such as a sport's introduction. */
    val facts: String? = null,
    private val makeEngine: () -> LanguageEngine,
    private val speaker: SentenceSpeaker,
    private val listener: ChildListener,
    private val worker: Executor = sharedWorker,
    private val main: (Runnable) -> Unit = { mainHandler.post(it) },
) {
    sealed interface Phase {
        data object Preparing : Phase
        data object Speaking : Phase
        data object Listening : Phase
        data object Thinking : Phase
        data object Ready : Phase
        data class Failed(val message: String) : Phase
    }

    /** The language the buddy talks in. In Bilingual it says everything in English and then Chinese. */
    val language: LearningLanguage = if (chinese == null) LearningLanguage.ENGLISH else language

    /** The language the child speaks in; in Bilingual they can pick either. */
    var listeningLanguage: BookLanguage
        get() = listener.language
        set(value) { listener.language = value }

    var phase by mutableStateOf<Phase>(Phase.Preparing)
        private set
    val messages = mutableStateListOf<ChatMessage>()
    /** What the listener has heard so far in this turn. */
    var heard by mutableStateOf("")
        private set
    /** A gentle note shown under the controls (e.g. "I didn't hear anything"). */
    var note by mutableStateOf<String?>(null)
        private set

    /** True while speaking, listening or thinking: keeps the screen awake and the button green. */
    val isActive: Boolean get() = phase == Phase.Speaking || phase == Phase.Listening || phase == Phase.Thinking

    private var engine: LanguageEngine? = null
    /** Bumped to cancel the current turn; work from an old turn checks it and stops. */
    @Volatile private var turn = 0
    /** Set once the reply has every sentence it will use, so generation can stop early. */
    @Volatile private var replyFull = false
    private var listenAfterSpeaking = false
    /** Said after the current reply finishes (the question that follows the introduction). */
    private var followUp: String? = null
    /** Sentences of the current reply that are being said and shown. */
    private val acceptedSentences = mutableListOf<String>()
    /** The buddy message the current reply is being written into. */
    private var replyMessageId: Long? = null

    init {
        if (this.language == LearningLanguage.CHINESE) listener.language = BookLanguage.CHINESE
        speaker.onFinished = { speechFinished() }
    }

    companion object {
        private val mainHandler by lazy { Handler(Looper.getMainLooper()) }
        /** The model runs on one thread, shared by every conversation. */
        val sharedWorker: Executor by lazy {
            Executors.newSingleThreadExecutor { r -> Thread(r, "SooFunny-Buddy").apply { priority = Thread.NORM_PRIORITY + 1 } }
        }

        @Volatile private var sharedEngine: LlamaEngine? = null

        /** The model is loaded once and shared by every conversation. Call on the worker thread. */
        fun loadSharedEngine(model: File): LanguageEngine =
            sharedEngine ?: synchronized(this) { sharedEngine ?: LlamaEngine.load(model).also { sharedEngine = it } }
    }

    private fun pick(english: String, chinese: String) = language.pick(english, chinese)

    /** The group name the model is told about: in Chinese for a Chinese conversation. */
    private val topicCategory: String
        get() = if (language == LearningLanguage.CHINESE) chineseCategory ?: category else category

    // Controls

    /** Starts the conversation with an introduction. */
    fun start() {
        if (phase != Phase.Preparing || messages.isNotEmpty()) return
        generate(AssistantPrompts.introduction(word, topicCategory, language, chinese, facts))
        followUp = AssistantPrompts.introductionQuestion(word, language, chinese)
    }

    /** The child wants to say something. */
    fun talk() {
        cancelTurn()
        listen()
    }

    /** The child finished speaking; send what was heard. */
    fun doneListening() {
        if (phase == Phase.Listening) listener.finish()
    }

    /** Stops whatever is happening and waits for the child. */
    fun cancel() {
        cancelTurn()
        phase = Phase.Ready
    }

    /** A typed question. */
    fun send(text: String) {
        val question = text.trim()
        if (question.isEmpty()) return
        cancelTurn()
        ask(question)
    }

    /** Leaving the screen: stop everything. */
    fun end() {
        cancelTurn()
    }

    // Turns

    private fun cancelTurn() {
        turn += 1
        followUp = null
        listenAfterSpeaking = false
        listener.cancel()
        speaker.stop()
        heard = ""
        note = null
    }

    private fun listen() {
        note = null
        heard = ""
        val current = turn
        try {
            listener.start(
                onPartial = { text -> if (turn == current) heard = text },
                onFinish = { text ->
                    if (turn == current) {
                        if (text != null) {
                            ask(text)
                        } else {
                            heard = ""
                            phase = Phase.Ready
                            note = pick("I didn't hear anything. Tap Talk when you're ready!", "我没有听到。准备好了就点“说话”！")
                        }
                    }
                },
                onError = { error -> if (turn == current) listenFailed(error) },
            )
            phase = Phase.Listening
        } catch (error: ListenError) {
            listenFailed(error)
        }
    }

    private fun listenFailed(error: ListenError) {
        heard = ""
        phase = Phase.Ready
        note = error.message(
            if (listener.language == BookLanguage.CHINESE) LearningLanguage.CHINESE
            else if (language == LearningLanguage.BOTH) LearningLanguage.BOTH else LearningLanguage.ENGLISH,
        )
    }

    private fun ask(question: String) {
        val history = messages.toList()
        messages += ChatMessage(ChatMessage.Speaker.CHILD, question)
        heard = ""
        generate(AssistantPrompts.reply(word, topicCategory, history, question, language, chinese, facts))
    }

    private fun generate(prompt: String) {
        turn += 1
        val current = turn
        phase = if (messages.isEmpty() && engine == null) Phase.Preparing else Phase.Thinking
        replyMessageId = null
        acceptedSentences.clear()
        replyFull = false
        val maxTokens = AssistantPrompts.tokenLimit(language)
        // Only one generation runs at a time; a newer turn waits for the old one to notice it's cancelled.
        worker.execute {
            // Also stops once the reply has every sentence it will use, so no time is spent on the rest.
            val isCancelled = { turn != current || replyFull }
            try {
                if (turn != current) return@execute
                val engine = this.engine ?: makeEngine()
                main {
                    this.engine = engine
                    if (turn == current && phase == Phase.Preparing) phase = Phase.Thinking
                }
                val stream = SentenceStream()
                engine.generate(prompt, maxTokens, isCancelled) { piece ->
                    val sentences = stream.append(piece)
                    if (sentences.isNotEmpty()) main { speak(sentences, current) }
                }
                val rest = stream.finish()
                main { finishReply(rest, current) }
            } catch (_: CancellationException) {
                // A newer turn took over, or the reply is already long enough.
                main { if (turn == current && replyFull) finishReply(emptyList(), current) }
            } catch (error: EngineException) {
                main { if (turn == current) phase = Phase.Failed(error.message(::pick)) }
            } catch (error: Throwable) {
                main {
                    if (turn == current) {
                        phase = Phase.Failed(pick("The talking buddy couldn't start. Please try again.", "小伙伴没能启动。请再试一次。"))
                    }
                }
            }
        }
    }

    /** Speaks finished sentences as soon as they're ready, and shows the reply growing. */
    private fun speak(sentences: List<String>, current: Int) {
        if (turn != current) return
        val accepted = sentences.filter(::accept)
        if (accepted.isEmpty()) return
        accepted.forEach(speaker::enqueue)
        updateBuddyMessage()
        phase = Phase.Speaking
    }

    private fun finishReply(rest: List<String>, current: Int) {
        if (turn != current) return
        val final = rest.filter(::accept).toMutableList()
        if (acceptedSentences.isEmpty()) {
            phase = Phase.Ready
            note = pick("Hmm, I'm not sure what to say. Try asking another way!", "嗯，我不知道该怎么说。换个问法试试吧！")
            return
        }
        followUp?.let {
            followUp = null
            acceptedSentences += it
            final += it
        }
        updateBuddyMessage()
        final.forEach(speaker::enqueue)
        listenAfterSpeaking = true
        if (speaker.isSpeaking) phase = Phase.Speaking else speechFinished()
    }

    /**
     * Keeps replies short. The introduction keeps at most two statements, because the app asks its
     * own question after it. In Bilingual every sentence comes twice, so twice as many.
     */
    private fun accept(sentence: String): Boolean {
        val isQuestion = '?' in sentence || '？' in sentence
        if (replyFull || (followUp != null && isQuestion)) return false
        // In 中文 the buddy sometimes adds an English translation; only the Chinese is said.
        if (language == LearningLanguage.CHINESE && sentence.none { BookLanguage.isHan(it.code) }) return false
        acceptedSentences += sentence
        replyFull = acceptedSentences.size >= sentenceLimit
        return true
    }

    private val sentenceLimit: Int
        get() = (if (followUp == null) 4 else 2) * (if (language == LearningLanguage.BOTH) 2 else 1)

    private fun updateBuddyMessage() {
        val sentences = acceptedSentences.toList()
        val text = AssistantCleanup.clean(sentences.joinToString(" "))
        val index = replyMessageId?.let { id -> messages.indexOfFirst { it.id == id } } ?: -1
        if (index >= 0) {
            messages[index] = messages[index].copy(text = text, sentences = sentences)
        } else {
            val message = ChatMessage(ChatMessage.Speaker.BUDDY, text, sentences)
            replyMessageId = message.id
            messages += message
        }
    }

    private fun speechFinished() {
        if (!listenAfterSpeaking) {
            // Spoke everything so far, but the reply is still being written.
            if (phase == Phase.Speaking) phase = Phase.Thinking
            return
        }
        listenAfterSpeaking = false
        // The buddy just asked a question: it's the child's turn.
        listen()
    }
}
