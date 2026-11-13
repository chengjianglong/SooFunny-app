import AVFoundation
import UIKit
import XCTest
@testable import SooFunny

@MainActor
final class BooksTests: XCTestCase {
    func testLibraryBooksAreComplete() {
        let books = StoryLibrary.books
        XCTAssertGreaterThanOrEqual(books.count, 8)
        XCTAssertEqual(Set(books.map(\.id)).count, books.count, "book ids must be unique")
        for book in books {
            XCTAssertGreaterThanOrEqual(book.pages.count, 5, book.title)
            for page in book.pages {
                XCTAssertFalse(page.text.isEmpty, book.title)
                XCTAssertFalse(page.scene.isEmpty, book.title)
                XCTAssertEqual(BookLanguage.detect(page.text), book.language, "\(book.title): \(page.text)")
                // Every sentence must be short enough for the voice to read in one go.
                for sentence in AudiobookMaker.sentences(in: page.text) {
                    XCTAssertLessThan(sentence.count, 300, "\(book.title): \(sentence)")
                }
            }
        }
    }

    func testLibraryHasTwoChineseBooks() {
        XCTAssertEqual(StoryLibrary.books.filter { $0.language == .chinese }.count, 2)
    }

    func testReflowJoinsLinesAndHyphensAndDropsPageNumbers() {
        func line(_ text: String, y: CGFloat, x: CGFloat = 0.1, confidence: Float = 0.9) -> PageReader.OCRLine {
            .init(text: text, confidence: confidence, box: CGRect(x: x, y: y, width: 0.6, height: 0.04))
        }
        let text = PageReader.reflow([
            line("the bears went for a", y: 0.80),
            line("Once upon a time,", y: 0.85),
            line("walk in the won-", y: 0.75),
            line("derful woods.", y: 0.70),
            line("The End", y: 0.40),
            line("12", y: 0.05),
            line("smudge", y: 0.30, confidence: 0.1),
        ])
        XCTAssertEqual(text, "Once upon a time, the bears went for a walk in the wonderful woods.\n\nThe End")
    }

    func testReflowJoinsChineseLinesWithoutSpaces() {
        func line(_ text: String, y: CGFloat) -> PageReader.OCRLine {
            .init(text: text, confidence: 0.9, box: CGRect(x: 0.1, y: y, width: 0.6, height: 0.04))
        }
        XCTAssertEqual(PageReader.reflow([line("小兔子跑得很快，", y: 0.8), line("它总是说：", y: 0.75), line("Hello", y: 0.70)]),
                       "小兔子跑得很快，它总是说：Hello")
    }

    func testDetectsLanguage() {
        XCTAssertEqual(BookLanguage.detect("床前明月光，疑是地上霜。"), .chinese)
        XCTAssertEqual(BookLanguage.detect("The moon is bright."), .english)
        XCTAssertEqual(BookLanguage.detect("小熊 Teddy 说你好"), .chinese)
        XCTAssertEqual(BookLanguage.detect(""), .english)
        XCTAssertNotNil(BookLanguage.chinese.systemVoice)
    }

    func testRecognizesChinesePageText() async throws {
        let text = await PageReader.text(in: Self.page(["床前明月光，", "疑是地上霜。"]))
        XCTAssertEqual(text, "床前明月光，疑是地上霜。")
        XCTAssertEqual(BookLanguage.detect(text), .chinese)
    }

    func testRecognizesPrintedPageText() async throws {
        let image = Self.page(["The little red hen", "found some wheat."])
        let text = await PageReader.text(in: image)
        XCTAssertEqual(text.lowercased(), "the little red hen found some wheat.")
    }

    func testSuggestedTitle() {
        XCTAssertEqual(ScanReviewView.suggestedTitle("Brown Bear Goes Home. Once upon a time there was a bear."), "Brown Bear Goes Home")
        XCTAssertEqual(ScanReviewView.suggestedTitle("Once upon a time, a very small bear lived far away in a big wood."), "My Book")
        XCTAssertEqual(ScanReviewView.suggestedTitle(""), "My Book")
        XCTAssertEqual(ScanReviewView.suggestedTitle("小熊回家。从前有一只小熊。"), "小熊回家")
        XCTAssertEqual(ScanReviewView.suggestedTitle("从前有一只很小很小的熊住在很远很远的大森林里面。"), "我的书")
    }

    func testStoreSavesEditsAndDeletes() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ScannedBookStore(folder: folder)
        let scan = try XCTUnwrap(PageScan(Self.page(["Hello"])))
        var book = try store.add(title: "Test", language: .english, pages: [(scan.jpeg, "Hello")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.imageURL(book.pages[0], in: book).path))
        XCTAssertLessThanOrEqual(scan.thumbnail.size.width, 240)

