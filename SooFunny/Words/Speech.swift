import AVFoundation
import Observation
import SwiftUI

/// Reads words aloud, offline: in the natural Kokoro voice by default, or a voice built
/// into iOS chosen in Settings.
@Observable
final class Speech: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speech()

    /// The text being spoken right now, used to animate its speaker button.
    private(set) var speaking: String?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var natural: NaturalVoice?

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

    func speak(_ text: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        natural?.stop()
        if NaturalVoiceEngine.isSelected {
            let voice = natural ?? NaturalVoice()
            natural = voice
            voice.onFinished = { [weak self] in
                if self?.speaking == text { self?.speaking = nil }
            }
            speaking = text
            voice.enqueue(text)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        let settings = UserDefaults.standard
        let identifier = settings.string(forKey: SettingsKey.voice) ?? ""
        utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
            ?? Self.englishVoices.first
            ?? AVSpeechSynthesisVoice(language: "en-US")
        let rate = settings.object(forKey: SettingsKey.speechRate) as? Double ?? SettingsKey.defaultSpeechRate
        utterance.rate = Float(rate) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
            + AVSpeechUtteranceMinimumSpeechRate
        speaking = text
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        natural?.stop()
        speaking = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { if self.speaking == utterance.speechString { self.speaking = nil } }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { if self.speaking == utterance.speechString { self.speaking = nil } }
    }
}

enum SettingsKey {
    /// An Apple voice identifier, or empty for the natural (Kokoro) voice.
    static let voice = "speechVoiceIdentifier"
    static let speechRate = "speechRate"
    /// 0 is slowest, 1 fastest. Matches what sounded best on the natural voice (about 1.05×);
    /// slower settings made it drag.
    static let defaultSpeechRate = 0.53
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
