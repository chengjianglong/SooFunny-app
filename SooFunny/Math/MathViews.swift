import SwiftUI

extension MathSession: Identifiable {}

private enum MathRoute: Hashable {
    case setup(MathMode)
    case progress
}

/// The Math tab: flashcards, quizzes and progress reports for + − × ÷. Everything is offline.
struct MathView: View {
    @State private var path: [MathRoute] = []
    @State private var settings = MathSettings.load()
    @State private var session: MathSession?
    @State private var showSettings = false
    private let store = MathProgressStore.shared

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    MathTitle()
                        .padding(.top, 8)
                    if store.streak() > 0 {
                        Text("🔥 \(store.streak())-day streak! Keep it up!")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                    MenuButton(title: "Flashcard Game", subtitle: "Flip cards and check yourself",
                               emoji: "🃏", colors: [.pink, .orange]) { path.append(.setup(.flashcards)) }
                    MenuButton(title: "Quiz", subtitle: "Type the answers, beat the clock",
                               emoji: "✏️", colors: [.blue, .teal]) { path.append(.setup(.quiz)) }
                    MenuButton(title: "Progress Reports", subtitle: "See how you're growing",
                               emoji: "📊", colors: [.green, .mint]) { path.append(.progress) }
                    MenuButton(title: "Math Settings", subtitle: "Voice and timer",
                               emoji: "⚙️", colors: [.purple, .indigo]) { showSettings = true }
                }
                .padding(16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(MathBackground())
            .navigationTitle("Math")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MathRoute.self) { route in
                switch route {
                case .setup(let mode):
                    MathSetupView(mode: mode, settings: $settings) { start(mode) }
                case .progress:
                    MathProgressReportView(store: store) { questions in
                        session = MathSession(mode: .quiz, questions: questions, markQuestions: true)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { MathSettingsView(settings: $settings, store: store) }
            .fullScreenCover(item: $session) { session in
                MathPlayView(session: session, settings: settings, store: store) { retry in
                    self.session = nil
                    if let retry {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            self.session = MathSession(mode: .quiz, questions: retry, markQuestions: true)
                        }
                    }
                }
            }
        }
        .onChange(of: settings) { _, new in new.save() }
    }

    private func start(_ mode: MathMode) {
        var round = settings
        if !Premium.shared.isActive { round.operations.formIntersection(FreeTier.mathOperations) }
        guard round.isReady else { return }
        session = MathSession(mode: mode, questions: MathQuestionMaker.questions(for: round),
                              markQuestions: settings.markQuestions)
    }
}

// MARK: - Menu

private struct MathTitle: View {
    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 14) {
                    ForEach(Array(MathOperation.allCases.enumerated()), id: \.element) { i, op in
                        Text(op.symbol)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(op.color.gradient, in: RoundedRectangle(cornerRadius: 18))
                            .rotationEffect(.degrees(sin(t * 2 + Double(i)) * 8))
                            .offset(y: -max(0, sin(t * 3 - Double(i) * 0.7)) * 8)
                    }
                }
            }
            Text("Math Fun")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.green, .orange, .blue, .purple], startPoint: .leading, endPoint: .trailing))
        }
        .accessibilityElement()
        .accessibilityLabel("Math Fun")
        .accessibilityAddTraits(.isHeader)
    }
}

private struct MenuButton: View {
    let title: String
    let subtitle: String
    let emoji: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title2.weight(.heavy))
                    Text(subtitle).font(.subheadline.weight(.medium)).opacity(0.9)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.title3.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: colors[0].opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(PressableStyle())
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: configuration.isPressed)
    }
}

