import UIKit

/// How finely a photo is split into blocks.
enum SegmentDetail: String, CaseIterable, Identifiable {
    case big, medium, small

    var id: Self { self }

    var title: String {
        switch self {
        case .big: return "Big"
        case .medium: return "Medium"
        case .small: return "Small"
        }
    }

    /// Number of color clusters used to quantize a photo.
    var clusters: Int {
        switch self {
        case .big: return 5
        case .medium: return 8
        case .small: return 12
        }
    }

    /// Blocks smaller than this fraction of the picture are merged into a neighbor.
    var minAreaFraction: Double {
        switch self {
        case .big: return 0.006
        case .medium: return 0.002
        case .small: return 0.0007
        }
    }

    var maxRegions: Int {
        switch self {
        case .big: return 30
        case .medium: return 90
        case .small: return 220
        }
    }
}

/// The result of splitting a picture into colorable blocks.
struct Segmentation {
    let width: Int
    let height: Int
    /// Block index for every pixel, or -1 for outline ("ink") pixels.
    let labels: [Int32]
    let regionCount: Int
    /// Average original color of each block.
    let meanColors: [RGBA]
    /// True when the picture was a black-and-white drawing (coloring page).
    let isLineArt: Bool
    /// Pixels drawn as outline: ink pixels plus the borders between blocks.
    let outline: [Bool]

    init(width: Int, height: Int, labels: [Int32], regionCount: Int, meanColors: [RGBA], isLineArt: Bool) {
        self.width = width
        self.height = height
        self.labels = labels
        self.regionCount = regionCount
        self.meanColors = meanColors
        self.isLineArt = isLineArt

        var outline = [Bool](repeating: false, count: labels.count)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                let label = labels[i]
                // Marking both sides of a border gives a 2px line that stays visible on screen.
                outline[i] = label < 0
                    || (x + 1 < width && labels[i + 1] != label)
                    || (x > 0 && labels[i - 1] != label)
                    || (y + 1 < height && labels[i + width] != label)
                    || (y > 0 && labels[i - width] != label)
            }
        }
        self.outline = outline
    }

    /// The block under a pixel. When the pixel is on an outline, the closest block
    /// within `searchRadius` is returned so little fingers don't miss.
    func region(atX x: Int, y: Int, searchRadius: Int = 10) -> Int? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let label = labels[y * width + x]
        if label >= 0 { return Int(label) }
        for r in 1...max(1, searchRadius) {
            var best: (distance: Int, label: Int32)?
            for dy in -r...r {
                for dx in -r...r where max(abs(dx), abs(dy)) == r {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                    let candidate = labels[ny * width + nx]
                    guard candidate >= 0 else { continue }
                    let d = dx * dx + dy * dy
                    if best == nil || d < best!.distance { best = (d, candidate) }
                }
            }
            if let best { return Int(best.label) }
        }
        return nil
    }
}

/// Splits an image into blocks entirely on device.
///
/// Black-and-white drawings are split along their lines (every enclosed area is a
/// block). Photos are color-quantized with k-means, split into connected areas,
/// and tiny areas are merged into their neighbors until the block count is kid-sized.
struct ImageSegmenter {
    /// Drawings keep their thin lines at a higher resolution; photos only need coarse blocks.
    var lineArtMaxDimension = 2048
    var photoMaxDimension = 512

    func segment(_ image: UIImage, detail: SegmentDetail) -> Segmentation? {
        guard let pixels = PixelImage(image: image, maxDimension: lineArtMaxDimension) else { return nil }
        if Self.looksLikeLineArt(pixels) || max(pixels.width, pixels.height) <= photoMaxDimension {
            return segment(pixels, detail: detail)
        }
        guard let small = PixelImage(image: image, maxDimension: photoMaxDimension) else { return nil }
        return segment(small, detail: detail)
    }

