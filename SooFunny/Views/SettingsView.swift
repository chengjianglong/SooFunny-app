import AVFoundation
import SwiftUI

/// App settings: the reading voice and its speed, plus the Research Lab for grown-ups.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.voice) private var voiceIdentifier = ""
    @AppStorage(SettingsKey.speechRate) private var speechRate = SettingsKey.defaultSpeechRate
    @State private var voices = Speech.englishVoices
    @State private var showSupport = false
    @State private var showManage = false
    @State private var gate: GateTarget?
    @State private var showResearchLab = false
    @Environment(\.openURL) private var openURL
    private let tipJar = TipJar.shared

    /// Things behind the grown-up check.
    private enum GateTarget: Identifiable {
        case researchLab, website
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showSupport = true
                    } label: {
                        Label("Leave a tip", systemImage: "heart.fill")
                    }
                    if tipJar.hasLegacySubscription {
                        Text("SooFunny is now free for everyone, so your SooFunny Premium subscription is no longer needed. You can cancel it so it doesn't renew.")
                            .font(.footnote)
                        Button("Manage subscription") { showManage = true }
                    }
                } header: {
                    Text("Support SooFunny")
                } footer: {
                    Text("SooFunny is free, with every feature for everyone. Tips are optional and help keep it maintained and updated.")
                }

                Section {
                    Picker("Voice", selection: $voiceIdentifier) {
                        Text(KokoroTTS.isBundled ? "Natural · Heart (recommended)" : "Automatic").tag("")
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
                    Text("The natural voice runs on this device and works offline. Other voices come with iOS; add more under iPhone or iPad Settings → Accessibility → Spoken Content → Voices.")
                }

                Section {
                    Button {
                        gate = .researchLab
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
                    Button {
                        gate = .website
                    } label: {
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
            .navigationDestination(isPresented: $showResearchLab) { ResearchLabView() }
            .sheet(isPresented: $showSupport) { SupportView() }
            .sheet(item: $gate) { target in
                NavigationStack {
                    ParentalGate(reason: target == .website ? "This opens a website." : "The Research Lab is for grown-ups.") {
                        gate = nil
                        switch target {
                        case .researchLab: showResearchLab = true
                        case .website: openURL(AppInfo.developerURL)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Close") { gate = nil } }
                    }
                }
            }
            .manageSubscriptionsSheet(isPresented: $showManage)
            .task { await tipJar.refresh() }
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

/// Who took the gallery and word photos. All are CC0 or public domain (free to use), from Wikimedia Commons.
private struct PhotoCreditsView: View {
    var body: some View {
        List {
            section("Gallery photos", Showcase.credits)
            section("Word photos", WordPhotos.credits)
            Section {} footer: {
                Text("Thank you to these photographers for sharing their photos freely (CC0 or public domain) on Wikimedia Commons.")
            }
        }
        .navigationTitle("Photo credits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ credits: [PictureCredit]) -> some View {
        Section(title) {
            ForEach(credits) { credit in
                VStack(alignment: .leading, spacing: 2) {
                    Text(credit.title).font(.headline)
                    Text("\(credit.author) · \(credit.license)").font(.subheadline).foregroundStyle(.secondary)
                    // Plain text, not a link: kids shouldn't leave the app from here.
                    Text("Wikimedia Commons: " + credit.source.replacingOccurrences(of: "File:", with: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

/// Who makes SooFunny, and its version.
enum AppInfo {
    static let developer = "Chengjiang Long"
    static let developerURL = URL(string: "https://www.chengjianglong.com/")!
    static let company = "Soo X Intelligence LLC"
    static let copyright = "© 2026 Soo X Intelligence LLC. All rights reserved."

    /// From the app's Info.plist (MARKETING_VERSION in project.yml).
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
