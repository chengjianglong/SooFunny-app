import XCTest
@testable import SooFunny

final class MathQuestionTests: XCTestCase {
    func testQuestionsFollowTheSettingsAndStayKidFriendly() {
        var rng = SplitMix64(seed: 1)
        for ops in [[MathOperation.add], [.subtract], [.multiply], [.divide], MathOperation.allCases] {
            for focus in [Set([0]), Set([3, 7]), Set(MathSettings.numbers)] {
                var settings = MathSettings()
                settings.operations = Set(ops)
                settings.focusNumbers = focus
                settings.questionCount = 30
                let questions = MathQuestionMaker.questions(for: settings, using: &rng)
                XCTAssertEqual(questions.count, 30)
                for q in questions {
                    XCTAssertTrue(ops.contains(q.operation), q.text)
                    XCTAssertGreaterThanOrEqual(q.answer, 0, q.text)
                    XCTAssertTrue(focus.contains(q.left) || focus.contains(q.right), "\(q.text) misses focus \(focus)")
                    if q.operation == .divide {
                        XCTAssertNotEqual(q.right, 0, q.text)
                        XCTAssertEqual(q.left % q.right, 0, q.text)
                    }
                }
            }
        }
    }

    func testAnswers() {
        XCTAssertEqual(MathQuestion(left: 9, right: 0, operation: .add).answer, 9)
        XCTAssertEqual(MathQuestion(left: 5, right: 1, operation: .subtract).answer, 4)
        XCTAssertEqual(MathQuestion(left: 7, right: 6, operation: .multiply).answer, 42)
        XCTAssertEqual(MathQuestion(left: 56, right: 8, operation: .divide).answer, 7)
        XCTAssertEqual(MathQuestion(left: 5, right: 1, operation: .subtract).text, "5 − 1")
        XCTAssertEqual(MathQuestion(left: 12, right: 3, operation: .divide).spokenText, "12 divided by 3")
    }

    func testNoImmediateRepeatsWhenThereIsAChoice() {
        var rng = SplitMix64(seed: 9)
        var settings = MathSettings()
        settings.operations = [.add]
        settings.focusNumbers = [2]
        settings.questionCount = 30
        let questions = MathQuestionMaker.questions(for: settings, using: &rng)
        let repeats = zip(questions, questions.dropFirst()).filter { $0 == $1 }.count
        XCTAssertLessThanOrEqual(repeats, 2)
    }

    func testNothingChosenMakesNoQuestions() {
        var settings = MathSettings()
        settings.operations = []
        XCTAssertFalse(settings.isReady)
        XCTAssertTrue(MathQuestionMaker.questions(for: settings).isEmpty)
    }
}

final class MathSessionTests: XCTestCase {
    private let questions = [MathQuestion(left: 3, right: 1, operation: .subtract),
                             MathQuestion(left: 9, right: 0, operation: .add)]

    func testQuizChecksTypedAnswers() throws {
        let session = MathSession(mode: .quiz, questions: questions, markQuestions: true)
        session.type(0)
        session.type(2)
        XCTAssertEqual(session.typed, "2", "a leading zero is replaced")
        XCTAssertEqual(session.check(), true)
        session.type(5)
        XCTAssertEqual(session.typed, "2", "typing is locked until Next")
        session.next()
        XCTAssertEqual(session.progressText, "Question 2 of 2")
        session.type(8)
        XCTAssertEqual(session.check(), false)
        session.next()
        let result = try XCTUnwrap(session.finishedResult)
        XCTAssertEqual(result.correctCount, 1)
        XCTAssertEqual(result.missed, [questions[1]])
        XCTAssertEqual(result.answers.map(\.given), [2, 8])
        XCTAssertEqual(result.stars, 1)
    }

    func testFlashcardsRevealThenMark() throws {
        let session = MathSession(mode: .flashcards, questions: questions, markQuestions: true)
        session.mark(true)
        XCTAssertTrue(session.answers.isEmpty, "can't mark before revealing")
        session.reveal()
        session.mark(true)
        XCTAssertFalse(session.revealed)
        session.reveal()
        session.mark(true)
        let result = try XCTUnwrap(session.finishedResult)
        XCTAssertEqual(result.score, 1)
        XCTAssertEqual(result.stars, 3)
    }

    func testUnmarkedFlashcardsHaveNoScore() throws {
        let session = MathSession(mode: .flashcards, questions: questions, markQuestions: false)
        for _ in questions {
            session.reveal()
            session.mark(true)
        }
        let result = try XCTUnwrap(session.finishedResult)
        XCTAssertNil(result.score)
        XCTAssertEqual(result.total, 2)
    }
}

final class MathProgressTests: XCTestCase {
    private func store() -> MathProgressStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("math-\(UUID()).json")
        return MathProgressStore(fileURL: url)
    }

    private func result(daysAgo: Int, correct: [Bool], op: MathOperation = .add) -> MathResult {
        let answers = correct.enumerated().map { i, ok in
            MathAnswer(question: MathQuestion(left: i, right: 1, operation: op), given: nil, correct: ok, seconds: 1)
        }
        return MathResult(date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
                          mode: .quiz, operations: [op], answers: answers, seconds: 10)
    }

    func testStatsStreakAndPersistence() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("math-\(UUID()).json")
        let store = MathProgressStore(fileURL: url)
        store.add(result(daysAgo: 2, correct: [true, false]))
        store.add(result(daysAgo: 1, correct: [true, true], op: .multiply))
        store.add(result(daysAgo: 0, correct: [false]))
        XCTAssertEqual(store.streak(), 3)

        let add = store.operationStats.first { $0.operation == .add }!
        XCTAssertEqual(add.asked, 3)
        XCTAssertEqual(add.correct, 1)
        XCTAssertEqual(store.trickyQuestions.first?.misses, 1)

        let reloaded = MathProgressStore(fileURL: url)
        XCTAssertEqual(reloaded.results.count, 3)
        reloaded.clear()
        XCTAssertEqual(MathProgressStore(fileURL: url).results.count, 0)
    }

    func testStreakBreaksOnAMissedDay() {
        let store = store()
        store.add(result(daysAgo: 3, correct: [true]))
        store.add(result(daysAgo: 1, correct: [true]))
        XCTAssertEqual(store.streak(), 1, "yesterday counts; the gap before it ends the streak")
    }
}
