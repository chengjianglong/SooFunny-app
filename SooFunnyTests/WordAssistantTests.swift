import XCTest
@testable import SooFunny

final class AssistantTextTests: XCTestCase {
    func testSentenceStreamEmitsCompleteSentences() {
        var stream = SentenceStream()
        XCTAssertEqual(stream.append("A lion is a big"), [])
        XCTAssertEqual(stream.append(" cat. What would"), ["A lion is a big cat."])
        XCTAssertEqual(stream.append(" you like to know? Lions"), ["What would you like to know?"])
        XCTAssertEqual(stream.finish(), ["Lions"])
        XCTAssertEqual(stream.finish(), [])
    }

    func testCleanupRemovesMarkdownEmojiAndLabels() {
        XCTAssertEqual(AssistantCleanup.clean("Buddy: **Lions** roar! 🦁"), "Lions roar!")
        XCTAssertEqual(AssistantCleanup.clean("  It's  3:00 and   fun.\n"), "It's 3:00 and fun.")
    }

    func testPromptsUseGemmaTurnsAndIncludeContext() {
        let intro = AssistantPrompts.introduction(word: "lion", category: "Animals")
        XCTAssertTrue(intro.hasPrefix("<start_of_turn>user\n"))
        XCTAssertTrue(intro.hasSuffix("<start_of_turn>model\n"))
        XCTAssertTrue(intro.contains("tell the child what \"lion\" is"))
        XCTAssertEqual(AssistantPrompts.introductionQuestion(word: "lion"), "What would you like to know about lion?")

        let history = [ChatMessage(speaker: .buddy, text: "A lion is a big cat."),
                       ChatMessage(speaker: .child, text: "What do lions eat?")]
        let reply = AssistantPrompts.reply(word: "lion", category: "Animals", history: history, question: "Do they sleep?")
        XCTAssertTrue(reply.contains("Buddy: A lion is a big cat.\nChild: What do lions eat?\nChild: Do they sleep?"))
    }
}

// MARK: - Turn flow with fakes

private final class FakeEngine: LanguageEngine {
    var replies: [String]
    var prompts: [String] = []
    init(_ replies: [String]) { self.replies = replies }

    func generate(prompt: String, maxTokens: Int, isCancelled: @escaping () -> Bool,
                  onText: @escaping (String) -> Void) throws -> String {
        prompts.append(prompt)
        let reply = replies.isEmpty ? "" : replies.removeFirst()
        for word in reply.split(separator: " ", omittingEmptySubsequences: false) {
            if isCancelled() { throw CancellationError() }
            onText(String(word) + " ")
        }
        return reply
    }
}

private final class FakeSpeaker: SentenceSpeaker {
    var onWord: ((String, NSRange) -> Void)?
    var onFinished: (() -> Void)?
    var spoken: [String] = []
    private var queued = 0
    var isSpeaking: Bool { queued > 0 }

    func enqueue(_ sentence: String) {
        spoken.append(sentence)
        queued += 1
        DispatchQueue.main.async {
            self.onWord?(sentence, NSRange(location: 0, length: 1))
            self.queued -= 1
            if self.queued == 0 { self.onFinished?() }
        }
    }

    func stop() { queued = 0 }
}

private final class FakeListener: ChildListener {
    var starts = 0
    var onFinish: ((String?) -> Void)?
    var onStart: (() -> Void)?

    func start(onPartial: @escaping (String) -> Void, onFinish: @escaping (String?) -> Void) throws {
        starts += 1
        self.onFinish = onFinish
        onStart?()
    }

    func finish() {}
    func cancel() { onFinish = nil }

    func say(_ text: String?) {
        let callback = onFinish
        onFinish = nil
        callback?(text)
    }
}

