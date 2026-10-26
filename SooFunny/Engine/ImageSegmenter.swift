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

    /// Number of color clusters for the subject (the background gets about half).
    var clusters: Int {
        switch self {
        case .big: return 5
        case .medium: return 8
        case .small: return 12
        }
    }

    /// Neighboring blocks whose colors differ by less than this (CIE ΔE) become one block.
    var mergeDeltaE: Float {
        switch self {
        case .big: return 18
        case .medium: return 13
        case .small: return 9
        }
    }

    /// Blocks smaller than this fraction of the picture are merged into a neighbor.
    var minAreaFraction: Double {
        switch self {
        case .big: return 0.008
        case .medium: return 0.0035
        case .small: return 0.0012
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

/// The result of splitting a picture into colorable blocks: a coloring page.
struct Segmentation {
    let width: Int
    let height: Int
    /// Block index for every pixel, including pixels under the outlines.
    let labels: [Int32]
    /// How much of each pixel is covered by black outline, 0...255 (anti-aliased).
    let ink: [UInt8]
    let regionCount: Int
    /// Average original color of each block.
    let meanColors: [RGBA]
    /// True when the picture was a black-and-white drawing (coloring page).
    let isLineArt: Bool

    /// The block under a pixel.
    func region(atX x: Int, y: Int) -> Int? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let label = labels[y * width + x]
        return label >= 0 ? Int(label) : nil
    }
}

/// Turns any picture into a coloring page, entirely on device.
///
/// Black-and-white drawings are split along their own lines. Photos go through a
/// sketch pipeline: edge-preserving smoothing, subject/background separation, color
/// grouping in a perceptual color space, merging of look-alike neighbors, contour
/// smoothing at a higher resolution, and even anti-aliased outlines.
struct ImageSegmenter {
    /// Drawings keep their own lines at a high resolution.
    var lineArtMaxDimension = 2048
    /// Photos are analyzed at this size (blocks are big, so this is plenty)...
    var photoMaxDimension = 512
    /// ...and the finished coloring page is drawn at about this size.
    var outputDimension = 1024

    func segment(_ image: UIImage, detail: SegmentDetail) -> Segmentation? {
        guard let pixels = PixelImage(image: image, maxDimension: lineArtMaxDimension) else { return nil }
        if Self.looksLikeLineArt(pixels) {
            return segment(pixels, detail: detail)
        }
        let photo = max(pixels.width, pixels.height) <= photoMaxDimension
            ? pixels
            : PixelImage(image: image, maxDimension: photoMaxDimension)
        guard let photo else { return nil }
        return segment(photo, detail: detail, subject: SubjectMask.compute(for: photo))
    }

    func segment(_ image: PixelImage, detail: SegmentDetail, subject: [Bool]? = nil) -> Segmentation {
        Self.looksLikeLineArt(image) ? lineArt(image) : sketch(image, detail: detail, subject: subject)
    }

    // MARK: - Drawings

    private func lineArt(_ image: PixelImage) -> Segmentation {
        let n = image.pixelCount
        // Dark pixels are lines; every enclosed light area becomes a block.
        var classes = [Int32](repeating: 0, count: n)
        var ink = [UInt8](repeating: 0, count: n)
        for i in 0..<n {
            let lum = image[i].luminance
            if lum < 0.55 { classes[i] = -1 }
            // Keep the drawing's own anti-aliasing so lines stay smooth.
            ink[i] = UInt8(max(0, min(1, (0.85 - lum) / 0.45)) * 255)
        }
        var (labels, count) = Self.connectedComponents(classes: classes, width: image.width, height: image.height)
        // Specks inside thick lines are not worth coloring.
        let minArea = max(6, n / 5000)
        var sizes = [Int](repeating: 0, count: count)
        for l in labels where l >= 0 { sizes[Int(l)] += 1 }
        for i in labels.indices where labels[i] >= 0 && sizes[Int(labels[i])] < minArea {
            labels[i] = -1
        }
        count = Self.compact(&labels)
        // Pixels under the lines belong to the nearest block, so fills reach right up to the ink.
        Self.growIntoUnlabeled(&labels, width: image.width, height: image.height)
        return Segmentation(width: image.width, height: image.height, labels: labels, ink: ink, regionCount: count,
                            meanColors: Self.meanColors(image, labels: labels, count: count, scale: 1),
                            isLineArt: true)
    }

    // MARK: - Photos

    private func sketch(_ image: PixelImage, detail: SegmentDetail, subject: [Bool]?) -> Segmentation {
        let w = image.width, h = image.height, n = image.pixelCount

        // 1. Flatten texture and shading while keeping edges.
        let radius = max(2, max(w, h) / 110)
        let lab = LabImage(image).kuwahara(radius: radius).kuwahara(radius: radius).kuwahara(radius: radius / 2 + 1)

        // 2–3. Group colors separately for the subject and the background, so the subject
        // gets the detail and the background stays a few big shapes.
        let backgroundClusters = max(3, detail.clusters / 2)
        var classes = [Int32](repeating: 0, count: n)
        if let subject {
            Self.kMeans(lab, pixels: (0..<n).filter { subject[$0] }, k: detail.clusters, offset: 0, into: &classes)
            Self.kMeans(lab, pixels: (0..<n).filter { !subject[$0] }, k: backgroundClusters,
                        offset: Int32(detail.clusters), into: &classes)
        } else {
            Self.kMeans(lab, pixels: Array(0..<n), k: detail.clusters, offset: 0, into: &classes)
        }
        let classCount = detail.clusters + (subject == nil ? 0 : backgroundClusters)
        for _ in 0..<2 {
            classes = Self.majorityFiltered(classes, width: w, height: h, classCount: classCount)
        }

        // 4. Connected areas, then merge look-alike neighbors and tiny pieces.
        var (labels, count) = Self.connectedComponents(classes: classes, width: w, height: h)
        count = Self.mergeSimilarRegions(&labels, count: count, width: w, height: h, lab: lab, subject: subject,
                                         threshold: detail.mergeDeltaE)
        let minArea = max(4, Int(Double(n) * detail.minAreaFraction))
        // A small subject still gets its parts: its minimum block size follows its own area.
        let subjectPixels = subject?.reduce(0) { $1 ? $0 + 1 : $0 } ?? 0
        let subjectMinArea = max(4, min(minArea, Int(Double(subjectPixels) * detail.minAreaFraction * 6)))
        count = Self.mergeSmallRegions(&labels, count: count, width: w, height: h, minArea: minArea,
                                       maxRegions: detail.maxRegions, subject: subject, subjectMinArea: subjectMinArea)

        // 5. Round off squiggly borders and thin fingers (each pass works like a little
        // curvature flow), then redraw the shapes at a higher resolution with smooth contours.
        for _ in 0..<6 {
            labels = Self.modeFiltered(labels, width: w, height: h)
        }
        let scale = max(1, outputDimension / max(w, h))
        let outW = w * scale, outH = h * scale
        var smooth = Self.upscaled(labels, width: w, height: h, factor: scale)
        for _ in 0..<2 {
            smooth = Self.smoothedContours(smooth, width: outW, height: outH, radius: 2 * scale + 1)
        }
        // Smoothing can pinch off crumbs of a block; fold them back into a neighbor.
        (smooth, count) = Self.connectedComponents(classes: smooth, width: outW, height: outH)
        count = Self.mergeSmallRegions(&smooth, count: count, width: outW, height: outH,
                                       minArea: max(4, minArea * scale * scale / 2), maxRegions: detail.maxRegions)

        // 6. Even, anti-aliased outlines along every border.
        let ink = Self.outlineInk(smooth, width: outW, height: outH,
                                  halfWidth: max(1, Float(max(outW, outH)) / 680))
        return Segmentation(width: outW, height: outH, labels: smooth, ink: ink, regionCount: count,
                            meanColors: Self.meanColors(image, labels: smooth, count: count, scale: scale),
                            isLineArt: false)
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

    /// Clusters the Lab colors of `pixels` and writes `offset + cluster` into `classes`.
    static func kMeans(_ lab: LabImage, pixels: [Int], k requested: Int, offset: Int32,
                       into classes: inout [Int32], iterations: Int = 12, seed: UInt64 = 0x50_0F_A1) {
        guard !pixels.isEmpty else { return }
        let k = min(requested, pixels.count)
        func color(_ i: Int) -> SIMD3<Float> { SIMD3(lab.l[i], lab.a[i], lab.b[i]) }
        let stride = max(1, pixels.count / 20_000)
        let samples = Swift.stride(from: 0, to: pixels.count, by: stride).map { color(pixels[$0]) }

        // k-means++ seeding with a fixed seed so results are repeatable.
        var rng = SplitMix64(seed: seed)
        var centers: [SIMD3<Float>] = [samples[Int(rng.next() % UInt64(samples.count))]]
        var nearest = samples.map { distanceSquared($0, centers[0]) }
        while centers.count < k {
            let total = nearest.reduce(0, +)
            var pick = Int(rng.next() % UInt64(samples.count))
            if total > 0 {
                var target = Float(Double(rng.next() % 1_000_000) / 1_000_000) * total
                for (i, d) in nearest.enumerated() {
                    target -= d
                    if target <= 0 { pick = i; break }
                }
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
        for i in pixels {
            classes[i] = offset + Int32(closest(color(i), in: centers))
        }
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

    /// Like `majorityFiltered`, for any number of labels: each pixel takes the label that
    /// appears most often among itself and its eight neighbors. Rounds off staircases.
    static func modeFiltered(_ labels: [Int32], width: Int, height: Int) -> [Int32] {
        var out = labels
        labels.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                for y in 1..<max(1, height - 1) {
                    for x in 1..<max(1, width - 1) {
                        let i = y * width + x
                        let offsets = (-width - 1, -width, -width + 1, -1, 1, width - 1, width, width + 1)
                        let center = src[i]
                        var best = center
                        var bestCount = 0
                        withUnsafeBytes(of: offsets) { raw in
                            let o = raw.bindMemory(to: Int.self)
                            var centerCount = 1
                            for k in 0..<8 where src[i + o[k]] == center { centerCount += 1 }
                            bestCount = centerCount
                            if centerCount >= 5 { return }
                            for k in 0..<8 {
                                let candidate = src[i + o[k]]
                                guard candidate != center, candidate != best else { continue }
                                var count = 0
                                for m in 0..<8 where src[i + o[m]] == candidate { count += 1 }
                                if count > bestCount {
                                    bestCount = count
                                    best = candidate
                                }
                            }
                        }
                        dst[i] = best
                    }
                }
            }
        }
        return out
    }

    /// Contour smoothing for the finished page: each pixel near a border takes the label
    /// with the most Gaussian-weighted votes in a window around it, turning jagged borders
    /// into round curves like a drawn line. Pixels deep inside a block are left alone.
    static func smoothedContours(_ labels: [Int32], width: Int, height: Int, radius: Int) -> [Int32] {
        let step = max(1, radius / 3)
        var offsets: [(dx: Int, dy: Int, weight: Float)] = []
        let sigma = Float(radius) / 2
        // Samples symmetric around the pixel, so straight borders don't drift.
        let reach = radius / step * step
        for dy in stride(from: -reach, through: reach, by: step) {
            for dx in stride(from: -reach, through: reach, by: step) where dx * dx + dy * dy <= radius * radius {
                offsets.append((dx, dy, expf(-Float(dx * dx + dy * dy) / (2 * sigma * sigma))))
            }
        }
        var out = labels
        var candidates = [Int32](repeating: 0, count: offsets.count)
        var votes = [Float](repeating: 0, count: offsets.count)
        labels.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                for y in 0..<height {
                    for x in 0..<width {
                        let i = y * width + x
                        let center = src[i]
                        // Only pixels within reach of a border can change.
                        let r = radius
                        if src[max(0, y - r) * width + x] == center, src[min(height - 1, y + r) * width + x] == center,
                           src[y * width + max(0, x - r)] == center, src[y * width + min(width - 1, x + r)] == center,
                           src[i] == src[max(0, y - r / 2) * width + max(0, x - r / 2)],
                           src[i] == src[min(height - 1, y + r / 2) * width + min(width - 1, x + r / 2)] {
                            continue
                        }
                        var used = 0
                        for o in offsets {
                            let nx = min(width - 1, max(0, x + o.dx)), ny = min(height - 1, max(0, y + o.dy))
                            let label = src[ny * width + nx]
                            var k = 0
                            while k < used && candidates[k] != label { k += 1 }
                            if k == used {
                                candidates[k] = label
                                votes[k] = 0
                                used += 1
                            }
                            votes[k] += o.weight
                        }
                        var best = 0
                        for k in 1..<max(1, used) where votes[k] > votes[best] { best = k }
                        dst[i] = candidates[best]
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

    /// Joins neighboring blocks whose average colors look alike (ΔE below `threshold`),
    /// so gradients such as a sky become one block. Never joins subject and background.
    static func mergeSimilarRegions(_ labels: inout [Int32], count: Int, width: Int, height: Int,
                                    lab: LabImage, subject: [Bool]?, threshold: Float) -> Int {
        guard count > 1 else { return count }
        var sums = [SIMD3<Float>](repeating: .zero, count: count)
        var sizes = [Int](repeating: 0, count: count)
        var subjectVotes = [Int](repeating: 0, count: count)
        var pairs = Set<Int>()
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                let l = Int(labels[i])
                sums[l] += SIMD3(lab.l[i], lab.a[i], lab.b[i])
                sizes[l] += 1
                if subject?[i] == true { subjectVotes[l] += 1 }
                if x + 1 < width, labels[i + 1] != labels[i] { pairs.insert(min(l, Int(labels[i + 1])) * count + max(l, Int(labels[i + 1]))) }
                if y + 1 < height, labels[i + width] != labels[i] { pairs.insert(min(l, Int(labels[i + width])) * count + max(l, Int(labels[i + width]))) }
            }
        }
        let means = (0..<count).map { sums[$0] / Float(max(1, sizes[$0])) }
        let isSubject = (0..<count).map { subjectVotes[$0] * 2 > sizes[$0] }

        var parent = Array(0..<count)
        func find(_ v: Int) -> Int {
            var v = v
            while parent[v] != v {
                parent[v] = parent[parent[v]]
                v = parent[v]
            }
            return v
        }
        let candidates = pairs.compactMap { key -> (Int, Int, Float)? in
            let p = key / count, q = key % count
            guard subject == nil || isSubject[p] == isSubject[q] else { return nil }
            // The background tolerates bigger differences so it stays simple.
            let limit = subject != nil && !isSubject[p] ? threshold * 1.3 : threshold
            let d = (means[p] - means[q]) * (means[p] - means[q])
            let distance = d.sum().squareRoot()
            return distance < limit ? (p, q, distance) : nil
        }
        // Merge the closest pairs first. Tiny steps (a smooth gradient such as a sky) always
        // join; bigger steps are checked against the merged blocks' running averages, so a
        // chain of them can't join two clearly different areas (like sky and waterfall).
        var groupSums = (0..<count).map { sums[$0] }
        var groupSizes = sizes
        for (p, q, step) in candidates.sorted(by: { $0.2 < $1.2 }) {
            let rp = find(p), rq = find(q)
            guard rp != rq else { continue }
            let mp = groupSums[rp] / Float(max(1, groupSizes[rp])), mq = groupSums[rq] / Float(max(1, groupSizes[rq]))
            let limit = subject != nil && !isSubject[p] ? threshold * 1.3 : threshold
            guard step < limit / 2 || ((mp - mq) * (mp - mq)).sum().squareRoot() < limit else { continue }
            parent[rp] = rq
            groupSums[rq] += groupSums[rp]
            groupSizes[rq] += groupSizes[rp]
        }
        for i in labels.indices { labels[i] = Int32(find(Int(labels[i]))) }
        return compact(&labels)
    }

    /// Repeatedly merges blocks smaller than `minArea` into the neighbor they share the
    /// longest border with, growing `minArea` until there are at most `maxRegions` blocks.
    /// Blocks that are mostly `subject` use `subjectMinArea` instead.
    static func mergeSmallRegions(_ labels: inout [Int32], count initialCount: Int, width: Int, height: Int,
                                  minArea initialMinArea: Int, maxRegions: Int,
                                  subject: [Bool]? = nil, subjectMinArea: Int = 0) -> Int {
        var count = initialCount
        var minArea = initialMinArea
        var subjectMin = subjectMinArea
        for _ in 0..<60 where count > 1 {
            var sizes = [Int](repeating: 0, count: count)
            var perimeters = [Int](repeating: 0, count: count)
            var subjectVotes = [Int](repeating: 0, count: count)
            if let subject {
                for i in labels.indices where labels[i] >= 0 && subject[i] { subjectVotes[Int(labels[i])] += 1 }
            }
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
            let small = (0..<count).map { r -> Bool in
                let limit = subject != nil && subjectVotes[r] * 2 > sizes[r] ? subjectMin : minArea
                return sizes[r] < limit || sizes[r] * 2 < perimeters[r] * 3
            }
            guard small.contains(true) else {
                if count <= maxRegions { break }
                minArea = minArea * 3 / 2 + 1
                subjectMin = subjectMin * 3 / 2 + 1
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

    /// Gives every -1 pixel the label of its nearest labeled pixel (breadth-first).
    static func growIntoUnlabeled(_ labels: inout [Int32], width: Int, height: Int) {
        var frontier = labels.indices.filter { labels[$0] >= 0 }
        guard !frontier.isEmpty else { return }
        while !frontier.isEmpty {
            var next: [Int] = []
            for i in frontier {
                let x = i % width, y = i / width
                for j in [x > 0 ? i - 1 : -1, x + 1 < width ? i + 1 : -1, y > 0 ? i - width : -1, y + 1 < height ? i + width : -1]
                where j >= 0 && labels[j] < 0 {
                    labels[j] = labels[i]
                    next.append(j)
                }
            }
            frontier = next
        }
    }

    static func upscaled(_ labels: [Int32], width: Int, height: Int, factor: Int) -> [Int32] {
        guard factor > 1 else { return labels }
        let outW = width * factor
        var out = [Int32](repeating: 0, count: outW * height * factor)
        for y in 0..<height * factor {
            for x in 0..<outW {
                out[y * outW + x] = labels[(y / factor) * width + x / factor]
            }
        }
        return out
    }

    /// Outline coverage for every pixel: a line of `2 * halfWidth` pixels centered on each
    /// border between blocks, with soft edges, from a chamfer distance transform.
    static func outlineInk(_ labels: [Int32], width: Int, height: Int, halfWidth: Float) -> [UInt8] {
        let n = width * height
        var distance = [Float](repeating: .greatestFiniteMagnitude, count: n)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                let l = labels[i]
                // Pixel centers next to a border are half a pixel away from it.
                if (x + 1 < width && labels[i + 1] != l) || (x > 0 && labels[i - 1] != l)
                    || (y + 1 < height && labels[i + width] != l) || (y > 0 && labels[i - width] != l) {
                    distance[i] = 0.5
                }
            }
        }
        let diagonal: Float = 1.4142
        distance.withUnsafeMutableBufferPointer { d in
            for y in 0..<height {
                for x in 0..<width {
                    let i = y * width + x
                    var v = d[i]
                    if x > 0 { v = min(v, d[i - 1] + 1) }
                    if y > 0 {
                        v = min(v, d[i - width] + 1)
                        if x > 0 { v = min(v, d[i - width - 1] + diagonal) }
                        if x + 1 < width { v = min(v, d[i - width + 1] + diagonal) }
                    }
                    d[i] = v
                }
            }
            for y in stride(from: height - 1, through: 0, by: -1) {
                for x in stride(from: width - 1, through: 0, by: -1) {
                    let i = y * width + x
                    var v = d[i]
                    if x + 1 < width { v = min(v, d[i + 1] + 1) }
                    if y + 1 < height {
                        v = min(v, d[i + width] + 1)
                        if x + 1 < width { v = min(v, d[i + width + 1] + diagonal) }
                        if x > 0 { v = min(v, d[i + width - 1] + diagonal) }
                    }
                    d[i] = v
                }
            }
        }
        return distance.map { UInt8(max(0, min(1, halfWidth + 0.5 - $0)) * 255) }
    }

    /// Average original color of each block. `scale` is how many label pixels span one image pixel.
    static func meanColors(_ image: PixelImage, labels: [Int32], count: Int, scale: Int) -> [RGBA] {
        var sums = [SIMD3<Int>](repeating: .zero, count: count)
        var counts = [Int](repeating: 0, count: count)
        let labelWidth = image.width * scale
        for i in labels.indices where labels[i] >= 0 {
            let c = image[(i / labelWidth / scale) * image.width + (i % labelWidth) / scale]
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

/// Paints a coloring page: each block's fill, with the outlines blended on top.
enum ColoringRenderer {
    static func render(_ segmentation: Segmentation, fills: [RGBA], outlineColor: RGBA = .ink) -> CGImage? {
        let n = segmentation.width * segmentation.height
        var data = [UInt8](repeating: 255, count: n * 4)
        let ir = Int(outlineColor.r), ig = Int(outlineColor.g), ib = Int(outlineColor.b)
        segmentation.labels.withUnsafeBufferPointer { labels in
        segmentation.ink.withUnsafeBufferPointer { ink in
        data.withUnsafeMutableBufferPointer { out in
            for i in 0..<n {
                let label = labels[i]
                let c = label >= 0 ? fills[Int(label)] : .white
                let a = Int(ink[i]), keep = 255 - a
                out[i * 4] = UInt8((Int(c.r) * keep + ir * a) / 255)
                out[i * 4 + 1] = UInt8((Int(c.g) * keep + ig * a) / 255)
                out[i * 4 + 2] = UInt8((Int(c.b) * keep + ib * a) / 255)
            }
        }}}
        return PixelImage(width: segmentation.width, height: segmentation.height, data: data).makeCGImage()
    }
}
