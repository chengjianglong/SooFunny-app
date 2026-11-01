import Observation
import SwiftUI

/// One page in the reader: the words, and either an emoji picture or a scanned photo.
struct ReaderPage: Hashable {
    var text: String
    var scene: String?
    var imageURL: URL?
}

/// Reads a page aloud and follows along, word by word.
@MainActor
@Observable
final class ReadAloud {
    /// The page text being read, and the word being said in it.
    private(set) var text = ""
    private(set) var highlight: NSRange?
    private(set) var isReading = false
    /// Called when a whole page has been read (not when stopped).
    @ObservationIgnored var onPageFinished: (() -> Void)?

    /// One voice per language, made when first needed.
    @ObservationIgnored private var speakers: [BookLanguage: SentenceSpeaker] = [:]
    /// What's left to say on this page: runs of text in one language, each said by its own voice.
    @ObservationIgnored private var batches: [(language: BookLanguage, texts: [String])] = []
    /// Where to look for the next spoken word, so repeated words light up in order.
    @ObservationIgnored private var cursor = 0

    /// English is read in the natural voice and Chinese in Apple's Chinese voice; a page with
    /// both switches voice wherever the language changes. `language` is for text with no letters.
    func read(_ text: String, language: BookLanguage = .english) {
        stop()
        Speech.shared.stop()
        self.text = text
        cursor = 0
        batches = []
        for part in AudiobookMaker.parts(in: text, language: language) {
            if batches.last?.language == part.language {
                batches[batches.count - 1].texts.append(part.text)
            } else {
                batches.append((part.language, [part.text]))
            }
        }
        guard !batches.isEmpty else {
            // Nothing to say on this page (a picture-only page): move straight on.
            DispatchQueue.main.async { self.onPageFinished?() }
            return
        }
        isReading = true
        Self.prefetch(text, language: language)
        speakNextBatch()
    }

    func stop() {
        isReading = false
        highlight = nil
        batches = []
        for speaker in speakers.values { speaker.stop() }
    }

    /// Prepares the natural voice for the English on a page that's coming up.
    static func prefetch(_ text: String, language: BookLanguage = .english) {
        let english = AudiobookMaker.parts(in: text, language: language).filter { $0.language == .english }
        guard !english.isEmpty else { return }
        NaturalVoiceEngine.shared.prefetch(english.flatMap { NaturalVoice.phrases(in: $0.text).map(\.text) })
    }

    private func speakNextBatch() {
        guard isReading, !batches.isEmpty else { return }
        let batch = batches.removeFirst()
        let speaker = speaker(for: batch.language)
        speaker.onWord = { [weak self] phrase, range in self?.follow((phrase as NSString).substring(with: range)) }
        speaker.onFinished = { [weak self] in
            guard let self, self.isReading else { return }
            if self.batches.isEmpty {
                self.isReading = false
                self.highlight = nil
                self.onPageFinished?()
            } else {
                self.speakNextBatch()
            }
        }
        for text in batch.texts { speaker.enqueue(text) }
    }

    private func speaker(for language: BookLanguage) -> SentenceSpeaker {
        if let speaker = speakers[language] { return speaker }
        let speaker: SentenceSpeaker
        switch language {
        case .english:
            speaker = NaturalVoice()
        case .chinese:
            let system = SystemSentenceSpeaker()
            system.voice = language.systemVoice
            speaker = system
        }
        speakers[language] = speaker
        return speaker
    }

    private func follow(_ word: String) {
        let ns = text as NSString
        guard cursor < ns.length else { return }
        let found = ns.range(of: word, options: [.caseInsensitive], range: NSRange(location: cursor, length: ns.length - cursor))
        guard found.location != NSNotFound else { return }
        highlight = found
        cursor = found.location + found.length
    }
}

