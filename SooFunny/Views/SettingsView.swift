import AVFoundation
import SwiftUI

/// App settings: the language for every tab, the reading voice and its speed, plus
/// the Research Lab for grown-ups.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.voice) private var voiceIdentifier = ""
    @AppStorage(SettingsKey.speechRate) private var speechRate = SettingsKey.defaultSpeechRate
    @AppStorage(SettingsKey.chineseVoice) private var chineseVoice = KokoroTTS.chineseVoices[0]
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english
    @State private var voices = Speech.englishVoices
    @State private var showSupport = false
    @State private var showManage = false
    @State private var gate: GateTarget?
    @State private var showResearchLab = false
    @Environment(\.openURL) private var openURL
    private let tipJar = TipJar.shared

    /// Things behind the grown-up check.
    private enum GateTarget: Identifiable {
        case researchLab, email
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Language 语言", selection: $language) {
                        ForEach(LearningLanguage.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Language 语言")
                } footer: {
                    Text(language.pick("Color, Words, Sports, Books and Math are shown and read aloud in English, in Chinese, or in "
                                       + "both. You can also switch with the globe button at the top.",
                                       "涂色、词语、运动、图书和数学都可以用英文、中文或双语显示和朗读，也可以用顶部的地球按钮切换。",
                                       separator: "\n"))
                }

                Section {
                    Button {
                        showSupport = true
                    } label: {
                        Label(language.pick("Leave a tip", "打赏支持"), systemImage: "heart.fill")
                    }
                    if tipJar.hasLegacySubscription {
                        Text(language.pick("SooFunny is now free for everyone, so your SooFunny Premium subscription is no longer needed. You can cancel it so it doesn't renew.",
                                           "SooFunny 现在对所有人免费，不再需要 SooFunny Premium 订阅。你可以取消订阅，以免自动续费。", separator: "\n"))
                            .font(.footnote)
                        Button(language.pick("Manage subscription", "管理订阅")) { showManage = true }
                    }
                } header: {
                    Text(language.pick("Support SooFunny", "支持 SooFunny"))
                } footer: {
                    Text(language.pick("SooFunny is free, with every feature for everyone. Tips are optional and help keep it maintained and updated.",
                                       "SooFunny 免费提供所有功能。打赏是自愿的，可以帮助我们维护和更新。", separator: "\n"))
                }

                Section {
                    Picker(language.pick("Voice", "声音"), selection: $voiceIdentifier) {
                        Text(KokoroTTS.isBundled ? naturalVoiceName : language.pick("Automatic", "自动")).tag("")
                        ForEach(voices, id: \.identifier) { voice in
                            Text(label(voice)).tag(voice.identifier)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text(language.pick("Speed", "语速"))
                        HStack {
                            Image(systemName: "tortoise.fill").foregroundStyle(.secondary)
                            Slider(value: $speechRate, in: 0.2...0.7)
                            Image(systemName: "hare.fill").foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        Speech.shared.speak("Hello! Let's learn some words.")
                    } label: {
                        Label(language.pick("Try the voice", "试听"), systemImage: "speaker.wave.2.fill")
                    }
                } header: {
                    Text(language.pick("English voice", "英文声音"))
                } footer: {
                    Text(language.pick("The natural voice runs on this device and works offline. Other voices come with iOS; add more under iPhone or iPad Settings → Accessibility → Spoken Content → Voices.",
                                       "自然的声音在设备上运行，离线可用。其他声音来自 iOS，可以在 iPhone 或 iPad 的“设置 → 辅助功能 → 朗读内容 → 声音”里添加。",
                                       separator: "\n"))
                }

                if KokoroTTS.isChineseBundled {
                    Section {
                        Picker(language.pick("Voice", "声音"), selection: $chineseVoice) {
                            ForEach(Array(KokoroTTS.chineseVoices.enumerated()), id: \.element) { i, voice in
                                Text(language.pick("Voice \(i + 1)" + (i == 0 ? " (recommended)" : ""), "声音\(i + 1)" + (i == 0 ? "（推荐）" : "")))
                                    .tag(voice)
                            }
                        }
                        .onChange(of: chineseVoice) { Speech.shared.speak("你好！我们一起来学习吧。") }
                        Button {
                            Speech.shared.speak("你好！我们一起来学习吧。")
                        } label: {
                            Label(language.pick("Try the voice", "试听"), systemImage: "speaker.wave.2.fill")
                        }
                    } header: {
                        Text(language.pick("Chinese voice", "中文声音"))
                    } footer: {
                        Text(language.pick("Chinese is read in a natural voice that runs on this device and works offline.",
                                           "中文用自然的声音朗读，在设备上运行，离线可用。", separator: "\n"))
                    }
                }

                Section {
                    Button {
                        gate = .researchLab
                    } label: {
                        Label(language.pick("Research Lab", "研究实验室"), systemImage: "flask")
                    }
                } footer: {
                    Text(language.pick("On-device model and benchmarking tools, for grown-ups.", "设备上的模型和性能测试工具，供家长使用。",
                                       separator: "\n"))
                }

                Section {
                    NavigationLink {
                        PhotoCreditsView()
                    } label: {
                        Label(language.pick("Photo credits", "照片来源"), systemImage: "photo.stack")
                    }
                }

                Section {
                    Button(language.pick("Reset defaults", "恢复默认设置"), role: .destructive) {
                        voiceIdentifier = ""
                        speechRate = SettingsKey.defaultSpeechRate
                        chineseVoice = KokoroTTS.chineseVoices[0]
                    }
                }

                Section(language.pick("About", "关于")) {
                    LabeledContent(language.pick("Version", "版本"), value: AppInfo.version)
                    LabeledContent(language.pick("Developers", "开发者"), value: AppInfo.developers)
                    Button {
                        gate = .email
                    } label: {
                        Label(AppInfo.contactEmail, systemImage: "envelope")
                    }
                    .accessibilityLabel(language.pick("Contact: ", "联系：") + AppInfo.contactEmail)
                    Text(AppInfo.copyright)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(language.pick("Settings", "设置"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.pick("Done", "完成")) { dismiss() }
                }
            }
            .onAppear { voices = Speech.englishVoices }
            .navigationDestination(isPresented: $showResearchLab) { ResearchLabView() }
            .sheet(isPresented: $showSupport) { SupportView() }
            .sheet(item: $gate) { target in
                NavigationStack {
                    ParentalGate(reason: gateReason(target)) {
                        gate = nil
                        switch target {
                        case .researchLab: showResearchLab = true
                        case .email: openURL(AppInfo.contactURL)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(language.pick("Close", "关闭")) { gate = nil } }
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

    /// The natural English voice's name, kept short enough for one line in Bilingual.
    private var naturalVoiceName: String {
        switch language {
        case .english: return "Natural · Heart (recommended)"
        case .chinese: return "自然 · Heart（推荐）"
        case .both: return "Natural · Heart（推荐）"
        }
    }

    private func gateReason(_ target: GateTarget) -> String {
        switch target {
        case .researchLab: return language.pick("The Research Lab is for grown-ups.", "研究实验室是给家长用的。", separator: "\n")
        case .email: return language.pick("This opens an email to the developers.", "这会打开给开发者的邮件。", separator: "\n")
        }
    }
}

/// Who took the gallery and word photos. All are CC0 or public domain (free to use), from Wikimedia Commons.
private struct PhotoCreditsView: View {
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    var body: some View {
        List {
            section(language.pick("Gallery photos", "图库照片"), Showcase.credits)
            section(language.pick("Word photos", "词语照片"), WordPhotos.credits)
            Section {} footer: {
                Text(language.pick("Thank you to these photographers for sharing their photos freely (CC0 or public domain) on Wikimedia Commons.",
                                   "感谢这些摄影师在 Wikimedia Commons 上免费分享他们的照片（CC0 或公有领域）。", separator: "\n"))
            }
        }
        .navigationTitle(language.pick("Photo credits", "照片来源"))
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
    static let developers = "Chengjiang Long and Yao Xu"
    static let contactEmail = "chengjiang.long@gmail.com"
    static let contactURL = URL(string: "mailto:chengjiang.long@gmail.com")!
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
