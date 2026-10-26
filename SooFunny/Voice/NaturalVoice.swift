import AVFoundation
import Foundation

/// Loads the Kokoro voice once and makes all speech on one background thread.
///
/// Speech that's needed now always goes before speech prepared in advance, and recent clips
/// are remembered so repeated words play instantly. Kokoro takes about 0.65 s per word on an
/// iPhone 16, so preparing likely-next words ahead of time is what makes taps feel instant.
final class NaturalVoiceEngine {
    static let shared = NaturalVoiceEngine()

    enum Priority { case now, prefetch }

    private let queue = DispatchQueue(label: "SooFunny.NaturalVoice", qos: .userInitiated)
    private let lock = NSLock()
    private var tts: KokoroTTS?
    private var failed = false
    private var working = false
    private var nowJobs: [Job] = []
    private var prefetchJobs: [Job] = []
    private var cache: [String: [Float]] = [:]
    private var cacheOrder: [String] = []
    private static let cacheLimit = 400
    private static let prefetchLimit = 60

    private struct Job {
        let key: String
        let text: String
        let speed: Float
        let completion: (([Float]?) -> Void)?
    }

    /// True when the natural voice is bundled and chosen in Settings.
    static var isSelected: Bool {
        KokoroTTS.isBundled && (UserDefaults.standard.string(forKey: SettingsKey.voice) ?? "").isEmpty
    }

    /// Kokoro speed for the Settings speed slider (0.2...0.7, default 0.42 → about 0.96).
    static var speed: Float {
        let rate = UserDefaults.standard.object(forKey: SettingsKey.speechRate) as? Double ?? SettingsKey.defaultSpeechRate
        return Float(0.6 + rate * 0.85)
    }

    /// Loads the model in the background, warms it up, and prepares common phrases.
    func preload() {
        guard KokoroTTS.isBundled else { return }
        prefetch(Self.commonPhrases)
    }

    /// Phrases the app says often.
    static let commonPhrases = ["Great job!", "You got it!", "Super!", "Awesome!", "Yes!", "Amazing! 🎉",
                                "Great work! 🌟", "Good try! 💪", "Keep practicing! 🌱"]

    /// Speech for `text` (trimmed of silence), from the cache or made now.
    /// `completion` runs on the main thread; nil means the natural voice can't say it.
    func audio(for text: String, completion: @escaping ([Float]?) -> Void) {
        enqueue(Job(key: Self.key(text), text: text, speed: Self.speed, completion: completion), priority: .now)
    }

    /// Prepares speech for texts that will probably be needed soon.
    func prefetch(_ texts: [String]) {
        guard Self.isSelected else { return }
        let speed = Self.speed
        for text in texts where !text.isEmpty {
            enqueue(Job(key: Self.key(text), text: text, speed: speed, completion: nil), priority: .prefetch)
        }
    }

    // MARK: - Work

    private static func key(_ text: String) -> String { "\(speed)|\(text)" }

    private func enqueue(_ job: Job, priority: Priority) {
        lock.lock()
        if let cached = cache[job.key] {
            lock.unlock()
            if let completion = job.completion { DispatchQueue.main.async { completion(cached) } }
            return
        }
        switch priority {
        case .now:
            nowJobs.append(job)
        case .prefetch:
            if !prefetchJobs.contains(where: { $0.key == job.key }) {
                prefetchJobs.append(job)
                if prefetchJobs.count > Self.prefetchLimit { prefetchJobs.removeFirst() }
            }
        }
        let start = !working
        working = true
        lock.unlock()
        if start { queue.async { self.run() } }
    }

    /// Works through jobs one at a time, always taking "now" jobs first.
    private func run() {
        while true {
            lock.lock()
            let job: Job
            if !nowJobs.isEmpty {
                job = nowJobs.removeFirst()
            } else if !prefetchJobs.isEmpty {
                job = prefetchJobs.removeFirst()
            } else {
                working = false
                lock.unlock()
                return
            }
            let cached = cache[job.key]
            lock.unlock()

            var samples = cached
            if samples == nil, let tts = loaded(), let raw = try? tts.synthesize(job.text, speed: job.speed) {
                samples = KokoroTTS.trimmingSilence(raw)
                remember(job.key, samples!)
            }
            if let completion = job.completion {
                let result = samples
                DispatchQueue.main.async { completion(result) }
            }
        }
    }

    private func remember(_ key: String, _ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        if cache[key] == nil { cacheOrder.append(key) }
        cache[key] = samples
        if cacheOrder.count > Self.cacheLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
    }

