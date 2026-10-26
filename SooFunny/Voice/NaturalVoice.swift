import AVFoundation
import Foundation

/// Loads the Kokoro voice once, off the main thread, and runs every synthesis on one queue.
final class NaturalVoiceEngine {
    static let shared = NaturalVoiceEngine()

    let queue = DispatchQueue(label: "SooFunny.NaturalVoice", qos: .userInitiated)
    private var tts: KokoroTTS?
    private var failed = false

    /// True when the natural voice is bundled and chosen in Settings.
    static var isSelected: Bool {
        KokoroTTS.isBundled && (UserDefaults.standard.string(forKey: SettingsKey.voice) ?? "").isEmpty
    }

    /// Loads the model in the background so the first word plays quickly.
    func preload() {
        guard KokoroTTS.isBundled else { return }
        queue.async { _ = self.loaded() }
    }

    /// Call on `queue`. Nil if the voice can't be loaded (then Apple voices are used).
    func loaded() -> KokoroTTS? {
        if let tts { return tts }
        guard !failed else { return nil }
        do {
            tts = try KokoroTTS()
            return tts
        } catch {
            failed = true
            return nil
        }
    }

    /// Kokoro speed for the Settings speed slider (0.2...0.7, default 0.42 → about 0.96).
    static var speed: Float {
        let rate = UserDefaults.standard.object(forKey: SettingsKey.speechRate) as? Double ?? SettingsKey.defaultSpeechRate
        return Float(0.6 + rate * 0.85)
    }
}

/// Speaks sentences one after another in the natural voice, reporting which word is
/// being said. Falls back to Apple's voices when the natural voice isn't available.
final class NaturalVoice: SentenceSpeaker {
    var onWord: ((String, NSRange) -> Void)? {
        didSet { fallback.onWord = onWord }
    }
    var onFinished: (() -> Void)? {
        didSet { fallback.onFinished = onFinished }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: KokoroTTS.sampleRate, channels: 1)!
    private let fallback = SystemSentenceSpeaker()
    private let voice = NaturalVoiceEngine.shared
    private let usesFallback: Bool

    /// Bumped by `stop()`; audio made for an older generation is dropped.
    private var generation = 0
    private var queued = 0
    /// Sentences scheduled on the player, with the frame each starts at.
    private var segments: [(sentence: String, start: AVAudioFramePosition, frames: AVAudioFramePosition)] = []
    private var scheduledFrames: AVAudioFramePosition = 0
    private var timer: Timer?
    private var lastWord: NSRange?

    init(forceFallback: Bool = false) {
        usesFallback = forceFallback || !NaturalVoiceEngine.isSelected
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    deinit {
        timer?.invalidate()
        engine.stop()
    }

    var isSpeaking: Bool { usesFallback ? fallback.isSpeaking : queued > 0 }

    func enqueue(_ sentence: String) {
        guard !usesFallback else { return fallback.enqueue(sentence) }
        queued += 1
        let current = generation
        let speed = NaturalVoiceEngine.speed
        voice.queue.async { [weak self] in
            guard let self else { return }
            let samples = (try? self.voice.loaded()?.synthesize(sentence, speed: speed)) ?? nil
            DispatchQueue.main.async {
                guard current == self.generation else { return }
                if let samples, !samples.isEmpty {
                    self.play(samples, sentence: sentence, generation: current)
                } else {
                    // The natural voice couldn't say it: let Apple's voice say this sentence.
                    self.queued -= 1
                    self.fallback.enqueue(sentence)
                }
            }
        }
    }

    func stop() {
        generation += 1
        queued = 0
        segments = []
        scheduledFrames = 0
        lastWord = nil
        timer?.invalidate()
        timer = nil
        player.stop()
        fallback.stop()
    }

    // MARK: - Playback

    private func play(_ samples: [Float], sentence: String, generation current: Int) {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }

        if !engine.isRunning {
            AssistantAudioSession.activateForSpeaking()
            do {
                try engine.start()
            } catch {
                queued -= 1
                return fallback.enqueue(sentence)
            }
        }
        segments.append((sentence, scheduledFrames, AVAudioFramePosition(samples.count)))
        scheduledFrames += AVAudioFramePosition(samples.count)
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, current == self.generation else { return }
                self.queued -= 1
                if self.queued == 0 {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.player.stop()
                    self.segments = []
                    self.scheduledFrames = 0
                    self.onFinished?()
                }
            }
        }
        if !player.isPlaying { player.play() }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        }
    }

    /// Estimates the word being spoken from the playback position. Kokoro gives no word
    /// timings, so each word gets a share of its sentence's audio by its length.
    private func tick() {
        guard let nodeTime = player.lastRenderTime, let time = player.playerTime(forNodeTime: nodeTime) else { return }
        let frame = time.sampleTime
        guard let segment = segments.last(where: { $0.start <= frame }) else { return }
        let progress = Double(frame - segment.start) / Double(max(1, segment.frames))
        guard let range = Self.wordRange(in: segment.sentence, at: progress), range != lastWord else { return }
        lastWord = range
        onWord?(segment.sentence, range)
    }

    static func wordRange(in sentence: String, at progress: Double) -> NSRange? {
        var words: [(NSRange, Int)] = []
        let ns = sentence as NSString
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byWords) { word, range, _, _ in
            words.append((range, (word?.count ?? 1) + 2))
        }
        guard !words.isEmpty else { return nil }
        // Kokoro adds a little silence at both ends; trim it from the estimate.
        let p = min(1, max(0, (progress - 0.05) / 0.88))
        let total = Double(words.reduce(0) { $0 + $1.1 })
        var acc = 0.0
        for (range, weight) in words {
            acc += Double(weight) / total
            if p <= acc { return range }
        }
        return words.last?.0
    }
}
