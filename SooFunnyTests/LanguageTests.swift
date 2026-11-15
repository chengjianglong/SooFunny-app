import XCTest
@testable import SooFunny

final class LearningLanguageTests: XCTestCase {
    func testPickAndSpokenText() {
        XCTAssertEqual(LearningLanguage.english.pick("Next", "下一个"), "Next")
        XCTAssertEqual(LearningLanguage.chinese.pick("Next", "下一个"), "下一个")
        XCTAssertEqual(LearningLanguage.both.pick("Next", "下一个"), "Next · 下一个")

        XCTAssertEqual(LearningLanguage.english.spoken("dog", "狗"), "dog")
        XCTAssertEqual(LearningLanguage.chinese.spoken("dog", "狗"), "狗")
        XCTAssertEqual(LearningLanguage.both.spoken("dog", "狗"), "dog, 狗")
        XCTAssertEqual(LearningLanguage.both.spoken("Yes!", "对啦！"), "Yes! 对啦！")
        // A word with no Chinese is always said in English.
        XCTAssertEqual(LearningLanguage.chinese.spoken("dog", nil), "dog")
    }

    func testBilingualTextSplitsIntoEnglishThenChinese() {
        let runs = BookLanguage.runs(in: LearningLanguage.both.spoken("dog", "狗"))
        XCTAssertEqual(runs.map(\.language), [.english, .chinese])
        XCTAssertEqual(runs.map(\.text), ["dog,", "狗"])
    }
}

final class ChineseWordsTests: XCTestCase {
    func testParsesChineseColumn() throws {
        let text = "Category: Farm | 🚜 | 农场\ncow | 🐮 | 奶牛\nhay |  | 干草\npig | 🐷\n"
        let farm = try XCTUnwrap(WordDictionary.parse(text).first)
        XCTAssertEqual(farm.chinese, "农场")
        XCTAssertEqual(farm.words, [WordEntry(text: "cow", emoji: "🐮", chinese: "奶牛"),
                                    WordEntry(text: "hay", emoji: nil, chinese: "干草"),
                                    WordEntry(text: "pig", emoji: "🐷", chinese: nil)])
    }

    func testEveryBundledWordHasChinese() throws {
        let categories = try WordDictionary.loadBundled(Bundle(for: ColoringSession.self))
        for category in categories {
            XCTAssertTrue(category.chinese?.unicodeScalars.contains(where: \.isHan) == true, category.name)
            for word in category.words {
                let chinese = try XCTUnwrap(word.chinese, "\(word.text) in \(category.name)")
                XCTAssertTrue(chinese.unicodeScalars.allSatisfy(\.isHan), "\(word.text): \(chinese)")
            }
        }
    }
}

final class ChineseMathTests: XCTestCase {
    func testNumbersInChineseWords() {
        let expected = [0: "零", 7: "七", 10: "十", 12: "十二", 20: "二十", 35: "三十五", 100: "一百",
                        105: "一百零五", 110: "一百一十", 144: "一百四十四", 1001: "一千零一"]
        for (number, words) in expected { XCTAssertEqual(ChineseNumber.words(number), words, "\(number)") }
    }

    func testQuestionsAreReadInTheChosenLanguage() {
        let question = MathQuestion(left: 12, right: 3, operation: .multiply)
        XCTAssertEqual(question.spokenQuestion(in: .english), "12 times 3 equals?")
        XCTAssertEqual(question.spokenQuestion(in: .chinese), "十二乘三等于几？")
        XCTAssertEqual(question.spokenQuestion(in: .both), "12 times 3 equals? 十二乘三等于几？")
        XCTAssertEqual(question.spokenAnswer(in: .chinese), "十二乘三等于三十六。")
        // Numbers are in words, so the Chinese part is said entirely in the Chinese voice.
        XCTAssertEqual(BookLanguage.runs(in: question.spokenQuestion(in: .both)).map(\.language), [.english, .chinese])
    }
}

final class ChineseBuddyTests: XCTestCase {
    func testPromptsAskForTheChosenLanguage() {
        let chinese = AssistantPrompts.introduction(word: "lion", category: "动物", language: .chinese, chinese: "狮子")
        XCTAssertTrue(chinese.contains("\"狮子\" (lion in English)"))
        XCTAssertTrue(chinese.contains("Always answer only in simple Mandarin Chinese"))
        let both = AssistantPrompts.reply(word: "lion", category: "Animals", history: [], question: "狮子吃什么？",
                                          language: .both, chinese: "狮子")
        XCTAssertTrue(both.contains("then the same sentence in simple Mandarin"))
        XCTAssertEqual(AssistantPrompts.introductionQuestion(word: "lion", language: .chinese, chinese: "狮子"),
                       "关于狮子，你想知道什么？")
        XCTAssertEqual(AssistantPrompts.introductionQuestion(word: "lion", language: .both, chinese: "狮子"),
                       "What would you like to know about lion? 关于狮子，你想知道什么？")
    }

    func testSentenceStreamSplitsChineseSentences() {
        var stream = SentenceStream()
        XCTAssertEqual(stream.append("狮子是大猫。它们"), ["狮子是大猫。"])
        XCTAssertEqual(stream.append("住在草原上！你"), ["它们住在草原上！"])
        XCTAssertEqual(stream.finish(), ["你"])
    }

    func testWithoutChineseTheBuddyTalksEnglish() {
        let assistant = WordAssistant(word: "UFO", category: "Space", language: .chinese, chinese: nil,
                                      makeEngine: { throw CancellationError() },
                                      speaker: RecordingSpeaker(), listener: SilentListener())
        XCTAssertEqual(assistant.language, .english)
    }

