import XCTest
@testable import SooFunny

final class WordDictionaryTests: XCTestCase {
    func testParsesCategoriesWordsAndEmoji() throws {
        let text = "\u{FEFF}Category: Fruit | 🍎\napple | 🍎\npear\n\n\nCategory: Colors\nred | 🔴\n"
        let categories = try WordDictionary.parse(text)
        XCTAssertEqual(categories.map(\.name), ["Fruit", "Colors"])
        XCTAssertEqual(categories[0].emoji, "🍎")
        XCTAssertNil(categories[1].emoji)
        XCTAssertEqual(categories[0].words, [WordEntry(text: "apple", emoji: "🍎"), WordEntry(text: "pear", emoji: nil)])
        XCTAssertEqual(categories[1].words.map(\.text), ["red"])
    }

    func testRejectsMalformedLists() {
        XCTAssertThrowsError(try WordDictionary.parse("apple\n")) {
            XCTAssertEqual($0 as? WordDictionary.ParseError, .wordBeforeCategory(line: 1))
        }
        XCTAssertThrowsError(try WordDictionary.parse("Category: Fruit\n\nCategory: Colors\nred")) {
            XCTAssertEqual($0 as? WordDictionary.ParseError, .emptyCategory("Fruit"))
        }
        XCTAssertThrowsError(try WordDictionary.parse("Category:\napple")) {
            XCTAssertEqual($0 as? WordDictionary.ParseError, .emptyCategoryName(line: 1))
        }
        XCTAssertThrowsError(try WordDictionary.parse("\n\n")) {
            XCTAssertEqual($0 as? WordDictionary.ParseError, .noCategories)
        }
    }

    func testBundledListIsComplete() throws {
        let categories = try WordDictionary.loadBundled(Bundle(for: ColoringSession.self))
        XCTAssertGreaterThanOrEqual(categories.count, 30)
        XCTAssertEqual(Set(categories.map(\.name)).count, categories.count, "category names are unique")
        for category in categories {
            XCTAssertGreaterThanOrEqual(category.words.count, 15, category.name)
            let lowercased = category.words.map { $0.text.lowercased() }
            XCTAssertEqual(Set(lowercased).count, lowercased.count, "duplicate word in \(category.name)")
            XCTAssertNotNil(category.emoji, "\(category.name) needs a picture")
            for word in category.words {
                XCTAssertFalse(word.text.isEmpty)
                XCTAssertFalse(word.text.contains("|"), word.text)
            }
        }
    }
}

final class LabTests: XCTestCase {
    func testMedian() {
        XCTAssertEqual(LabStats.median([]), 0)
        XCTAssertEqual(LabStats.median([5, 1, 3]), 3)
        XCTAssertEqual(LabStats.median([4, 1, 3, 2]), 2.5)
    }

    func testMeasureSkipsWarmUp() {
        var calls = 0
        let runs = LabStats.measure(warmUp: 2, runs: 3) { calls += 1 }
        XCTAssertEqual(calls, 5)
        XCTAssertEqual(runs.count, 3)
    }

    func testColoringBenchmarkMeasuresAPage() {
        let result = LabBenchmarks.coloringPage(name: "Scene", image: LabInputs.scene(seed: 1), detail: .big)
        XCTAssertEqual(result.kind, "coloring-page")
        XCTAssertEqual(result.runsMs.count, 3)
        XCTAssertGreaterThan(Int(result.details["blocks"] ?? "") ?? 0, 1)
    }

    func testCSVQuotesTextFields() {
        let result = LabResult(kind: "language-model", name: "Say \"hi\", please", settings: "x", runsMs: [10, 20],
                               details: ["characters": "5"])
        let lines = LabStore.csv([result]).split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("date,kind,name"))
        XCTAssertTrue(lines[1].contains("\"Say \"\"hi\"\", please\""))
        XCTAssertTrue(lines[1].contains(",15.0,10.0,20.0,"))
    }
}

final class ShowcaseTests: XCTestCase {
    func testEveryGalleryPhotoIsBundledAndCredited() throws {
        let bundle = Bundle(for: ColoringSession.self)
        let url = try XCTUnwrap(bundle.url(forResource: "credits", withExtension: "json"))
        let credits = try JSONDecoder().decode([PictureCredit].self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(credits.count, 12)
        for kind in [PictureKind.animals, .portraits, .people, .outdoors] {
            XCTAssertGreaterThanOrEqual(credits.filter { $0.category == kind.rawValue }.count, 3, kind.title)
        }
        for credit in credits {
            XCTAssertEqual(credit.license, "CC0", credit.file)
            XCTAssertFalse(credit.author.contains("<"), credit.file)
            let name = (credit.file as NSString).deletingPathExtension
            let file = try XCTUnwrap(bundle.url(forResource: name, withExtension: "jpg"), credit.file)
            XCTAssertNotNil(UIImage(contentsOfFile: file.path), credit.file)
        }
    }
}
