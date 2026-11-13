import SwiftUI
import XCTest
@testable import SooFunny

final class SportsTests: XCTestCase {
    func testEverySportHasNamesAndIntroductionsInBothLanguages() {
        XCTAssertEqual(OlympicSports.sports(.summer).count, 35)
        XCTAssertEqual(OlympicSports.sports(.winter).count, 16)
        XCTAssertEqual(Set(OlympicSports.all.map(\.id)).count, OlympicSports.all.count, "ids are unique")
        XCTAssertEqual(Set(OlympicSports.all.map(\.english)).count, OlympicSports.all.count, "English names are unique")
        XCTAssertEqual(Set(OlympicSports.all.map(\.chinese)).count, OlympicSports.all.count, "Chinese names are unique")
        for sport in OlympicSports.all {
            XCTAssertFalse(sport.emoji.isEmpty, sport.id)
            XCTAssertGreaterThan(sport.aboutEnglish.count, 60, sport.id)
            XCTAssertGreaterThan(sport.aboutChinese.count, 25, sport.id)
            XCTAssertEqual(BookLanguage.detect(sport.chinese), .chinese, sport.id)
            XCTAssertEqual(BookLanguage.detect(sport.aboutChinese), .chinese, sport.id)
            XCTAssertEqual(BookLanguage.detect(sport.aboutEnglish), .english, sport.id)
        }
    }

    func testReusedWordPhotosAreBundled() {
        let bundle = Bundle(for: ColoringSession.self)
        let withPhotos = OlympicSports.all.filter { $0.photo != nil }
        XCTAssertGreaterThanOrEqual(withPhotos.count, 10)
        for sport in withPhotos {
            let ref = sport.photo!
            XCTAssertNotNil(WordPhotos.image(category: ref.category, word: ref.word, bundle: bundle),
                            "\(sport.id) photo \(ref.word)")
        }
    }

    func testEverySportHasAnAnimatedDemo() {
        XCTAssertEqual(Set(SportDemos.all.keys), Set(OlympicSports.all.map(\.id)), "one demo per sport, no strays")
        for (id, demo) in SportDemos.all {
            XCTAssertGreaterThan(demo.duration, 1, id)
            XCTAssertFalse(demo.actors.isEmpty, id)
            for actor in demo.actors {
                XCTAssertFalse(actor.keys.isEmpty, id)
                XCTAssertEqual(actor.keys.map(\.t), actor.keys.map(\.t).sorted(), "\(id) keys in time order")
                for t in stride(from: 0.0, through: 1.0, by: 0.05) {
                    let (point, turn) = actor.place(at: t)
                    XCTAssertTrue(point.x.isFinite && point.y.isFinite && turn.isFinite, id)
                    XCTAssertTrue((0...1).contains(actor.opacity(at: t)), id)
                }
            }
        }
    }

    func testIntroductionsSplitIntoReadableParts() {
        for sport in OlympicSports.all {
            let english = AudiobookMaker.parts(in: sport.aboutEnglish, language: .english)
            XCTAssertTrue(english.allSatisfy { $0.language == .english }, sport.id)
            let chinese = AudiobookMaker.parts(in: sport.aboutChinese, language: .chinese)
            XCTAssertFalse(chinese.isEmpty, sport.id)
            XCTAssertTrue(chinese.contains { $0.language == .chinese }, sport.id)
        }
    }
}

/// Renders frames of every sport demo into contact sheets, for checking them by eye.
/// Writes to the folder in SPORT_DEMO_SHEETS (skipped when it isn't set).
@MainActor
final class SportDemoSheetTests: XCTestCase {
    func testRenderDemoSheets() throws {
        // Run with TEST_RUNNER_SPORT_DEMO_SHEETS=<folder> xcodebuild test … to write the sheets.
        guard let folder = ProcessInfo.processInfo.environment["SPORT_DEMO_SHEETS"] else {
            throw XCTSkip("Set SPORT_DEMO_SHEETS to render the demo sheets")
        }
        for sport in OlympicSports.all {
            guard let demo = SportDemos.demo(for: sport.id) else { continue }
            let frames = HStack(spacing: 4) {
                ForEach([0.1, 0.3, 0.5, 0.7, 0.9], id: \.self) { t in
                    SportDemoCanvas(demo: demo, t: t).frame(width: 240, height: 150)
                }
            }
            let renderer = ImageRenderer(content: frames.background(.white))
            renderer.scale = 2
            let data = try XCTUnwrap(renderer.uiImage?.pngData(), sport.id)
            try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(sport.id).png"))
        }
    }
}
