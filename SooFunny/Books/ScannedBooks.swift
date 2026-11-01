import AVFoundation
import Observation
import UIKit
import Vision

/// A book the family scanned. Its page photos and text stay on this device.
struct ScannedBook: Identifiable, Codable, Hashable {
    struct Page: Codable, Hashable {
        /// Photo file name inside the book's folder.
        var image: String
        /// The text read from the photo, which a grown-up can fix.
        var text: String
    }

    var id = UUID()
    var title: String
    var created = Date()
    var pages: [Page]
    /// True once the audiobook file has been made for the current text.
    var hasAudio = false
    /// "zh" for Chinese books; nil (English) for books saved before Chinese was supported.
    var language: String?

    var bookLanguage: BookLanguage { BookLanguage(code: language) }
}

/// The languages books can be read in.
enum BookLanguage: String {
    case english = "en", chinese = "zh"

    init(code: String?) { self = code == "zh" ? .chinese : .english }

    /// Mostly Chinese characters means a Chinese page.
    static func detect(_ text: String) -> BookLanguage {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return .english }
        let han = letters.filter(\.isHan).count
        return Double(han) / Double(letters.count) > 0.3 ? .chinese : .english
    }

    /// Splits text into stretches of English and Chinese, so each is read in its own voice.
    /// Spaces, digits and other marks stay with the stretch before them; text with no letters at
    /// all is read in `fallback`. Pinyin is left out: the Chinese voice already says those words.
    static func runs(in text: String, fallback: BookLanguage = .english) -> [(text: String, language: BookLanguage)] {
        var runs: [(text: String, language: BookLanguage)] = []
        var leading = ""
        for character in text {
            guard let language = language(of: character) else {
                if runs.isEmpty { leading.append(character) } else { runs[runs.count - 1].text.append(character) }
                continue
            }
            if let last = runs.last, last.language == language {
                runs[runs.count - 1].text.append(character)
            } else {
                runs.append((leading + String(character), language))
                leading = ""
            }
        }
        if runs.isEmpty { runs = [(leading, fallback)] }
        return runs.compactMap { run in
            let text = run.language == .english ? withoutPinyin(run.text) : run.text
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Nothing to say in a stretch of only marks (a stray "•" the camera read).
            guard trimmed.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
            return (trimmed, run.language)
        }
    }

    /// Leaves out pinyin, as printed under the characters in bilingual books: words with tone
    /// marks, and the toneless little words (de, le, ma) between them. Only text with a tone mark
    /// French doesn't use (ā, ǎ) counts as pinyin, so "café" is still read.
    static func withoutPinyin(_ text: String) -> String {
        let toneMarks: Set<Character> = Set("āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ")
        let pinyinOnly: Set<Character> = Set("āǎēěīǐōǒūǔǖǘǚǜ")
        guard text.lowercased().contains(where: pinyinOnly.contains) else { return text }
        let words = text.split(whereSeparator: \.isWhitespace)
        let toned = words.map { $0.lowercased().contains(where: toneMarks.contains) }
        let kept = words.indices.filter { index in
            if toned[index] { return false }
            let word = words[index]
            let particle = word.count <= 4 && word.allSatisfy(\.isLowercase)
            let before = index > 0 && toned[index - 1]
            let after = index + 1 < words.count && toned[index + 1]
            return !(particle && (before || after))
        }
        return kept.map { String(words[$0]) }.joined(separator: " ")
    }

    /// Chinese characters are Chinese; other letters are English; anything else (punctuation,
    /// digits, spaces) belongs to neither.
    private static func language(of character: Character) -> BookLanguage? {
        for scalar in character.unicodeScalars {
            if scalar.isHan { return .chinese }
            if CharacterSet.letters.contains(scalar) { return .english }
        }
        return nil
    }

    /// The Apple voice for this language (Chinese isn't spoken by the natural voice).
    var systemVoice: AVSpeechSynthesisVoice? {
        switch self {
        case .english: return nil
        case .chinese:
            return AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language == "zh-CN" && !$0.voiceTraits.contains(.isNoveltyVoice) }
                .max { $0.quality.rawValue < $1.quality.rawValue }
                ?? AVSpeechSynthesisVoice(language: "zh-CN")
        }
    }
}

