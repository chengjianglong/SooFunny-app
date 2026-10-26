// Generates the 1024x1024 app icon: a grid of crayon-colored blocks with a smile.
// Usage: swift scripts/make_icon.swift SooFunny/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cg = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!,
                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let colors: [UInt32] = [0xF94144, 0xF8961E, 0xF9C74F, 0x90BE6D, 0x43AA8B, 0x4CC9F0, 0x5E60CE, 0x9B5DE5, 0xF15BB5]
cg.setFillColor(color(0xFFFFFF))
cg.fill(CGRect(x: 0, y: 0, width: size, height: size))
let cell = CGFloat(size) / 3
for row in 0..<3 {
    for col in 0..<3 {
        cg.setFillColor(color(colors[(row * 3 + col * 2) % colors.count]))
        cg.fill(CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
    }
}
cg.setStrokeColor(color(0x222228))
cg.setLineWidth(28)
for i in 1..<3 {
    let p = CGFloat(i) * cell
    cg.strokeLineSegments(between: [CGPoint(x: p, y: 0), CGPoint(x: p, y: CGFloat(size)),
                                    CGPoint(x: 0, y: p), CGPoint(x: CGFloat(size), y: p)])
}
cg.setFillColor(color(0xFFFFFF))
let face = CGRect(x: 232, y: 232, width: 560, height: 560)
cg.fillEllipse(in: face)
cg.strokeEllipse(in: face)
cg.setFillColor(color(0x222228))
cg.fillEllipse(in: CGRect(x: 390, y: 560, width: 70, height: 90))
cg.fillEllipse(in: CGRect(x: 564, y: 560, width: 70, height: 90))
cg.setLineCap(.round)
cg.addArc(center: CGPoint(x: 512, y: 470), radius: 150, startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false)
cg.strokePath()
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, cg.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
