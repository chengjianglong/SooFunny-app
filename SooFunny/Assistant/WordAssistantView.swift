import SwiftUI

/// Talk about one word (or a sport) with the on-device buddy: picture, conversation, and a big
/// Talk button.
struct WordAssistantView: View {
    let word: WordEntry
    let category: WordCategory
    /// Background the buddy keeps to (a sport's introduction), and a picture to show instead of
    /// the word's photos.
    var facts: String?
    var picture: AnyView?

    @State private var assistant: WordAssistant
    @State private var typed = ""
    @State private var permissionAsked = false
    @FocusState private var typing: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english
    /// In Bilingual the child can talk in either language.
    @State private var childSpeaksChinese = false

    init(word: WordEntry, category: WordCategory, facts: String? = nil, picture: AnyView? = nil) {
        self.word = word
        self.category = category
        self.facts = facts
        self.picture = picture
        let language = LearningLanguage(rawValue: UserDefaults.standard.string(forKey: LearningLanguage.key) ?? "") ?? .english
        _assistant = State(initialValue: Self.makeAssistant(word: word, category: category, facts: facts, language: language))
    }

    private static func makeAssistant(word: WordEntry, category: WordCategory, facts: String?,
                                      language: LearningLanguage) -> WordAssistant {
        WordAssistant(word: word.text, category: category.name, language: language,
                      chinese: word.chinese, chineseCategory: category.chinese, facts: facts)
    }

    /// Switching language starts the conversation again in the new language.
    private func restart() {
        assistant.end()
        assistant = Self.makeAssistant(word: word, category: category, facts: facts, language: language)
        if assistant.language == .both, childSpeaksChinese { assistant.listeningLanguage = .chinese }
        assistant.start()
    }