extension Unicode.Scalar {
    /// A Chinese character (CJK ideograph).
    var isHan: Bool {
        switch value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2EBEF: return true
        default: return false
        }
    }
}

/// A page photo waiting to be added to a book: kept as a JPEG (not a full-size image) so a book
/// can have any number of pages without running out of memory.
struct PageScan: Identifiable {
    let id = UUID()
    let jpeg: Data
    let thumbnail: UIImage

    init?(_ image: UIImage) {
        let page = image.resizedToFit(ScannedBookStore.maxPageSide)
        guard let jpeg = page.jpegData(compressionQuality: 0.8) else { return nil }
        self.jpeg = jpeg
        thumbnail = page.resizedToFit(240)
    }

    var image: UIImage? { UIImage(data: jpeg) }
}

/// Keeps scanned books in Application Support/ScannedBooks/<id>/: book.json, page photos and
/// the audiobook. Nothing is uploaded.
@MainActor
@Observable
final class ScannedBookStore {
    static let shared = ScannedBookStore()
    /// Page photos are saved no bigger than this, which is plenty to read the words.
    static let maxPageSide: CGFloat = 1600

    private(set) var books: [ScannedBook] = []
    @ObservationIgnored let folder: URL

    init(folder: URL? = nil) {
        let base = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScannedBooks", isDirectory: true)
        self.folder = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        load()
    }

    func folder(for book: ScannedBook) -> URL { folder.appendingPathComponent(book.id.uuidString, isDirectory: true) }
    func imageURL(_ page: ScannedBook.Page, in book: ScannedBook) -> URL { folder(for: book).appendingPathComponent(page.image) }
    func audioURL(for book: ScannedBook) -> URL { folder(for: book).appendingPathComponent("audiobook.m4a") }

    /// Saves a new book from page photos and their recognized text.
    @discardableResult
    func add(title: String, language: BookLanguage, pages: [(jpeg: Data, text: String)]) throws -> ScannedBook {
        var book = ScannedBook(title: title, pages: [], language: language.rawValue)
        try FileManager.default.createDirectory(at: folder(for: book), withIntermediateDirectories: true)
        book.pages = try write(pages, in: book)
        try save(book)
        books.insert(book, at: 0)
        return book
    }

    /// Adds pages to the end of a book. Its audiobook no longer matches, so it's removed.
    func append(_ pages: [(jpeg: Data, text: String)], to book: ScannedBook) throws {
        guard var book = books.first(where: { $0.id == book.id }) else { return }
        book.pages += try write(pages, in: book)
        try? FileManager.default.removeItem(at: audioURL(for: book))
        book.hasAudio = false
        try save(book)
        if let index = books.firstIndex(where: { $0.id == book.id }) { books[index] = book }
    }

    private func write(_ pages: [(jpeg: Data, text: String)], in book: ScannedBook) throws -> [ScannedBook.Page] {
        try pages.map { page in
            let name = "page-\(UUID().uuidString).jpg"
            try page.jpeg.write(to: folder(for: book).appendingPathComponent(name))
            return ScannedBook.Page(image: name, text: page.text)
        }
    }

    /// Saves changes to a book's title or text. Changed text makes the old audiobook stale.
    func update(_ book: ScannedBook) throws {
        var book = book
        if let old = books.first(where: { $0.id == book.id }), old.pages.map(\.text) != book.pages.map(\.text) {
            try? FileManager.default.removeItem(at: audioURL(for: book))
            book.hasAudio = false
        }
        try save(book)
        if let index = books.firstIndex(where: { $0.id == book.id }) { books[index] = book }
    }

    func delete(_ book: ScannedBook) {
        try? FileManager.default.removeItem(at: folder(for: book))
        books.removeAll { $0.id == book.id }
    }

    private func save(_ book: ScannedBook) throws {
        let data = try JSONEncoder().encode(book)
        try data.write(to: folder(for: book).appendingPathComponent("book.json"), options: .atomic)
    }

