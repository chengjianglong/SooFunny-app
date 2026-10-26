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
            .navigationTitle("Words")
            .navigationDestination(for: WordCategory.self) { WordList(category: $0, path: $path) }
            .navigationDestination(for: WordDetailRoute.self) { WordDetail(route: $0, path: $path) }
            .navigationDestination(for: AssistantRoute.self) {
                WordAssistantView(word: $0.category.words[$0.index], category: $0.category)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick a group of words to explore. Tap the speaker to hear it.")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        NavigationLink(value: category) {
                            HStack(spacing: 14) {
                                Picture(emoji: category.emoji, word: category.name, size: 56, tint: tileColor(index))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name).font(.title3.weight(.bold)).foregroundStyle(.primary)
                                    Text("\(category.words.count) words").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                SpeakButton(text: category.name, size: 18)
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct WordList: View {
    let category: WordCategory
    @Binding var path: NavigationPath

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
                            Picture(emoji: word.emoji, word: word.text, size: 52, tint: tileColor(index))
                            Text(word.text)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            SpeakButton(text: word.text)
                            TalkButton { path.append(AssistantRoute(category: category, index: index)) }
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
        .navigationTitle(category.name)
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
                Picture(emoji: word.emoji, word: word.text, size: 200, tint: tileColor(index))
                    .onTapGesture { Speech.shared.speak(word.text) }
                    .accessibilityAddTraits(.isButton)
                HStack(spacing: 8) {
                    Text(word.text)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.4)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    SpeakButton(text: word.text, size: 30)
                }
                // Each letter can be heard on its own.
                FlowLetters(text: word.text)
                Button {
                    path.append(AssistantRoute(category: route.category, index: index))
                } label: {
                    Label("Talk about \(word.text)", systemImage: "sparkles")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: 480, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                HStack(spacing: 16) {
                    Button { move(-1) } label: {
                        Label("Previous", systemImage: "arrow.left").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(index == 0)
                    Button { move(1) } label: {
                        Label("Next", systemImage: "arrow.right").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(index == words.count - 1)
                }
                .buttonStyle(.bordered)
                .font(.headline)
                .frame(maxWidth: 480)
                Text("\(index + 1) of \(words.count) in \(route.category.name)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(route.category.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Speech.shared.speak(word.text) }
    }

    private func move(_ step: Int) {
        index = min(max(0, index + step), words.count - 1)
        Speech.shared.speak(word.text)
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