        // Pages can be added in any number of batches.
        for batch in 1...3 {
            try store.append(Array(repeating: (scan.jpeg, "Batch \(batch)"), count: 10), to: book)
        }
        book = store.books[0]
        XCTAssertEqual(book.pages.count, 31)
        XCTAssertEqual(Set(book.pages.map(\.image)).count, 31, "every page has its own photo file")
        XCTAssertEqual(book.pages.last?.text, "Batch 3")

        // Changing the words throws away the old audiobook.
        try Data([1, 2, 3]).write(to: store.audioURL(for: book))
        book.hasAudio = true
        try store.update(book)
        book.pages[0].text = "Hello there"
        try store.update(book)
        XCTAssertFalse(store.books[0].hasAudio)
        XCTAssertEqual(store.books[0].bookLanguage, .english)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.audioURL(for: book).path))

        // Pages can be put in a new order, which also throws away the audiobook.
        book = store.books[0]
        book.hasAudio = true
        try store.update(book)
        let moved = book.pages.removeLast()
        book.pages.insert(moved, at: 0)
        try store.update(book)
        XCTAssertEqual(store.books[0].pages.first?.image, moved.image)
        XCTAssertEqual(store.books[0].pages[1].text, "Hello there")
        XCTAssertFalse(store.books[0].hasAudio)

        // A new store finds the saved book, in its new order.
        XCTAssertEqual(ScannedBookStore(folder: folder).books.first?.pages.map(\.image), store.books[0].pages.map(\.image))

        store.delete(book)
        XCTAssertTrue(store.books.isEmpty)
        XCTAssertTrue(ScannedBookStore(folder: folder).books.isEmpty)
    }

    func testMakesAudiobook() async throws {
        try XCTSkipUnless(KokoroTTS.isBundled, "The natural voice isn't in this build.")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        var progress = 0.0
        try await AudiobookMaker.make(pages: ["Hello there.", "Good night, moon."], to: url) { progress = $0 }
        XCTAssertEqual(progress, 1)
        let file = try AVAudioFileProbe.duration(of: url)
        XCTAssertGreaterThan(file, 1.5)
    }

    func testSplitsMixedEnglishAndChinese() {
        func runs(_ text: String, _ fallback: BookLanguage = .english) -> [String] {
            BookLanguage.runs(in: text, fallback: fallback).map { "\($0.language.rawValue):\($0.text)" }
        }
        XCTAssertEqual(runs("Apple 苹果"), ["en:Apple", "zh:苹果"])
        XCTAssertEqual(runs("我喜欢apple，你呢？"), ["zh:我喜欢", "en:apple，", "zh:你呢？"])
        XCTAssertEqual(runs("“Hi,” 小熊说。I have 3 只猫"), ["en:“Hi,”", "zh:小熊说。", "en:I have 3", "zh:只猫"])
        XCTAssertEqual(runs("The moon is bright."), ["en:The moon is bright."])
        XCTAssertEqual(runs("床前明月光，疑是地上霜。"), ["zh:床前明月光，疑是地上霜。"])
        XCTAssertEqual(runs("123", .chinese), ["zh:123"])
        XCTAssertEqual(runs("  "), [])

        // Pinyin printed under the characters isn't read a second time in the English voice.
        XCTAssertEqual(runs("消防员 xiāo fáng yuán Firefighter"), ["zh:消防员", "en:Firefighter"])
        XCTAssertEqual(runs("shēng huó zhōng de yīng xióng"), [])
        XCTAssertEqual(runs("A café in Paris"), ["en:A café in Paris"])
        XCTAssertEqual(runs("• ~"), [])

        let parts = AudiobookMaker.parts(in: "Cat 猫. Dog 狗.")
        XCTAssertEqual(parts.map(\.text), ["Cat", "猫.", "Dog", "狗."])
        XCTAssertEqual(parts.map(\.gap), [0.08, 0.3, 0.08, 0.3])
    }

    func testMakesMixedAudiobook() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        // Like a scanned bilingual book: an English-looking book with Chinese, pinyin and stray marks.
        try await AudiobookMaker.make(pages: ["EVERYDAY HEROES 生活中的英雄 shēng huó zhōng de yīng xióng", "• 58 ~",
                                              "The apple is red. 苹果是红色的。", "Banana 香蕉"], language: .english, to: url) { _ in }
        XCTAssertGreaterThan(try AVAudioFileProbe.duration(of: url), 2)
    }

    func testMakesChineseAudiobook() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        try await AudiobookMaker.make(pages: ["床前明月光，疑是地上霜。", "举头望明月，低头思故乡。"], language: .chinese, to: url) { _ in }
        XCTAssertGreaterThan(try AVAudioFileProbe.duration(of: url), 2)
    }

    /// Black text on white, like a book page.
    static func page(_ lines: [String]) -> UIImage {
        let size = CGSize(width: 1200, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 72, weight: .medium), .foregroundColor: UIColor.black]
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(at: CGPoint(x: 80, y: 200 + CGFloat(index) * 110), withAttributes: attributes)
            }
        }
    }
}

private enum AVAudioFileProbe {
    static func duration(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.fileFormat.sampleRate
    }
}