    private func load() {
        let dirs = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        books = dirs.compactMap { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("book.json")) else { return nil }
            return try? JSONDecoder().decode(ScannedBook.self, from: data)
        }
        .sorted { $0.created > $1.created }
    }
}

// MARK: - Reading text from photos

/// Reads the words on a book page with Apple's on-device text recognition (no network).
enum PageReader {
    static func text(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? []).compactMap { observation in
                    observation.topCandidates(1).first.map { OCRLine(text: $0.string, confidence: $0.confidence, box: observation.boundingBox) }
                }
                continuation.resume(returning: reflow(lines))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // English and Chinese (simplified and traditional) books; Vision picks per page.
            request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]
            request.automaticallyDetectsLanguage = true
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    struct OCRLine {
        let text: String
        let confidence: Float
        /// Normalized, origin at the bottom left (Vision's convention).
        let box: CGRect
    }

    /// Turns recognized lines into reading text: top to bottom, lines joined into sentences,
    /// words split across lines with a hyphen put back together, and page numbers and
    /// low-confidence scraps dropped. A big gap between lines starts a new paragraph. Chinese
    /// lines join without a space.
    static func reflow(_ lines: [OCRLine]) -> String {
        let kept = lines
            .filter { $0.confidence >= 0.3 }
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).allSatisfy(\.isNumber) }
            .sorted { abs($0.box.midY - $1.box.midY) > min($0.box.height, $1.box.height) / 2
                ? $0.box.midY > $1.box.midY : $0.box.minX < $1.box.minX }
        var result = ""
        var previous: OCRLine?
        for line in kept {
            let text = line.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            if let previous {
                let gap = previous.box.minY - line.box.maxY
                if gap > max(previous.box.height, line.box.height) * 1.2 {
                    result += "\n\n" + text
                } else if result.hasSuffix("-"), let first = text.first, first.isLowercase {
                    result.removeLast()
                    result += text
                } else if result.unicodeScalars.last?.isHan == true || text.unicodeScalars.first?.isHan == true
                            || "，。！？；：、」』）".contains(result.last ?? " ") {
                    result += text
                } else {
                    result += " " + text
                }
            } else {
                result = text
            }
            previous = line
        }
        return result
    }
}

// MARK: - Making audiobooks

/// Makes an audiobook file from a book's text in the natural voice, on the device.
enum AudiobookMaker {
    enum MakeError: Error { case noVoice, writeFailed }

    /// A stretch of a page read in one voice, and the pause after it.
    struct Part {
        var text: String
        var language: BookLanguage
        var gap: Double
    }

    /// A page's words in reading order, split wherever the language changes. A short pause
    /// follows a language change inside a sentence, a longer one each sentence.
    static func parts(in page: String, language fallback: BookLanguage = .english) -> [Part] {
        sentences(in: page).flatMap { sentence in
            let runs = BookLanguage.runs(in: sentence, fallback: fallback)
            return runs.enumerated().map { index, run in
                Part(text: run.text, language: run.language, gap: index == runs.count - 1 ? 0.3 : 0.08)
            }
        }
    }

    /// Writes `pages` as one AAC file, with a pause between pages. `progress` gets 0...1.
    /// English is read in the natural voice; Chinese in Apple's Chinese voice; a page with both
    /// switches voice wherever the language changes.
    static func make(pages: [String], language: BookLanguage = .english, to url: URL,
                     progress: @escaping @MainActor (Double) -> Void) async throws {
        let pageParts = pages.map { parts(in: $0, language: language) }
        if pageParts.joined().contains(where: { $0.language == .english }) {
            guard KokoroTTS.isBundled else { throw MakeError.noVoice }
        }
        let format = AVAudioFormat(standardFormatWithSampleRate: KokoroTTS.sampleRate, channels: 1)!
        try? FileManager.default.removeItem(at: url)
        let partial = url.deletingPathExtension().appendingPathExtension("partial.m4a")
        try? FileManager.default.removeItem(at: partial)
        let file = try AVAudioFile(forWriting: partial, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: KokoroTTS.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ], commonFormat: .pcmFormatFloat32, interleaved: false)

