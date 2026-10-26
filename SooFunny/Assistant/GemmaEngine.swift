import Foundation
import llama

/// Something that turns a prompt into streamed text. `GemmaEngine` in the app; fakes in tests.
protocol LanguageEngine: AnyObject {
    /// Generates a reply, calling `onText` with each new piece. Returns the full text.
    /// Throws `CancellationError` when `isCancelled` becomes true.
    func generate(prompt: String, maxTokens: Int, isCancelled: @escaping () -> Bool,
                  onText: @escaping (String) -> Void) throws -> String
}

/// Gemma 3 1B (4-bit), bundled with the app and run on the device with llama.cpp.
/// Nothing is downloaded and nothing leaves the device.
///
/// Not thread-safe: call it from one serial queue (`WordAssistant` does).
final class GemmaEngine: LanguageEngine {
    enum EngineError: LocalizedError {
        case modelMissing
        case loadFailed
        case promptTooLong
        case decodeFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .modelMissing: return "The talking buddy's brain isn't included in this build of the app."
            case .loadFailed: return "The talking buddy couldn't start. Close other apps and try again."
            case .promptTooLong: return "That conversation got too long. Tap Back and start again."
            case .decodeFailed(let code): return "The talking buddy got confused (error \(code)). Please try again."
            }
        }
    }

    static let modelName = "gemma-3-1b-it-Q4_K_M"
    static var bundledModelURL: URL? { Bundle.main.url(forResource: modelName, withExtension: "gguf") }

    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private let contextSize: Int32 = 2048
    private let batchSize: Int32 = 512

    init(modelURL: URL? = GemmaEngine.bundledModelURL) throws {
        guard let modelURL else { throw EngineError.modelMissing }
        Self.initializeBackend
        var modelParams = llama_model_default_params()
        #if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0 // The Simulator has no usable Metal GPU for this.
        #else
        modelParams.n_gpu_layers = 99
        #endif
        guard let model = llama_model_load_from_file(modelURL.path, modelParams) else { throw EngineError.loadFailed }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(contextSize)
        contextParams.n_batch = UInt32(batchSize)
        let threads = Int32(max(1, min(4, ProcessInfo.processInfo.activeProcessorCount - 2)))
        contextParams.n_threads = threads
        contextParams.n_threads_batch = threads
        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            throw EngineError.loadFailed
        }
        self.model = model
        self.context = context
        self.vocab = llama_model_get_vocab(model)
    }

    deinit {
        llama_free(context)
        llama_model_free(model)
    }

    private static let initializeBackend: Void = {
        llama_log_set({ _, _, _ in }, nil) // Keep the console quiet.
        llama_backend_init()
    }()

    func generate(prompt: String, maxTokens: Int, isCancelled: @escaping () -> Bool,
                  onText: @escaping (String) -> Void) throws -> String {
        llama_memory_clear(llama_get_memory(context), true)
        var tokens = tokenize(prompt)
        guard tokens.count + maxTokens < Int(contextSize) else { throw EngineError.promptTooLong }

        // Read the prompt in batches.
        var start = 0
        while start < tokens.count {
            if isCancelled() { throw CancellationError() }
            let count = min(Int(batchSize), tokens.count - start)
            let status = tokens.withUnsafeMutableBufferPointer { buffer in
                llama_decode(context, llama_batch_get_one(buffer.baseAddress! + start, Int32(count)))
            }
            guard status == 0 else { throw EngineError.decodeFailed(status) }
            start += count
        }

        let sampler = Self.makeSampler()
        defer { llama_sampler_free(sampler) }
        var text = ""
        var pending: [CChar] = [] // Bytes of a character split across tokens.
        for _ in 0..<maxTokens {
            if isCancelled() { throw CancellationError() }
            var token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            pending += piece(token)
            if let piece = String(validatingUTF8: pending + [0]) {
                pending.removeAll()
                text += piece
                onText(piece)
            }
            let status = llama_decode(context, llama_batch_get_one(&token, 1))
            guard status == 0 else { throw EngineError.decodeFailed(status) }
        }
        return text
    }

    private static func makeSampler() -> UnsafeMutablePointer<llama_sampler> {
        let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())!
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(0.7))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        return chain
    }

    private func tokenize(_ text: String) -> [llama_token] {
        let utf8Count = Int32(text.utf8.count)
        var tokens = [llama_token](repeating: 0, count: Int(utf8Count) + 8)
        var count = llama_tokenize(vocab, text, utf8Count, &tokens, Int32(tokens.count), true, true)
        if count < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-count))
            count = llama_tokenize(vocab, text, utf8Count, &tokens, Int32(tokens.count), true, true)
        }
        return Array(tokens.prefix(Int(max(0, count))))
    }

    private func piece(_ token: llama_token) -> [CChar] {
        var buffer = [CChar](repeating: 0, count: 64)
        var length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        if length < 0 {
            buffer = [CChar](repeating: 0, count: Int(-length))
            length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        }
        return Array(buffer.prefix(Int(max(0, length))))
    }
}
