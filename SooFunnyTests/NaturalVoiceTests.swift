import AVFoundation
import XCTest
@testable import SooFunny

final class KokoroPhonemizerTests: XCTestCase {
    private static var shared: KokoroPhonemizer?

    private func phonemizer() throws -> KokoroPhonemizer {
        if let p = Self.shared { return p }
        let bundle = Bundle(for: ColoringSession.self)
        let p = try KokoroPhonemizer(
            lexiconURL: try XCTUnwrap(bundle.url(forResource: "kokoro_lexicon", withExtension: "tsv")),
            vocabURL: try XCTUnwrap(bundle.url(forResource: "kokoro_vocab", withExtension: "tsv")))
        Self.shared = p
        return p
    }

    func testMatchesMisakiForBuddySentences() throws {
        let p = try phonemizer()
        // Expected values come from the reference pipeline (misaki dictionaries + rules).
        XCTAssertEqual(p.phonemize("A lion is a big, strong cat."), "ɐ lˈIən ɪz ɐ bˈɪɡ, stɹˈɔŋ kˈæt.")
        XCTAssertEqual(p.phonemize("What would you like to know about lion?"), "wˌʌt wʊd ju lˈIk tə nˈO əbˈWt lˈIən?")
        XCTAssertEqual(p.phonemize("Lions eat meat. They hunt zebras and wildebeest on the savanna!"),
                       "lˈIənz ˈit mˈit. ðA hˈʌnt zˈibɹəz ænd wˈɪldəbˌist ˌɔn ðə səvˈænə!")
        XCTAssertEqual(p.phonemize("Great job! You got it."), "ɡɹˈAt ʤˈɑb! ju ɡɑt ɪt.")
    }

    func testFunctionWordsNumbersEndingsAndLetters() throws {
        let p = try phonemizer()
        XCTAssertEqual(p.phonemize("the apple"), p.phonemize("thee apple").replacingOccurrences(of: "ðˈi", with: "ði"),
                       "'the' before a vowel is 'thee'")
        XCTAssertTrue(p.phonemize("the cat").hasPrefix("ðə "))
        XCTAssertEqual(p.phonemize("12 + 7"), p.phonemize("twelve seven"), "digits become words")
        XCTAssertTrue(p.phonemize("jumped").hasSuffix("t"), "-ed after p sounds like t")
        XCTAssertTrue(p.phonemize("painting").hasSuffix("ɾɪŋ") || p.phonemize("painting").hasSuffix("tɪŋ"))
        XCTAssertEqual(p.phonemize("B"), "bˈi", "a single letter is said as its name")
        XCTAssertEqual(p.phonemize("a"), "ˈA", "the letter a alone is 'ay', not 'uh'")
        XCTAssertFalse(p.phonemize("zxqv").isEmpty, "unknown words are spelled out")
        XCTAssertTrue(p.phonemize("I can").hasPrefix("ˌI"))
    }

    func testEveryWordInTheWordListCanBeSaid() throws {
        let p = try phonemizer()
        let categories = try WordDictionary.loadBundled(Bundle(for: ColoringSession.self))
        for word in categories.flatMap(\.words) {
            XCTAssertGreaterThan(p.tokenIDs(for: p.phonemize(word.text)).count, 2, word.text)
        }
    }

    func testWordHighlightMovesThroughTheSentence() {
        let sentence = "Lions eat meat."
        let ns = sentence as NSString
        XCTAssertEqual(ns.substring(with: NaturalVoice.wordRange(in: sentence, at: 0)!), "Lions")
        XCTAssertEqual(ns.substring(with: NaturalVoice.wordRange(in: sentence, at: 0.5)!), "eat")
        XCTAssertEqual(ns.substring(with: NaturalVoice.wordRange(in: sentence, at: 1)!), "meat")
    }
}

final class KokoroTTSTests: XCTestCase {
    func testSynthesizesTheSameSpeechAsTheReference() throws {
        try XCTSkipIf(Bundle(for: ColoringSession.self).url(forResource: KokoroTTS.modelName, withExtension: "onnx") == nil,
                      "Voice model not bundled; run scripts/fetch_model.sh")
        let tts = try KokoroTTS(bundle: Bundle(for: ColoringSession.self))
        let start = Date()
        let samples = try tts.synthesize("A lion is a big, strong cat.")
        let seconds = Date().timeIntervalSince(start)
        let audio = Double(samples.count) / KokoroTTS.sampleRate
        let rms = sqrt(samples.reduce(0) { $0 + Double($1 * $1) } / Double(max(1, samples.count)))
        print("KOKORO \(samples.count) samples, \(String(format: "%.2f", audio)) s audio in \(String(format: "%.2f", seconds)) s, rms \(rms)")
        // The Python/ONNX reference makes 58,200 samples (2.43 s) with RMS 0.063 for this sentence.
        // Kokoro times speech in 600-sample steps, and ONNX Runtime builds can round a step or two
        // differently, so allow four steps.
        XCTAssertEqual(samples.count, 58_200, accuracy: 2_400)
        XCTAssertEqual(rms, 0.063, accuracy: 0.01)
        XCTAssertLessThan(seconds, audio, "faster than real time")
    }