final class WordAssistantFlowTests: XCTestCase {
    private func waitUntil(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition(), "timed out")
    }

    func testIntroductionIsSpokenThenListens() {
        let engine = FakeEngine(["A lion is a big cat."])
        let speaker = FakeSpeaker(), listener = FakeListener()
        let assistant = WordAssistant(word: "lion", category: "Animals", makeEngine: { engine },
                                      speaker: speaker, listener: listener)
        assistant.start()
        waitUntil { assistant.phase == .listening }
        XCTAssertEqual(speaker.spoken, ["A lion is a big cat.", "What would you like to know about lion?"])
        XCTAssertEqual(assistant.messages.map(\.text), ["A lion is a big cat. What would you like to know about lion?"])
        XCTAssertEqual(listener.starts, 1)
    }

    func testIntroductionDropsTheModelsOwnQuestionsAndExtraSentences() {
        let engine = FakeEngine(["A rat is a small animal. Do you like rats? It has a long tail. It squeaks. It runs."])
        let speaker = FakeSpeaker(), listener = FakeListener()
        let assistant = WordAssistant(word: "rat", category: "Animals", makeEngine: { engine },
                                      speaker: speaker, listener: listener)
        assistant.start()
        waitUntil { assistant.phase == .listening }
        XCTAssertEqual(speaker.spoken, ["A rat is a small animal.", "It has a long tail.", "What would you like to know about rat?"])
        XCTAssertEqual(assistant.messages.last?.text, "A rat is a small animal. It has a long tail. What would you like to know about rat?")
    }

    func testChildQuestionGetsAnAnswerWithHistory() {
        let engine = FakeEngine(["A lion is a big cat.", "Lions eat meat. Want to know more?"])
        let speaker = FakeSpeaker(), listener = FakeListener()
        let assistant = WordAssistant(word: "lion", category: "Animals", makeEngine: { engine },
                                      speaker: speaker, listener: listener)
        assistant.start()
        waitUntil { assistant.phase == .listening }
        listener.say("What do lions eat?")
        waitUntil { assistant.messages.count == 3 && assistant.phase == .listening }
        XCTAssertEqual(assistant.messages.map(\.speaker), [.buddy, .child, .buddy])
        XCTAssertEqual(assistant.messages.last?.text, "Lions eat meat. Want to know more?")
        XCTAssertTrue(engine.prompts[1].contains("Buddy: A lion is a big cat. What would you like to know about lion?"))
        XCTAssertTrue(engine.prompts[1].hasSuffix("Child: What do lions eat?\nAnswer the child's last message as the Buddy.<end_of_turn>\n<start_of_turn>model\n"))
    }

    func testSilenceReturnsToReadyWithANote() {
        let engine = FakeEngine(["Hi there. What would you like to know?"])
        let listener = FakeListener()
        let assistant = WordAssistant(word: "cat", category: "Animals", makeEngine: { engine },
                                      speaker: FakeSpeaker(), listener: listener)
        assistant.start()
        waitUntil { assistant.phase == .listening }
        listener.say(nil)
        XCTAssertEqual(assistant.phase, .ready)
        XCTAssertNotNil(assistant.note)
    }

    func testCancelStopsWithoutListening() {
        let engine = FakeEngine(["One. Two. Three."])
        let speaker = FakeSpeaker(), listener = FakeListener()
        let assistant = WordAssistant(word: "cat", category: "Animals", makeEngine: { engine },
                                      speaker: speaker, listener: listener)
        assistant.start()
        assistant.cancel()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(assistant.phase, .ready)
        XCTAssertEqual(listener.starts, 0)
    }

    func testTypedQuestionIsAnswered() {
        let engine = FakeEngine(["A cat is a furry pet.", "Cats purr when happy. Do you have a cat?"])
        let listener = FakeListener()
        let assistant = WordAssistant(word: "cat", category: "Animals", makeEngine: { engine },
                                      speaker: FakeSpeaker(), listener: listener)
        assistant.start()
        waitUntil { assistant.phase == .listening }
        assistant.send("Why do cats purr?")
        waitUntil { assistant.messages.count == 3 && assistant.phase == .listening }
        XCTAssertEqual(assistant.messages[1].text, "Why do cats purr?")
    }

    func testEngineErrorIsShown() {
        let assistant = WordAssistant(word: "cat", category: "Animals",
                                      makeEngine: { throw GemmaEngine.EngineError.modelMissing },
                                      speaker: FakeSpeaker(), listener: FakeListener())
        assistant.start()
        waitUntil { if case .failed = assistant.phase { return true } else { return false } }
    }
}

// MARK: - The real model

final class GemmaEngineTests: XCTestCase {
    func testGemmaIntroducesAWord() throws {
        let url = Bundle(for: ColoringSession.self).url(forResource: GemmaEngine.modelName, withExtension: "gguf")
        try XCTSkipIf(url == nil, "Model not bundled; run scripts/fetch_model.sh")
        let engine = try GemmaEngine(modelURL: url)
        var pieces = 0
        let start = Date()
        let text = try engine.generate(prompt: AssistantPrompts.introduction(word: "lion", category: "Animals"),
                                       maxTokens: AssistantPrompts.replyTokenLimit, isCancelled: { false }) { _ in pieces += 1 }
        print("GEMMA (\(String(format: "%.1f", Date().timeIntervalSince(start)))s, \(pieces) pieces): \(text)")
        XCTAssertGreaterThan(pieces, 5)
        XCTAssertTrue(text.lowercased().contains("lion"), text)
        XCTAssertFalse(text.contains("<end_of_turn>"), text)
    }

    /// Prints sample conversations to review answer quality (see the test log).
    func testGemmaSampleConversations() throws {
        let url = Bundle(for: ColoringSession.self).url(forResource: GemmaEngine.modelName, withExtension: "gguf")
        try XCTSkipIf(url == nil, "Model not bundled; run scripts/fetch_model.sh")
        let engine = try GemmaEngine(modelURL: url)
        for (word, category) in [("rat", "Animals"), ("rainbow", "Weather"), ("happy", "Feelings"), ("broccoli", "Vegetables")] {
            let intro = try engine.generate(prompt: AssistantPrompts.introduction(word: word, category: category),
                                            maxTokens: AssistantPrompts.replyTokenLimit, isCancelled: { false }) { _ in }
            print("GEMMA intro \(word): \(AssistantCleanup.clean(intro))")
        }
        let history = [ChatMessage(speaker: .buddy, text: "A lion is a big wild cat with a fluffy mane. What would you like to know about lion?")]
        let answer = try engine.generate(prompt: AssistantPrompts.reply(word: "lion", category: "Animals", history: history,
                                                                       question: "What does a lion eat?"),
                                         maxTokens: AssistantPrompts.replyTokenLimit, isCancelled: { false }) { _ in }
        print("GEMMA reply lion: \(AssistantCleanup.clean(answer))")
        XCTAssertFalse(answer.isEmpty)
    }

    func testGemmaStopsWhenCancelled() throws {
        let url = Bundle(for: ColoringSession.self).url(forResource: GemmaEngine.modelName, withExtension: "gguf")
        try XCTSkipIf(url == nil, "Model not bundled; run scripts/fetch_model.sh")
        let engine = try GemmaEngine(modelURL: url)
        var pieces = 0
        XCTAssertThrowsError(try engine.generate(prompt: AssistantPrompts.introduction(word: "cat", category: "Animals"),
                                                 maxTokens: 100, isCancelled: { pieces >= 3 }) { _ in pieces += 1 }) {
            XCTAssertTrue($0 is CancellationError)
        }
        XCTAssertEqual(pieces, 3)
    }
}
