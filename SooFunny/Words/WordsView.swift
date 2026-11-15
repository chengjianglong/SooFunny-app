import SwiftUI

/// The word browser: categories → words → one word. The Back button returns up a level.
struct WordsView: View {
    @State private var categories: [WordCategory] = []
    @State private var loadFailed = false
    @State private var showSettings = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if loadFailed {
                    ContentUnavailableView("Couldn't open the words", systemImage: "book.closed",
                                           description: Text("Please reopen the app to try again."))
                } else {
                    CategoryGrid(categories: categories)
                }
            }
            // No bar title: the big SooFunny title sits at the top, as on the Color tab.
            .navigationDestination(for: WordCategory.self) {
                WordList(category: $0, path: $path)
            }
            .navigationDestination(for: WordDetailRoute.self) {
                WordDetail(route: $0, path: $path)
            }
            .navigationDestination(for: AssistantRoute.self) {
                WordAssistantView(word: $0.category.words[$0.index], category: $0.category)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
                ToolbarItem(placement: .topBarLeading) { LanguageSwitch() }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .task {
            guard categories.isEmpty else { return }
            do { categories = try WordDictionary.loadBundled() } catch { loadFailed = true }
        }
        .onDisappear { Speech.shared.stop() }
    }
}

private struct CategoryGrid: View {
    let categories: [WordCategory]
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 6) {
                    BouncyTitle()
                    Text(language.pick("Pick a group of words to explore!", "选一组词来学习吧！", separator: "\n"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 8)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        NavigationLink(value: category) { row(category, index: index) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding([.horizontal, .bottom], 16)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        // Prepare the group names so the speaker buttons answer instantly.
        .onAppear {
            if language.speaksEnglish { NaturalVoiceEngine.shared.prefetch(categories.map(\.name)) }
            if language != .english { NaturalVoiceEngine.chinese.prefetch(categories.compactMap(\.chinese)) }
        }
    }

    private func row(_ category: WordCategory, index: Int) -> some View {
        HStack(spacing: 14) {
            Picture(emoji: category.emoji, word: category.name, size: 56, tint: tileColor(index))
            VStack(alignment: .leading, spacing: 2) {
                WordName(english: category.name, chinese: category.chinese, language: language)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(language.pick("\(category.words.count) words", "\(category.words.count)个词"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            SpeakButton(text: language.spoken(category.name, category.chinese), size: 18)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct WordList: View {
    let category: WordCategory
    @Binding var path: NavigationPath
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                ForEach(Array(category.words.enumerated()), id: \.element.id) { index, word in
                    NavigationLink(value: WordDetailRoute(category: category, index: index)) {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.callout.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.tint)
                                .frame(minWidth: 26)
                            WordPicture(category: category, word: word, size: 60, tint: tileColor(index))
                            WordName(english: word.text, chinese: word.chinese, language: language)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                                // Shrink long words a little rather than break them ("beave / r")
                                // in narrow columns, as on a 13-inch iPad's three-column list.
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            SpeakButton(text: language.spoken(word.text, word.chinese))
                            TalkButton {
                                path.append(AssistantRoute(category: category, index: index))
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.title(in: language))
        .languageSwitch()
        .onAppear {
            if language.speaksEnglish { NaturalVoiceEngine.shared.prefetch(category.words.map(\.text)) }
            if language != .english { NaturalVoiceEngine.chinese.prefetch(category.words.compactMap(\.chinese)) }
        }
        .navigationBarTitleDisplayMode(.large)
    }
}

struct WordDetailRoute: Hashable {
    let category: WordCategory
    let index: Int
}

/// Opens a spoken conversation about one word.
struct AssistantRoute: Hashable {
    let category: WordCategory
    let index: Int
}

/// Sparkle button that starts a conversation about a word.
private struct TalkButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.gradient, in: Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Talk about it")
    }
}

/// One word, big: its picture, the word to hear, and its letters to tap one by one.
private struct WordDetail: View {
    let route: WordDetailRoute
    @Binding var path: NavigationPath
    @State private var index: Int
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    init(route: WordDetailRoute, path: Binding<NavigationPath>) {
        self.route = route
        _path = path
        _index = State(initialValue: route.index)
    }

    private var words: [WordEntry] { route.category.words }
    private var word: WordEntry { words[index] }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                WordPicture(category: route.category, word: word, size: 240, tint: tileColor(index))
                    .id(word.id)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .onTapGesture { say() }
                    .accessibilityAddTraits(.isButton)
                HStack(spacing: 8) {
                    WordName(english: word.text, chinese: word.chinese, language: language, stacked: true)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.4)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    SpeakButton(text: spoken, size: 30)
                }
                // Each letter (or Chinese character) can be heard on its own.
                if language != .chinese || word.chinese == nil { FlowLetters(text: word.text) }
                if language != .english, let chinese = word.chinese { FlowLetters(text: chinese) }
                Button {
                    path.append(AssistantRoute(category: route.category, index: index))
                } label: {
                    Label(language.pick("Talk about \(word.text)", "聊聊\(word.chinese ?? word.text)", separator: "\n"),
                          systemImage: "sparkles")
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                HStack(spacing: 16) {
                    Button { move(-1) } label: {
                        Label(language.pick("Previous", "上一个"), systemImage: "arrow.left").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(index == 0)
                    Button { move(1) } label: {
                        Label(language.pick("Next", "下一个"), systemImage: "arrow.right").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(index == words.count - 1)
                }
                .buttonStyle(.bordered)
                .font(.headline)
                .frame(maxWidth: 480)
                Text(language.pick("\(index + 1) of \(words.count) in \(route.category.name)",
                                   "\(route.category.chinese ?? route.category.name)：第\(index + 1)个，共\(words.count)个"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(route.category.title(in: language))
        .navigationBarTitleDisplayMode(.inline)
        .languageSwitch()
        .onAppear {
            say()
            prefetchAround()
        }
        // Hear the word again in the language just picked.
        .onChange(of: language) {
            say()
            prefetchAround()
        }
    }

    private var spoken: String { language.spoken(word.text, word.chinese) }

    private func say() { Speech.shared.speak(spoken) }

    private func move(_ step: Int) {
        withAnimation(.spring(duration: 0.35)) { index = min(max(0, index + step), words.count - 1) }
        say()
        prefetchAround()
    }

    /// Prepares this word's letters and the words next to it, so taps answer instantly.
    private func prefetchAround() {
        guard language.speaksEnglish else { return }
        let letters = Set(word.text.filter(\.isLetter).map { String($0).lowercased() })
        let neighbors = [index + 1, index - 1].filter(words.indices.contains).map { words[$0].text }
        NaturalVoiceEngine.shared.prefetch(neighbors + letters.sorted())
    }
}

private struct FlowLetters: View {
    let text: String

    var body: some View {
        let letters = Array(text)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
            ForEach(Array(letters.enumerated()), id: \.offset) { offset, letter in
                if letter.isLetter {
                    Button { Speech.shared.speak(String(letter).lowercased()) } label: {
                        Text(String(letter).uppercased())
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(width: 52, height: 52)
                            .background(tileColor(offset).opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Letter \(letter)")
                } else {
                    Color.clear.frame(width: 52, height: 52)
                }
            }
        }
        .frame(maxWidth: 520)
    }
}

/// A word or group name in the chosen language: English, Chinese, or English with the Chinese
/// beside it (or under it, for the big word on its own page).
struct WordName: View {
    let english: String
    let chinese: String?
    let language: LearningLanguage
    var stacked = false

    var body: some View {
        if let chinese, language == .chinese {
            Text(chinese)
        } else if let chinese, language == .both {
            if stacked {
                VStack(spacing: 4) {
                    Text(english)
                    Text(chinese)
                }
            } else {
                Text("\(english)  \(chinese)")
            }
        } else {
            Text(english)
        }
    }
}

extension WordCategory {
    /// The group's name for the top bar.
    func title(in language: LearningLanguage) -> String {
        guard let chinese else { return name }
        return language.pick(name, chinese)
    }
}

/// The word's emoji, or its first letter on a colored tile when there is none.
struct Picture: View {
    let emoji: String?
    let word: String
    let size: CGFloat
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24).fill(tint.opacity(0.18))
            if let emoji {
                Text(emoji).font(.system(size: size * 0.62))
            } else {
                Text(word.prefix(1).uppercased())
                    .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private let tints: [Color] = [.pink, .orange, .yellow, .green, .teal, .blue, .indigo, .purple]
private func tileColor(_ index: Int) -> Color { tints[index % tints.count] }
