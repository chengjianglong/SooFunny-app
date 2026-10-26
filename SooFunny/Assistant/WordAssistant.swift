import Foundation
import Observation

/// One spoken conversation about a word, like a patient buddy:
/// it introduces the word, asks what the child wants to know, listens, and answers.
///
/// Turn flow: preparing → speaking → listening → thinking → speaking → listening …
/// The child can stop at any point; Talk starts a new turn with the conversation so far.
@Observable
final class WordAssistant {
    enum Phase: Equatable {
        case preparing, speaking, listening, thinking, ready
        case failed(String)
    }

    let word: String
    let category: String

    private(set) var phase: Phase = .preparing
    private(set) var messages: [ChatMessage] = []
    /// The sentence being read aloud and the word in it being said, for highlighting.
    private(set) var spokenSentence: String?
    private(set) var spokenRange: NSRange?
    /// What the listener has heard so far in this turn.
    private(set) var heard = ""
    /// A gentle note shown under the controls (e.g. "I didn't hear anything").
    private(set) var note: String?

    /// True while speaking, listening or thinking: keeps the screen awake and the button green.
    var isActive: Bool { phase == .speaking || phase == .listening || phase == .thinking }

    @ObservationIgnored private let makeEngine: () throws -> LanguageEngine
    @ObservationIgnored private let speaker: SentenceSpeaker
    @ObservationIgnored private let listener: ChildListener
    @ObservationIgnored private let queue = DispatchQueue(label: "SooFunny.Gemma", qos: .userInitiated)
    @ObservationIgnored private var engine: LanguageEngine?
    /// Bumped to cancel the current turn; work from an old turn checks it and stops.
    @ObservationIgnored private var turn = 0
    @ObservationIgnored private var listenAfterSpeaking = false
    /// Said after the current reply finishes (the question that follows the introduction).
    @ObservationIgnored private var followUp: String?
    /// Sentences of the current reply that are being said and shown.
    @ObservationIgnored private var acceptedSentences: [String] = []
    /// The buddy message the current reply is being written into.
    @ObservationIgnored private var replyMessageID: UUID?

    /// The model is loaded once and shared by every conversation.
    @ObservationIgnored private static var sharedEngine: LanguageEngine?

    init(word: String, category: String,
         makeEngine: @escaping () throws -> LanguageEngine = { try WordAssistant.loadSharedEngine() },
         speaker: SentenceSpeaker = NaturalVoice(),
         listener: ChildListener = SystemChildListener()) {
        self.word = word
        self.category = category
        self.makeEngine = makeEngine
        self.speaker = speaker
        self.listener = listener
        speaker.onWord = { [weak self] sentence, range in
            self?.spokenSentence = sentence
            self?.spokenRange = range
        }
        speaker.onFinished = { [weak self] in self?.speechFinished() }
    }

    static func loadSharedEngine() throws -> LanguageEngine {
        if let sharedEngine { return sharedEngine }
        let engine = try GemmaEngine()
        sharedEngine = engine
        return engine
    }

    // MARK: - Controls

    /// Starts the conversation with an introduction.
    func start() {
        guard phase == .preparing, messages.isEmpty else { return }
        generate(prompt: AssistantPrompts.introduction(word: word, category: category))
        followUp = AssistantPrompts.introductionQuestion(word: word)
    }

    /// The child wants to say something.
    func talk() {
        cancelTurn()
        listen()
    }

    /// The child finished speaking; send what was heard.
    func doneListening() {
        guard phase == .listening else { return }
        listener.finish()
    }

    /// Stops whatever is happening and waits for the child.
    func cancel() {
        cancelTurn()
        phase = .ready
    }