    func testSlowerSpeedMakesLongerAudio() throws {
        try XCTSkipIf(Bundle(for: ColoringSession.self).url(forResource: KokoroTTS.modelName, withExtension: "onnx") == nil,
                      "Voice model not bundled; run scripts/fetch_model.sh")
        let tts = try KokoroTTS(bundle: Bundle(for: ColoringSession.self))
        let normal = try tts.synthesize("What would you like to know?", speed: 1)
        let slow = try tts.synthesize("What would you like to know?", speed: 0.8)
        XCTAssertGreaterThan(slow.count, normal.count)
    }
}

final class NaturalVoicePhraseTests: XCTestCase {
    func testShortSentencesStayWholeWithAPauseAfter() {
        let phrases = NaturalVoice.phrases(in: "Lions eat meat.")
        XCTAssertEqual(phrases.map(\.text), ["Lions eat meat."])
        XCTAssertEqual(phrases.last?.gap ?? 0, 0.22, accuracy: 0.001)
    }

    func testLongSentencesSplitAtCommasIntoNaturalPhrases() {
        let sentence = "A lion is a big wild cat, with a fluffy mane, and it lives in Africa."
        let phrases = NaturalVoice.phrases(in: sentence)
        XCTAssertEqual(phrases.map(\.text), ["A lion is a big wild cat,", "with a fluffy mane,", "and it lives in Africa."])
        XCTAssertEqual(phrases.map(\.gap), [0.12, 0.12, 0.22])
        for phrase in phrases { XCTAssertTrue(sentence.contains(phrase.text), "highlighting finds \(phrase.text)") }
    }

    func testTinyLastPhraseJoinsThePreviousOne() {
        let phrases = NaturalVoice.phrases(in: "They like to eat zebras and other big animals, too.")
        XCTAssertEqual(phrases.map(\.text), ["They like to eat zebras and other big animals, too."])
    }

    func testTrimmingRemovesSilenceButKeepsTheSound() {
        let silence = [Float](repeating: 0, count: 9_000)
        let sound = (0..<2_400).map { sin(Float($0) / 5) * 0.3 }
        let trimmed = KokoroTTS.trimmingSilence(silence + sound + silence + silence)
        XCTAssertLessThan(trimmed.count, sound.count + 2_400, "at most 0.1 s of padding is kept")
        XCTAssertGreaterThanOrEqual(trimmed.count, sound.count - 20)
    }
}

final class VoiceChoiceTests: XCTestCase {
    func testNoveltyVoicesAreHiddenAndResetToTheNaturalVoice() throws {
        let novelty = AVSpeechSynthesisVoice.speechVoices().first { $0.voiceTraits.contains(.isNoveltyVoice) }
        try XCTSkipIf(novelty == nil, "No novelty voices installed here")
        XCTAssertFalse(Speech.englishVoices.contains { $0.voiceTraits.contains(.isNoveltyVoice) })

        let defaults = try XCTUnwrap(UserDefaults(suiteName: "VoiceChoiceTests"))
        defaults.set(novelty!.identifier, forKey: SettingsKey.voice)
        Speech.resetUnsuitableVoice(defaults)
        XCTAssertNil(defaults.string(forKey: SettingsKey.voice), "a novelty voice goes back to the natural voice")

        if let normal = Speech.englishVoices.first {
            defaults.set(normal.identifier, forKey: SettingsKey.voice)
            Speech.resetUnsuitableVoice(defaults)
            XCTAssertEqual(defaults.string(forKey: SettingsKey.voice), normal.identifier, "a normal voice choice is kept")
        }
        defaults.removePersistentDomain(forName: "VoiceChoiceTests")
    }
}

final class VoiceSpeedTests: XCTestCase {
    func testDefaultSpeedIsLivelyNotDragging() throws {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: SettingsKey.speechRate)
        defer { defaults.set(saved, forKey: SettingsKey.speechRate) }
        defaults.removeObject(forKey: SettingsKey.speechRate)
        XCTAssertEqual(NaturalVoiceEngine.speed, 1.05, accuracy: 0.01, "the default reads at about 1.05x")
        defaults.set(0.5262573778629303, forKey: SettingsKey.speechRate)
        XCTAssertEqual(NaturalVoiceEngine.speed, 1.047, accuracy: 0.01, "a saved choice is kept as it was")
    }
}