    /// Call on `queue`. Nil if the voice can't be loaded (then Apple voices are used).
    private func loaded() -> KokoroTTS? {
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
    /// Phrases waiting to play, in order. Each is played once its audio is ready and
    /// everything before it has been scheduled.
    private var pending: [(id: Int, text: String, gap: Double, samples: [Float]?, failed: Bool)] = []
    private var nextID = 0
    private var playing = 0
    /// Phrases scheduled on the player, with the frame each starts at.
    private var segments: [(text: String, start: AVAudioFramePosition, frames: AVAudioFramePosition)] = []
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

    var isSpeaking: Bool { usesFallback ? fallback.isSpeaking : (!pending.isEmpty || playing > 0) }

    func enqueue(_ sentence: String) {
        guard !usesFallback else { return fallback.enqueue(sentence) }
        let current = generation
        for (text, gap) in Self.phrases(in: sentence) {
            let id = nextID
            nextID += 1
            pending.append((id, text, gap, nil, false))
            voice.audio(for: text) { [weak self] samples in
                guard let self, current == self.generation,
                      let index = self.pending.firstIndex(where: { $0.id == id }) else { return }
                if let samples, !samples.isEmpty {
                    self.pending[index].samples = samples
                } else {
                    self.pending[index].failed = true
                }
                self.drain()
            }
        }
    }

    func stop() {
        generation += 1
        pending = []
        playing = 0
        segments = []
        scheduledFrames = 0
        lastWord = nil
        timer?.invalidate()
        timer = nil
        player.stop()
        fallback.stop()
    }

    // MARK: - Phrases

    /// Splits a sentence into phrases so speech can start before all of it is made. Long
    /// sentences split at commas; each phrase gets a short pause after it, like a breath.
    static func phrases(in sentence: String) -> [(text: String, gap: Double)] {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        let endGap = trimmed.last.map { ".!?".contains($0) } == true ? 0.22 : 0.12
        guard words > 8, trimmed.contains(",") else { return [(trimmed, endGap)] }
        let parts = trimmed.components(separatedBy: ",")
        var phrases: [String] = []
        var current = ""
        for (i, part) in parts.enumerated() {
            current += (current.isEmpty ? "" : ",") + part
            let isLast = i == parts.count - 1
            // Keep phrases at least four words long so the voice keeps a natural tune.
            if isLast || current.split(whereSeparator: \.isWhitespace).count >= 4 {
                phrases.append(current.trimmingCharacters(in: .whitespaces) + (isLast ? "" : ","))
                current = ""
            }
        }
        if phrases.count > 1, phrases[phrases.count - 1].split(whereSeparator: \.isWhitespace).count < 3 {
            let last = phrases.removeLast()
            phrases[phrases.count - 1] += " " + last
        }
        return phrases.enumerated().map { ($1, $0 == phrases.count - 1 ? endGap : 0.12) }
    }

    // MARK: - Playback

    /// Schedules every ready phrase at the front of the line, in order.
    private func drain() {
        while let first = pending.first, first.samples != nil || first.failed {
            pending.removeFirst()
            if let samples = first.samples {
                play(samples, text: first.text, gap: first.gap)
            } else {
                // The natural voice couldn't say it: let Apple's voice say this phrase.
                fallback.enqueue(first.text)
            }
        }
    }

    private func play(_ samples: [Float], text: String, gap: Double) {
        let silence = Int(KokoroTTS.sampleRate * gap)
        let total = samples.count + silence
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)) else { return }
        buffer.frameLength = AVAudioFrameCount(total)
        let channel = buffer.floatChannelData![0]
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        (channel + samples.count).update(repeating: 0, count: silence)

        if !engine.isRunning {
            AssistantAudioSession.activateForSpeaking()
            do {
                try engine.start()
            } catch {
                return fallback.enqueue(text)
            }
        }
        let current = generation
        playing += 1
        segments.append((text, scheduledFrames, AVAudioFramePosition(samples.count)))
        scheduledFrames += AVAudioFramePosition(total)
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, current == self.generation else { return }
                self.playing -= 1
                if self.playing == 0 && self.pending.isEmpty {
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
    /// timings, so each word gets a share of its phrase's audio by its length.
    private func tick() {
        guard let nodeTime = player.lastRenderTime, let time = player.playerTime(forNodeTime: nodeTime) else { return }
        let frame = time.sampleTime
        guard let segment = segments.last(where: { $0.start <= frame }),
              frame < segment.start + segment.frames else { return }
        let progress = Double(frame - segment.start) / Double(max(1, segment.frames))
        guard let range = Self.wordRange(in: segment.text, at: progress), range != lastWord else { return }
        lastWord = range
        onWord?(segment.text, range)
    }

    static func wordRange(in sentence: String, at progress: Double) -> NSRange? {
        var words: [(NSRange, Int)] = []
        let ns = sentence as NSString
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byWords) { word, range, _, _ in
            words.append((range, (word?.count ?? 1) + 2))
        }
        guard !words.isEmpty else { return nil }
        let p = min(1, max(0, progress))
        let total = Double(words.reduce(0) { $0 + $1.1 })
        var acc = 0.0
        for (range, weight) in words {
            acc += Double(weight) / total
            if p <= acc { return range }
        }
        return words.last?.0
    }
}
