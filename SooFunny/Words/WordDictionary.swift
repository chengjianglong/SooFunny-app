import Foundation

struct WordEntry: Identifiable, Hashable {
    let text: String
    /// Picture for the word; nil when no emoji fits, and a letter tile is shown instead.
    let emoji: String?

    var id: String { text }
}

struct WordCategory: Identifiable, Hashable {
    let name: String
    let emoji: String?
    let words: [WordEntry]

    var id: String { name }
}

/// The kids' word list bundled as `kids_words.txt`.
///
/// Format: blank-line-separated sections. Each starts with `Category: <name>` and has one
/// word per line. Either may end with `| <emoji>`. Order and text are kept as written.
enum WordDictionary {
    static let resourceName = "kids_words"

    enum ParseError: Error, Equatable {
        case wordBeforeCategory(line: Int)
        case emptyCategoryName(line: Int)
        case emptyCategory(String)
        case noCategories
    }

    static func loadBundled(_ bundle: Bundle = .main) throws -> [WordCategory] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "txt") else { throw ParseError.noCategories }
        return try parse(String(contentsOf: url, encoding: .utf8))
    }

    static func parse(_ text: String) throws -> [WordCategory] {
        var categories: [WordCategory] = []
        var current: (name: String, emoji: String?)?
        var words: [WordEntry] = []

        func finishCategory() throws {
            if let current {
                guard !words.isEmpty else { throw ParseError.emptyCategory(current.name) }
                categories.append(WordCategory(name: current.name, emoji: current.emoji, words: words))
            }
            current = nil
            words = []
        }

        for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
            let line = (index == 0 ? raw.replacingOccurrences(of: "\u{FEFF}", with: "") : raw)
                .trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                try finishCategory()
            } else if line.hasPrefix("Category:") {
                try finishCategory()
                let (name, emoji) = split(String(line.dropFirst("Category:".count)))
                guard !name.isEmpty else { throw ParseError.emptyCategoryName(line: index + 1) }
                current = (name, emoji)
            } else {
                guard current != nil else { throw ParseError.wordBeforeCategory(line: index + 1) }
                let (word, emoji) = split(line)
                words.append(WordEntry(text: word, emoji: emoji))
            }
        }
        try finishCategory()
        guard !categories.isEmpty else { throw ParseError.noCategories }
        return categories
    }

    /// "cat | 🐱" → ("cat", "🐱"); "cat" → ("cat", nil).
    private static func split(_ text: String) -> (String, String?) {
        let parts = text.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        let emoji = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        return (parts.first ?? "", emoji)
    }
}
