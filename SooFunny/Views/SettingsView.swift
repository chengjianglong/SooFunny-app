import AVFoundation
import SwiftUI

/// App settings: the reading voice and its speed, plus the Research Lab for grown-ups.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.voice) private var voiceIdentifier = ""
    @AppStorage(SettingsKey.speechRate) private var speechRate = SettingsKey.defaultSpeechRate
    @State private var voices = Speech.englishVoices

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Voice", selection: $voiceIdentifier) {
                        Text("Automatic").tag("")
                        ForEach(voices, id: \.identifier) { voice in
                            Text(label(voice)).tag(voice.identifier)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Speed")
                        HStack {
                            Image(systemName: "tortoise.fill").foregroundStyle(.secondary)
                            Slider(value: $speechRate, in: 0.2...0.7)
                            Image(systemName: "hare.fill").foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        Speech.shared.speak("Hello! Let's learn some words.")
                    } label: {
                        Label("Try the voice", systemImage: "speaker.wave.2.fill")
                    }
                } header: {
                    Text("Reading voice")
                } footer: {
                    Text("Voices come with iOS and work offline. Add more under iPhone or iPad Settings → Accessibility → Spoken Content → Voices.")
                }

                Section {
                    NavigationLink {
                        ResearchLabView()
                    } label: {
                        Label("Research Lab", systemImage: "flask")
                    }
                } footer: {
                    Text("On-device model and benchmarking tools, for grown-ups.")
                }

                Section {
                    Button("Reset defaults", role: .destructive) {
                        voiceIdentifier = ""
                        speechRate = SettingsKey.defaultSpeechRate
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { voices = Speech.englishVoices }
        }
    }

    private func label(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium: quality = " (Premium)"
        case .enhanced: quality = " (Enhanced)"
        default: quality = ""
        }
        return "\(voice.name) · \(voice.language)\(quality)"
    }
}
