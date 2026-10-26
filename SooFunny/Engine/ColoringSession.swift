import Observation
import UIKit

/// One picture being colored: holds its blocks, the chosen colors and the undo history.
@Observable
final class ColoringSession: Identifiable {
    let id = UUID()
    let source: UIImage

    var detail: SegmentDetail = .medium
    var selectedColor: RGBA = Palette.crayons[0]
    var peek = false

    private(set) var segmentation: Segmentation?
    private(set) var fills: [RGBA] = []
    private(set) var canvas: UIImage?
    private(set) var isProcessing = false

    @ObservationIgnored private var undoStack: [[RGBA]] = []
    @ObservationIgnored private var strokeSaved = false
    @ObservationIgnored private let haptics = UIImpactFeedbackGenerator(style: .light)
    private(set) var canUndo = false

    init(image: UIImage) {
        source = image
    }

    /// Splits the picture into blocks (off the main thread) and starts with a blank page.
    @MainActor
    func prepare() async {
        isProcessing = true
        let image = source
        let detail = detail
        let result = await Task.detached(priority: .userInitiated) {
            ImageSegmenter().segment(image, detail: detail)
        }.value
        guard detail == self.detail else { return } // a newer request is running
        segmentation = result
        fills = Array(repeating: .white, count: result?.regionCount ?? 0)
        undoStack.removeAll()
        canUndo = false
        render()
        isProcessing = false
    }

    // MARK: - Painting

    /// Fills the block under a pixel with the selected color.
    /// A whole finger stroke counts as one undo step.
    func paint(atX x: Int, y: Int, startingStroke: Bool) {
        if startingStroke { strokeSaved = false }
        guard let segmentation, let region = segmentation.region(atX: x, y: y),
              fills[region] != selectedColor else { return }
        if !strokeSaved {
            saveUndo()
            strokeSaved = true
        }
        fills[region] = selectedColor
        render()
        haptics.impactOccurred()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        fills = previous
        canUndo = !undoStack.isEmpty
        render()
    }

    /// Fills every block with a random crayon.
    func surprise() {
        replaceFills { _ in Palette.crayons.randomElement()! }
    }

    /// Colors each block with its average color from the original picture.
    func realColors() {
        guard let segmentation else { return }
        replaceFills { segmentation.meanColors[$0] }
    }

    func clear() {
        replaceFills { _ in .white }
    }

    // MARK: - Private

    private func replaceFills(_ color: (Int) -> RGBA) {
        guard !fills.isEmpty else { return }
        saveUndo()
        fills = fills.indices.map(color)
        render()
    }

    private func saveUndo() {
        undoStack.append(fills)
        if undoStack.count > 80 { undoStack.removeFirst() }
        canUndo = true
    }

    private func render() {
        guard let segmentation, let cgImage = ColoringRenderer.render(segmentation, fills: fills) else {
            canvas = nil
            return
        }
        canvas = UIImage(cgImage: cgImage)
    }
}

enum Palette {
    static let crayons: [RGBA] = [
        0xF94144, 0xF3722C, 0xF8961E, 0xF9C74F, 0xFFE66D, 0x90BE6D,
        0x43AA8B, 0x2EC4B6, 0x4CC9F0, 0x277DA1, 0x5E60CE, 0x9B5DE5,
        0xF15BB5, 0xFFAFCC, 0xA0522D, 0xFFD6A5, 0x8D99AE, 0x2B2D42,
    ].map(RGBA.init(hex:))
}
