import AVFoundation
import Speech

/// Listens in English or Chinese. English uses Apple's speech recognition as before; Chinese uses
/// the newer on-device speech engine (iOS 26) when its Mandarin model is ready, which the app can
/// download itself, so families don't have to add a Chinese keyboard first.
final class LanguageChildListener: ChildListener {
    var language: BookLanguage
    private let english = SystemChildListener(language: .english)
    private let olderChinese = SystemChildListener(language: .chinese)
    private lazy var newerChinese: ChildListener? = {
        if #available(iOS 26, *) { return AnalyzerChildListener() }
        return nil
    }()
    private var active: ChildListener?

    init(language: BookLanguage) {
        self.language = language
    }

    func start(onPartial: @escaping (String) -> Void, onFinish: @escaping (String?) -> Void) throws {
        active?.cancel()
        let listener = try chooseListener()
        active = listener
        try listener.start(onPartial: onPartial, onFinish: onFinish)
    }

    func finish() { active?.finish() }

    func cancel() { active?.cancel() }

    private func chooseListener() throws -> ChildListener {
        guard language == .chinese else { return english }
        if #available(iOS 26, *) {
            if AnalyzerChildListener.isReady, let newerChinese { return newerChinese }
            // Still downloading the Mandarin model: say so, rather than "not available".
            if AnalyzerChildListener.isDownloading { throw SystemChildListener.ListenError.chineseGettingReady }
        }
        return olderChinese
    }

    /// Gets Chinese listening ready ahead of time (downloads Apple's Mandarin model if needed).
    static func prepareChinese() async {
        if #available(iOS 26, *) { await AnalyzerChildListener.prepare() }
    }
}

/// Hears Mandarin with `SpeechAnalyzer` and Apple's dictation model, entirely on the device.
/// A turn ends after a short pause, after a long silence, or after twenty seconds, as in English.
@available(iOS 26, *)
final class AnalyzerChildListener: ChildListener {
    var language: BookLanguage = .chinese

    /// True once the Mandarin model is installed on this device.
    private(set) static var isReady = false
    private(set) static var isDownloading = false
    private static let wanted = Locale(identifier: "zh-CN")

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var tasks: [Task<Void, Never>] = []
    private var timer: Timer?
    private var finalized = ""
    private var volatile = ""
    private var lastChange = Date()
    private var started = Date()
    private var onFinish: ((String?) -> Void)?
    /// Bumped on every start and stop, so results from an old turn are ignored.
    private var turn = 0

    private var heard: String { (finalized + volatile).trimmingCharacters(in: .whitespacesAndNewlines) }

    private static func transcriber(_ locale: Locale) -> DictationTranscriber {
        DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
    }

    /// Downloads and installs the Mandarin model if this device doesn't have it yet. Apple's model
    /// is downloaded once; no voice or text is sent anywhere.
    @MainActor
    static func prepare() async {
        guard !isReady, !isDownloading,
              let locale = await DictationTranscriber.supportedLocale(equivalentTo: wanted) else { return }
        let module = transcriber(locale)
        isDownloading = true
        defer { isDownloading = false }
        do {
            if await AssetInventory.status(forModules: [module]) != .installed,
               let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
            isReady = await AssetInventory.status(forModules: [module]) == .installed
        } catch {
            isReady = false
        }
    }

    func start(onPartial: @escaping (String) -> Void, onFinish: @escaping (String?) -> Void) throws {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SystemChildListener.ListenError.speechNotAllowed
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw SystemChildListener.ListenError.microphoneNotAllowed
        }
        guard Self.isReady else { throw SystemChildListener.ListenError.unavailable }
        cancel()
        self.onFinish = onFinish
        finalized = ""
        volatile = ""
        started = Date()
        lastChange = Date()
        turn += 1
        let current = turn

        try AssistantAudioSession.activateForListening()
        let inputNode = audioEngine.inputNode
        let micFormat = inputNode.outputFormat(forBus: 0)
        guard micFormat.sampleRate > 0 else { throw SystemChildListener.ListenError.unavailable }

        let locale = Self.wanted
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        input = continuation

        tasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let supported = await DictationTranscriber.supportedLocale(equivalentTo: locale) else {
                    throw SystemChildListener.ListenError.unavailable
                }
                let module = Self.transcriber(supported)
                let analyzer = SpeechAnalyzer(modules: [module])
                guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]),
                      let converter = AVAudioConverter(from: micFormat, to: format) else {
                    throw SystemChildListener.ListenError.unavailable
                }
                guard self.turn == current else { return }
                self.analyzer = analyzer
                self.listen(to: module, turn: current, onPartial: onPartial)
                inputNode.removeTap(onBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { buffer, _ in
                    if let converted = Self.convert(buffer, with: converter, to: format) {
                        continuation.yield(AnalyzerInput(buffer: converted))
                    }
                }
                self.audioEngine.prepare()
                try self.audioEngine.start()
                try await analyzer.start(inputSequence: stream)
            } catch {
                if self.turn == current { self.complete(submit: false) }
            }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
    }

    /// Shows what's been heard as it comes in: settled words plus the words still being worked out.
    @MainActor
    private func listen(to module: DictationTranscriber, turn current: Int, onPartial: @escaping (String) -> Void) {
        tasks.append(Task { @MainActor [weak self] in
            do {
                for try await result in module.results {
                    guard let self, self.turn == current else { return }
                    let text = String(result.text.characters)
                    if result.isFinal {
                        self.finalized += text
                        self.volatile = ""
                    } else {
                        self.volatile = text
                    }
                    self.lastChange = Date()
                    onPartial(self.heard)
                }
            } catch {}
        })
    }

    /// Converts the microphone's audio into the format the speech model wants.
    private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter,
                                to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && output.frameLength > 0 ? output : nil
    }

    private func tick() {
        let now = Date()
        if heard.isEmpty, now.timeIntervalSince(started) > SystemChildListener.silenceToGiveUp {
            complete(submit: false)
        } else if !heard.isEmpty, now.timeIntervalSince(lastChange) > SystemChildListener.pauseToFinish {
            complete(submit: true)
        } else if now.timeIntervalSince(started) > SystemChildListener.longestTurn {
            complete(submit: true)
        }
    }

    func finish() { complete(submit: true) }

    func cancel() {
        onFinish = nil
        teardown()
    }

    private func complete(submit: Bool) {
        let callback = onFinish
        let text = heard
        onFinish = nil
        teardown()
        callback?(submit && !text.isEmpty ? text : nil)
    }

    private func teardown() {
        turn += 1
        timer?.invalidate()
        timer = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        input?.finish()
        input = nil
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        analyzer = nil
        tasks.forEach { $0.cancel() }
        tasks = []
    }
}