    /// A typed question.
    func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        cancelTurn()
        ask(question)
    }

    /// Leaving the screen: stop everything.
    func end() {
        cancelTurn()
        AssistantAudioSession.deactivate()
    }

    // MARK: - Turns

    private func cancelTurn() {
        turn += 1
        followUp = nil
        listenAfterSpeaking = false
        listener.cancel()
        speaker.stop()
        spokenSentence = nil
        spokenRange = nil
        heard = ""
        note = nil
    }

    private func listen() {
        note = nil
        heard = ""
        let current = turn
        do {
            try listener.start(onPartial: { [weak self] text in
                guard let self, self.turn == current else { return }
                self.heard = text
            }, onFinish: { [weak self] text in
                guard let self, self.turn == current else { return }
                if let text {
                    self.ask(text)
                } else {
                    self.heard = ""
                    self.phase = .ready
                    self.note = "I didn't hear anything. Tap Talk when you're ready!"
                }
            })
            phase = .listening
        } catch {
            phase = .ready
            note = error.localizedDescription
        }
    }

    private func ask(_ question: String) {
        let history = messages
        messages.append(ChatMessage(speaker: .child, text: question))
        heard = ""
        generate(prompt: AssistantPrompts.reply(word: word, category: category, history: history, question: question))
    }

    private func generate(prompt: String) {
        turn += 1
        let current = turn
        phase = messages.isEmpty && engine == nil ? .preparing : .thinking
        // Only one generation runs at a time; a newer turn waits for the old one to notice it's cancelled.
        replyMessageID = nil
        acceptedSentences = []
        queue.async { [weak self] in
            guard let self else { return }
            let isCancelled = { [weak self] in
                guard let self else { return true }
                return DispatchQueue.main.sync { self.turn != current }
            }
            do {
                let engine = try self.engine ?? self.makeEngine()
                DispatchQueue.main.sync {
                    self.engine = engine
                    if self.turn == current { self.phase = .thinking }
                }
                var stream = SentenceStream()
                _ = try engine.generate(prompt: prompt, maxTokens: AssistantPrompts.replyTokenLimit,
                                        isCancelled: isCancelled) { piece in
                    let sentences = stream.append(piece)
                    guard !sentences.isEmpty else { return }
                    DispatchQueue.main.async { self.speak(sentences, turn: current) }
                }
                let rest = stream.finish()
                DispatchQueue.main.async { self.finishReply(rest, turn: current) }
            } catch is CancellationError {
                // A newer turn took over.
            } catch {
                DispatchQueue.main.async {
                    guard self.turn == current else { return }
                    self.phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// Speaks finished sentences as soon as they're ready, and shows the reply growing.
    private func speak(_ sentences: [String], turn current: Int) {
        guard turn == current else { return }
        let accepted = sentences.filter(accept)
        guard !accepted.isEmpty else { return }
        for sentence in accepted { speaker.enqueue(sentence) }
        updateBuddyMessage(acceptedSentences.joined(separator: " "))
        phase = .speaking
    }

    private func finishReply(_ rest: [String], turn current: Int) {
        guard turn == current else { return }
        var final = rest.filter(accept)
        guard !acceptedSentences.isEmpty else {
            phase = .ready
            note = "Hmm, I'm not sure what to say. Try asking another way!"
            return
        }
        if let followUp {
            self.followUp = nil
            acceptedSentences.append(followUp)
            final.append(followUp)
        }
        updateBuddyMessage(acceptedSentences.joined(separator: " "))
        for sentence in final { speaker.enqueue(sentence) }
        listenAfterSpeaking = true
        if speaker.isSpeaking {
            phase = .speaking
        } else {
            speechFinished()
        }
    }

    /// Keeps replies short. The introduction keeps at most two statements, because the
    /// app asks its own question after it.
    private func accept(_ sentence: String) -> Bool {
        let limit = followUp == nil ? 4 : 2
        guard acceptedSentences.count < limit, followUp == nil || !sentence.contains("?") else { return false }
        acceptedSentences.append(sentence)
        return true
    }

    private func updateBuddyMessage(_ reply: String) {
        let text = AssistantCleanup.clean(reply)
        if let id = replyMessageID, let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].text = text
        } else {
            let message = ChatMessage(speaker: .buddy, text: text)
            replyMessageID = message.id
            messages.append(message)
        }
    }

    private func speechFinished() {
        spokenSentence = nil
        spokenRange = nil
        guard listenAfterSpeaking else {
            // Spoke everything so far, but the reply is still being written.
            if phase == .speaking { phase = .thinking }
            return
        }
        listenAfterSpeaking = false
        // The buddy just asked a question: it's the child's turn.
        listen()
    }
}