    func segment(_ image: PixelImage, detail: SegmentDetail) -> Segmentation {
        let lineArt = Self.looksLikeLineArt(image)
        var labels: [Int32]
        var count: Int

        if lineArt {
            // Dark pixels are lines; every enclosed light area becomes a block.
            var classes = [Int32](repeating: 0, count: image.pixelCount)
            for i in 0..<image.pixelCount where image[i].luminance < 0.55 {
                classes[i] = -1
            }
            (labels, count) = Self.connectedComponents(classes: classes, width: image.width, height: image.height)
            // Specks inside thick lines are not worth coloring.
            let minArea = max(6, image.pixelCount / 5000)
            var sizes = [Int](repeating: 0, count: count)
            for l in labels where l >= 0 { sizes[Int(l)] += 1 }
            for i in labels.indices where labels[i] >= 0 && sizes[Int(labels[i])] < minArea {
                labels[i] = -1
            }
            count = Self.compact(&labels)
        } else {
            let smooth = image.boxBlurred(radius: 2)
            var classes = Self.kMeans(smooth, k: detail.clusters)
            for _ in 0..<2 {
                classes = Self.majorityFiltered(classes, width: image.width, height: image.height, classCount: detail.clusters)
            }
            (labels, count) = Self.connectedComponents(classes: classes, width: image.width, height: image.height)
            let minArea = max(4, Int(Double(image.pixelCount) * detail.minAreaFraction))
            count = Self.mergeSmallRegions(&labels, count: count, width: image.width, height: image.height,
                                           minArea: minArea, maxRegions: detail.maxRegions)
        }

        return Segmentation(width: image.width, height: image.height, labels: labels, regionCount: count,
                            meanColors: Self.meanColors(image, labels: labels, count: count), isLineArt: lineArt)
    }

    // MARK: - Steps

    /// Mostly-gray pixels and mostly-white background means a coloring page.
    static func looksLikeLineArt(_ image: PixelImage) -> Bool {
        var gray = 0, light = 0
        for i in 0..<image.pixelCount {
            let c = image[i]
            let hi = max(c.r, c.g, c.b), lo = min(c.r, c.g, c.b)
            if hi - lo <= 40 { gray += 1 }
            if c.luminance > 0.78 { light += 1 }
        }
        let n = Double(image.pixelCount)
        return Double(gray) >= 0.95 * n && Double(light) >= 0.5 * n
    }

    /// Clusters pixel colors and returns the cluster index of every pixel.
    static func kMeans(_ image: PixelImage, k: Int, iterations: Int = 12, seed: UInt64 = 0x50_0F_A1) -> [Int32] {
        let n = image.pixelCount
        let stride = max(1, n / 20_000)
        var samples: [SIMD3<Float>] = []
        samples.reserveCapacity(n / stride + 1)
        for i in Swift.stride(from: 0, to: n, by: stride) {
            let c = image[i]
            samples.append(SIMD3(Float(c.r), Float(c.g), Float(c.b)))
        }

        // k-means++ seeding with a fixed seed so results are repeatable.
        var rng = SplitMix64(seed: seed)
        var centers: [SIMD3<Float>] = [samples[Int(rng.next() % UInt64(samples.count))]]
        var nearest = samples.map { distanceSquared($0, centers[0]) }
        while centers.count < k {
            let total = nearest.reduce(0, +)
            var pick = 0
            if total > 0 {
                var target = Float(Double(rng.next() % 1_000_000) / 1_000_000) * total
                for (i, d) in nearest.enumerated() {
                    target -= d
                    if target <= 0 { pick = i; break }
                }
            } else {
                pick = Int(rng.next() % UInt64(samples.count))
            }
            centers.append(samples[pick])
            for i in samples.indices {
                nearest[i] = min(nearest[i], distanceSquared(samples[i], samples[pick]))
            }
        }

        for _ in 0..<iterations {
            var sums = [SIMD3<Float>](repeating: .zero, count: k)
            var counts = [Int](repeating: 0, count: k)
            for s in samples {
                let c = closest(s, in: centers)
                sums[c] += s
                counts[c] += 1
            }
            for c in 0..<k where counts[c] > 0 {
                centers[c] = sums[c] / Float(counts[c])
            }
        }

        var classes = [Int32](repeating: 0, count: n)
        for i in 0..<n {
            let c = image[i]
            classes[i] = Int32(closest(SIMD3(Float(c.r), Float(c.g), Float(c.b)), in: centers))
        }
        return classes
    }

