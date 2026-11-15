import Foundation

/// Turns Chinese text into the phonemes Kokoro's Chinese model (v1.1-zh) reads: zhuyin-like
/// symbols with tone numbers, as misaki's `ZHG2P(version: "1.1")` makes them.
///
/// A port of misaki's Chinese front end (itself adapted from PaddleSpeech, Apache-2.0), with the
/// parts it relies on: jieba's dictionary segmentation and part-of-speech HMM, and pypinyin's
/// readings. The data comes from those projects (MIT) in `ChineseG2P/`; `ChineseG2PTests` checks
/// the result matches misaki on all of the app's Chinese text.
///
/// Loading takes a moment, so make one and keep it. Not thread-safe.
final class ChineseG2P {
    enum G2PError: Error { case missingData }

    private let chars: [Character: String]
    private let phrases: [String: [String]]
    private let maxPhrase: Int
    private let freq: [String: Int]
    private let tags: [String: String]
    private let logTotal: Double
    private let mustNeural: Set<String>
    private let mustNotNeural: Set<String>
    private let mustErhua: Set<String>
    private let notErhua: Set<String>
    private let hmm: HMM
    /// English parts are given to this (the English voice's phonemizer).
    private let english: (String) -> String

    init(bundle: Bundle = .main, english: @escaping (String) -> String) throws {
        func lines(_ name: String) throws -> [Substring] {
            guard let url = bundle.url(forResource: name, withExtension: "tsv") else { throw G2PError.missingData }
            return try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: true)
        }
        var chars: [Character: String] = [:]
        for line in try lines("zh_chars") {
            let f = line.split(separator: "\t")
            if f.count == 2, let c = f[0].first { chars[c] = String(f[1]) }
        }
        var phrases: [String: [String]] = [:]
        var maxPhrase = 2
        for line in try lines("zh_phrases") {
            let f = line.split(separator: "\t")
            guard f.count == 2 else { continue }
            phrases[String(f[0])] = f[1].split(separator: " ").map(String.init)
            maxPhrase = max(maxPhrase, f[0].count)
        }
        var freq: [String: Int] = [:]
        var tags: [String: String] = [:]
        var total = 0
        for line in try lines("zh_words") {
            let f = line.split(separator: "\t")
            guard f.count == 3, let n = Int(f[1]) else { continue }
            let word = String(f[0])
            freq[word] = n
            tags[word] = String(f[2])
            total += n
            // jieba keeps every prefix of a word, with frequency 0, to know when to keep looking.
            var prefix = ""
            for c in word.dropLast() {
                prefix.append(c)
                if freq[prefix] == nil { freq[prefix] = 0 }
            }
        }
        guard let rulesURL = bundle.url(forResource: "zh_rules", withExtension: "json"),
              let rules = try JSONSerialization.jsonObject(with: Data(contentsOf: rulesURL)) as? [String: [String]] else {
            throw G2PError.missingData
        }
        self.chars = chars
        self.phrases = phrases
        self.maxPhrase = maxPhrase
        self.freq = freq
        self.tags = tags
        self.logTotal = log(Double(total))
        mustNeural = Set(rules["must_neural"] ?? [])
        mustNotNeural = Set(rules["must_not_neural"] ?? [])
        mustErhua = Set(rules["must_erhua"] ?? [])
        notErhua = Set(rules["not_erhua"] ?? [])
        hmm = try HMM(lines: try lines("zh_hmm"))
        self.english = english
    }

    // MARK: - Whole text

    /// Phonemes for text that may mix Chinese and English.
    func phonemize(_ text: String) -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let mapped = Self.mapPunctuation(Self.numbersToChinese(text))
        var segments: [String] = []
        // English runs (letters with spaces, apostrophes and hyphens) and everything else.
        let pattern = try! NSRegularExpression(pattern: "([A-Za-z '-]*[A-Za-z][A-Za-z '-]*)|([^A-Za-z]+)")
        let ns = mapped as NSString
        for m in pattern.matches(in: mapped, range: NSRange(location: 0, length: ns.length)) {
            if m.range(at: 1).location != NSNotFound {
                let en = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if !en.isEmpty { segments.append(english(en)) }
            } else {
                let zh = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
                if !zh.isEmpty { segments.append(frontend(zh)) }
            }
        }
        return segments.joined(separator: " ")
    }

    static func mapPunctuation(_ text: String) -> String {
        var t = text
        for (a, b) in [("、", ", "), ("，", ", "), ("。", ". "), ("．", ". "), ("！", "! "), ("：", ": "), ("；", "; "), ("？", "? "),
                       ("«", " “"), ("»", "” "), ("《", " “"), ("》", "” "), ("「", " “"), ("」", "” "), ("【", " “"), ("】", "” "),
                       ("（", " ("), ("）", ") ")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Arabic numbers in Chinese words, as cn2an does: 175 → 一百七十五, 3.5 → 三点五, 50% → 百分之五十.
    static func numbersToChinese(_ text: String) -> String {
        var t = text
        let percent = try! NSRegularExpression(pattern: "(\\d+)%")
        for m in percent.matches(in: t, range: NSRange(t.startIndex..., in: t)).reversed() {
            let n = Int((t as NSString).substring(with: m.range(at: 1))) ?? 0
            t = (t as NSString).replacingCharacters(in: m.range, with: "百分之" + chineseNumber(n))
        }
        let number = try! NSRegularExpression(pattern: "\\d+(?:\\.\\d+)?")
        for m in number.matches(in: t, range: NSRange(t.startIndex..., in: t)).reversed() {
            let s = (t as NSString).substring(with: m.range)
            let parts = s.split(separator: ".")
            var words = chineseNumber(Int(parts[0]) ?? 0)
            if parts.count > 1 { words += "点" + parts[1].map { digits[Int(String($0)) ?? 0] }.joined() }
            t = (t as NSString).replacingCharacters(in: m.range, with: words)
        }
        return t
    }

    private static let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    static func chineseNumber(_ n: Int) -> String {
        if n == 0 { return "零" }
        if n < 0 { return "负" + chineseNumber(-n) }
        for (unit, name) in [(100_000_000, "亿"), (10_000, "万")] where n >= unit {
            let (hi, lo) = n.quotientAndRemainder(dividingBy: unit)
            return chineseNumber(hi) + name + (lo == 0 ? "" : (lo < unit / 10 ? "零" : "") + chineseNumber(lo))
        }
        var out = ""
        var zero = false
        for (unit, name) in [(1000, "千"), (100, "百"), (10, "十"), (1, "")] {
            let d = n / unit % 10
            if d == 0 {
                zero = !out.isEmpty
            } else {
                if zero { out += "零" }
                out += digits[d] + name
                zero = false
            }
        }
        return out
    }

    // MARK: - Chinese

    private struct Token {
        var word: String
        var tag: String
        var phonemes: String?
        var whitespace = ""
    }

    private static let punctuation: Set<Character> = Set(";:,.!?—…\"()“”")
    private static let xEng: Set<String> = ["x", "eng"]
    private static let zhMap: [String: String] = {
        var m = ["b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ", "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ", "g": "ㄍ", "k": "ㄎ", "h": "ㄏ",
                 "j": "ㄐ", "q": "ㄑ", "x": "ㄒ", "zh": "ㄓ", "ch": "ㄔ", "sh": "ㄕ", "r": "ㄖ", "z": "ㄗ", "c": "ㄘ", "s": "ㄙ",
                 "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "ie": "ㄝ", "ai": "ㄞ", "ei": "ㄟ", "ao": "ㄠ", "ou": "ㄡ", "an": "ㄢ", "en": "ㄣ",
                 "ang": "ㄤ", "eng": "ㄥ", "er": "ㄦ", "i": "ㄧ", "u": "ㄨ", "v": "ㄩ", "ii": "ㄭ", "iii": "十", "ve": "月",
                 "ia": "压", "ian": "言", "iang": "阳", "iao": "要", "in": "阴", "ing": "应", "iong": "用", "iou": "又", "ong": "中",
                 "ua": "穵", "uai": "外", "uan": "万", "uang": "王", "uei": "为", "uen": "文", "ueng": "瓮", "uo": "我", "van": "元",
                 "vn": "云"]
        for p in ";:,.!?/—…\"()“” 12345R" { m[String(p)] = String(p) }
        return m
    }()

    private func frontend(_ text: String) -> String {
        var tokens: [Token] = []
        for (word, rawTag) in merge(posseg(text)) {
            var tag = rawTag
            let w = Array(word)
            if tag == "x", let lo = w.min(), let hi = w.max(), lo >= "\u{4E00}", hi <= "\u{9FFF}" {
                tag = "X"
            } else if tag != "x", w.count == 1, Self.punctuation.contains(w[0]) {
                tag = "x"
            }
            if Self.xEng.contains(tag) {
                if !word.allSatisfy(\.isWhitespace) {
                    let isPunc = tag == "x" && w.count == 1 && Self.punctuation.contains(w[0])
                    tokens.append(Token(word: word, tag: tag, phonemes: isPunc ? word : nil))
                } else if !tokens.isEmpty {
                    tokens[tokens.count - 1].whitespace += word
                }
                continue
            } else if let last = tokens.last, !Self.xEng.contains(last.tag), last.whitespace.isEmpty {
                tokens[tokens.count - 1].whitespace = "/"
            }
            var initials: [String] = []
            var finals: [String] = []
            for (c, py) in zip(w, pinyin(w)) {
                var (i, f) = Self.splitSyllable(py)
                if c == "嗯" { i = "" }
                if f.count == 2, f.hasPrefix("i") {
                    if ["z", "c", "s"].contains(i) { f = "ii" + f.suffix(1) }
                    else if ["zh", "ch", "sh", "r"].contains(i) { f = "iii" + f.suffix(1) }
                }
                initials.append(i)
                finals.append(f)
            }
            for (k, c) in w.enumerated() where c == "嗯" { finals[k] = "n2" }
            finals = modifiedTone(w, tag, finals)
            // 儿化
            if !finals.isEmpty, w.last == "儿", finals[finals.count - 1] == "er1" { finals[finals.count - 1] = "er2" }
            if mustErhua.contains(word) || !(notErhua.contains(word) || ["a", "j", "nr"].contains(tag)), finals.count == w.count {
                var ni: [String] = []
                var nf: [String] = []
                for (k, ph) in finals.enumerated() {
                    if k == finals.count - 1, w[k] == "儿", ph == "er2" || ph == "er5",
                       !notErhua.contains(String(w.suffix(2))), let last = nf.last {
                        nf[nf.count - 1] = String(last.dropLast()) + "R" + String(last.suffix(1))
                    } else {
                        ni.append(initials[k])
                        nf.append(ph)
                    }
                }
                initials = ni
                finals = nf
            }
            var phones: [String] = []
            for (c, v) in zip(initials, finals) {
                if !c.isEmpty { phones.append(c) }
                if !v.isEmpty, !(v.count == 1 && Self.punctuation.contains(Character(v))) || v != c { phones.append(v) }
            }
            var joined = phones.joined(separator: "_").replacingOccurrences(of: "_eR", with: "_er").replacingOccurrences(of: "R", with: "_R")
            joined = joined.replacingOccurrences(of: "([0-9])", with: "_$1", options: .regularExpression)
            let symbols = joined.split(separator: "_", omittingEmptySubsequences: false).map { Self.zhMap[String($0)] ?? "❓" }
            tokens.append(Token(word: word, tag: tag, phonemes: symbols.joined()))
        }
        return tokens.map { ($0.phonemes ?? "❓") + $0.whitespace }.joined()
    }

    // MARK: - Pinyin

    /// TONE3 syllables (5 for the neutral tone): phrases that read differently first, longest first.
    private func pinyin(_ word: [Character]) -> [String] {
        var out: [String] = []
        var i = 0
        while i < word.count {
            var matched = false
            var n = min(maxPhrase, word.count - i)
            while n >= 2 {
                if let p = phrases[String(word[i..<(i + n)])] {
                    out += p
                    i += n
                    matched = true
                    break
                }
                n -= 1
            }
            if !matched {
                out.append(chars[word[i]] ?? String(word[i]))
                i += 1
            }
        }
        return out
    }

    private static let initials = ["zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "r", "z", "c", "s"]

    /// pypinyin's strict initial and final (with tone) for one TONE3 syllable.
    static func splitSyllable(_ py: String) -> (String, String) {
        guard let tone = py.last, tone.isNumber else { return ("", py) }
        let s = String(py.dropLast())
        let initial = initials.first { s.hasPrefix($0) } ?? ""
        var rest = String(s.dropFirst(initial.count))
        if initial.isEmpty {
            if s.hasPrefix("y") {
                rest = String(s.dropFirst())
                if rest.hasPrefix("u") { rest = "v" + rest.dropFirst() }
                else if !rest.hasPrefix("i") { rest = "i" + rest }
                if rest == "iu" || rest == "iou" { rest = "iou" }
            } else if s.hasPrefix("w") {
                rest = String(s.dropFirst())
                if rest != "u" && !rest.hasPrefix("u") { rest = "u" + rest }
                rest = ["ui": "uei", "un": "uen", "uei": "uei"][rest] ?? rest
            } else {
                rest = s
            }
        } else {
            if ["j", "q", "x"].contains(initial), rest.hasPrefix("u") { rest = "v" + rest.dropFirst() }
            rest = rest.replacingOccurrences(of: "ü", with: "v")
            rest = ["iu": "iou", "ui": "uei", "un": "uen"][rest] ?? rest
        }
        if rest == "ue" { rest = "ve" }
        return (initial, rest + String(tone))
    }

    private func finals(of word: [Character]) -> [String] {
        var fs = pinyin(word).map { Self.splitSyllable($0).1 }
        for (i, c) in word.enumerated() where c == "嗯" && i < fs.count { fs[i] = "n2" }
        return fs
    }

    // MARK: - jieba

    private func dag(_ s: [Character]) -> [[Int]] {
        var out: [[Int]] = []
        for k in 0..<s.count {
            var tmp: [Int] = []
            var i = k
            var frag = String(s[k])
            while i < s.count, let f = freq[frag] {
                if f > 0 { tmp.append(i) }
                i += 1
                if i < s.count { frag.append(s[i]) } else { break }
            }
            out.append(tmp.isEmpty ? [k] : tmp)
        }
        return out
    }

    /// jieba's most likely route through the dictionary words: for each start, (score, end).
    private func route(_ s: [Character]) -> [(Double, Int)] {
        let d = dag(s)
        var r = Array(repeating: (0.0, 0), count: s.count + 1)
        for idx in stride(from: s.count - 1, through: 0, by: -1) {
            var best: (Double, Int)? = nil
            for x in d[idx] {
                let f = freq[String(s[idx...x])] ?? 0
                let candidate = (log(Double(f == 0 ? 1 : f)) - logTotal + r[x + 1].0, x)
                if best == nil || candidate.0 > best!.0 || (candidate.0 == best!.0 && candidate.1 > best!.1) { best = candidate }
            }
            r[idx] = best!
        }
        return r
    }

    /// jieba.posseg's cut of a run of Chinese (and similar) characters: (word, tag).
    private func cutDAG(_ s: [Character]) -> [(String, String)] {
        let r = route(s)
        var out: [(String, String)] = []
        var x = 0
        var buf: [Character] = []
        func flush() {
            if buf.count == 1 {
                out.append((String(buf), tags[String(buf)] ?? "x"))
            } else if !buf.isEmpty, (freq[String(buf)] ?? 0) == 0 {
                out += hmm.cut(buf)
            } else {
                for c in buf { out.append((String(c), tags[String(c)] ?? "x")) }
            }
            buf = []
        }
        while x < s.count {
            let y = r[x].1 + 1
            if y - x == 1 {
                buf.append(s[x])
            } else {
                flush()
                let w = String(s[x..<y])
                out.append((w, tags[w] ?? "x"))
            }
            x = y
        }
        flush()
        return out
    }

    private static func isHanInternal(_ c: Character) -> Bool {
        guard let u = c.unicodeScalars.first?.value, c.unicodeScalars.count == 1 else { return false }
        return (0x4E00...0x9FD5).contains(u) || c.isASCII && (c.isLetter || c.isNumber || "+#&._".contains(c))
    }

    private func posseg(_ text: String) -> [(String, String)] {
        var out: [(String, String)] = []
        var block: [Character] = []
        var isHan: Bool? = nil
        func flushBlock() {
            guard !block.isEmpty else { return }
            if isHan == true {
                out += cutDAG(block)
            } else {
                for c in block {
                    if c.isWhitespace { out.append((String(c), "x")) }
                    else if c.isASCII, c.isNumber || c == "." { out.append((String(c), "m")) }
                    else { out.append((String(c), "x")) }
                }
            }
            block = []
        }
        for c in text {
            let han = Self.isHanInternal(c)
            if isHan != nil, han != isHan { flushBlock() }
            isHan = han
            block.append(c)
        }
        flushBlock()
        return out
    }

    private func cutForSearch(_ word: [Character]) -> [String] {
        var out: [String] = []
        for (w, _) in cutDAG(word) {
            let x = Array(w)
            if x.count > 2 {
                for i in 0..<(x.count - 1) {
                    let g = String(x[i..<(i + 2)])
                    if (freq[g] ?? 0) > 0 { out.append(g) }
                }
            }
            if x.count > 3 {
                for i in 0..<(x.count - 2) {
                    let g = String(x[i..<(i + 3)])
                    if (freq[g] ?? 0) > 0 { out.append(g) }
                }
            }
            out.append(w)
        }
        return out
    }

    // MARK: - Tone sandhi (misaki / PaddleSpeech)

    private static func allThree(_ fs: [String]) -> Bool { fs.allSatisfy { $0.last == "3" } }
    private static func isReduplication(_ w: String) -> Bool { let a = Array(w); return a.count == 2 && a[0] == a[1] }
    private static func setTone(_ f: String, _ t: Character) -> String { String(f.dropLast()) + String(t) }
    private static func isNumeric(_ c: Character) -> Bool { c.unicodeScalars.allSatisfy { $0.properties.numericType != nil } }

    private func merge(_ input: [(String, String)]) -> [(String, String)] {
        var seg = input
        // 不 joins the word after it.
        var new: [(String, String)] = []
        for (i, (w0, p)) in seg.enumerated() {
            var w = w0
            if !Self.xEng.contains(p), i > 0, seg[i - 1].0 == "不" { w = "不" + w }
            let next = i + 1 < seg.count ? seg[i + 1].1 : nil
            if w != "不" || next == nil || Self.xEng.contains(next!) { new.append((w, p)) }
        }
        seg = new
        // 听一听, then 一 joins the word after it.
        new = []
        var skip = false
        for (i, (w, p)) in seg.enumerated() {
            if skip { skip = false; continue }
            if i > 0, w == "一", i + 1 < seg.count, seg[i - 1].0 == seg[i + 1].0, seg[i - 1].1 == "v", !Self.xEng.contains(seg[i + 1].1) {
                new[new.count - 1].0 += "一" + seg[i + 1].0
                skip = true
            } else {
                new.append((w, p))
            }
        }
        seg = new
        new = []
        for (w, p) in seg {
            if let last = new.last, last.0 == "一", !Self.xEng.contains(p) { new[new.count - 1].0 += w } else { new.append((w, p)) }
        }
        seg = new
        // Reduplication: 看看.
        new = []
        for (w, p) in seg {
            if let last = new.last, w == last.0, !Self.xEng.contains(p) { new[new.count - 1].0 += w } else { new.append((w, p)) }
        }
        seg = new
        // Runs of third tones.
        for first in [true, false] {
            let fl = seg.map { Self.xEng.contains($0.1) ? ["0"] : finals(of: Array($0.0)) }
            new = []
            var mergedLast = Array(repeating: false, count: seg.count)
            for (i, (w, p)) in seg.enumerated() {
                let cond = i > 0 && (first ? Self.allThree(fl[i - 1]) && Self.allThree(fl[i])
                                           : fl[i - 1].last?.last == "3" && fl[i].first?.last == "3")
                if !Self.xEng.contains(p), cond, !mergedLast[i - 1] {
                    if !Self.isReduplication(seg[i - 1].0), seg[i - 1].0.count + w.count <= 3 {
                        new[new.count - 1].0 += w
                        mergedLast[i] = true
                    } else {
                        new.append((w, p))
                    }
                } else {
                    new.append((w, p))
                }
            }
            seg = new
        }
        // 儿 joins the word before it.
        new = []
        for (i, (w, p)) in seg.enumerated() {
            if i > 0, w == "儿", let last = new.last, !Self.xEng.contains(last.1) { new[new.count - 1].0 += w } else { new.append((w, p)) }
        }
        return new
    }

    private func splitWord(_ word: [Character]) -> [[Character]] {
        let list = cutForSearch(word).enumerated().sorted { ($0.element.count, $0.offset) < ($1.element.count, $1.offset) }.map(\.element)
        let first = Array(list[0])
        let w = String(word)
        if w.hasPrefix(String(first)) { return [first, Array(word.dropFirst(first.count))] }
        return [Array(word.dropLast(first.count)), first]
    }

    private func modifiedTone(_ w: [Character], _ pos: String, _ input: [String]) -> [String] {
        var fs = input
        let word = String(w)
        guard fs.count == w.count else { return fs }
        // 不
        if w.count == 3, w[1] == "不" {
            fs[1] = Self.setTone(fs[1], "5")
        } else {
            for (i, c) in w.enumerated() where c == "不" && i + 1 < w.count && fs[i + 1].last == "4" { fs[i] = Self.setTone(fs[i], "2") }
        }
        // 一
        if w.contains("一"), w.filter({ $0 != "一" }).allSatisfy(Self.isNumeric) {
        } else if w.count == 3, w[1] == "一", w[0] == w[2] {
            fs[1] = Self.setTone(fs[1], "5")
        } else if word.hasPrefix("第一") {
            fs[1] = Self.setTone(fs[1], "1")
        } else {
            for (i, c) in w.enumerated() where c == "一" && i + 1 < w.count {
                if "45".contains(fs[i + 1].last!) { fs[i] = Self.setTone(fs[i], "2") }
                else if !Self.punctuation.contains(w[i + 1]) { fs[i] = Self.setTone(fs[i], "4") }
            }
        }
        // Neutral tones.
        if !mustNotNeural.contains(word) {
            if let p0 = pos.first, "nva".contains(p0) {
                for j in 1..<max(1, w.count) where w[j] == w[j - 1] { fs[j] = Self.setTone(fs[j], "5") }
            }
            let ge = w.firstIndex(of: "个") ?? -1
            let last = w[w.count - 1]
            let lastTwo = String(w.suffix(2))
            if "吧呢啊呐噻嘛吖嗨呐哦哒滴哩哟喽啰耶喔诶".contains(last) || "的地得".contains(last) {
                fs[fs.count - 1] = Self.setTone(fs[fs.count - 1], "5")
            } else if w.count == 1, "了着过".contains(last), ["ul", "uz", "ug"].contains(pos) {
                fs[fs.count - 1] = Self.setTone(fs[fs.count - 1], "5")
            } else if w.count > 1, "们子".contains(last), ["r", "n"].contains(pos) {
                fs[fs.count - 1] = Self.setTone(fs[fs.count - 1], "5")
            } else if w.count > 1, "上下".contains(last), ["s", "l", "f"].contains(pos) {
                fs[fs.count - 1] = Self.setTone(fs[fs.count - 1], "5")
            } else if w.count > 1, "来去".contains(last), "上下进出回过起开".contains(w[w.count - 2]) {
                fs[fs.count - 1] = Self.setTone(fs[fs.count - 1], "5")
            } else if (ge >= 1 && (Self.isNumeric(w[ge - 1]) || "几有两半多各整每做是".contains(w[ge - 1]))) || word == "个" {
                fs[max(0, ge)] = Self.setTone(fs[max(0, ge)], "5")
            } else if mustNeural.contains(word) || mustNeural.contains(lastTwo) {
                fs[fs.count - 1] = Self.setTone(fs[fs.count - 1], "5")
            }
            let parts = splitWord(w)
            var lists = [Array(fs.prefix(parts[0].count)), Array(fs.dropFirst(parts[0].count))]
            for (i, p) in parts.enumerated() where !lists[i].isEmpty {
                let s = String(p)
                if mustNeural.contains(s) || mustNeural.contains(String(p.suffix(2))) {
                    lists[i][lists[i].count - 1] = Self.setTone(lists[i][lists[i].count - 1], "5")
                }
            }
            fs = lists[0] + lists[1]
        }
        // Third tones.
        if w.count == 2, Self.allThree(fs) {
            fs[0] = Self.setTone(fs[0], "2")
        } else if w.count == 3 {
            let parts = splitWord(w)
            if Self.allThree(fs) {
                if parts[0].count == 2 {
                    fs[0] = Self.setTone(fs[0], "2")
                    fs[1] = Self.setTone(fs[1], "2")
                } else if parts[0].count == 1 {
                    fs[1] = Self.setTone(fs[1], "2")
                }
            } else {
                var lists = [Array(fs.prefix(parts[0].count)), Array(fs.dropFirst(parts[0].count))]
                for i in 0..<2 {
                    let sub = lists[i]
                    if Self.allThree(sub), sub.count == 2 {
                        lists[i][0] = Self.setTone(lists[i][0], "2")
                    } else if i == 1, !Self.allThree(sub), sub.first?.last == "3", lists[0].last?.last == "3" {
                        lists[0][lists[0].count - 1] = Self.setTone(lists[0][lists[0].count - 1], "2")
                    }
                    fs = lists[0] + lists[1]
                }
            }
        } else if w.count == 4 {
            var out: [String] = []
            for var sub in [Array(fs.prefix(2)), Array(fs.dropFirst(2))] {
                if Self.allThree(sub) { sub[0] = Self.setTone(sub[0], "2") }
                out += sub
            }
            fs = out
        }
        return fs
    }

    // MARK: - jieba's part-of-speech HMM

    /// Splits runs of characters jieba doesn't know into words, and tags them.
    private struct HMM {
        static let minFloat = -3.14e100
        var states: [(bmes: Character, tag: String)] = []
        var start: [Double] = []
        var trans: [[Int: Double]] = []
        var emit: [[Character: Double]] = []
        var charStates: [Character: [Int]] = [:]

        init(lines: [Substring]) throws {
            for line in lines {
                let f = line.split(separator: "\t", omittingEmptySubsequences: false)
                switch f.first {
                case "S":
                    states.append((f[2].first!, String(f[3])))
                    start.append(Double(f[4]) ?? Self.minFloat)
                    trans.append([:])
                    emit.append([:])
                case "T":
                    trans[Int(f[1])!][Int(f[2])!] = Double(f[3])!
                case "E":
                    let s = Int(f[1])!
                    for x in f.dropFirst(2) where !x.isEmpty {
                        emit[s][x.first!] = Double(x.dropFirst())!
                    }
                case "C":
                    charStates[f[1].first!] = f[2].split(separator: ",").map { Int($0)! }
                default:
                    break
                }
            }
        }

        private func less(_ a: (Double, Int), _ b: (Double, Int)) -> Bool {
            if a.0 != b.0 { return a.0 < b.0 }
            let sa = states[a.1], sb = states[b.1]
            return sa.bmes != sb.bmes ? sa.bmes < sb.bmes : sa.tag < sb.tag
        }

        func viterbi(_ obs: [Character]) -> [Int] {
            let all = Array(0..<states.count)
            var v: [[Int: Double]] = [[:]]
            var mem: [[Int: Int]] = [[:]]
            for y in charStates[obs[0]] ?? all {
                v[0][y] = start[y] + (emit[y][obs[0]] ?? Self.minFloat)
                mem[0][y] = -1
            }
            for t in 1..<obs.count {
                v.append([:])
                mem.append([:])
                let prev = mem[t - 1].keys.filter { !trans[$0].isEmpty }
                var expect = Set<Int>()
                for x in prev { expect.formUnion(trans[x].keys) }
                var obsStates = Set(charStates[obs[t]] ?? all).intersection(expect)
                if obsStates.isEmpty { obsStates = expect.isEmpty ? Set(all) : expect }
                for y in obsStates {
                    var best: (Double, Int)? = nil
                    for y0 in prev {
                        let p = v[t - 1][y0]! + (trans[y0][y] ?? -Double.infinity) + (emit[y][obs[t]] ?? Self.minFloat)
                        if best == nil || less(best!, (p, y0)) { best = (p, y0) }
                    }
                    v[t][y] = best!.0
                    mem[t][y] = best!.1
                }
            }
            var last: (Double, Int)? = nil
            for y in mem[obs.count - 1].keys {
                let c = (v[obs.count - 1][y]!, y)
                if last == nil || less(last!, c) { last = c }
            }
            var route = Array(repeating: 0, count: obs.count)
            var state = last!.1
            for i in stride(from: obs.count - 1, through: 0, by: -1) {
                route[i] = state
                state = mem[i][state] ?? -1
            }
            return route
        }

        func cut(_ s: [Character]) -> [(String, String)] {
            var out: [(String, String)] = []
            // Chinese runs go through the HMM; anything else is numbers, letters or marks.
            var i = 0
            while i < s.count {
                var j = i
                let han = { (c: Character) -> Bool in
                    guard let u = c.unicodeScalars.first?.value else { return false }
                    return (0x4E00...0x9FD5).contains(u)
                }
                if han(s[i]) {
                    while j < s.count, han(s[j]) { j += 1 }
                    let blk = Array(s[i..<j])
                    let pl = viterbi(blk)
                    var begin = 0, next = 0
                    for (k, c) in blk.enumerated() {
                        let st = states[pl[k]]
                        if st.bmes == "B" { begin = k }
                        else if st.bmes == "E" { out.append((String(blk[begin...k]), st.tag)); next = k + 1 }
                        else if st.bmes == "S" { out.append((String(c), st.tag)); next = k + 1 }
                    }
                    if next < blk.count { out.append((String(blk[next...]), states[pl[next]].tag)) }
                } else {
                    while j < s.count, !han(s[j]) { j += 1 }
                    for c in s[i..<j] {
                        out.append((String(c), c.isASCII && (c.isNumber || c == ".") ? "m" : c.isASCII && c.isLetter ? "eng" : "x"))
                    }
                }
                i = j
            }
            return out
        }
    }
}
