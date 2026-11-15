import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Speaker { case child, buddy }
    let id = UUID()
    let speaker: Speaker
    var text: String

    static func == (a: ChatMessage, b: ChatMessage) -> Bool { a.speaker == b.speaker && a.text == b.text }
}

/// Prompts for Qwen, in its chat format (ChatML): the buddy's rules are the system message,
/// then the conversation so far as alternating turns.
enum AssistantPrompts {
    static let replyTokenLimit = 160

    /// Both says everything twice, so it gets more room.
    static func tokenLimit(for language: LearningLanguage) -> Int {
        language == .both ? replyTokenLimit * 2 : replyTokenLimit
    }

    /// The word in the language the conversation is in: "lion", "狮子 (lion)" or "lion (狮子)".
    private static func topic(_ word: String, _ chinese: String?, _ language: LearningLanguage) -> String {
        guard let chinese, !chinese.isEmpty else { return "\"\(word)\"" }
        switch language {
        case .english: return "\"\(word)\""
        case .chinese: return "\"\(chinese)\" (\(word) in English)"
        case .both: return "\"\(word)\" (\"\(chinese)\" in Chinese)"
        }
    }

    private static func rules(word: String, category: String, language: LearningLanguage, chinese: String?,
                              facts: String? = nil) -> String {
        let about = topic(word, chinese, language)
        // What the child has just read about it (a sport's introduction), so answers match it.
        let background = facts.map { "\nWhat the child just read about it: \($0)" } ?? ""
        let languageRules: String
        switch language {
        case .english:
            languageRules = "about the English word \(about) from the group \"\(category)\". Your words are read aloud.\n"
                + "Rules: Use short, simple sentences and easy words. Say at most three sentences and no more "
                + "than forty words."
        case .chinese:
            languageRules = "about the Chinese word \(about) from the group \"\(category)\". Your words are read aloud.\n"
                + "Rules: Always answer only in simple Mandarin Chinese with simplified characters (简体中文), "
                + "even if the child speaks English. Never add an English translation. Use short, simple sentences and easy words. Say at most three "
                + "sentences and no more than sixty Chinese characters. For example: 猫是一种小宠物。猫喜欢睡觉。"
        case .both:
            languageRules = "about the word \(about) from the group \"\(category)\". The child is learning English and "
                + "Chinese. Your words are read aloud.\n"
                + "Rules: Say each sentence in simple English first, then the same sentence in simple Mandarin "
                + "Chinese with simplified characters (简体中文). Use short, simple sentences and easy words. Say "
                + "at most two sentences, each in both languages. For example: A cat is a small pet. 猫是一种小宠物。 "
                + "Cats like to sleep. 猫喜欢睡觉。"
        }
        return """
        You are a cheerful learning buddy talking with a young child (about 4 to 8 years old) \
        \(languageRules) Write plain spoken text only: no lists, no markdown, no emojis, no labels, \
        no pinyin. Write numbers as words. Be kind, curious and encouraging. Stay on topic and keep everything \
        safe for children. If you are not sure about something, say so simply. End by asking one \
        short question the child might enjoy answering, unless the child wants to stop; then say a \
        short friendly goodbye. Never start with "Okay" or a greeting.
        """ + background
    }

    /// The opening turn: a short explanation of the word. The app adds the question itself,
    /// because a small model doesn't reliably ask it word for word.
    static func introduction(word: String, category: String, language: LearningLanguage = .english,
                             chinese: String? = nil, facts: String? = nil) -> String {
        let ask: String
        switch language {
        case .english:
            ask = "In one or two short sentences, tell the child what \"\(word)\" is. "
                + "Start directly with the word \"\(word)\"."
        case .chinese:
            let name = chinese ?? word
            ask = "In one or two short sentences in Chinese, tell the child what \"\(name)\" is. "
                + "Start directly with the word \"\(name)\"."
        case .both:
            ask = "In one short English sentence, tell the child what \"\(word)\" is, then say the same "
                + "sentence in Chinese. Start directly with the word \"\(word)\"."
        }
        return chat(system: rules(word: word, category: category, language: language, chinese: chinese, facts: facts),
                    turns: [(.child, ask + " Do not greet and do not ask a question.")])
    }

