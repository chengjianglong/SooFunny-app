import AVFoundation
import PhotosUI
import SwiftUI
import VisionKit

/// The Books tab: picture books that read themselves aloud, and the family's own books,
/// scanned with the camera and turned into read-along books and audiobooks on the device.
struct BooksView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var openStory: StoryBook?
    @State private var scanning = false
    @State private var choosingPhotos = false
    @State private var scannedPages: ScannedPages?
    @State private var path = NavigationPath()
    private let premium = Premium.shared
    private let store = ScannedBookStore.shared

    private let scannerAvailable = VNDocumentCameraViewController.isSupported
    private var canAddBook: Bool { premium.isActive || store.books.count < FreeTier.scannedBooks }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 6) {
                        BouncyTitle()
                        Text("Pick a book and listen along!")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    sectionTitle("📚", "Story time")
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(Array(StoryLibrary.books.enumerated()), id: \.element.id) { index, book in
                            let locked = !premium.isActive && !FreeTier.allows(book)
                            Button {
                                if locked { showPaywall = true } else { openStory = book }
                            } label: {
                                StoryCover(book: book, locked: locked, tilt: index.isMultiple(of: 2) ? -2 : 2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(locked ? "\(book.title), Premium" : "Read \(book.title)")
                        }
                    }

                    sectionTitle("📷", "My books")
                    Text("Scan the pages of a book you own, in English, Chinese or both, as many pages as it has. SooFunny reads the words on your device and turns them into a read-along book and an audiobook.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    scanButtons
                    if !store.books.isEmpty {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(store.books) { book in
                                NavigationLink(value: book) { ScannedCover(book: book) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding([.horizontal, .bottom], 16)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .navigationDestination(for: ScannedBook.self) { book in
                ScannedBookView(bookID: book.id) { path = NavigationPath() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(item: $scannedPages) { pages in
                ScanReviewView(pages: pages.pages) { book in
                    path.append(book)
                }
            }
            .fullScreenCover(item: $openStory) { book in
                BookReader(title: book.title, color: book.color,
                           pages: book.pages.map { ReaderPage(text: $0.text, scene: $0.scene) }, language: book.language)
            }
            .pageSources(scanning: $scanning, choosingPhotos: $choosingPhotos) {
                scannedPages = ScannedPages(pages: $0)
            }
        }
        .onDisappear { Speech.shared.stop() }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: sizeClass == .regular ? 200 : 150), spacing: 16)]
    }

    private func sectionTitle(_ emoji: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji).font(.title)
            Text(title).font(.title2.weight(.heavy))
        }
        .padding(.top, 4)
    }

    private var scanButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                if scannerAvailable {
                    Button { canAddBook ? (scanning = true) : (showPaywall = true) } label: {
                        ScanButtonLabel(title: "Scan a book", systemImage: canAddBook ? "doc.viewfinder" : "lock.fill", color: .orange)
                    }
                }
                Button { canAddBook ? (choosingPhotos = true) : (showPaywall = true) } label: {
                    ScanButtonLabel(title: "From Photos", systemImage: canAddBook ? "photo.on.rectangle.angled" : "lock.fill", color: .pink)
                }
            }
            .frame(maxWidth: 560)
            if !premium.isActive {
                let left = max(0, FreeTier.scannedBooks - store.books.count)
                Text(left == 1 ? "1 free book of your own left" : left > 0 ? "\(left) free books of your own left"
                     : "Get Premium to add more of your own books")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Pages waiting to be read into a book.
struct ScannedPages: Identifiable {
    let id = UUID()
    let pages: [PageScan]
}

// MARK: - Covers

private struct StoryCover: View {
    let book: StoryBook
    let locked: Bool
    let tilt: Double

    var body: some View {
        VStack(spacing: 0) {
            Text(book.cover)
                .font(.system(size: 80))
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(LinearGradient(colors: [book.color.opacity(0.45), book.color.opacity(0.15)],
                                           startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .topTrailing) {
                    if locked { PremiumBadge().padding(8) }
                }
            Text(book.title)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(book.color.gradient)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white, lineWidth: 4))
        .shadow(color: book.color.opacity(0.3), radius: 6, y: 4)
        .rotationEffect(.degrees(tilt))
    }
}

private struct ScannedCover: View {
    let book: ScannedBook
    private let store = ScannedBookStore.shared

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let first = book.pages.first {
                    AsyncImage(url: store.imageURL(first, in: book)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.orange.opacity(0.2)
                    }
                } else {
                    Text("📖").font(.system(size: 64))
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if book.hasAudio {
                    Image(systemName: "headphones")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Color.black.opacity(0.55), in: Circle())
                        .padding(8)
                        .accessibilityLabel("Has audiobook")
                }
            }
            Text(book.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.orange.gradient)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white, lineWidth: 4))
        .shadow(color: .orange.opacity(0.3), radius: 6, y: 4)
    }
}

