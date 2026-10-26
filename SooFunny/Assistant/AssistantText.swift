import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Speaker { case child, buddy }
    let id = UUID()
    let speaker: Speaker
    var text: String

    static func == (a: ChatMessage, b: ChatMessage) -> Bool { a.speaker == b.speaker && a.text == b.text }
}

/// Prompts for Gemma, in its chat format. Gemma has no system role, so the guidance
/// goes at the top of the first user turn.
enum AssistantPrompts {
    static let replyTokenLimit = 160

    private static func rules(word: String, category: String) -> String {
        """
        You are a cheerful learning buddy talking with a young child (about 4 to 8 years old) \
        about the English word "\(word)" from the group "\(category)". Your words are read aloud.
        Rules: Use short, simple sentences and easy words. Say at most three sentences and no more \
        than forty words. Write plain spoken text only: no lists, no markdown, no emojis, no labels. \
        Write numbers as words. Be kind, curious and encouraging. Stay on topic and keep everything \
        safe for children. If you are not sure about something, say so simply. End by asking one \
        short question the child might enjoy answering, unless the child wants to stop; then say a \
        short friendly goodbye. Never start with "Okay" or a greeting.
        """
    }

    /// The opening turn: a short explanation of the word. The app adds the question itself,
    /// because a small model doesn't reliably ask it word for word.
    static func introduction(word: String, category: String) -> String {
        turn(user: rules(word: word, category: category)
             + "\nIn one or two short sentences, tell the child what \"\(word)\" is. "
             + "Start directly with the word \"\(word)\". Do not greet and do not ask a question.")
    }

    /// Spoken after the introduction, like the buddy in the demo.
    static func introductionQuestion(word: String) -> String {
        "What would you like to know about \(word)?"
    }

    /// A follow-up: recent conversation plus the child's new question.
    static func reply(word: String, category: String, history: [ChatMessage], question: String) -> String {
        var transcript = ""
        for message in history.suffix(8) {
            transcript += (message.speaker == .child ? "Child: " : "Buddy: ") + String(message.text.prefix(600)) + "\n"
        }
        return turn(user: rules(word: word, category: category)
                    + "\nConversation so far:\n" + transcript
                    + "Child: " + String(question.prefix(400))
                    + "\nAnswer the child's last message as the Buddy.")
    }

    private static func turn(user: String) -> String {
        "<start_of_turn>user\n\(user)<end_of_turn>\n<start_of_turn>model\n"
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

    /// The index just past a sentence-ending mark that is followed by whitespace.
    private static func sentenceEnd(in text: String) -> String.Index? {
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
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
        for label in ["Buddy:", "Gemma:", "Model:", "Assistant:"] where s.trimmingCharacters(in: .whitespaces).hasPrefix(label) {
            s = String(s.trimmingCharacters(in: .whitespaces).dropFirst(label.count))
        }
        s = String(s.unicodeScalars.filter { scalar in
            !"*_#`~>".unicodeScalars.contains(scalar)
                && !(scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0x2000))
        }.map(Character.init))
        return s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
