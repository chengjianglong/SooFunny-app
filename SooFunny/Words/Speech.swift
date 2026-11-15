import AVFoundation
import Observation
import SwiftUI

/// Reads words aloud, offline: English in the natural Kokoro voice by default, or a voice built
/// into iOS chosen in Settings; Chinese in the natural Chinese voice chosen in Settings.
@Observable
final class Speech: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speech()

    /// The text being spoken right now, used to animate its speaker button.
    private(set) var speaking: String?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var natural: NaturalVoice?
    @ObservationIgnored private var naturalChinese: NaturalVoice?
    /// What's left to say of `speaking`, in runs of one language.
    @ObservationIgnored private var parts: [(text: String, language: BookLanguage)] = []
    /// The Apple voice utterance being said now.
    @ObservationIgnored private var utterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// English voices installed on this device, best quality first. Novelty voices such as
    /// "Boing" and "Bubbles" are left out: they're hard for children to understand.
    static var englishVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .sorted { ($0.quality.rawValue, $0.language == "en-US" ? 1 : 0, $0.name) > ($1.quality.rawValue, $1.language == "en-US" ? 1 : 0, $1.name) }
    }

    /// If a novelty voice (or one no longer on this device) was saved, go back to the
    /// natural voice. Runs at launch.
    static func resetUnsuitableVoice(_ defaults: UserDefaults = .standard) {
        guard let identifier = defaults.string(forKey: SettingsKey.voice), !identifier.isEmpty else { return }
        let voice = AVSpeechSynthesisVoice(identifier: identifier)
        if voice == nil || voice!.voiceTraits.contains(.isNoveltyVoice) {
            defaults.removeObject(forKey: SettingsKey.voice)
        }
    }

    /// AVSpeechUtterance rate for the speed chosen in Settings.
    static var appleRate: Float {
        let rate = UserDefaults.standard.object(forKey: SettingsKey.speechRate) as? Double ?? SettingsKey.defaultSpeechRate
        return Float(rate) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
            + AVSpeechUtteranceMinimumSpeechRate
    }

    /// Says `text`. English is read in the chosen voice and Chinese in the chosen Chinese voice;
    /// text with both ("dog, 狗") switches voice where the language changes.
    func speak(_ text: String) {
        stopVoices()
        speaking = text
        parts = BookLanguage.runs(in: text)
        speakNextPart(of: text)
    }

    func stop() {
        stopVoices()
        speaking = nil
    }

    private func stopVoices() {
        parts = []
        utterance = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        natural?.stop()
        naturalChinese?.stop()
    }

    private func speakNextPart(of text: String) {
        guard speaking == text else { return }
        guard !parts.isEmpty else {
            speaking = nil
            return
        }
        let part = parts.removeFirst()
        if part.language == .english, NaturalVoiceEngine.isSelected {
            let voice = natural ?? NaturalVoice()
            natural = voice
            voice.onFinished = { [weak self] in self?.speakNextPart(of: text) }
            voice.enqueue(part.text)
            return
        }
        if part.language == .chinese, NaturalVoiceEngine.isChineseSelected {
            let voice = naturalChinese ?? NaturalVoice(language: .chinese)
            naturalChinese = voice
            voice.onFinished = { [weak self] in self?.speakNextPart(of: text) }
            voice.enqueue(part.text)
            return
        }
        let utterance = AVSpeechUtterance(string: part.text)
        if part.language == .chinese {
            utterance.voice = BookLanguage.chinese.systemVoice
        } else {
            let identifier = UserDefaults.standard.string(forKey: SettingsKey.voice) ?? ""
            utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
                ?? Self.englishVoices.first
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        utterance.rate = Self.appleRate
        self.utterance = utterance
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            // Only the part being said moves things on, not one that was stopped.
            guard utterance === self.utterance, let text = self.speaking else { return }
            self.utterance = nil
            self.speakNextPart(of: text)
        }
    }
}

enum SettingsKey {
    /// An Apple voice identifier, or empty for the natural (Kokoro) voice.
    static let voice = "speechVoiceIdentifier"
    static let speechRate = "speechRate"
    /// 0 is slowest, 1 fastest. Matches what sounded best on the natural voice (about 1.05×);
    /// slower settings made it drag.
    static let defaultSpeechRate = 0.53
    /// The natural Chinese voice: one of `KokoroTTS.chineseVoices`.
    static let chineseVoice = "chineseVoice"
}

/// Speaker button that pulses while its text is being read.
struct SpeakButton: View {
    let text: String
    var size: CGFloat = 22

    private var isSpeaking: Bool { Speech.shared.speaking == text }

    var body: some View {
        Button {
            isSpeaking ? Speech.shared.stop() : Speech.shared.speak(text)
        } label: {
            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                .font(.system(size: size, weight: .bold))
                .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                .frame(width: size * 2, height: size * 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isSpeaking ? "Stop" : "Say \(text)")
    }
}
