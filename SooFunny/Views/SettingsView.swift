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
                    NavigationLink {
                        PhotoCreditsView()
                    } label: {
                        Label("Photo credits", systemImage: "photo.stack")
                    }
                }

                Section {
                    Button("Reset defaults", role: .destructive) {
                        voiceIdentifier = ""
                        speechRate = SettingsKey.defaultSpeechRate
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: AppInfo.version)
                    LabeledContent("Developer", value: AppInfo.developer)
                    Link(destination: AppInfo.developerURL) {
                        Label("chengjianglong.com", systemImage: "globe")
                    }
                    Text(AppInfo.copyright)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

/// Who took the gallery photos. All are CC0 (free to use), from Wikimedia Commons.
private struct PhotoCreditsView: View {
    var body: some View {
        List {
            Section {
                ForEach(Showcase.credits) { credit in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(credit.title).font(.headline)
                        Text("\(credit.author) · \(credit.license)").font(.subheadline).foregroundStyle(.secondary)
                        if let url = URL(string: credit.url) {
                            Link(credit.source.replacingOccurrences(of: "File:", with: ""), destination: url)
                                .font(.caption)
                        }
                    }
                }
            } footer: {
                Text("Thank you to these photographers for sharing their photos freely (CC0) on Wikimedia Commons.")
            }
        }
        .navigationTitle("Photo credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Who makes SooFunny, and its version.
enum AppInfo {
    static let developer = "Chengjiang Long"
    static let developerURL = URL(string: "https://www.chengjianglong.com/")!
    static let company = "Soo Intelligence Inc."
    static let copyright = "© 2026 Soo Intelligence Inc. All rights reserved."

    /// From the app's Info.plist (MARKETING_VERSION in project.yml).
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
