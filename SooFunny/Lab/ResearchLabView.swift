import PhotosUI
import SwiftUI

/// Settings → Research Lab: on-device model and benchmarking tools for grown-ups.
/// Everything runs offline on this device; results stay on the device until exported.
struct ResearchLabView: View {
    @State private var store = LabStore()
    @State private var detail: SegmentDetail = .medium
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var status: String?
    @State private var running = false
    @State private var exportURLs: [URL] = []
    @State private var prompt = "Explain what a rainbow is to a five-year-old."
    @State private var answer = ""
    @State private var answerTiming = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("This device") {
                LabeledContent("Model", value: LabDevice.model)
                LabeledContent("System", value: LabDevice.system)
                LabeledContent("CPU cores", value: "\(LabDevice.cores)")
                LabeledContent("Memory", value: String(format: "%.1f GB", LabDevice.memoryGB))
                LabeledContent("Thermal state", value: LabDevice.thermal)
                LabeledContent("Apple on-device model", value: LabLanguageModel.status)
            }

            Section {
                Picker("Block size", selection: $detail) {
                    ForEach(SegmentDetail.allCases) { Text($0.title).tag($0) }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photo == nil ? "Add a photo to test (optional)" : "Change test photo", systemImage: "photo")
                }
                if let photo {
                    HStack {
                        Image(uiImage: photo).resizable().scaledToFill().frame(width: 44, height: 44).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("Test photo added")
                        Spacer()
                        Button("Remove", role: .destructive) { self.photo = nil }
                    }
                }
                Button {
                    runColoringBenchmark()
                } label: {
                    Label("Run coloring-page benchmark", systemImage: "paintbrush.pointed")
                }
                .disabled(running)
                Button {
                    runSubjectBenchmark()
                } label: {
                    Label("Run subject-model benchmark", systemImage: "person.crop.rectangle")
                }
                .disabled(running)
            } header: {
                Text("Image models")
            } footer: {
                Text("Times SooFunny's coloring-page pipeline on the built-in drawings, two generated scenes and your photo: one warm-up, then three measured runs each. The subject benchmark times Apple's on-device subject model (Vision), which simulators can't run.")
            }

            Section {
                TextField("Prompt", text: $prompt, axis: .vertical)
                    .lineLimit(2...5)
                Button {
                    runPrompt()
                } label: {
                    Label("Ask the on-device model", systemImage: "sparkles")
                }
                .disabled(running || !LabLanguageModel.isAvailable || prompt.trimmingCharacters(in: .whitespaces).isEmpty)
                if !answer.isEmpty {
                    Text(answer).textSelection(.enabled)
                    if !answerTiming.isEmpty {
                        Text(answerTiming).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Button {
                    runLanguageBenchmark()
                } label: {
                    Label("Run language-model benchmark", systemImage: "gauge.with.dots.needle.67percent")
                }
                .disabled(running || !LabLanguageModel.isAvailable)
            } header: {
                Text("Language model playground")
            } footer: {
                Text("Uses Apple's built-in on-device model (Apple Intelligence, iOS 26+). It runs offline; nothing is downloaded or sent to a server. The benchmark warms up once, then times three fixed prompts: time to first output, total time and output speed.")
            }

            if let status {
                Section {
                    HStack(spacing: 12) {
                        if running { ProgressView() }
                        Text(status)
                    }
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                if store.results.isEmpty {
                    Text("No results yet. Run a benchmark above.").foregroundStyle(.secondary)
                } else {
                    ForEach(store.results) { ResultRow(result: $0) }
                }
            } header: {
                HStack {
                    Text("Results (\(store.results.count))")
                    Spacer()
                    if !exportURLs.isEmpty {
                        ShareLink(items: exportURLs) { Label("Export", systemImage: "square.and.arrow.up") }
                            .font(.footnote)
                    }
                }
            } footer: {
                Text("Results are saved on this device. Export shares a JSON and a CSV file.")
            }
            if !store.results.isEmpty {
                Section {
                    Button("Clear results", role: .destructive) {
                        store.clear()
                        refreshExport()
                    }
                    .disabled(running)
                }
            }
        }
        .navigationTitle("Research Lab")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshExport)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photo = image
                } else {
                    errorMessage = "Couldn't open that photo."
                }
                photoItem = nil
            }
        }
        // Keep the screen on during long runs so measurements aren't interrupted.
        .onChange(of: running) { _, isRunning in UIApplication.shared.isIdleTimerDisabled = isRunning }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Actions

    private func inputs() -> [(name: String, image: UIImage)] {
        LabInputs.all + (photo.map { [("Your photo", $0)] } ?? [])
    }

    private func runColoringBenchmark() {
        let inputs = inputs()
        let detail = detail
        start("Coloring pages: starting…")
        Task {
            var results: [LabResult] = []
            for (i, input) in inputs.enumerated() {
                status = "Coloring pages: \(input.name) (\(i + 1) of \(inputs.count))…"
                let result = await Task.detached(priority: .userInitiated) {
                    LabBenchmarks.coloringPage(name: input.name, image: input.image, detail: detail)
                }.value
                results.append(result)
            }
            finish(results, summary: "Coloring pages: \(results.count) pictures measured.")
        }
    }

    private func runSubjectBenchmark() {
        let inputs: [(name: String, image: UIImage)] = (photo.map { [("Your photo", $0)] } ?? [])
            + [("Scene: garden", LabInputs.scene(seed: 2))]
        start("Subject model: running…")
        Task {
            var results: [LabResult] = []
            for input in inputs {
                if let result = await Task.detached(priority: .userInitiated, operation: {
                    LabBenchmarks.subjectMask(name: input.name, image: input.image)
                }).value {
                    results.append(result)
                }
            }
            finish(results, summary: "Subject model: \(results.count) pictures measured.")
        }
    }

    private func runPrompt() {
        answer = ""
        answerTiming = ""
        start("Asking the on-device model…")
        Task {
            do {
                let run = try await LabLanguageModel.generate(prompt) { text in
                    Task { @MainActor in answer = text }
                }
                answer = run.text
                answerTiming = String(format: "First output %.0f ms · total %.1f s", run.firstOutputMs, run.totalMs / 1000)
                    + (run.tokens.map { " · \($0) tokens" } ?? "")
                finish([], summary: "Done.")
            } catch {
                fail(error)
            }
        }
    }

    private func runLanguageBenchmark() {
        start("Language model: starting…")
        Task {
            do {
                let results = try await LabLanguageModel.benchmark { message in
                    Task { @MainActor in status = "Language model: \(message)" }
                }
                finish(results, summary: "Language model: \(results.count) prompts measured.")
            } catch {
                fail(error)
            }
        }
    }

    private func start(_ message: String) {
        running = true
        errorMessage = nil
        status = message
    }

    private func finish(_ results: [LabResult], summary: String) {
        store.add(results)
        refreshExport()
        running = false
        status = summary
    }

    private func fail(_ error: Error) {
        running = false
        status = nil
        errorMessage = error.localizedDescription
    }

    private func refreshExport() {
        exportURLs = store.results.isEmpty ? [] : ((try? store.exportFiles()) ?? [])
    }
}

private struct ResultRow: View {
    let result: LabResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                Spacer()
                Text(String(format: "%.0f ms", result.medianMs))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var caption: String {
        var parts = ["\(kindTitle) · \(result.settings)"]
        if result.runsMs.count > 1 {
            parts.append(String(format: "median of %d (%.0f–%.0f ms)", result.runsMs.count, result.minMs, result.maxMs))
        }
        parts += result.details.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
        parts.append(result.date.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " · ")
    }

    private var kindTitle: String {
        switch result.kind {
        case "coloring-page": return "Coloring page"
        case "subject-mask": return "Subject model"
        case "language-model": return "Language model"
        default: return result.kind
        }
    }
}
