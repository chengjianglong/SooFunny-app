import Foundation
import OnnxRuntimeBindings

/// Kokoro-82M (Apache-2.0), a natural-sounding neural voice, run on the device with
/// ONNX Runtime. Makes 24 kHz mono audio from text, offline.
///
/// Not thread-safe: use it from one serial queue (`NaturalVoice` does).
final class KokoroTTS {
    static let sampleRate = 24_000.0
    static let modelName = "kokoro-82m-q8"
    static let voiceName = "kokoro_af_heart"
    /// Kokoro reads at most 510 phoneme tokens at a time.
    private static let maxTokens = 510

    enum TTSError: Error {
        case missingResources
        case badOutput
    }

    let phonemizer: KokoroPhonemizer
    private let env: ORTEnv
    private let session: ORTSession
    /// One 256-number style per possible input length (510 × 256).
    private let styles: [Float]

    static var isBundled: Bool { Bundle.main.url(forResource: modelName, withExtension: "onnx") != nil }

    init(bundle: Bundle = .main) throws {
        guard let model = bundle.url(forResource: Self.modelName, withExtension: "onnx"),
              let voice = bundle.url(forResource: Self.voiceName, withExtension: "bin"),
              let lexicon = bundle.url(forResource: "kokoro_lexicon", withExtension: "tsv"),
              let vocab = bundle.url(forResource: "kokoro_vocab", withExtension: "tsv") else {
            throw TTSError.missingResources
        }
        phonemizer = try KokoroPhonemizer(lexiconURL: lexicon, vocabURL: vocab)
        let data = try Data(contentsOf: voice)
        styles = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        // Leave cores free for the talking buddy and the UI.
        try options.setIntraOpNumThreads(2)
        try options.setGraphOptimizationLevel(.all)
        session = try ORTSession(env: env, modelPath: model.path, sessionOptions: options)
    }

    /// Speech for `text` as samples in -1...1. `speed` 1 is normal; below 1 is slower.
    func synthesize(_ text: String, speed: Float = 1) throws -> [Float] {
        let phonemes = phonemizer.phonemize(text)
        var ids = phonemizer.tokenIDs(for: phonemes)
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
}