    /// Spoken after the introduction, like the buddy in the demo.
    static func introductionQuestion(word: String, language: LearningLanguage = .english, chinese: String? = nil) -> String {
        let english = "What would you like to know about \(word)?"
        let inChinese = "关于\(chinese ?? word)，你想知道什么？"
        switch language {
        case .english: return english
        case .chinese: return inChinese
        case .both: return "\(english) \(inChinese)"
        }
    }

    /// A follow-up: recent conversation plus the child's new question.
    static func reply(word: String, category: String, history: [ChatMessage], question: String,
                      language: LearningLanguage = .english, chinese: String? = nil, facts: String? = nil) -> String {
        let turns = history.suffix(8).map { ($0.speaker, String($0.text.prefix(600))) }
            + [(ChatMessage.Speaker.child, String(question.prefix(400)))]
        return chat(system: rules(word: word, category: category, language: language, chinese: chinese, facts: facts),
                    turns: turns)
    }

    /// The child speaks as the user and the buddy as the assistant; the prompt ends where the
    /// buddy's next reply begins.
    private static func chat(system: String, turns: [(ChatMessage.Speaker, String)]) -> String {
        var prompt = "<|im_start|>system\n\(system)<|im_end|>\n"
        for (speaker, text) in turns {
            // Keep the child's words from closing the turn early.
            let clean = text.replacingOccurrences(of: "<|", with: "<")
            prompt += "<|im_start|>\(speaker == .child ? "user" : "assistant")\n\(clean)<|im_end|>\n"
        }
        return prompt + "<|im_start|>assistant\n"
    }
}

/// Splits streamed text into complete sentences so speech can start before the reply ends.
struct SentenceStream {
    private var buffer = ""

    /// Adds text and returns any sentences it completed.
    mutating func append(_ text: String) -> [String] {
        buffer += text
        var sentences: [String] = []
        while let end = Self.sentenceEnd(in: buffer) {
            let sentence = AssistantCleanup.clean(String(buffer[..<end]))
            buffer = String(buffer[end...])
            if !sentence.isEmpty { sentences.append(sentence) }
        }
        return sentences
    }

    /// Whatever is left once the reply has finished.
    mutating func finish() -> [String] {
        let rest = AssistantCleanup.clean(buffer)
        buffer = ""
        return rest.isEmpty ? [] : [rest]
    }

    /// The index just past a sentence-ending mark that is followed by whitespace, or just past a
    /// Chinese one (。！？), which needs no space after it.
    private static func sentenceEnd(in text: String) -> String.Index? {
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if "。！？".contains(text[index]), next < text.endIndex {
                return next
            }
            if ".!?".contains(text[index]), next < text.endIndex, text[next].isWhitespace {
                // Keep closing quotes and the like with the sentence.
                return next
            }
            index = next
        }
        return nil
    }
}

enum AssistantCleanup {
    /// Removes markdown, emojis and speaker labels a small model sometimes adds.
    static func clean(_ text: String) -> String {
        var s = text
        for label in ["Buddy:", "Qwen:", "Model:", "Assistant:"] where s.trimmingCharacters(in: .whitespaces).hasPrefix(label) {
            s = String(s.trimmingCharacters(in: .whitespaces).dropFirst(label.count))
        }
        // Pinyin the model adds in brackets, "狗 (gǒu)": the characters are already there.
        s = s.replacingOccurrences(of: "\\s*[(（][^()（）]*[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ][^()（）]*[)）]", with: "",
                                   options: .regularExpression)
        s = String(s.unicodeScalars.filter { scalar in
            !"*_#`~>".unicodeScalars.contains(scalar)
                && !(scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0x2000))
        }.map(Character.init))
        return s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            // Chinese has no spaces between words: "狗 是 动物。" → "狗是动物。"
            .replacingOccurrences(of: "(?<=[\\p{Han}，。！？、：；]) (?=[\\p{Han}，。！？、：；])", with: "",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
