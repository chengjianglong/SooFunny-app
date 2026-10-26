import Foundation
import Observation
import SwiftUI

enum MathOperation: String, Codable, CaseIterable, Identifiable, Comparable {
    case add, subtract, multiply, divide

    var id: Self { self }

    var symbol: String {
        switch self {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        }
    }

    /// How the sign is read aloud.
    var spoken: String {
        switch self {
        case .add: return "plus"
        case .subtract: return "minus"
        case .multiply: return "times"
        case .divide: return "divided by"
        }
    }

    var name: String {
        switch self {
        case .add: return "Adding"
        case .subtract: return "Taking away"
        case .multiply: return "Times"
        case .divide: return "Sharing"
        }
    }

    var color: Color {
        switch self {
        case .add: return .green
        case .subtract: return .orange
        case .multiply: return .blue
        case .divide: return .purple
        }
    }

    static func < (a: MathOperation, b: MathOperation) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

/// One problem, such as 9 + 0. Answers are always whole numbers of zero or more.
struct MathQuestion: Codable, Hashable {
    let left: Int
    let right: Int
    let operation: MathOperation

    var answer: Int {
        switch operation {
        case .add: return left + right
        case .subtract: return left - right
        case .multiply: return left * right
        case .divide: return right == 0 ? 0 : left / right
        }
    }

    var text: String { "\(left) \(operation.symbol) \(right)" }
    var spokenText: String { "\(left) \(operation.spoken) \(right)" }
}

/// What to practice. Saved between launches.
struct MathSettings: Codable, Equatable {
    static let numbers = Array(0...12)
    static let counts = [10, 20, 30]

    var operations: Set<MathOperation> = [.add, .subtract]
    /// Every question uses at least one of these numbers.
    var focusNumbers: Set<Int> = Set(1...10)
    var questionCount = 10
    /// Flashcards: after seeing the answer, the child says whether they got it right.
    var markQuestions = true
    /// Read each question aloud with the iPad's built-in voice.
    var readAloud = true
    /// Show the timer during quizzes.
    var showTimer = true

    var isReady: Bool { !operations.isEmpty && !focusNumbers.isEmpty }

    private static let key = "mathSettings"

    static func load() -> MathSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(MathSettings.self, from: data) else { return MathSettings() }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}

/// Makes practice questions that suit young children.
enum MathQuestionMaker {
    /// `count` questions using the chosen operations and focus numbers, without the
    /// same question twice in a row. `focusLimits` keeps an operation to some focus numbers;
    /// an operation left with none isn't used.
    static func questions<R: RandomNumberGenerator>(for settings: MathSettings,
                                                    focusLimits: [MathOperation: ClosedRange<Int>] = [:],
                                                    using rng: inout R) -> [MathQuestion] {
        let choices: [(op: MathOperation, focus: [Int])] = settings.operations.sorted().compactMap { op in
            let focus = settings.focusNumbers.sorted().filter { focusLimits[op]?.contains($0) ?? true }
            return focus.isEmpty ? nil : (op, focus)
        }
        guard !choices.isEmpty else { return [] }
        let possible = choices.reduce(0) { $0 + $1.focus.count }
        var questions: [MathQuestion] = []
        while questions.count < settings.questionCount {
            let choice = choices.randomElement(using: &rng)!
            let f = choice.focus.randomElement(using: &rng)!
            let other = Int.random(in: 0...12, using: &rng)
            let question = make(choice.op, focus: f, other: other, flip: Bool.random(using: &rng))
            // Try again on an immediate repeat, unless only one question is possible.
            if question == questions.last, possible > 1, Int.random(in: 0..<10, using: &rng) > 0 { continue }
            questions.append(question)
        }
        return questions
    }

    static func questions(for settings: MathSettings,
                          focusLimits: [MathOperation: ClosedRange<Int>] = [:]) -> [MathQuestion] {
        var rng = SystemRandomNumberGenerator()
        return questions(for: settings, focusLimits: focusLimits, using: &rng)
    }

    /// One question where the focus number appears. Subtraction never goes below zero and
    /// division always comes out even (and never divides by zero).
    static func make(_ op: MathOperation, focus f: Int, other n: Int, flip: Bool) -> MathQuestion {
        switch op {
        case .add:
            return flip ? MathQuestion(left: n, right: f, operation: .add) : MathQuestion(left: f, right: n, operation: .add)
        case .subtract:
            // (f + n) − f = n: the focus number is the one taken away, so it's always shown.
            return MathQuestion(left: f + n, right: f, operation: .subtract)
        case .multiply:
            return flip ? MathQuestion(left: n, right: f, operation: .multiply) : MathQuestion(left: f, right: n, operation: .multiply)
        case .divide:
            if f == 0 {
                // 0 ÷ n = 0, with n at least 1.
                return MathQuestion(left: 0, right: max(1, n), operation: .divide)
            }
            return MathQuestion(left: f * n, right: f, operation: .divide)
        }
    }
}

enum MathMode: String, Codable {
    case flashcards, quiz

    var title: String { self == .flashcards ? "Flashcards" : "Quiz" }
}

/// How one question went.
struct MathAnswer: Codable, Hashable {
    let question: MathQuestion
    /// What the child typed (quiz only).
    let given: Int?
    /// Nil when flashcards weren't marked.
    let correct: Bool?
    let seconds: Double
}

/// One finished practice round, kept for Progress Reports.
struct MathResult: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    let mode: MathMode
    let operations: [MathOperation]
    let answers: [MathAnswer]
    let seconds: Double

