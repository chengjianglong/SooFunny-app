import Foundation

/// An image in CIE L*a*b* (D65), where distances match how different colors look to people.
struct LabImage {
    let width: Int
    let height: Int
    var l: [Float]
    var a: [Float]
    var b: [Float]

    var pixelCount: Int { width * height }

    init(_ image: PixelImage) {
        width = image.width
        height = image.height
        let n = image.pixelCount
        var l = [Float](repeating: 0, count: n)
        var a = [Float](repeating: 0, count: n)
        var b = [Float](repeating: 0, count: n)
        image.data.withUnsafeBufferPointer { px in
            for i in 0..<n {
                let lab = Self.lab(r: px[i * 4], g: px[i * 4 + 1], b: px[i * 4 + 2])
                l[i] = lab.l
                a[i] = lab.a
                b[i] = lab.b
            }
        }
        self.l = l
        self.a = a
        self.b = b
    }

    private static let linear: [Float] = (0..<256).map { v in
        let c = Float(v) / 255
        return c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4)
    }

    static func lab(r: UInt8, g: UInt8, b: UInt8) -> (l: Float, a: Float, b: Float) {
        let rl = linear[Int(r)], gl = linear[Int(g)], bl = linear[Int(b)]
        let x = (0.4124 * rl + 0.3576 * gl + 0.1805 * bl) / 0.95047
        let y = 0.2126 * rl + 0.7152 * gl + 0.0722 * bl
        let z = (0.0193 * rl + 0.1192 * gl + 0.9505 * bl) / 1.08883
        func f(_ t: Float) -> Float { t > 0.008856 ? cbrtf(t) : 7.787 * t + 16 / 116 }
        let fx = f(x), fy = f(y), fz = f(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    /// Kuwahara filter: every pixel takes the average color of whichever of its four
    /// neighboring windows is flattest. Texture and shading become flat areas while real
    /// edges stay sharp, which is what makes a photo look like a drawing.
    func kuwahara(radius r: Int) -> LabImage {
        let w = width, h = height, stride = w + 1
        var sumL = [Double](repeating: 0, count: stride * (h + 1))
        var sumL2 = sumL, sumA = sumL, sumB = sumL
        // Summed-area tables so every window average costs four lookups.
        for y in 0..<h {
            var rowL = 0.0, rowL2 = 0.0, rowA = 0.0, rowB = 0.0
            for x in 0..<w {
                let i = y * w + x
                let lv = Double(l[i])
                rowL += lv
                rowL2 += lv * lv
                rowA += Double(a[i])
                rowB += Double(b[i])
                let o = (y + 1) * stride + x + 1
                sumL[o] = sumL[o - stride] + rowL
                sumL2[o] = sumL2[o - stride] + rowL2
                sumA[o] = sumA[o - stride] + rowA
                sumB[o] = sumB[o - stride] + rowB
            }
        }

        var out = self
        sumL.withUnsafeBufferPointer { sL in
        sumL2.withUnsafeBufferPointer { sL2 in
        sumA.withUnsafeBufferPointer { sA in
        sumB.withUnsafeBufferPointer { sB in
            func box(_ s: UnsafeBufferPointer<Double>, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> Double {
                s[y1 * stride + x1] - s[y0 * stride + x1] - s[y1 * stride + x0] + s[y0 * stride + x0]
            }
            for y in 0..<h {
                for x in 0..<w {
                    var bestVariance = Double.infinity
                    var best = (l: 0.0, a: 0.0, b: 0.0)
                    for q in 0..<4 {
                        let qx = q & 1 == 0 ? x - r : x
                        let qy = q < 2 ? y - r : y
                        let x0 = max(0, qx), y0 = max(0, qy)
                        let x1 = min(w, qx + r + 1), y1 = min(h, qy + r + 1)
                        let count = Double((x1 - x0) * (y1 - y0))
                        let mean = box(sL, x0, y0, x1, y1) / count
                        let variance = box(sL2, x0, y0, x1, y1) / count - mean * mean
                        if variance < bestVariance {
                            bestVariance = variance
                            best = (mean, box(sA, x0, y0, x1, y1) / count, box(sB, x0, y0, x1, y1) / count)
                        }
                    }
                    let i = y * w + x
                    out.l[i] = Float(best.l)
                    out.a[i] = Float(best.a)
                    out.b[i] = Float(best.b)
                }
            }
        }}}}
        return out
    }
}
