import AVFoundation
import Speech

/// Speaks sentences one after another and reports which word is being said.
protocol SentenceSpeaker: AnyObject {
    /// Called on the main thread with the sentence and the range of the word being spoken.
    var onWord: ((String, NSRange) -> Void)? { get set }
    /// Called on the main thread when every queued sentence has been spoken.
    var onFinished: (() -> Void)? { get set }
    func enqueue(_ sentence: String)
    func stop()
    var isSpeaking: Bool { get }
}

/// Hears the child and turns their speech into text.
protocol ChildListener: AnyObject {
    /// The language the child speaks in, English or Chinese.
    var language: BookLanguage { get set }
    /// Starts listening. `onPartial` gets the words so far; `onFinish` gets the final text,
    /// or nil when nothing was said. Both are called on the main thread.
    func start(onPartial: @escaping (String) -> Void, onFinish: @escaping (String?) -> Void) throws
    /// Ends listening now and submits what was heard.
    func finish()
    /// Ends listening and discards what was heard.
    func cancel()
}

final class SystemSentenceSpeaker: NSObject, SentenceSpeaker, AVSpeechSynthesizerDelegate {
    var onWord: ((String, NSRange) -> Void)?
    var onFinished: (() -> Void)?
    /// A voice to use instead of the one chosen in Settings (Chinese books).
    var voice: AVSpeechSynthesisVoice?
    private let synthesizer = AVSpeechSynthesizer()
    private var queued = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// A speaker in Apple's Chinese voice.
    static func chinese() -> SystemSentenceSpeaker {
        let speaker = SystemSentenceSpeaker()
        speaker.voice = BookLanguage.chinese.systemVoice
        return speaker
    }

    var isSpeaking: Bool { queued > 0 }

    func enqueue(_ sentence: String) {
        AssistantAudioSession.activateForSpeaking()
        let utterance = AVSpeechUtterance(string: sentence)
        let settings = UserDefaults.standard
        utterance.voice = voice
            ?? AVSpeechSynthesisVoice(identifier: settings.string(forKey: SettingsKey.voice) ?? "")
            ?? Speech.englishVoices.first
        let rate = settings.object(forKey: SettingsKey.speechRate) as? Double ?? SettingsKey.defaultSpeechRate
        utterance.rate = Float(rate) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
            + AVSpeechUtteranceMinimumSpeechRate
        utterance.postUtteranceDelay = 0.15
        queued += 1
        synthesizer.speak(utterance)
    }

    func stop() {
        queued = 0
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        let sentence = utterance.speechString
        DispatchQueue.main.async { self.onWord?(sentence, characterRange) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard self.queued > 0 else { return }
            self.queued -= 1
            if self.queued == 0 { self.onFinished?() }
        }
    }
}

/// Says sentences that mix English and Chinese: English in the natural voice and Chinese in
/// Apple's Chinese voice, switching wherever the language changes within a sentence.
final class BilingualSentenceSpeaker: SentenceSpeaker {
    var onWord: ((String, NSRange) -> Void)?
    var onFinished: (() -> Void)?
    private let english: SentenceSpeaker
    private let chinese: SentenceSpeaker
    /// Stretches still to say, each with the sentence it came from.
    private var parts: [(sentence: String, text: String, language: BookLanguage)] = []
    /// The sentence being said, and where to look for the next spoken word in it.
    private var current: (sentence: String, cursor: Int)?

    init(english: SentenceSpeaker = NaturalVoice(), chinese: SentenceSpeaker = SystemSentenceSpeaker.chinese()) {
        self.english = english
        self.chinese = chinese
        for speaker in [english, chinese] {
            speaker.onWord = { [weak self] phrase, range in
                self?.follow((phrase as NSString).substring(with: range))
            }
            speaker.onFinished = { [weak self] in self?.speakNext() }
        }
    }

    var isSpeaking: Bool { current != nil }

    func enqueue(_ sentence: String) {
        for run in BookLanguage.runs(in: sentence) {
            parts.append((sentence, run.text, run.language))
        }
        if current == nil { speakNext() }
    }

    func stop() {
        parts = []
        current = nil
        english.stop()
        chinese.stop()
    }

