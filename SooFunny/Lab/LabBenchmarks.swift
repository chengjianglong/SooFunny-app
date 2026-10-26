import Foundation
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// One saved benchmark measurement.
struct LabResult: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    /// "coloring-page", "subject-mask" or "language-model".
    var kind: String
    /// What was measured, e.g. the picture name or prompt.
    var name: String
    /// Settings used, e.g. block size.
    var settings: String
    /// Measured durations in milliseconds (warm-up runs excluded).
    var runsMs: [Double]
    /// Anything else worth keeping, e.g. block count or characters per second.
    var details: [String: String] = [:]
    var device: String = LabDevice.summary

    var medianMs: Double { LabStats.median(runsMs) }
    var minMs: Double { runsMs.min() ?? 0 }
    var maxMs: Double { runsMs.max() ?? 0 }
}

enum LabStats {
    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    /// Runs `work` `warmUp` times unmeasured, then `runs` times measured, in milliseconds.
    static func measure(warmUp: Int = 1, runs: Int = 3, _ work: () throws -> Void) rethrows -> [Double] {
        for _ in 0..<warmUp { try work() }
        return try (0..<runs).map { _ in
            let start = DispatchTime.now().uptimeNanoseconds
            try work()
            return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        }
    }
}

enum LabDevice {
    static var model: String {
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        // Simulators report the Mac's architecture; show the simulated device instead.
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"].map { "\($0) (Simulator)" } ?? machine
    }

    static var system: String { "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)" }
    static var cores: Int { ProcessInfo.processInfo.activeProcessorCount }
    static var memoryGB: Double { Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824 }

    static var thermal: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    static var summary: String { "\(model), \(system), \(cores) cores, \(String(format: "%.1f", memoryGB)) GB" }
}

/// Pictures the coloring-page benchmark runs on: the built-in drawings plus two
/// generated photo-like scenes, so results are comparable across devices.
enum LabInputs {
    static var all: [(name: String, image: UIImage)] {
        SampleArt.all.map { ("Drawing: \($0.name)", $0.image) } + [
            ("Scene: hills", scene(seed: 1)),
            ("Scene: garden", scene(seed: 2)),
        ]
    }

    /// A 1024×768 photo-like scene: sky gradient, sun, layered hills, flowers and grain.
    static func scene(seed: UInt64) -> UIImage {
        var rng = SplitMix64(seed: seed)
        func random() -> CGFloat { CGFloat(rng.next() % 10_000) / 10_000 }
        let size = CGSize(width: 1024, height: 768)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [UIColor(red: 0.45, green: 0.7, blue: 0.95, alpha: 1).cgColor,
                                          UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1).cgColor] as CFArray,
                                 locations: [0, 1])!
            cg.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: size.height * 0.6), options: [.drawsAfterEndLocation])
            UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 120 + random() * 600, y: 60, width: 120, height: 120))
            for layer in 0..<3 {
                let base = size.height * (0.45 + CGFloat(layer) * 0.15)
                let green = 0.55 - CGFloat(layer) * 0.12
                UIColor(red: 0.25 + random() * 0.1, green: green, blue: 0.2, alpha: 1).setFill()
                cg.move(to: CGPoint(x: 0, y: size.height))
                for x in stride(from: 0, through: size.width, by: 16) {
                    cg.addLine(to: CGPoint(x: x, y: base + sin(x / (90 + CGFloat(layer) * 40) + random() * 0.2) * 40))
                }
                cg.addLine(to: CGPoint(x: size.width, y: size.height))
                cg.closePath()
                cg.fillPath()
            }
            for _ in 0..<18 {
                let hue = [UIColor.systemPink, .systemYellow, .systemPurple, .white][Int(rng.next() % 4)]
                hue.setFill()
                let r = 10 + random() * 16
                cg.fillEllipse(in: CGRect(x: random() * size.width, y: size.height * 0.75 + random() * size.height * 0.22,
                                          width: r, height: r))
            }
            // Fine grain, like camera noise.
            for _ in 0..<20_000 {
                UIColor(white: random(), alpha: 0.08).setFill()
                cg.fill(CGRect(x: random() * size.width, y: random() * size.height, width: 2, height: 2))
            }
        }
    }
}

enum LabBenchmarks {
    /// Times turning `image` into a coloring page.
    static func coloringPage(name: String, image: UIImage, detail: SegmentDetail) -> LabResult {
        var blocks = 0
        var pageSize = ""
        let runs = LabStats.measure {
            let segmentation = ImageSegmenter().segment(image, detail: detail)
            blocks = segmentation?.regionCount ?? 0
            pageSize = segmentation.map { "\($0.width)×\($0.height)" } ?? "failed"
        }
        return LabResult(kind: "coloring-page", name: name, settings: "\(detail.title) blocks", runsMs: runs,
                         details: ["blocks": "\(blocks)", "page": pageSize])
    }

