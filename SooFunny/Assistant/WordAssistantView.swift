import SwiftUI

/// Talk about one word with the on-device buddy: picture, conversation, and a big Talk button.
struct WordAssistantView: View {
    let word: WordEntry
    let category: WordCategory

    @State private var assistant: WordAssistant
    @State private var typed = ""
    @State private var permissionAsked = false
    @FocusState private var typing: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(word: WordEntry, category: WordCategory) {
        self.word = word
        self.category = category
        _assistant = State(initialValue: WordAssistant(word: word.text, category: category.name))
    }

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
        .navigationTitle(word.text)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            Speech.shared.stop()
            if !permissionAsked {
                permissionAsked = true
                // Ask once up front so the first listening turn isn't interrupted by a prompt.
                SystemChildListener.requestPermission { _ in assistant.start() }
            }
        }
        .onDisappear { assistant.end() }
        .onChange(of: assistant.isActive) { _, active in UIApplication.shared.isIdleTimerDisabled = active }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 8) {
            WordPhotoRow(category: category, word: word, size: sizeClass == .regular ? 190 : 118, tint: .orange)
            Text(word.text)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage, live: Bool = false) -> some View {
        let isChild = message.speaker == .child
        VStack(alignment: isChild ? .trailing : .leading, spacing: 4) {
            Text(isChild ? "You" : "Buddy")
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
        case .preparing: return "Getting ready… (the first time takes a few seconds)"
        case .speaking: return "Listen…"
        case .listening: return "Listening — your turn!"
        case .thinking: return "Thinking about \(word.text)…"
        case .ready: return assistant.note ?? "Tap Talk to ask a question."
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
                Text("Speak, then pause. Tap Done when you finish.")
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
                    Button("Cancel") { assistant.cancel() }
                        .font(.headline)
                }
            }
            HStack {
                TextField("Type a question", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .submitLabel(.send)
                    .onSubmit(sendTyped)
                Button(action: sendTyped) {
                    Image(systemName: "paperplane.fill").font(.title3)
                }
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty || assistant.phase == .preparing)
                .accessibilityLabel("Send")
            }
            Text("Voice and conversation stay on this device. The buddy can make mistakes.")
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
        case .listening: return "Done"
        case .thinking: return "Cancel"
        case .speaking: return "Stop speaking"
        case .preparing: return "Getting ready"
        case .ready, .failed: return "Talk"
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