/// A picture book, full screen: swipe or tap the arrows to turn pages, and tap Read to me to
/// hear it with each word lighting up. While reading, pages turn by themselves.
struct BookReader: View {
    let title: String
    let color: Color
    let pages: [ReaderPage]
    var language: BookLanguage = .english

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var index = 0
    @State private var reader = ReadAloud()
    /// True while reading on from page to page.
    @State private var playing = false
    @State private var finished = false

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $index) {
                ForEach(Array(pages.enumerated()), id: \.offset) { offset, page in
                    pageView(page, current: offset == index)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            controls
        }
        .background(color.opacity(0.12).ignoresSafeArea())
        .onChange(of: index) { _, _ in
            finished = false
            if playing { reader.read(pages[index].text, language: language) } else { reader.stop() }
            prefetchNext()
        }
        .onAppear {
            reader.onPageFinished = pageFinished
            ReadAloud.prefetch(pages[0].text, language: language)
            prefetchNext()
        }
        .onDisappear { reader.stop() }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
            }
            .accessibilityLabel("Close book")
            Spacer()
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Text("\(index + 1)/\(pages.count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func pageView(_ page: ReaderPage, current: Bool) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                picture(page)
                pageText(page.text, current: current)
                    .frame(maxWidth: 760)
                if finished && current && index == pages.count - 1 {
                    Text(language == .chinese ? "完 🎉" : "The End 🎉")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func picture(_ page: ReaderPage) -> some View {
        let height: CGFloat = sizeClass == .regular ? 420 : 260
        if let url = page.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: height)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        } else {
            Text(page.scene ?? "📖")
                .font(.system(size: sizeClass == .regular ? 150 : 90))
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .padding(24)
                .frame(maxWidth: 760, minHeight: height)
                .background(
                    LinearGradient(colors: [color.opacity(0.35), color.opacity(0.12)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 32))
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white, lineWidth: 5))
                .shadow(color: color.opacity(0.3), radius: 10, y: 5)
                .accessibilityHidden(true)
        }
    }

    /// The page's words; the word being read is highlighted. Tap the words to hear them.
    private func pageText(_ text: String, current: Bool) -> some View {
        var attributed = AttributedString(text)
        if current, reader.text == text, let range = reader.highlight, let r = Range(range, in: text),
           let lower = AttributedString.Index(r.lowerBound, within: attributed),
           let upper = AttributedString.Index(r.upperBound, within: attributed) {
            attributed[lower..<upper].backgroundColor = .yellow.opacity(0.75)
            attributed[lower..<upper].foregroundColor = .black
        }
        return Text(attributed)
            .font(.system(size: sizeClass == .regular ? 34 : 26, weight: .semibold, design: .rounded))
            .lineSpacing(8)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture { startReading() }
            .accessibilityAddTraits(.isButton)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button { turn(-1) } label: {
                Image(systemName: "arrow.left").frame(width: 56, height: 56)
            }
            .disabled(index == 0)
            .accessibilityLabel("Previous page")

            Button {
                playing ? stopReading() : startReading()
            } label: {
                Label(playing ? (language == .chinese ? "停" : "Stop") : (language == .chinese ? "读给我听" : "Read to me"), systemImage: playing ? "stop.fill" : "play.fill")
                    .font(.title2.weight(.heavy))
                    .frame(maxWidth: 320, minHeight: 56)
                    .symbolEffect(.pulse, isActive: playing)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)

            Button { turn(1) } label: {
                Image(systemName: "arrow.right").frame(width: 56, height: 56)
            }
            .disabled(index == pages.count - 1)
            .accessibilityLabel("Next page")
        }
        .font(.title2.weight(.bold))
        .buttonStyle(.bordered)
        .tint(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func turn(_ step: Int) {
        withAnimation { index = min(max(0, index + step), pages.count - 1) }
    }

    private func startReading() {
        playing = true
        finished = false
        reader.read(pages[index].text, language: language)
    }

    private func stopReading() {
        playing = false
        reader.stop()
    }

    private func pageFinished() {
        guard playing else { return }
        if index < pages.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if playing { turn(1) }
            }
        } else {
            playing = false
            withAnimation(.spring(duration: 0.5, bounce: 0.5)) { finished = true }
        }
    }

    private func prefetchNext() {
        if index + 1 < pages.count { ReadAloud.prefetch(pages[index + 1].text, language: language) }
    }
}