private struct ScanButtonLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Scanning

/// Apple's document camera: finds the page edges, flattens and crops each page.
struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: ([PageScan]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner

        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // One page at a time, so only one full-size photo is in memory at once.
            parent.onScan((0..<scan.pageCount).compactMap { index in autoreleasepool { PageScan(scan.imageOfPage(at: index)) } })
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}

/// Reads the words on each page, then lets a grown-up fix the text and name the book. More
/// pages can be scanned or chosen at any time, so a book can have any number of pages.
struct ScanReviewView: View {
    /// When set, the pages are added to the end of this book instead of making a new one.
    var addingTo: ScannedBook?
    let onSaved: (ScannedBook) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pages: [ReviewPage]
    @State private var title = ""
    @State private var readerRunning = false
    @State private var scanning = false
    @State private var choosingPhotos = false
    @State private var saveFailed = false
    @State private var reordering = false
    private let scannerAvailable = VNDocumentCameraViewController.isSupported

    private struct ReviewPage: Identifiable {
        let scan: PageScan
        var text = ""
        var read = false
        var id: UUID { scan.id }
    }

    init(pages: [PageScan], addingTo: ScannedBook? = nil, onSaved: @escaping (ScannedBook) -> Void) {
        _pages = State(initialValue: pages.map { ReviewPage(scan: $0) })
        self.addingTo = addingTo
        self.onSaved = onSaved
    }

    private var readCount: Int { pages.filter(\.read).count }
    private var reading: Bool { readCount < pages.count }

