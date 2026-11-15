import Foundation
import OnnxRuntimeBindings

/// Kokoro-82M (Apache-2.0), a natural-sounding neural voice, run on the device with
/// ONNX Runtime. Makes 24 kHz mono audio from text, offline. English uses Kokoro v1.0 with the
/// "Heart" voice; Chinese uses Kokoro v1.1-zh with a voice chosen in Settings.
///
/// Not thread-safe: use it from one serial queue (`NaturalVoice` does).
final class KokoroTTS {
    enum Language { case english, chinese }

    static let sampleRate = 24_000.0
    static let modelName = "kokoro-82m-q8"
    static let voiceName = "kokoro_af_heart"
    static let chineseModelName = "kokoro-v1.1-zh-fp16"
    /// The Chinese voices offered in Settings, the first being the default.
    static let chineseVoices = ["zf_001", "zf_017", "zf_032", "zf_049", "zf_094"]
    /// Kokoro reads at most 510 phoneme tokens at a time.
    private static let maxTokens = 510

    enum TTSError: Error {
        case missingResources
        case badOutput
    }

    let language: Language
    let phonemizer: KokoroPhonemizer
    private let chinese: ChineseG2P?
    private let chineseVocab: [Character: Int64]
    private let bundle: Bundle
    private let env: ORTEnv
    private let session: ORTSession
    /// The voice in use, and its style: one 256-number style per possible input length (510 × 256).
    private(set) var voice: String
    private var styles: [Float]

    static var isBundled: Bool { Bundle.main.url(forResource: modelName, withExtension: "onnx") != nil }
    static var isChineseBundled: Bool { Bundle.main.url(forResource: chineseModelName, withExtension: "onnx") != nil }

    init(language: Language = .english, voice: String? = nil, bundle: Bundle = .main) throws {
        let voice = voice ?? (language == .english ? "af_heart" : Self.chineseVoices[0])
        let modelName = language == .english ? Self.modelName : Self.chineseModelName
        guard let model = bundle.url(forResource: modelName, withExtension: "onnx"),
              let lexicon = bundle.url(forResource: "kokoro_lexicon", withExtension: "tsv"),
              let vocab = bundle.url(forResource: "kokoro_vocab", withExtension: "tsv") else {
            throw TTSError.missingResources
        }
        self.language = language
        self.bundle = bundle
        self.voice = voice
        let english = try KokoroPhonemizer(lexiconURL: lexicon, vocabURL: vocab)
        phonemizer = english
        if language == .chinese {
            guard let zhVocab = bundle.url(forResource: "kokoro_vocab_zh", withExtension: "tsv") else { throw TTSError.missingResources }
            chineseVocab = try KokoroPhonemizer.loadVocab(zhVocab)
            // English words inside Chinese text are said with the English voice's pronunciations.
            chinese = try ChineseG2P(bundle: bundle) { english.phonemize($0) }
        } else {
            chineseVocab = [:]
            chinese = nil
        }
        styles = try Self.loadStyles(voice, bundle: bundle)
        env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        // Measured on iPhone 16: more threads aren't faster and Core ML is slower, so use two
        // and leave cores free for the talking buddy and the UI.
        try options.setIntraOpNumThreads(2)
        try options.setGraphOptimizationLevel(.all)
        session = try ORTSession(env: env, modelPath: model.path, sessionOptions: options)
    }

    private static func loadStyles(_ voice: String, bundle: Bundle) throws -> [Float] {
        guard let url = bundle.url(forResource: "kokoro_" + voice, withExtension: "bin") else { throw TTSError.missingResources }
        let data = try Data(contentsOf: url)
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    /// Switches to another voice for the same language (the Chinese voice picker).
    func setVoice(_ name: String) throws {
        guard name != voice else { return }
        styles = try Self.loadStyles(name, bundle: bundle)
        voice = name
    }

    /// The model's tokens for `text`.
    func tokenIDs(for text: String) -> [Int64] {
        guard let chinese else { return phonemizer.tokenIDs(for: phonemizer.phonemize(text)) }
        // A few English symbols aren't in the Chinese model's set; say them the nearest way.
        let phonemes = chinese.phonemize(text).replacingOccurrences(of: "ɚ", with: "əɹ").replacingOccurrences(of: "ꭧ", with: "ʈʃ")
        return [0] + phonemes.compactMap { chineseVocab[$0] } + [0]
    }

    /// Speech for `text` as samples in -1...1. `speed` 1 is normal; below 1 is slower.
    func synthesize(_ text: String, speed: Float = 1) throws -> [Float] {
        var ids = tokenIDs(for: text)
        guard ids.count > 2 else { return [] }
        if ids.count > Self.maxTokens + 2 {
            ids = Array(ids.prefix(Self.maxTokens + 1)) + [0]
        }
        let styleIndex = min(ids.count - 2, styles.count / 256 - 1)
        var style = Array(styles[(styleIndex * 256)..<(styleIndex * 256 + 256)])
        var speedValue = speed

        let idData = NSMutableData(bytes: &ids, length: ids.count * MemoryLayout<Int64>.size)
        let styleData = NSMutableData(bytes: &style, length: style.count * MemoryLayout<Float>.size)
        let speedData = NSMutableData(bytes: &speedValue, length: MemoryLayout<Float>.size)
        let inputs: [String: ORTValue] = [
            "input_ids": try ORTValue(tensorData: idData, elementType: .int64, shape: [1, NSNumber(value: ids.count)]),
            "style": try ORTValue(tensorData: styleData, elementType: .float, shape: [1, 256]),
            "speed": try ORTValue(tensorData: speedData, elementType: .float, shape: [1]),
        ]
        let outputs = try session.run(withInputs: inputs, outputNames: ["waveform"], runOptions: nil)
        guard let waveform = outputs["waveform"] else { throw TTSError.badOutput }
        let out = try waveform.tensorData() as Data
        return out.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    /// Removes the silence Kokoro puts around each clip (about 0.35 s before and 0.5 s
    /// after), keeping a few milliseconds so words don't start or end abruptly.
    static func trimmingSilence(_ samples: [Float], threshold: Float = 0.008) -> [Float] {
        guard let first = samples.firstIndex(where: { abs($0) > threshold }),
              let last = samples.lastIndex(where: { abs($0) > threshold }) else { return [] }
        let lead = Int(sampleRate * 0.03), tail = Int(sampleRate * 0.06)
        return Array(samples[max(0, first - lead)...min(samples.count - 1, last + tail)])
    }
}