    private func speakNext() {
        guard !parts.isEmpty else {
            guard current != nil else { return }
            current = nil
            onFinished?()
            return
        }
        let part = parts.removeFirst()
        if current?.sentence != part.sentence { current = (part.sentence, 0) }
        (part.language == .chinese ? chinese : english).enqueue(part.text)
    }

    /// Reports the spoken word's place in the whole sentence, so it lights up there.
    private func follow(_ word: String) {
        guard let current else { return }
        let sentence = current.sentence as NSString
        guard current.cursor < sentence.length else { return }
        let found = sentence.range(of: word, options: .caseInsensitive,
                                   range: NSRange(location: current.cursor, length: sentence.length - current.cursor))
        guard found.location != NSNotFound else { return }
        self.current?.cursor = found.location + found.length
        onWord?(current.sentence, found)
    }
}

/// On-device speech recognition (no audio leaves the device; nothing is saved).
/// A turn ends after a short pause, after a long silence, or after twenty seconds.
final class SystemChildListener: ChildListener {
    static let pauseToFinish: TimeInterval = 1.4
    static let silenceToGiveUp: TimeInterval = 8
    static let longestTurn: TimeInterval = 20

    var language: BookLanguage
    private var recognizer: SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: Locale(identifier: language == .chinese ? "zh-CN" : "en-US"))
    }
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timer: Timer?
    private var heard = ""
    private var lastChange = Date()
    private var started = Date()
    private var onFinish: ((String?) -> Void)?

    init(language: BookLanguage = .english) {
        self.language = language
    }

    enum ListenError: LocalizedError {
        case microphoneNotAllowed, speechNotAllowed, unavailable
        var errorDescription: String? {
            switch self {
            case .microphoneNotAllowed: return "To talk, allow the microphone for SooFunny in Settings → Privacy & Security."
            case .speechNotAllowed: return "To talk, allow speech recognition for SooFunny in Settings → Privacy & Security."
            case .unavailable: return "Listening isn't available on this device right now. You can type a question instead."
            }
        }

        /// The message in the conversation's language.
        func message(in language: LearningLanguage) -> String {
            let chinese: String
            switch self {
            case .microphoneNotAllowed: chinese = "要说话，请在“设置”→“隐私与安全性”里允许 SooFunny 使用麦克风。"
            case .speechNotAllowed: chinese = "要说话，请在“设置”→“隐私与安全性”里允许 SooFunny 使用语音识别。"
            case .unavailable: chinese = "这台设备现在听不了中文。可以在“设置”→“通用”→“键盘”里打开中文听写，或者直接输入问题。"
            }
            return language.pick(errorDescription ?? "", chinese, separator: "\n")
        }
    }

    /// Asks for microphone and speech recognition permission. Calls back on the main thread.
    static func requestPermission(_ done: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return DispatchQueue.main.async { done(false) } }
            AVAudioApplication.requestRecordPermission { granted in DispatchQueue.main.async { done(granted) } }
        }
    }

    func start(onPartial: @escaping (String) -> Void, onFinish: @escaping (String?) -> Void) throws {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw ListenError.speechNotAllowed }
        guard AVAudioApplication.shared.recordPermission == .granted else { throw ListenError.microphoneNotAllowed }
        // Only listen when speech can be recognized on the device: a child's voice is never
        // sent to a server (see PRIVACY.md).
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw ListenError.unavailable
        }
        cancel()
        self.onFinish = onFinish
        heard = ""
        started = Date()
        lastChange = Date()

        try AssistantAudioSession.activateForListening()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .search
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw ListenError.unavailable }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.request === request else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if text != self.heard {
                        self.heard = text
                        self.lastChange = Date()
                        onPartial(text)
                    }
                    if result.isFinal { self.complete(submit: true) }
                } else if error != nil {
                    self.complete(submit: true)
                }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        let now = Date()
        if heard.isEmpty, now.timeIntervalSince(started) > Self.silenceToGiveUp {
            complete(submit: false)
        } else if !heard.isEmpty, now.timeIntervalSince(lastChange) > Self.pauseToFinish {
            complete(submit: true)
        } else if now.timeIntervalSince(started) > Self.longestTurn {
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
        let text = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        onFinish = nil
        teardown()
        callback?(submit && !text.isEmpty ? text : nil)
    }

    private func teardown() {
        timer?.invalidate()
        timer = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}

enum AssistantAudioSession {
    static func activateForSpeaking() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? session.setActive(true)
    }

    static func activateForListening() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