    var body: some View {
        NavigationStack {
            Form {
                if reading {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: Double(readCount), total: Double(max(1, pages.count)))
                            Text("Reading page \(min(readCount + 1, pages.count)) of \(pages.count)… The words are read on this device.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if addingTo == nil {
                    Section("Book name") {
                        TextField("Book name", text: $title)
                            .font(.title3.weight(.semibold))
                    }
                }
                ForEach($pages) { $page in
                    let number = (addingTo?.pages.count ?? 0) + (pages.firstIndex { $0.id == page.id } ?? 0) + 1
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(uiImage: page.scan.thumbnail)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            if page.read {
                                TextEditor(text: $page.text)
                                    .frame(minHeight: 120)
                                    .overlay(alignment: .topLeading) {
                                        if page.text.isEmpty {
                                            Text("No words found. Type them here, or leave it as a picture page.")
                                                .foregroundStyle(.tertiary)
                                                .padding(8)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            } else {
                                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                            }
                        }
                        Button("Remove page", role: .destructive) {
                            pages.removeAll { $0.id == page.id }
                        }
                    } header: {
                        Text("Page \(number)")
                    }
                }
                Section {
                    if scannerAvailable {
                        Button { scanning = true } label: { Label("Scan more pages", systemImage: "doc.viewfinder") }
                    }
                    Button { choosingPhotos = true } label: { Label("Add pages from Photos", systemImage: "photo.on.rectangle.angled") }
                    if pages.count > 1 {
                        Button { reordering = true } label: { Label("Change page order", systemImage: "arrow.up.arrow.down") }
                    }
                } footer: {
                    Text("Add as many pages as the book has. New pages go at the end; drag them into place with Change page order.")
                }
            }
            .navigationTitle(addingTo == nil ? "New book" : "Add pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(reading || pages.isEmpty)
                }
            }
            .pageSources(scanning: $scanning, choosingPhotos: $choosingPhotos) { added in
                pages += added.map { ReviewPage(scan: $0) }
                Task { await readPages() }
            }
            .sheet(isPresented: $reordering) {
                PageOrderView(items: pages.map { PageOrderView.Item(id: $0.id.uuidString, thumbnail: $0.scan.thumbnail, text: $0.text) },
                              firstNumber: (addingTo?.pages.count ?? 0) + 1) { order in
                    pages.sort { (order.firstIndex(of: $0.id.uuidString) ?? 0) < (order.firstIndex(of: $1.id.uuidString) ?? 0) }
                }
            }
            .alert("Couldn't save the book", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please check there's space on this device and try again.")
            }
        }
        .interactiveDismissDisabled()
        .task { await readPages() }
    }

    /// Reads every page that hasn't been read yet, one at a time, including pages added meanwhile.
    private func readPages() async {
        guard !readerRunning else { return }
        readerRunning = true
        defer { readerRunning = false }
        while let index = pages.firstIndex(where: { !$0.read }) {
            let id = pages[index].id
            var text = ""
            if let image = pages[index].scan.image { text = await PageReader.text(in: image) }
            guard let current = pages.firstIndex(where: { $0.id == id }) else { continue }
            pages[current].text = text
            pages[current].read = true
            if addingTo == nil, title.isEmpty, current == 0 {
                title = Self.suggestedTitle(text)
            }
        }
    }

    /// The first line of the first page, if it's short enough to be a title.
    static func suggestedTitle(_ firstPage: String) -> String {
        let first = AudiobookMaker.sentences(in: firstPage).first ?? ""
        let fallback = BookLanguage.detect(firstPage) == .chinese ? "我的书" : "My Book"
        let trimmed = first.trimmingCharacters(in: CharacterSet(charactersIn: ".!?,;:。！？，；：").union(.whitespaces))
        if BookLanguage.detect(trimmed) == .chinese {
            return (1...16).contains(trimmed.count) ? trimmed : fallback
        }
        let words = trimmed.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty, words.count <= 8 else { return fallback }
        return words.joined(separator: " ")
    }

    private func save() {
        let texts = pages.map { (jpeg: $0.scan.jpeg, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
        do {
            if let book = addingTo {
                try ScannedBookStore.shared.append(texts, to: book)
                dismiss()
            } else {
                let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let language = BookLanguage.detect(texts.map(\.text).joined())
                let book = try ScannedBookStore.shared.add(title: name.isEmpty ? "My Book" : name, language: language, pages: texts)
                dismiss()
                onSaved(book)
            }
        } catch {
            saveFailed = true
        }
    }
}

/// Brings in book pages from the document camera or Photos, any number at a time.
private struct PageSources: ViewModifier {
    @Binding var scanning: Bool
    @Binding var choosingPhotos: Bool
    let onPages: ([PageScan]) -> Void
    @State private var cameraPages: [PageScan] = []
    @State private var photoItems: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $scanning, onDismiss: {
                if !cameraPages.isEmpty {
                    onPages(cameraPages)
                    cameraPages = []
                }
            }) {
                DocumentScanner { cameraPages = $0 }
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $choosingPhotos, selection: $photoItems, maxSelectionCount: nil,
                          selectionBehavior: .ordered, matching: .images)
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                photoItems = []
                Task {
                    var scans: [PageScan] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
                           let scan = PageScan(image) {
                            scans.append(scan)
                        }
                    }
                    if !scans.isEmpty { onPages(scans) }
                }
            }
    }
}

extension View {
    func pageSources(scanning: Binding<Bool>, choosingPhotos: Binding<Bool>, onPages: @escaping ([PageScan]) -> Void) -> some View {
        modifier(PageSources(scanning: scanning, choosingPhotos: choosingPhotos, onPages: onPages))
    }
}

