import XCTest
@testable import SooFunny

final class ChineseG2PTests: XCTestCase {
    private static let g2p = try? ChineseG2P(bundle: Bundle(for: ColoringSession.self), english: { "<" + $0 + ">" })

    /// misaki's own output for every Chinese string in the app (plus some buddy-style sentences),
    /// made with misaki 0.9.4. The Swift port should say every one of them the same way.
    func testMatchesMisakiOnAllAppText() throws {
        let g2p = try XCTUnwrap(Self.g2p, "Chinese data not bundled")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "zh_g2p_expected", withExtension: "json"))
        let expected = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String])
        var wrong: [String] = []
        for (text, phonemes) in expected.sorted(by: { $0.key < $1.key }) {
            let got = g2p.phonemize(text)
            if got != phonemes { wrong.append("\(text)\n  misaki \(phonemes)\n  swift  \(got)") }
        }
        print("ChineseG2P: \(expected.count - wrong.count)/\(expected.count) match")
        for w in wrong.prefix(20) { print(w) }
        XCTAssertTrue(wrong.isEmpty, "\(wrong.count) differ")
    }

    func testNumbersAndPunctuation() {
        XCTAssertEqual(ChineseG2P.numbersToChinese("175个"), "一百七十五个")
        XCTAssertEqual(ChineseG2P.numbersToChinese("3.5"), "三点五")
        XCTAssertEqual(ChineseG2P.numbersToChinese("50%"), "百分之五十")
        XCTAssertEqual(ChineseG2P.numbersToChinese("105"), "一百零五")
        XCTAssertEqual(ChineseG2P.mapPunctuation("你好，世界。"), "你好, 世界.")
    }

    func testSyllables() {
        XCTAssertEqual(ChineseG2P.splitSyllable("yu2").1, "v2")
        XCTAssertEqual(ChineseG2P.splitSyllable("you3").1, "iou3")
        XCTAssertEqual(ChineseG2P.splitSyllable("wei4").1, "uei4")
        XCTAssertEqual(ChineseG2P.splitSyllable("ju4").1, "v4")
        XCTAssertEqual(ChineseG2P.splitSyllable("gui4").1, "uei4")
        XCTAssertEqual(ChineseG2P.splitSyllable("zhang1").0, "zh")
    }

    func testSpeedForABuddySentence() throws {
        let g2p = try XCTUnwrap(Self.g2p)
        measure { _ = g2p.phonemize("狗狗摇尾巴是因为它们高兴或兴奋，我们一起去公园玩吧！") }
    }
}

final class ChineseVoiceTests: XCTestCase {
    func testEveryChineseVoiceSpeaks() throws {
        let bundle = Bundle(for: ColoringSession.self)
        try XCTSkipIf(bundle.url(forResource: KokoroTTS.chineseModelName, withExtension: "onnx") == nil,
                      "Chinese model not bundled; run scripts/fetch_model.sh")
        let tts = try KokoroTTS(language: .chinese, bundle: bundle)
        for voice in KokoroTTS.chineseVoices {
            try tts.setVoice(voice)
            let start = Date()
            let samples = KokoroTTS.trimmingSilence(try tts.synthesize("你好！我们一起来学习吧。"))
            let seconds = Double(samples.count) / KokoroTTS.sampleRate
            print("Chinese \(voice): \(String(format: "%.2f", seconds)) s of speech in \(String(format: "%.2f", Date().timeIntervalSince(start))) s")
            XCTAssertGreaterThan(seconds, 1.0, voice)
            XCTAssertLessThan(seconds, 5.0, voice)
            XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.05, voice)
        }
        // English words inside Chinese are said too.
        XCTAssertGreaterThan(tts.tokenIDs(for: "我喜欢 SooFunny。").count, tts.tokenIDs(for: "我喜欢。").count + 4)
    }

    func testChinesePhrasesSplitLongSentencesAtCommas() {
        let phrases = NaturalVoice.phrases(in: "小朋友们在公园里跑来跑去，玩得很开心，最后大家一起回家吃晚饭。")
        XCTAssertGreaterThan(phrases.count, 1)
        XCTAssertEqual(phrases.map(\.text).joined(), "小朋友们在公园里跑来跑去，玩得很开心，最后大家一起回家吃晚饭。")
        XCTAssertEqual(NaturalVoice.phrases(in: "狗").map(\.text), ["狗"])
    }
}
