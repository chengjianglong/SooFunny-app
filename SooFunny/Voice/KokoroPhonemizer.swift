import Foundation

/// Turns English text into Kokoro's phonemes, entirely offline.
///
/// A compact Swift port of the dictionary path of misaki (Apache-2.0), Kokoro's own
/// phonemizer: a 183k-word US pronunciation dictionary, misaki's rules for small function
/// words ("a", "the", "to", …) and for -s, -ed and -ing endings, numbers spelled out, and
/// unknown words spelled letter by letter. There's no part-of-speech tagger, so words with
/// several readings ("read") use their most common one.
final class KokoroPhonemizer {
    /// Kokoro's phoneme → token id table.
    let vocab: [Character: Int64]
    private let lexicon: [String: String]

    private static let vowels: Set<Character> = Set("AIOQWYaiuæɑɒɔəɛɜɪʊʌᵻ")
    private static let taus: Set<Character> = Set("AIOWYiuæɑəɛɪɹʊʌ")
    private static let punctuation: Set<Character> = Set(";:,.!?—…\"()“”")
    /// Words the dictionary doesn't have that should be said, not spelled: the app's name is
    /// "Soo Funny" ("Soo" rhymes with "zoo"), and "iPhone" and "iPad" are "eye phone" and "eye pad".
    private static let extraWords = ["soo": "sˈu", "soofunny": "sˈu fˈʌni",
                                     "iphone": "ˈI fˈOn", "ipad": "ˈI pˈæd"]

    init(lexiconURL: URL, vocabURL: URL) throws {
        var lexicon: [String: String] = [:]
        lexicon.reserveCapacity(190_000)
        for line in try String(contentsOf: lexiconURL, encoding: .utf8).split(separator: "\n") {
            guard let tab = line.firstIndex(of: "\t") else { continue }
            lexicon[String(line[..<tab])] = String(line[line.index(after: tab)...])
        }
        var vocab: [Character: Int64] = [:]
        // Don't trim lines: one of the phonemes is the space character.
        for line in try String(contentsOf: vocabURL, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count == 2, let symbol = parts[0].first, let id = Int64(parts[1]) else { continue }
            vocab[symbol] = id
        }
        lexicon.merge(Self.extraWords) { dictionary, _ in dictionary }
        self.lexicon = lexicon
        self.vocab = vocab
    }

    /// Phonemes for `text`, using only symbols Kokoro knows.
    func phonemize(_ text: String) -> String {
        let tokens = Self.tokens(in: Self.expandNumbers(text))
        // A single letter is said as its name ("B" is "bee", "a" is "ay").
        if tokens.count == 1, let only = tokens.first, only.count == 1, only.first!.isLetter {
            return filter(raw(only.uppercased()) ?? "")
        }
        var out = ""
        for (i, token) in tokens.enumerated() {
            if let c = token.first, Self.punctuation.contains(c) {
                out += token
                continue
            }
            let next = i + 1 < tokens.count ? tokens[i + 1] : nil
            if !out.isEmpty { out += " " }
            out += word(token, nextStartsWithVowel: next.flatMap(startsWithVowel))
        }
        return filter(out)
    }

    /// Token ids for the model: phonemes wrapped in the boundary token 0.
    func tokenIDs(for phonemes: String) -> [Int64] {
        [0] + phonemes.compactMap { vocab[$0] } + [0]
    }

    // MARK: - Words