    /// Replaces each pixel's class with the most common class in its 3x3 neighborhood,
    /// removing speckles and smoothing block edges.
    static func majorityFiltered(_ classes: [Int32], width: Int, height: Int, classCount: Int) -> [Int32] {
        var out = classes
        var counts = [Int](repeating: 0, count: classCount)
        classes.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                for y in 0..<height {
                    for x in 0..<width {
                        for i in counts.indices { counts[i] = 0 }
                        for dy in -1...1 {
                            let ny = min(height - 1, max(0, y + dy))
                            for dx in -1...1 {
                                let nx = min(width - 1, max(0, x + dx))
                                counts[Int(src[ny * width + nx])] += 1
                            }
                        }
                        let current = Int(src[y * width + x])
                        var best = current
                        for c in counts.indices where counts[c] > counts[best] { best = c }
                        dst[y * width + x] = Int32(best)
                    }
                }
            }
        }
        return out
    }

    /// Groups 4-connected pixels that share a class. Pixels with class -1 get label -1.
    static func connectedComponents(classes: [Int32], width: Int, height: Int) -> (labels: [Int32], count: Int) {
        var labels = [Int32](repeating: -1, count: classes.count)
        var next: Int32 = 0
        var stack: [Int] = []
        for start in classes.indices where classes[start] >= 0 && labels[start] < 0 {
            let cls = classes[start]
            labels[start] = next
            stack.append(start)
            while let i = stack.popLast() {
                let x = i % width, y = i / width
                if x > 0, labels[i - 1] < 0, classes[i - 1] == cls { labels[i - 1] = next; stack.append(i - 1) }
                if x + 1 < width, labels[i + 1] < 0, classes[i + 1] == cls { labels[i + 1] = next; stack.append(i + 1) }
                if y > 0, labels[i - width] < 0, classes[i - width] == cls { labels[i - width] = next; stack.append(i - width) }
                if y + 1 < height, labels[i + width] < 0, classes[i + width] == cls { labels[i + width] = next; stack.append(i + width) }
            }
            next += 1
        }
        return (labels, Int(next))
    }

    /// Repeatedly merges blocks smaller than `minArea` into the neighbor they share the
    /// longest border with, growing `minArea` until there are at most `maxRegions` blocks.
    static func mergeSmallRegions(_ labels: inout [Int32], count initialCount: Int, width: Int, height: Int,
                                  minArea initialMinArea: Int, maxRegions: Int) -> Int {
        var count = initialCount
        var minArea = initialMinArea
        for _ in 0..<60 where count > 1 {
            var sizes = [Int](repeating: 0, count: count)
            var perimeters = [Int](repeating: 0, count: count)
            for y in 0..<height {
                for x in 0..<width {
                    let i = y * width + x
                    let l = labels[i]
                    guard l >= 0 else { continue }
                    sizes[Int(l)] += 1
                    if x + 1 < width, labels[i + 1] != l {
                        perimeters[Int(l)] += 1
                        if labels[i + 1] >= 0 { perimeters[Int(labels[i + 1])] += 1 }
                    }
                    if y + 1 < height, labels[i + width] != l {
                        perimeters[Int(l)] += 1
                        if labels[i + width] >= 0 { perimeters[Int(labels[i + width])] += 1 }
                    }
                }
            }
            // Too small, or a sliver (under ~2px wide) left by soft edges between colors.
            let small = (0..<count).map { sizes[$0] < minArea || sizes[$0] * 2 < perimeters[$0] * 3 }
            guard small.contains(true) else {
                if count <= maxRegions { break }
                minArea = minArea * 3 / 2 + 1
                continue
            }

            var borders: [Int: [Int: Int]] = [:]
            func note(_ a: Int32, _ b: Int32) {
                guard a >= 0, b >= 0, a != b else { return }
                if small[Int(a)] { borders[Int(a), default: [:]][Int(b), default: 0] += 1 }
                if small[Int(b)] { borders[Int(b), default: [:]][Int(a), default: 0] += 1 }
            }
            for y in 0..<height {
                for x in 0..<width {
                    let i = y * width + x
                    if x + 1 < width { note(labels[i], labels[i + 1]) }
                    if y + 1 < height { note(labels[i], labels[i + width]) }
                }
            }

            var parent = Array(0..<count)
            func find(_ v: Int) -> Int {
                var v = v
                while parent[v] != v {
                    parent[v] = parent[parent[v]]
                    v = parent[v]
                }
                return v
            }
            var merged = false
            for a in (0..<count).filter({ small[$0] }).sorted(by: { sizes[$0] < sizes[$1] }) {
                guard let target = borders[a]?.max(by: { ($0.value, -$0.key) < ($1.value, -$1.key) })?.key else { continue }
                let ra = find(a), rt = find(target)
                if ra != rt {
                    parent[ra] = rt
                    merged = true
                }
            }
            guard merged else { break }
            for i in labels.indices where labels[i] >= 0 {
                labels[i] = Int32(find(Int(labels[i])))
            }
            count = compact(&labels)
        }
        return count
    }

    /// Renumbers labels to 0..<count, keeping -1 as is. Returns the count.
    @discardableResult
    static func compact(_ labels: inout [Int32]) -> Int {
        guard let maxLabel = labels.max(), maxLabel >= 0 else { return 0 }
        var map = [Int32](repeating: -1, count: Int(maxLabel) + 1)
        var next: Int32 = 0
        for i in labels.indices {
            let l = labels[i]
            guard l >= 0 else { continue }
            if map[Int(l)] < 0 {
                map[Int(l)] = next
                next += 1
            }
            labels[i] = map[Int(l)]
        }
        return Int(next)
    }

    static func meanColors(_ image: PixelImage, labels: [Int32], count: Int) -> [RGBA] {
        var sums = [SIMD3<Int>](repeating: .zero, count: count)
        var counts = [Int](repeating: 0, count: count)
        for i in labels.indices where labels[i] >= 0 {
            let c = image[i]
            sums[Int(labels[i])] &+= SIMD3(Int(c.r), Int(c.g), Int(c.b))
            counts[Int(labels[i])] += 1
        }
        return (0..<count).map { r in
            let n = max(1, counts[r])
            return RGBA(r: UInt8(sums[r].x / n), g: UInt8(sums[r].y / n), b: UInt8(sums[r].z / n))
        }
    }

    private static func distanceSquared(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let d = a - b
        return (d * d).sum()
    }

    private static func closest(_ p: SIMD3<Float>, in centers: [SIMD3<Float>]) -> Int {
        var best = 0
        var bestDistance = Float.greatestFiniteMagnitude
        for (i, c) in centers.enumerated() {
            let d = distanceSquared(p, c)
            if d < bestDistance {
                bestDistance = d
                best = i
            }
        }
        return best
    }
}

/// Small deterministic random number generator.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Paints a segmentation with the chosen block colors.
enum ColoringRenderer {
    static func render(_ segmentation: Segmentation, fills: [RGBA], outlineColor: RGBA = .ink) -> CGImage? {
        let n = segmentation.width * segmentation.height
        var data = [UInt8](repeating: 255, count: n * 4)
        data.withUnsafeMutableBufferPointer { out in
            for i in 0..<n {
                let label = segmentation.labels[i]
                let c = segmentation.outline[i] || label < 0 ? outlineColor : fills[Int(label)]
                out[i * 4] = c.r
                out[i * 4 + 1] = c.g
                out[i * 4 + 2] = c.b
            }
        }
        return PixelImage(width: segmentation.width, height: segmentation.height, data: data).makeCGImage()
    }
}