// MARK: - A scanned book

/// A scanned book: read along, make and play its audiobook, fix its words, share or delete it.
struct ScannedBookView: View {
    let bookID: UUID
    let onDeleted: () -> Void

    @State private var reading = false
    @State private var editing = false
    @State private var making: Task<Void, Never>?
    @State private var progress = 0.0
    @State private var makeFailed = false
    @State private var player: AVAudioPlayer?
    @State private var playing = false
    @State private var sharing = false
    @State private var confirmDelete = false
    @State private var scanning = false
    @State private var choosingPhotos = false
    @State private var addedPages: ScannedPages?
    @State private var reordering = false
    private let store = ScannedBookStore.shared
    private let scannerAvailable = VNDocumentCameraViewController.isSupported

    private var book: ScannedBook? { store.books.first { $0.id == bookID } }

    var body: some View {
        if let book {
            content(book)
        } else {
            ContentUnavailableView("This book was deleted", systemImage: "book.closed")
        }
    }

    private func content(_ book: ScannedBook) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if let first = book.pages.first {
                    AsyncImage(url: store.imageURL(first, in: book)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                Text("\(book.pages.count) \(book.pages.count == 1 ? "page" : "pages")")
                    .foregroundStyle(.secondary)

                Button { reading = true } label: {
                    Label("Read along", systemImage: "book.fill")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: 480, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                audiobookSection(book)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if scannerAvailable {
                        Button { scanning = true } label: { Label("Scan more pages", systemImage: "doc.viewfinder") }
                    }
                    Button { choosingPhotos = true } label: { Label("Add pages from Photos", systemImage: "photo.on.rectangle.angled") }
                    if book.pages.count > 1 {
                        Button { reordering = true } label: { Label("Change page order", systemImage: "arrow.up.arrow.down") }
                    }
                    Button { editing = true } label: { Label("Fix the words", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete book", systemImage: "trash") }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .fullScreenCover(isPresented: $reading) {
            BookReader(title: book.title, color: .orange, pages: book.pages.map {
                ReaderPage(text: $0.text, imageURL: store.imageURL($0, in: book))
            }, language: book.bookLanguage)
        }
        .pageSources(scanning: $scanning, choosingPhotos: $choosingPhotos) { addedPages = ScannedPages(pages: $0) }
        .sheet(item: $addedPages) { pages in
            ScanReviewView(pages: pages.pages, addingTo: book) { _ in }
        }
        .sheet(isPresented: $editing) { EditBookView(book: book) }
        .sheet(isPresented: $reordering) {
            PageOrderView(items: book.pages.map { PageOrderView.Item(id: $0.image, imageURL: store.imageURL($0, in: book), text: $0.text) }) { order in
                var reordered = book
                reordered.pages.sort { (order.firstIndex(of: $0.image) ?? 0) < (order.firstIndex(of: $1.image) ?? 0) }
                stopAudio()
                try? store.update(reordered)
            }
        }
        .sheet(isPresented: $sharing) {
            ShareAudiobookView(url: store.audioURL(for: book), title: book.title)
        }
        .confirmationDialog("Delete \(book.title)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                stopAudio()
                store.delete(book)
                onDeleted()
            }
        } message: {
            Text("Its pages and audiobook will be removed from this device.")
        }
        .alert("Couldn't make the audiobook", isPresented: $makeFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("There were no words to read aloud. Check them with Fix the words in the ⋯ menu, then try again.")
        }
        .onDisappear {
            making?.cancel()
            stopAudio()
        }
    }

    @ViewBuilder
    private func audiobookSection(_ book: ScannedBook) -> some View {
        VStack(spacing: 12) {
            Label("Audiobook", systemImage: "headphones")
                .font(.title3.weight(.heavy))
            if making != nil {
                ProgressView(value: progress)
                Text("Making the audiobook… \(Int(progress * 100))%")
                    .foregroundStyle(.secondary)
                Button("Cancel", role: .cancel) { making?.cancel() }
            } else if book.hasAudio {
                HStack(spacing: 12) {
                    Button { playing ? stopAudio() : play(book) } label: {
                        Label(playing ? "Stop" : "Listen", systemImage: playing ? "stop.fill" : "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    Button { sharing = true } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.headline)
            } else {
                Text("Turn this book into an audio file in the natural voice, to listen to anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button { make(book) } label: {
                    Label("Make audiobook", systemImage: "waveform")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .font(.headline)
                .disabled(book.pages.allSatisfy { $0.text.isEmpty })
            }
        }
        .padding(20)
        .frame(maxWidth: 480)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private func make(_ book: ScannedBook) {
        progress = 0
        making = Task {
            do {
                try await AudiobookMaker.make(pages: book.pages.map(\.text), language: book.bookLanguage,
                                              to: store.audioURL(for: book)) { progress = $0 }
                var done = book
                done.hasAudio = true
                try store.update(done)
            } catch is CancellationError {
            } catch {
                makeFailed = true
            }
            making = nil
        }
    }

    private func play(_ book: ScannedBook) {
        Speech.shared.stop()
        AssistantAudioSession.activateForSpeaking()
        guard let player = try? AVAudioPlayer(contentsOf: store.audioURL(for: book)) else { return }
        self.player = player
        player.play()
        playing = true
        // AVAudioPlayer's delegate needs an object; poll the end instead.
        Task {
            while playing, player.isPlaying { try? await Task.sleep(for: .milliseconds(300)) }
            if self.player === player { playing = false }
        }
    }

    private func stopAudio() {
        player?.stop()
        playing = false
    }
}

/// Drag pages into the right order, for photos picked or scanned out of order.
struct PageOrderView: View {
    struct Item: Identifiable {
        let id: String
        var thumbnail: UIImage?
        var imageURL: URL?
        var text: String
    }

    @State var items: [Item]
    /// The number of the first page shown, when these pages go after a book's existing pages.
    var firstNumber = 1
    let onDone: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            thumbnail(item)
                                .frame(width: 60, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Page \(firstNumber + index)").font(.headline)
                                Text(item.text.isEmpty ? "Picture page" : item.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Drag the handles to move a page.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Page order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(items.map(\.id))
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(_ item: Item) -> some View {
        if let image = item.thumbnail {
            Image(uiImage: image).resizable().scaledToFit()
        } else if let url = item.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.secondary.opacity(0.1)
            }
        } else {
            Color.secondary.opacity(0.1)
        }
    }
}

/// Fix the words the camera read wrong.
private struct EditBookView: View {
    @State var book: ScannedBook
    @Environment(\.dismiss) private var dismiss
    private let store = ScannedBookStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Book name") {
                    TextField("Book name", text: $book.title)
                }
                ForEach(book.pages.indices, id: \.self) { index in
                    Section("Page \(index + 1)") {
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImage(url: store.imageURL(book.pages[index], in: book)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Color.secondary.opacity(0.1)
                            }
                            .frame(width: 90, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            TextEditor(text: $book.pages[index].text)
                                .frame(minHeight: 120)
                        }
                    }
                }
            }
            .navigationTitle("Fix the words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if book.title.trimmingCharacters(in: .whitespaces).isEmpty { book.title = "My Book" }
                        try? store.update(book)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Sharing sends the file out of the app, so a grown-up says yes first.
private struct ShareAudiobookView: View {
    let url: URL
    let title: String
    @State private var gatePassed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if gatePassed {
                    VStack(spacing: 20) {
                        Image(systemName: "headphones.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.orange)
                        Text(title).font(.title2.weight(.bold))
                        ShareLink(item: url, preview: SharePreview(title)) {
                            Label("Share audiobook", systemImage: "square.and.arrow.up")
                                .font(.title3.weight(.bold))
                                .frame(maxWidth: 320, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        Text("Only share books you're allowed to copy.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ParentalGate(reason: "Sharing sends the audiobook out of the app.") { gatePassed = true }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