    private func word(_ w: String, nextStartsWithVowel: Bool?) -> String {
        let lower = w.lowercased()
        switch lower {
        case "a": return "ɐ"
        case "an": return "ɐn"
        case "the": return nextStartsWithVowel == true ? "ði" : "ðə"
        case "to": return nextStartsWithVowel == true ? "tʊ" : "tə"
        default: break
        }
        if w == "I" { return "ˌI" }
        if let p = raw(w) { return p }
        if lower.hasSuffix("'s"), let stem = raw(String(lower.dropLast(2))) { return Self.plural(stem) }
        if lower.count > 2, lower.hasSuffix("s") {
            if let stem = raw(String(lower.dropLast())) { return Self.plural(stem) }
            if lower.hasSuffix("ies"), let stem = raw(String(lower.dropLast(3)) + "y") { return Self.plural(stem) }
            if lower.hasSuffix("es"), let stem = raw(String(lower.dropLast(2))) { return Self.plural(stem) }
        }
        if lower.count > 3, lower.hasSuffix("ed") {
            if let stem = raw(String(lower.dropLast())) { return Self.past(stem) }
            if let stem = raw(String(lower.dropLast(2))) { return Self.past(stem) }
        }
        if lower.count > 4, lower.hasSuffix("ing") {
            let base = String(lower.dropLast(3))
            for candidate in [base, base + "e", String(base.dropLast())] {
                if let stem = raw(candidate) { return Self.continuous(stem) }
            }
        }
        // Unknown word: say its letters.
        return lower.filter(\.isLetter).compactMap { raw(String($0).uppercased()) }.joined()
    }

    /// Dictionary lookup, trying the word as written, lowercase and capitalized.
    private func raw(_ w: String) -> String? {
        lexicon[w] ?? lexicon[w.lowercased()] ?? lexicon[w.capitalized]
    }

    private func startsWithVowel(_ w: String) -> Bool? {
        guard let first = w.first, first.isLetter else { return nil }
        let p = (raw(w) ?? "").filter { $0 != "ˈ" && $0 != "ˌ" }
        guard let sound = p.first else { return nil }
        return Self.vowels.contains(sound)
    }

    private static func plural(_ stem: String) -> String {
        guard let last = stem.last else { return stem }
        if "ptkfθ".contains(last) { return stem + "s" }
        if "szʃʒʧʤ".contains(last) { return stem + "ᵻz" }
        return stem + "z"
    }

    private static func past(_ stem: String) -> String {
        guard let last = stem.last else { return stem }
        if "pkfθʃsʧ".contains(last) { return stem + "t" }
        if last == "d" { return stem + "ᵻd" }
        if last != "t" { return stem + "d" }
        if stem.count > 1, taus.contains(stem[stem.index(stem.endIndex, offsetBy: -2)]) {
            return String(stem.dropLast()) + "ɾᵻd"
        }
        return stem + "ᵻd"
    }

    private static func continuous(_ stem: String) -> String {
        if stem.count > 1, stem.last == "t", taus.contains(stem[stem.index(stem.endIndex, offsetBy: -2)]) {
            return String(stem.dropLast()) + "ɾɪŋ"
        }
        return stem + "ɪŋ"
    }

    // MARK: - Text

    private func filter(_ s: String) -> String {
        String(s.filter { vocab[$0] != nil })
    }

    /// Words (with apostrophes), numbers and punctuation, in order.
    static func tokens(in text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { tokens.append(current) }
            current = ""
        }
        let chars = Array(text)
        for (i, c) in chars.enumerated() {
            if c.isLetter || c.isNumber {
                current.append(c)
            } else if (c == "'" || c == "’"), !current.isEmpty, i + 1 < chars.count, chars[i + 1].isLetter {
                current.append("'")
            } else {
                flush()
                if punctuation.contains(c) { tokens.append(String(c)) }
            }
        }
        flush()
        return tokens
    }

    /// Writes whole numbers as words: "12" → "twelve", "21" → "twenty one".
    static func expandNumbers(_ text: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .spellOut
        var result = ""
        var digits = ""
        func flush() {
            if let n = Int(digits), let words = formatter.string(from: NSNumber(value: n)) {
                result += " " + words.replacingOccurrences(of: "-", with: " ") + " "
            } else {
                result += digits
            }
            digits = ""
        }
        for c in text {
            if c.isASCII, c.isNumber {
                digits.append(c)
            } else {
                if !digits.isEmpty { flush() }
                result.append(c)
            }
        }
        if !digits.isEmpty { flush() }
        return result
    }
}