    var total: Int { answers.count }
    var marked: [MathAnswer] { answers.filter { $0.correct != nil } }
    var correctCount: Int { answers.filter { $0.correct == true }.count }
    /// Fraction right (0...1), or nil when nothing was marked.
    var score: Double? { marked.isEmpty ? nil : Double(correctCount) / Double(marked.count) }
    var missed: [MathQuestion] { answers.filter { $0.correct == false }.map(\.question) }

    /// 0–3 stars for the score.
    var stars: Int {
        guard let score else { return 3 }
        switch score {
        case 0.9...: return 3
        case 0.7..<0.9: return 2
        case 0.4..<0.7: return 1
        default: return 0
        }
    }
}

/// A flashcard round or quiz in progress.
@Observable
final class MathSession {
    let mode: MathMode
    let questions: [MathQuestion]
    let markQuestions: Bool

    private(set) var index = 0
    /// Flashcards: the answer is showing.
    private(set) var revealed = false
    /// Quiz: the digits typed so far.
    private(set) var typed = ""
    /// Quiz: the result of the last Check, shown until Next.
    private(set) var feedback: Bool?
    private(set) var answers: [MathAnswer] = []
    private(set) var finishedResult: MathResult?

    let startDate = Date()
    @ObservationIgnored private var questionStart = Date()

    init(mode: MathMode, questions: [MathQuestion], markQuestions: Bool) {
        self.mode = mode
        self.questions = questions
        self.markQuestions = markQuestions
    }

    var current: MathQuestion { questions[min(index, questions.count - 1)] }
    var isFinished: Bool { finishedResult != nil }
    var progressText: String { "Question \(min(index + 1, questions.count)) of \(questions.count)" }

    // MARK: Flashcards

    func reveal() {
        guard mode == .flashcards, !isFinished else { return }
        revealed = true
    }

    /// Flashcards: move on, recording whether the child got it (nil when not marking).
    func mark(_ correct: Bool?) {
        guard mode == .flashcards, revealed, !isFinished else { return }
        record(given: nil, correct: markQuestions ? correct : nil)
        advance()
    }

    // MARK: Quiz

    func type(_ digit: Int) {
        guard mode == .quiz, feedback == nil, typed.count < 3, (0...9).contains(digit) else { return }
        typed = typed == "0" ? String(digit) : typed + String(digit)
    }

    func deleteDigit() {
        guard mode == .quiz, feedback == nil, !typed.isEmpty else { return }
        typed.removeLast()
    }

    /// Checks the typed answer. Returns whether it was right.
    @discardableResult
    func check() -> Bool? {
        guard mode == .quiz, feedback == nil, let value = Int(typed) else { return nil }
        let right = value == current.answer
        feedback = right
        record(given: value, correct: right)
        return right
    }

    func next() {
        guard mode == .quiz, feedback != nil else { return }
        advance()
    }

    // MARK: -

    private func record(given: Int?, correct: Bool?) {
        answers.append(MathAnswer(question: current, given: given, correct: correct,
                                  seconds: Date().timeIntervalSince(questionStart)))
    }

    private func advance() {
        if index + 1 >= questions.count {
            finishedResult = MathResult(mode: mode, operations: Array(Set(questions.map(\.operation))).sorted(),
                                        answers: answers, seconds: Date().timeIntervalSince(startDate))
            return
        }
        index += 1
        revealed = false
        typed = ""
        feedback = nil
        questionStart = Date()
    }
}

/// Saved rounds for Progress Reports. Kept on this device only.
@Observable
final class MathProgressStore {
    static let shared = MathProgressStore()

    private(set) var results: [MathResult] = []
    private let fileURL: URL

    init(fileURL: URL = MathProgressStore.defaultURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? Self.decoder.decode([MathResult].self, from: data) {
            results = saved
        }
    }

    static var defaultURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("math-progress.json")
    }

    func add(_ result: MathResult) {
        results.insert(result, at: 0)
        if results.count > 300 { results.removeLast(results.count - 300) }
        save()
    }

    func clear() {
        results = []
        save()
    }

    struct OperationStats {
        let operation: MathOperation
        let asked: Int
        let correct: Int
        var accuracy: Double? { asked == 0 ? nil : Double(correct) / Double(asked) }
    }

    /// Right answers per operation, over every marked question.
    var operationStats: [OperationStats] {
        MathOperation.allCases.map { op in
            let marked = results.flatMap(\.answers).filter { $0.question.operation == op && $0.correct != nil }
            return OperationStats(operation: op, asked: marked.count, correct: marked.filter { $0.correct == true }.count)
        }
    }

    var totalQuestions: Int { results.reduce(0) { $0 + $1.total } }

    /// Questions answered wrong most often, for "Tricky ones".
    var trickyQuestions: [(question: MathQuestion, misses: Int)] {
        var misses: [MathQuestion: Int] = [:]
        for answer in results.flatMap(\.answers) where answer.correct == false { misses[answer.question, default: 0] += 1 }
        return misses.sorted { ($0.value, $1.key.text) > ($1.value, $0.key.text) }.prefix(8).map { ($0.key, $0.value) }
    }

    /// Days in a row (ending today or yesterday) with at least one round.
    func streak(today: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(results.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while days.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    private func save() {
        try? Self.encoder.encode(results).write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