    /// Text in the buddy's language.
    private func say(_ english: String, _ chinese: String) -> String { assistant.language.pick(english, chinese) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        ForEach(assistant.messages) { message in
                            bubble(message).id(message.id)
                        }
                        if !assistant.heard.isEmpty {
                            bubble(ChatMessage(speaker: .child, text: assistant.heard), live: true)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: assistant.messages.last?.text) { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: assistant.heard) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            controls
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(word.chinese.map { language.pick(word.text, $0) } ?? word.text)
        .navigationBarTitleDisplayMode(.inline)
        .languageSwitch()
        .onChange(of: language) {
            restart()
            if language != .english { Task { await LanguageChildListener.prepareChinese() } }
        }
        .task {
            Speech.shared.stop()
            if !permissionAsked {
                permissionAsked = true
                // Ask once up front so the first listening turn isn't interrupted by a prompt.
                SystemChildListener.requestPermission { _ in assistant.start() }
            }
            // Fetch Apple's Mandarin listening model in the background, if this device needs it.
            if language != .english { await LanguageChildListener.prepareChinese() }
        }
        .onDisappear { assistant.end() }
        .onChange(of: assistant.isActive) { _, active in UIApplication.shared.isIdleTimerDisabled = active }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 8) {
            if let picture {
                picture
            } else {
                WordPhotoRow(category: category, word: word, size: sizeClass == .regular ? 190 : 118, tint: .orange)
            }
            WordName(english: word.text, chinese: word.chinese, language: language)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage, live: Bool = false) -> some View {
        let isChild = message.speaker == .child
        VStack(alignment: isChild ? .trailing : .leading, spacing: 4) {
            Text(isChild ? say("You", "你") : say("Buddy", "小伙伴"))
                .font(.caption.weight(.bold))
                .foregroundStyle(isChild ? Color.blue : Color.accentColor)
            highlighted(message)
                .font(.title3)
                .padding(14)
                .background(isChild ? Color.blue.opacity(0.14) : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 18))
                .opacity(live ? 0.7 : 1)
        }
        .frame(maxWidth: .infinity, alignment: isChild ? .trailing : .leading)
    }

    /// Buddy text with the word being spoken right now highlighted.
    private func highlighted(_ message: ChatMessage) -> Text {
        guard message.speaker == .buddy, message.id == assistant.messages.last?.id,
              let sentence = assistant.spokenSentence, let range = assistant.spokenRange,
              let sentenceRange = message.text.range(of: sentence),
              let wordRange = Range(range, in: sentence) else {
            return Text(message.text)
        }
        let start = message.text.distance(from: message.text.startIndex, to: sentenceRange.lowerBound)
        let wordStart = message.text.index(message.text.startIndex,
                                           offsetBy: start + sentence.distance(from: sentence.startIndex, to: wordRange.lowerBound))
        let wordEnd = message.text.index(wordStart, offsetBy: sentence[wordRange].count)
        var attributed = AttributedString(message.text)
        if let lower = AttributedString.Index(wordStart, within: attributed),
           let upper = AttributedString.Index(wordEnd, within: attributed) {
            attributed[lower..<upper].backgroundColor = .yellow.opacity(0.6)
            attributed[lower..<upper].font = .title3.bold()
        }
        return Text(attributed)
    }

    private var statusText: String {
        switch assistant.phase {
        case .preparing: return say("Getting ready… (the first time takes a few seconds)", "准备中……（第一次需要几秒钟）")
        case .speaking: return say("Listen…", "听……")
        case .listening: return say("Listening — your turn!", "在听呢，轮到你了！")
        case .thinking: return say("Thinking about \(word.text)…", "正在想\(word.chinese ?? word.text)……")
        case .ready: return assistant.note ?? say("Tap Talk to ask a question.", "点“说话”来提问吧。")
        case .failed(let message): return message
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isFailed ? .red : .secondary)
                .multilineTextAlignment(.center)
            if assistant.phase == .listening {
                Text(say("Speak, then pause. Tap Done when you finish.", "说完停一下，或者点“好了”。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button(action: mainAction) {
                    Label(mainTitle, systemImage: mainIcon)
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(assistant.isActive || assistant.phase == .preparing ? .green : .accentColor)
                .disabled(assistant.phase == .preparing)
                if assistant.phase == .listening {
                    Button(say("Cancel", "取消")) { assistant.cancel() }
                        .font(.headline)
                }
            }
            if assistant.language == .both {
                Picker("I speak", selection: $childSpeaksChinese) {
                    Text("I speak English").tag(false)
                    Text("我说中文").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .onChange(of: childSpeaksChinese) { _, chinese in
                    assistant.listeningLanguage = chinese ? .chinese : .english
                    if assistant.phase == .listening { assistant.talk() }
                }
            }
            HStack {
                TextField(say("Type a question", "输入问题"), text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .submitLabel(.send)
                    .onSubmit(sendTyped)
                Button(action: sendTyped) {
                    Image(systemName: "paperplane.fill").font(.title3)
                }
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty || assistant.phase == .preparing)
                .accessibilityLabel(say("Send", "发送"))
            }
            Text(say("Voice and conversation stay on this device. The buddy can make mistakes.",
                     "声音和对话只留在这台设备上。小伙伴也可能说错。"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var isFailed: Bool {
        if case .failed = assistant.phase { return true }
        return false
    }

    private var mainTitle: String {
        switch assistant.phase {
        case .listening: return say("Done", "好了")
        case .thinking: return say("Cancel", "取消")
        case .speaking: return say("Stop speaking", "停止")
        case .preparing: return say("Getting ready", "准备中")
        case .ready, .failed: return say("Talk", "说话")
        }
    }

    private var mainIcon: String {
        switch assistant.phase {
        case .listening: return "checkmark.circle.fill"
        case .thinking: return "xmark.circle.fill"
        case .speaking: return "speaker.slash.fill"
        case .preparing: return "hourglass"
        case .ready, .failed: return "mic.fill"
        }
    }

    private func mainAction() {
        switch assistant.phase {
        case .listening: assistant.doneListening()
        case .thinking, .speaking: assistant.cancel()
        case .preparing: break
        case .ready, .failed: assistant.talk()
        }
    }

    private func sendTyped() {
        let text = typed
        typed = ""
        typing = false
        assistant.send(text)
    }
}