    func testBilingualSpeakerSwitchesVoicesInOrder() {
        let english = RecordingSpeaker(), chinese = RecordingSpeaker()
        let speaker = BilingualSentenceSpeaker(english: english, chinese: chinese)
        var words: [String] = []
        var finished = 0
        speaker.onWord = { sentence, range in words.append((sentence as NSString).substring(with: range)) }
        speaker.onFinished = { finished += 1 }

        speaker.enqueue("A lion roars. 狮子会吼叫。")
        XCTAssertTrue(speaker.isSpeaking)
        XCTAssertEqual(english.spoken, ["A lion roars."])
        XCTAssertEqual(chinese.spoken, [])
        english.say("lion")
        english.finish()
        XCTAssertEqual(chinese.spoken, ["狮子会吼叫。"])
        chinese.say("吼叫")
        chinese.finish()
        XCTAssertEqual(words, ["lion", "吼叫"])
        XCTAssertEqual(finished, 1)
        XCTAssertFalse(speaker.isSpeaking)
    }
}

/// Records what it was asked to say; the test says when each word is spoken and when it's done.
private final class RecordingSpeaker: SentenceSpeaker {
    var onWord: ((String, NSRange) -> Void)?
    var onFinished: (() -> Void)?
    var spoken: [String] = []
    var isSpeaking = false

    func enqueue(_ sentence: String) {
        spoken.append(sentence)
        isSpeaking = true
    }

    func stop() { isSpeaking = false }

    func say(_ word: String) {
        let sentence = spoken.last ?? ""
        onWord?(sentence, (sentence as NSString).range(of: word))
    }

    func finish() {
        isSpeaking = false
        onFinished?()
    }
}

private final class SilentListener: ChildListener {
    var language: BookLanguage = .english
    func start(onPartial: @escaping (String) -> Void, onFinish: @escaping (String?) -> Void) throws {}
    func finish() {}
    func cancel() {}
}

final class ChineseCleanupTests: XCTestCase {
    func testSpacesBetweenChineseWordsAreRemoved() {
        XCTAssertEqual(AssistantCleanup.clean("狗 是 动物。 狗 很 可爱。"), "狗是动物。狗很可爱。")
        XCTAssertEqual(AssistantCleanup.clean("A dog is a pet. 狗 是 宠物。"), "A dog is a pet. 狗是宠物。")
        XCTAssertEqual(AssistantCleanup.clean("Dog. 狗 (gǒu) is a pet."), "Dog. 狗 is a pet.")
    }
}

final class ChineseBuddyFlowTests: XCTestCase {
    func testChineseBuddyLeavesOutEnglishTranslations() {
        let engine = ScriptedEngine("熊猫主要吃竹子。 Pandas mainly eat bamboo. 熊猫很可爱。")
        let speaker = RecordingSpeaker()
        let assistant = WordAssistant(word: "panda", category: "Animals", language: .chinese, chinese: "熊猫",
                                      makeEngine: { engine }, speaker: speaker, listener: SilentListener())
        assistant.start()
        let deadline = Date().addingTimeInterval(5)
        while speaker.spoken.count < 3 && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        XCTAssertEqual(speaker.spoken, ["熊猫主要吃竹子。", "熊猫很可爱。", "关于熊猫，你想知道什么？"])
    }
}

private final class ScriptedEngine: LanguageEngine {
    let reply: String
    init(_ reply: String) { self.reply = reply }

    func generate(prompt: String, maxTokens: Int, isCancelled: @escaping () -> Bool,
                  onText: @escaping (String) -> Void) throws -> String {
        for piece in reply.split(separator: " ") {
            if isCancelled() { throw CancellationError() }
            onText(String(piece) + " ")
        }
        return reply
    }
}

final class BooksAndColorLanguageTests: XCTestCase {
    func testEveryStoryBookIsInBothLanguages() {
        for book in StoryLibrary.books {
            XCTAssertNotEqual(book.englishTitle, book.chineseTitle, book.id)
            XCTAssertTrue(book.chineseTitle.unicodeScalars.contains(where: \.isHan), book.id)
            for index in book.pages.indices {
                let english = book.pageText(index, in: .english), chinese = book.pageText(index, in: .chinese)
                XCTAssertEqual(BookLanguage.detect(english), .english, "\(book.id) page \(index + 1)")
                XCTAssertEqual(BookLanguage.detect(chinese), .chinese, "\(book.id) page \(index + 1)")
                XCTAssertEqual(book.pageText(index, in: .both), english + "\n\n" + chinese)
            }
        }
    }

    func testShelfHasTheTortoiseStoryOnce() {
        for language in LearningLanguage.allCases {
            let titles = StoryBook.shelf(in: language).map { $0.title(in: language) }
            XCTAssertEqual(Set(titles).count, titles.count, "\(language)")
        }
        XCTAssertTrue(StoryBook.shelf(in: .chinese).contains { $0.id == "tortoise-and-hare-zh" })
        XCTAssertFalse(StoryBook.shelf(in: .english).contains { $0.id == "tortoise-and-hare-zh" })
    }

    func testEveryPictureHasAChineseName() {
        let names = Showcase.credits.map(\.title) + SampleArt.all.map(\.name)
        for name in names { XCTAssertNotNil(Showcase.chineseTitles[name], name) }
        for kind in PictureKind.allCases {
            XCTAssertTrue(kind.chineseTitle.unicodeScalars.allSatisfy(\.isHan), kind.rawValue)
        }
    }
}