private struct MathBackground: View {
    var body: some View {
        Canvas { context, size in
            var rng = SplitMix64(seed: 7)
            let symbols = ["+", "−", "×", "÷", "=", "1", "2", "3"]
            for _ in 0..<40 {
                let x = Double(rng.next() % 10_000) / 10_000 * size.width
                let y = Double(rng.next() % 10_000) / 10_000 * size.height
                let symbol = symbols[Int(rng.next() % UInt64(symbols.count))]
                context.draw(Text(symbol).font(.system(size: 22 + Double(rng.next() % 20), weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.18)), at: CGPoint(x: x, y: y))
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}

// MARK: - Setup

/// Choose operations, the numbers to practice, how many questions, and marking.
struct MathSetupView: View {
    let mode: MathMode
    @Binding var settings: MathSettings
    let onStart: () -> Void
    @State private var showPaywall = false
    private let premium = Premium.shared

    private func isLocked(_ op: MathOperation) -> Bool {
        !premium.isActive && !FreeTier.mathOperations.contains(op)
    }

    /// The operations this round will really use.
    private var usable: Set<MathOperation> { settings.operations.filter { !isLocked($0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                section("Choose operations") {
                    HStack(spacing: 14) {
                        ForEach(MathOperation.allCases) { op in
                            let on = usable.contains(op)
                            Button {
                                if isLocked(op) { showPaywall = true } else { toggle(op) }
                            } label: {
                                Text(op.symbol)
                                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                                    .frame(width: 70, height: 70)
                                    .foregroundStyle(on ? .white : op.color)
                                    .background(on ? AnyShapeStyle(op.color.gradient) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                                                in: Circle())
                                    .overlay(Circle().stroke(op.color, lineWidth: 3))
                                    .overlay(alignment: .topTrailing) {
                                        if isLocked(op) { PremiumBadge().offset(x: 6, y: -6) }
                                    }
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(op.name)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }

                section("Choose numbers to focus on") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 10) {
                        ForEach(MathSettings.numbers, id: \.self) { n in
                            let on = settings.focusNumbers.contains(n)
                            Button {
                                if on { settings.focusNumbers.remove(n) } else { settings.focusNumbers.insert(n) }
                            } label: {
                                Text("\(n)")
                                    .font(.title2.weight(.bold).monospacedDigit())
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .foregroundStyle(on ? .white : .primary)
                                    .background(on ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                                                in: Circle())
                                    .overlay(Circle().stroke(Color.accentColor.opacity(on ? 0 : 0.4), lineWidth: 2))
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    HStack {
                        Button("All") { settings.focusNumbers = Set(MathSettings.numbers) }
                        Button("1 to 5") { settings.focusNumbers = Set(1...5) }
                        Button("None") { settings.focusNumbers = [] }
                    }
                    .buttonStyle(.bordered)
                }

                HStack(alignment: .top, spacing: 24) {
                    section("Number of questions") {
                        Picker("Number of questions", selection: $settings.questionCount) {
                            ForEach(MathSettings.counts, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if mode == .flashcards {
                        section("Mark questions?") {
                            Picker("Mark questions", selection: $settings.markQuestions) {
                                Text("Yes").tag(true)
                                Text("No").tag(false)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                if usable.isEmpty || settings.focusNumbers.isEmpty {
                    Text("Pick at least one operation and one number.")
                        .font(.headline)
                        .foregroundStyle(.red)
                }
                Button(action: onStart) {
                    Text("Start")
                        .font(.title2.weight(.heavy))
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.borderedProminent)
                .disabled(usable.isEmpty || settings.focusNumbers.isEmpty)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .navigationTitle(mode == .flashcards ? "Flashcard Game" : "Quiz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ op: MathOperation) {
        if settings.operations.contains(op) { settings.operations.remove(op) } else { settings.operations.insert(op) }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            content()
        }
    }
}

// MARK: - Playing

/// A flashcard round or quiz, then the results.
struct MathPlayView: View {
    @Bindable var session: MathSession
    let settings: MathSettings
    let store: MathProgressStore
    /// Called when done; passes questions to practice again, if the child chose that.
    let onClose: ([MathQuestion]?) -> Void

    @State private var saved = false
    private let haptics = UINotificationFeedbackGenerator()

    var body: some View {
        NavigationStack {
            Group {
                if let result = session.finishedResult {
                    MathResultView(result: result, onAgain: { onClose(result.missed) }, onDone: { onClose(nil) })
                        .onAppear { save(result) }
                } else if session.mode == .flashcards {
                    flashcard
                } else {
                    quiz
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !session.isFinished {
                        Button("Exit") { Speech.shared.stop(); onClose(nil) }
                            .font(.headline)
                    }
                }
            }
        }
        .onAppear(perform: readQuestion)
        .onChange(of: session.index) { readQuestion() }
    }

    // MARK: Flashcard

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Text(session.progressText).font(.headline)
                if session.mode == .quiz, settings.showTimer {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Label(clock(context.date.timeIntervalSince(session.startDate)), systemImage: "timer")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.blue)
                    }
                }
            }
            ProgressView(value: Double(session.index), total: Double(session.questions.count))
                .tint(.green)
                .frame(maxWidth: 320)
        }
    }

    private var flashcard: some View {
        VStack(spacing: 20) {
            progressBar
            Text(session.revealed ? (session.markQuestions ? "Did you get it right?" : "Tap Next for another card")
                                  : "Think of the answer, then tap the card to check")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button { withAnimation(.spring(duration: 0.4)) { session.reveal() } } label: {
                VerticalProblem(question: session.current, showAnswer: session.revealed)
                    .frame(maxWidth: 520)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                    .rotation3DEffect(.degrees(session.revealed ? 360 : 0), axis: (0, 1, 0))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.revealed ? "\(session.current.spokenText) equals \(session.current.answer)"
                                                 : "\(session.current.spokenText). Tap to see the answer")
            Spacer(minLength: 0)
            if session.revealed {
                if session.markQuestions {
                    HStack(spacing: 14) {
                        bigButton("Not yet", systemImage: "xmark", color: .red) { session.mark(false) }
                        bigButton("Got it!", systemImage: "checkmark", color: .green) { session.mark(true) }
                    }
                } else {
                    bigButton("Next", systemImage: "arrow.right", color: .accentColor) { session.mark(nil) }
                }
            } else {
                bigButton("Show answer", systemImage: "eye", color: .accentColor) {
                    withAnimation(.spring(duration: 0.4)) { session.reveal() }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 640)
    }

    // MARK: Quiz

    private var quiz: some View {
        VStack(spacing: 16) {
            progressBar
            HStack(spacing: 10) {
                Text(session.current.text + " =")
                Text(session.typed.isEmpty ? "?" : session.typed)
                    .foregroundStyle(session.typed.isEmpty ? .secondary : .primary)
                    .frame(minWidth: 70)
                    .padding(.horizontal, 10)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            .font(.system(size: 54, weight: .heavy, design: .rounded).monospacedDigit())
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(.top, 8)

            ZStack {
                if let right = session.feedback {
                    VStack(spacing: 6) {
                        Image(systemName: right ? "checkmark" : "xmark")
                            .font(.system(size: 90, weight: .black))
                            .foregroundStyle(right ? .green : .red)
                            .transition(.scale.combined(with: .opacity))
                        Text(right ? cheer : "It's \(session.current.answer)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(right ? .green : .red)
                    }
                } else {
                    NumberPad(onDigit: { session.type($0) }, onDelete: { session.deleteDigit() })
                }
            }
            .frame(maxHeight: .infinity)

            if session.feedback != nil {
                bigButton("Next", systemImage: "arrow.right", color: .accentColor) { session.next() }
            } else {
                bigButton("Check", systemImage: "checkmark.circle.fill", color: .green) { check() }
                    .disabled(session.typed.isEmpty)
            }
        }
        .padding(20)
        .frame(maxWidth: 560)
    }

    private var cheer: String {
        ["Great job!", "You got it!", "Super!", "Awesome!", "Yes!"][session.index % 5]
    }

    private func check() {
        guard let right = withAnimation(.spring(duration: 0.35, bounce: 0.5), { session.check() }) else { return }
        haptics.notificationOccurred(right ? .success : .error)
        if settings.readAloud {
            Speech.shared.speak(right ? cheer : "Nice try. \(session.current.spokenText) is \(session.current.answer).")
        }
    }

    // MARK: -

    private func readQuestion() {
        guard settings.readAloud, !session.isFinished else { return }
        Speech.shared.speak("\(session.current.spokenText) equals?")
    }

    private func save(_ result: MathResult) {
        guard !saved else { return }
        saved = true
        store.add(result)
    }

    private func bigButton(_ title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title2.weight(.heavy))
                .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    private func clock(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// A problem written the school way: numbers stacked, with a line and the answer below.
struct VerticalProblem: View {
    let question: MathQuestion
    let showAnswer: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(question.left)")
            HStack(spacing: 30) {
                Text(question.operation.symbol).foregroundStyle(question.operation.color)
                Text("\(question.right)")
            }
            Rectangle().frame(height: 6).padding(.vertical, 6)
            Text(showAnswer ? "\(question.answer)" : "?")
                .foregroundStyle(showAnswer ? Color.accentColor : .secondary)
        }
        .font(.system(size: 96, weight: .heavy, design: .rounded).monospacedDigit())
        .minimumScaleFactor(0.4)
        .foregroundStyle(.black)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 40)
    }
}

private struct NumberPad: View {
    let onDigit: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) { ForEach(row, id: \.self) { key($0) } }
            }
            HStack(spacing: 12) {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 80)
                key(0)
                Button(action: onDelete) {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity, maxHeight: 80)
                        .foregroundStyle(.red)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Delete")
            }
        }
        .frame(maxWidth: 360)
    }

    private func key(_ n: Int) -> some View {
        Button { onDigit(n) } label: {
            Text("\(n)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: 80)
                .aspectRatio(1, contentMode: .fit)
                .foregroundStyle(.primary)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .overlay(Circle().stroke(Color.accentColor.opacity(0.35), lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Results

struct MathResultView: View {
    let result: MathResult
    let onAgain: () -> Void
    let onDone: () -> Void

    @State private var shown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(headline)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < result.stars ? "star.fill" : "star")
                            .font(.system(size: 54))
                            .foregroundStyle(.yellow)
                            .scaleEffect(shown ? 1 : 0.2)
                            .animation(.spring(duration: 0.5, bounce: 0.6).delay(Double(i) * 0.2), value: shown)
                    }
                }
                if result.score != nil {
                    Text("\(result.correctCount) of \(result.marked.count) right")
                        .font(.title.weight(.bold))
                } else {
                    Text("\(result.total) cards practiced")
                        .font(.title.weight(.bold))
                }
                Label(time, systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if !result.missed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Let's practice these again").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                            ForEach(Array(result.missed.enumerated()), id: \.offset) { _, q in
                                Text("\(q.text) = \(q.answer)")
                                    .font(.title3.weight(.semibold).monospacedDigit())
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    Button(action: onAgain) {
                        Label("Practice missed ones", systemImage: "arrow.counterclockwise")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                Button(action: onDone) {
                    Text("Done")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .overlay { if result.stars == 3 { Confetti().allowsHitTesting(false) } }
        .onAppear {
            shown = true
            Speech.shared.speak(headline)
        }
    }

    private var headline: String {
        switch result.stars {
        case 3: return "Amazing! 🎉"
        case 2: return "Great work! 🌟"
        case 1: return "Good try! 💪"
        default: return "Keep practicing! 🌱"
        }
    }

    private var time: String {
        let s = Int(result.seconds)
        return s < 60 ? "\(s) seconds" : "\(s / 60) min \(s % 60) s"
    }
}

/// Falling confetti for a perfect round.
private struct Confetti: View {
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSince(start)
                guard t < 4 else { return }
                var rng = SplitMix64(seed: 3)
                let colors: [Color] = [.pink, .orange, .yellow, .green, .blue, .purple]
                for _ in 0..<90 {
                    let x0 = Double(rng.next() % 1000) / 1000 * size.width
                    let speed = 180 + Double(rng.next() % 260)
                    let sway = Double(rng.next() % 60)
                    let y = -20 + speed * t
                    let x = x0 + sin(t * 3 + x0) * sway
                    let color = colors[Int(rng.next() % UInt64(colors.count))]
                    canvas.fill(Path(roundedRect: CGRect(x: x, y: y, width: 10, height: 14), cornerRadius: 3),
                                with: .color(color.opacity(max(0, 1 - t / 4))))
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Progress

struct MathProgressReportView: View {
    let store: MathProgressStore
    let onPractice: ([MathQuestion]) -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    stat("\(store.results.count)", "rounds", "🏁")
                    stat("\(store.totalQuestions)", "questions", "🧮")
                    stat("\(store.streak())", "day streak", "🔥")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("How you're doing") {
                ForEach(store.operationStats, id: \.operation) { stat in
                    HStack(spacing: 12) {
                        Text(stat.operation.symbol)
                            .font(.title.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(stat.operation.color.gradient, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(stat.operation.name).font(.headline)
                                Spacer()
                                Text(stat.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "Not tried yet")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(.tertiarySystemFill))
                                    Capsule().fill(stat.operation.color.gradient)
                                        .frame(width: geo.size.width * (stat.accuracy ?? 0))
                                }
                            }
                            .frame(height: 12)
                            if stat.asked > 0 {
                                Text("\(stat.correct) of \(stat.asked) right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            let tricky = store.trickyQuestions
            if !tricky.isEmpty {
                Section {
                    ForEach(Array(tricky.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text("\(item.question.text) = \(item.question.answer)")
                                .font(.title3.weight(.semibold).monospacedDigit())
                            Spacer()
                            Text("missed \(item.misses)×").foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        onPractice(tricky.map(\.question))
                    } label: {
                        Label("Practice tricky ones", systemImage: "target")
                    }
                } header: {
                    Text("Tricky ones")
                }
            }

            Section("Recent rounds") {
                if store.results.isEmpty {
                    Text("No rounds yet. Try a flashcard game or a quiz!").foregroundStyle(.secondary)
                }
                ForEach(store.results.prefix(30)) { result in
                    HStack {
                        Text(result.mode == .quiz ? "✏️" : "🃏").font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.operations.map(\.symbol).joined(separator: " ") + "  ·  " + result.mode.title)
                                .font(.headline)
                            Text(result.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(result.score != nil ? "\(result.correctCount)/\(result.marked.count)" : "\(result.total) cards")
                                .font(.headline.monospacedDigit())
                            Text(String(repeating: "⭐", count: result.stars)).font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Progress Reports")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ value: String, _ label: String, _ emoji: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title)
            Text(value).font(.title.weight(.heavy).monospacedDigit())
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Settings

struct MathSettingsView: View {
    @Binding var settings: MathSettings
    let store: MathProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Read questions aloud", isOn: $settings.readAloud)
                    Toggle("Show timer in quizzes", isOn: $settings.showTimer)
                } footer: {
                    Text("Questions are read with the voice chosen in the app's Settings. Everything works offline.")
                }
                Section {
                    Button("Reset progress", role: .destructive) { confirmReset = true }
                        .disabled(store.results.isEmpty)
                } footer: {
                    Text("Progress is saved only on this device.")
                }
            }
            .navigationTitle("Math Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Erase all math progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase progress", role: .destructive) { store.clear() }
            }
        }
    }
}
