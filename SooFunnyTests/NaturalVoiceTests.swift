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
