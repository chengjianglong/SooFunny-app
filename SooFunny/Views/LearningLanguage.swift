import SwiftUI

/// The language Words and Math are shown and read aloud in. One setting for the whole app, so
/// switching it on one tab switches it everywhere.
enum LearningLanguage: String, CaseIterable, Identifiable {
    case english, chinese, both

    static let key = "learningLanguage"

    var id: String { rawValue }

    /// Short label for the switch.
    var label: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        case .both: return "Bilingual 双语"
        }
    }

    /// Text on screen: "Next", "下一个" or "Next · 下一个". Pass "\n" as the separator for a
    /// sentence, so each language gets its own line.
    func pick(_ english: String, _ chinese: String, separator: String = " · ") -> String {
        switch self {
        case .english: return english
        case .chinese: return chinese
        case .both: return english + separator + chinese
        }
    }

    /// What to say aloud: in Both, English and then Chinese, each in its own voice. Text with no
    /// Chinese is always said in English.
    func spoken(_ english: String, _ chinese: String?) -> String {
        guard let chinese, !chinese.isEmpty else { return english }
        switch self {
        case .english: return english
        case .chinese: return chinese
        case .both:
            // "dog, 狗", but "3 plus 4 equals? 三加四等于几？"
            let joiner = english.last.map { ".!?".contains($0) } == true ? " " : ", "
            return english + joiner + chinese
        }
    }

    /// Whether English is said in this language, so the natural voice is worth preparing.
    var speaksEnglish: Bool { self != .chinese }
}

/// The English / 中文 / Both switch, kept in the top bar of the Words and Math screens.
struct LanguageSwitch: View {
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    var body: some View {
        Menu {
            Picker("Language", selection: $language.animation(.snappy)) {
                ForEach(LearningLanguage.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            // Icon and text, so the language in use is always visible in the top bar.
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text(shortLabel)
            }
            .font(.subheadline.weight(.bold))
            .fixedSize()
        }
        .onChange(of: language) {
            Speech.shared.stop()
            // Get the Chinese voice ready as soon as Chinese is picked.
            if language != .english { NaturalVoiceEngine.chinese.preload() }
        }
        .accessibilityLabel("Language: \(language.label)")
    }

    private var shortLabel: String {
        switch language {
        case .english: return "EN"
        case .chinese: return "中文"
        case .both: return "EN+中"
        }
    }
}

extension View {
    /// Adds the language switch to the top bar.
    func languageSwitch() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) { LanguageSwitch() }
        }
    }
}