        // English parts are read a phrase at a time, as the natural voice does when speaking.
        let phrases: [[Part]] = pageParts.map { parts in
            parts.flatMap { part -> [Part] in
                guard part.language == .english else { return [part] }
                var phrases = NaturalVoice.phrases(in: part.text).map { Part(text: $0.text, language: .english, gap: $0.gap) }
                if !phrases.isEmpty { phrases[phrases.count - 1].gap = min(phrases[phrases.count - 1].gap, part.gap) }
                return phrases
            }
        }
        let voice = BookLanguage.chinese.systemVoice
        let englishVoice = Speech.englishVoices.first ?? AVSpeechSynthesisVoice(language: "en-US")
        var spoken = 0
        let total = max(1, phrases.reduce(0) { $0 + $1.count })
        var done = 0
        for pagePhrases in phrases {
            for phrase in pagePhrases {
                try Task.checkCancellation()
                var samples: [Float]?
                if phrase.language == .english {
                    samples = await audio(for: phrase.text)
                    // Words the natural voice can't say (odd spellings, symbols) go to Apple's English voice.
                    if samples?.isEmpty ?? true { samples = await systemAudio(for: phrase.text, voice: englishVoice) }
                } else {
                    samples = await systemAudio(for: phrase.text, voice: voice)
                }
                // A scrap of text with nothing to say (a stray mark the camera read) is skipped.
                if let samples, !samples.isEmpty {
                    try write(samples + [Float](repeating: 0, count: Int(KokoroTTS.sampleRate * phrase.gap)), to: file, format: format)
                    spoken += 1
                }
                done += 1
                let fraction = Double(done) / Double(total)
                await progress(fraction)
            }
            // A breath between pages.
            try write([Float](repeating: 0, count: Int(KokoroTTS.sampleRate * 0.8)), to: file, format: format)
        }
        guard spoken > 0 else {
            try? FileManager.default.removeItem(at: partial)
            throw MakeError.noVoice
        }
        try FileManager.default.moveItem(at: partial, to: url)
    }

    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        let ns = text as NSString
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .bySentences) { sentence, _, _, _ in
            if let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                result.append(sentence)
            }
        }
        return result
    }

    private static func audio(for text: String) async -> [Float]? {
        await withCheckedContinuation { continuation in
            NaturalVoiceEngine.shared.audio(for: text) { continuation.resume(returning: $0) }
        }
    }

    /// Speech from an Apple voice, as 24 kHz samples like the natural voice's.
    private static func systemAudio(for text: String, voice: AVSpeechSynthesisVoice?) async -> [Float]? {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Speech.appleRate
        let collector = SampleCollector()
        return await withCheckedContinuation { continuation in
            synthesizer.write(utterance) { buffer in
                _ = synthesizer
                guard let pcm = buffer as? AVAudioPCMBuffer, !collector.finished else { return }
                if pcm.frameLength == 0 {
                    collector.finished = true
                    continuation.resume(returning: KokoroTTS.trimmingSilence(collector.samples))
                } else {
                    collector.add(pcm)
                }
            }
        }
    }

    /// Gathers an Apple voice's audio buffers, converted to 24 kHz mono floats.
    private final class SampleCollector {
        var samples: [Float] = []
        var finished = false
        private var converter: AVAudioConverter?
        private let target = AVAudioFormat(standardFormatWithSampleRate: KokoroTTS.sampleRate, channels: 1)!

        func add(_ buffer: AVAudioPCMBuffer) {
            if converter == nil { converter = AVAudioConverter(from: buffer.format, to: target) }
            guard let converter else { return }
            let ratio = target.sampleRate / buffer.format.sampleRate
            guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024) else { return }
            var given = false
            converter.convert(to: out, error: nil) { _, status in
                if given {
                    status.pointee = .noDataNow
                    return nil
                }
                given = true
                status.pointee = .haveData
                return buffer
            }
            samples += UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength))
        }
    }

    private static func write(_ samples: [Float], to file: AVAudioFile, format: AVAudioFormat) throws {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        try file.write(from: buffer)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

extension UIImage {
    /// A copy no larger than `maxSide` points on its longest side, drawn upright.
    func resizedToFit(_ maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
