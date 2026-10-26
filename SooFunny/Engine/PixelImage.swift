import UIKit

/// An 8-bit RGBA color. Alpha is always opaque in this app.
struct RGBA: Hashable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8 = 255

    static let white = RGBA(r: 255, g: 255, b: 255)
    static let ink = RGBA(r: 34, g: 34, b: 40)

    /// Perceived brightness in 0...1.
    var luminance: Double {
        (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255
    }

    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(hex: UInt32) {
        self.init(r: UInt8((hex >> 16) & 0xFF), g: UInt8((hex >> 8) & 0xFF), b: UInt8(hex & 0xFF))
    }

    init(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func clamp(_ v: CGFloat) -> UInt8 { UInt8(max(0, min(255, (v * 255).rounded()))) }
        self.init(r: clamp(r), g: clamp(g), b: clamp(b))
    }

    var uiColor: UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}

/// A tightly packed RGBA bitmap (4 bytes per pixel, alpha ignored).
struct PixelImage {
    let width: Int
    let height: Int
    var data: [UInt8]

    var pixelCount: Int { width * height }

    init(width: Int, height: Int, data: [UInt8]) {
        precondition(data.count == width * height * 4, "pixel data does not match size")
        self.width = width
        self.height = height
        self.data = data
    }

    /// Downscales `image` so its longest side is at most `maxDimension` pixels,
    /// flattening transparency onto white and applying the image orientation.
    init?(image: UIImage, maxDimension: Int) {
        let pixelW = image.size.width * image.scale
        let pixelH = image.size.height * image.scale
        guard pixelW >= 1, pixelH >= 1 else { return nil }
        let factor = min(1, CGFloat(maxDimension) / max(pixelW, pixelH))
        let w = max(1, Int((pixelW * factor).rounded()))
        let h = max(1, Int((pixelH * factor).rounded()))
        let size = CGSize(width: w, height: h)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cgImage = normalized.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        var data = [UInt8](repeating: 255, count: w * h * 4)
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
            return true
        }
        guard drawn else { return nil }
        self.init(width: w, height: h, data: data)
    }

    subscript(index: Int) -> RGBA {
        let o = index * 4
        return RGBA(r: data[o], g: data[o + 1], b: data[o + 2])
    }

    func makeCGImage() -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: colorSpace,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Separable box blur over the color channels; smooths photo noise before clustering.
    func boxBlurred(radius: Int) -> PixelImage {
        guard radius > 0 else { return self }
        let w = width, h = height
        var temp = data
        var out = data
        let window = Double(2 * radius + 1)
        data.withUnsafeBufferPointer { src in
            temp.withUnsafeMutableBufferPointer { tmp in
                for y in 0..<h {
                    for x in 0..<w {
                        for c in 0..<3 {
                            var sum = 0
                            for dx in -radius...radius {
                                let sx = min(w - 1, max(0, x + dx))
                                sum += Int(src[(y * w + sx) * 4 + c])
                            }
                            tmp[(y * w + x) * 4 + c] = UInt8(Double(sum) / window)
                        }
                    }
                }
            }
        }
        temp.withUnsafeBufferPointer { tmp in
            out.withUnsafeMutableBufferPointer { dst in
                for y in 0..<h {
                    for x in 0..<w {
                        for c in 0..<3 {
                            var sum = 0
                            for dy in -radius...radius {
                                let sy = min(h - 1, max(0, y + dy))
                                sum += Int(tmp[(sy * w + x) * 4 + c])
                            }
                            dst[(y * w + x) * 4 + c] = UInt8(Double(sum) / window)
                        }
                    }
                }
            }
        }
        return PixelImage(width: w, height: h, data: out)
    }
}