    /// Times Apple's on-device subject model. Nil when this device can't run it.
    static func subjectMask(name: String, image: UIImage) -> LabResult? {
        guard let pixels = PixelImage(image: image, maxDimension: 512) else { return nil }
        var mask: [Bool]?
        let runs = LabStats.measure { mask = SubjectMask.compute(for: pixels) }
        guard let mask else {
            return LabResult(kind: "subject-mask", name: name, settings: "512px", runsMs: runs,
                             details: ["subject": "none found or model unavailable"])
        }
        let fraction = Double(mask.filter { $0 }.count) / Double(mask.count)
        return LabResult(kind: "subject-mask", name: name, settings: "512px", runsMs: runs,
                         details: ["subject": String(format: "%.0f%% of picture", fraction * 100)])
    }
}

/// Apple's on-device language model (Apple Intelligence), when the device has it.
enum LabLanguageModel {
    static let benchmarkPrompts = [
        "Explain what a rainbow is to a five-year-old in two sentences.",
        "Give three fun facts about elephants for kids.",
        "Write a short rhyme about a cat who loves to paint.",
    ]

    static var status: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return "Available"
            case .unavailable(.deviceNotEligible): return "This device doesn't support Apple Intelligence"
            case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings"
            case .unavailable(.modelNotReady): return "The model is still downloading or getting ready"
            case .unavailable: return "Unavailable"
            }
        }
        #endif
        return "Needs iOS 26 or later"
    }

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    struct Run {
        var text: String
        var firstOutputMs: Double
        var totalMs: Double
        var tokens: Int?
    }

    enum LabError: LocalizedError {
        case unavailable(String)
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .unavailable(let reason): return reason
            case .failed(let detail):
                return "Apple's on-device model couldn't answer. The Simulator often reports the model as ready but can't run it; try on a device with Apple Intelligence turned on. (\(detail))"
            }
        }
    }

    /// Streams one answer, calling `onText` with the text so far, and times it.
    static func generate(_ prompt: String, onText: @escaping (String) -> Void = { _ in }) async throws -> Run {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            let session = LanguageModelSession(instructions: "You are a friendly helper for young children. Use simple words.")
            let start = DispatchTime.now().uptimeNanoseconds
            func elapsed() -> Double { Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }
            var firstOutput: Double?
            var text = ""
            do {
                for try await snapshot in session.streamResponse(to: prompt) {
                    if firstOutput == nil, !snapshot.content.isEmpty { firstOutput = elapsed() }
                    text = snapshot.content
                    onText(text)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw LabError.failed(String(describing: error))
            }
            let total = elapsed()
            var tokens: Int?
            if #available(iOS 26.4, *) { tokens = try? await SystemLanguageModel.default.tokenCount(for: text) }
            return Run(text: text, firstOutputMs: firstOutput ?? total, totalMs: total, tokens: tokens)
        }
        #endif
        throw LabError.unavailable(status)
    }

    /// Runs each benchmark prompt once after a warm-up and records timings.
    static func benchmark(progress: @escaping (String) -> Void) async throws -> [LabResult] {
        progress("Warming up…")
        _ = try await generate("Say hello.")
        var results: [LabResult] = []
        for (i, prompt) in benchmarkPrompts.enumerated() {
            progress("Prompt \(i + 1) of \(benchmarkPrompts.count)…")
            let run = try await generate(prompt)
            var details = [
                "first output ms": String(format: "%.0f", run.firstOutputMs),
                "characters": "\(run.text.count)",
                "characters/s": String(format: "%.1f", Double(run.text.count) / max(0.001, run.totalMs / 1000)),
            ]
            if let tokens = run.tokens {
                details["tokens"] = "\(tokens)"
                details["tokens/s"] = String(format: "%.1f", Double(tokens) / max(0.001, run.totalMs / 1000))
            }
            results.append(LabResult(kind: "language-model", name: prompt, settings: "Apple on-device model",
                                     runsMs: [run.totalMs], details: details))
        }
        return results
    }
}

/// Keeps results on the device and writes export files.
@Observable
final class LabStore {
    private(set) var results: [LabResult] = []

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("research-lab-results.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? Self.decoder.decode([LabResult].self, from: data) {
            results = saved
        }
    }

    func add(_ new: [LabResult]) {
        results.insert(contentsOf: new, at: 0)
        save()
    }

    func clear() {
        results = []
        save()
    }

    private func save() {
        try? Self.encoder.encode(results).write(to: Self.fileURL, options: .atomic)
    }

    /// Writes all results as JSON and CSV into a temporary folder for sharing.
    func exportFiles() throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("research-lab-export", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json = dir.appendingPathComponent("soofunny-research-lab.json")
        try Self.encoder.encode(results).write(to: json)
        let csv = dir.appendingPathComponent("soofunny-research-lab.csv")
        try Self.csv(results).write(to: csv, atomically: true, encoding: .utf8)
        return [json, csv]
    }

    static func csv(_ results: [LabResult]) -> String {
        func field(_ s: String) -> String { "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        let dates = ISO8601DateFormatter()
        var lines = ["date,kind,name,settings,runs,median_ms,min_ms,max_ms,details,device"]
        for r in results {
            let details = r.details.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            lines.append([dates.string(from: r.date), r.kind, field(r.name), field(r.settings), "\(r.runsMs.count)",
                          String(format: "%.1f", r.medianMs), String(format: "%.1f", r.minMs), String(format: "%.1f", r.maxMs),
                          field(details), field(r.device)].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
