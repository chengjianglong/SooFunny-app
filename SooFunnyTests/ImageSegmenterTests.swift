import UIKit
import XCTest
@testable import SooFunny

final class ImageSegmenterTests: XCTestCase {
    private func image(width: Int, height: Int, _ color: (Int, Int) -> RGBA) -> PixelImage {
        var data = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let c = color(x, y), o = (y * width + x) * 4
                data[o] = c.r; data[o + 1] = c.g; data[o + 2] = c.b
            }
        }
        return PixelImage(width: width, height: height, data: data)
    }

    /// Block at a point given as fractions of the coloring page's size.
    private func region(_ s: Segmentation, _ fx: Double, _ fy: Double) -> Int? {
        s.region(atX: Int(fx * Double(s.width)), y: Int(fy * Double(s.height)))
    }

    private func ink(_ s: Segmentation, _ fx: Double, _ fy: Double) -> UInt8 {
        s.ink[Int(fy * Double(s.height)) * s.width + Int(fx * Double(s.width))]
    }

    func testPhotoWithTwoColorsGivesTwoBlocks() {
        let red = RGBA(r: 230, g: 40, b: 40), blue = RGBA(r: 40, g: 60, b: 220)
        let picture = image(width: 120, height: 80) { x, _ in x < 60 ? red : blue }
        let result = ImageSegmenter().segment(picture, detail: .medium)
        XCTAssertFalse(result.isLineArt)
        XCTAssertEqual(result.regionCount, 2)
        XCTAssertNotEqual(region(result, 0.1, 0.5), region(result, 0.9, 0.5))
    }

    func testPhotoIsDrawnAtHigherResolutionWithEvenOutlines() {
        let picture = image(width: 128, height: 128) { x, _ in x < 64 ? RGBA(r: 250, g: 200, b: 0) : RGBA(r: 0, g: 120, b: 60) }
        let result = ImageSegmenter().segment(picture, detail: .medium)
        XCTAssertEqual(result.width, 1024)
        // A solid line runs down the border, and nothing is drawn away from it.
        for fy in stride(from: 0.1, through: 0.9, by: 0.1) {
            XCTAssertEqual(ink(result, 0.5, fy), 255, "border at \(fy)")
            XCTAssertEqual(ink(result, 0.25, fy), 0)
            XCTAssertEqual(ink(result, 0.75, fy), 0)
        }
        let row = Int(0.5 * Double(result.height)) * result.width
        let lineWidth = (0..<result.width).filter { result.ink[row + $0] > 127 }.count
        XCTAssertTrue((2...4).contains(lineWidth), "line is \(lineWidth)px wide")
    }

    func testSmoothGradientBecomesOneBlock() {
        // A sky that fades from light to deeper blue should be one block, not stripes.
        let picture = image(width: 160, height: 120) { _, y in
            RGBA(r: UInt8(150 - y / 3), g: UInt8(200 - y / 3), b: 250)
        }
        let result = ImageSegmenter().segment(picture, detail: .medium)
        XCTAssertEqual(result.regionCount, 1)
    }

    func testSubjectGetsItsOwnBlocksAndBackgroundStaysSimple() {
        let w = 160, h = 160
        // A two-tone ball on a busy, speckled background.
        var rng = SplitMix64(seed: 3)
        let picture = image(width: w, height: h) { x, y in
            let dx = x - 80, dy = y - 80
            if dx * dx + dy * dy < 40 * 40 { return y < 80 ? RGBA(r: 240, g: 60, b: 50) : RGBA(r: 250, g: 220, b: 40) }
            let jitter = UInt8(rng.next() % 40)
            return RGBA(r: 60 + jitter, g: 150 + jitter, b: 70)
        }
        let subject = (0..<(w * h)).map { i -> Bool in
            let dx = i % w - 80, dy = i / w - 80
            return dx * dx + dy * dy < 40 * 40
        }
        let result = ImageSegmenter().segment(picture, detail: .medium, subject: subject)
        let top = region(result, 0.5, 0.35), bottom = region(result, 0.5, 0.65), background = region(result, 0.05, 0.05)
        XCTAssertNotEqual(top, bottom)
        XCTAssertNotEqual(top, background)
        XCTAssertNotEqual(bottom, background)
        XCTAssertLessThanOrEqual(result.regionCount, 5, "background noise should not become many blocks")
    }

    func testLineArtSquareGivesInsideAndOutside() {
        let picture = image(width: 100, height: 100) { x, y in
            let onEdge = (20...80).contains(x) && (20...80).contains(y)
                && ((20...23).contains(x) || (77...80).contains(x) || (20...23).contains(y) || (77...80).contains(y))
            return onEdge ? RGBA(r: 0, g: 0, b: 0) : .white
        }
        let result = ImageSegmenter().segment(picture, detail: .medium)
        XCTAssertTrue(result.isLineArt)
        XCTAssertEqual(result.regionCount, 2)
        XCTAssertEqual(result.ink[21 * 100 + 21], 255, "line pixels are drawn as ink")
        XCTAssertEqual(result.ink[50 * 100 + 50], 0)
        XCTAssertNotEqual(result.region(atX: 5, y: 5), result.region(atX: 50, y: 50))
    }

    func testTappingALineFindsABlock() {
        let picture = image(width: 60, height: 60) { x, _ in (28...31).contains(x) ? RGBA(r: 0, g: 0, b: 0) : .white }
        let result = ImageSegmenter().segment(picture, detail: .medium)
        XCTAssertEqual(result.regionCount, 2)
        XCTAssertNotNil(result.region(atX: 29, y: 30))
    }

    func testBlockCountIsCappedForNoisyPictures() {
        var rng = SplitMix64(seed: 7)
        let picture = image(width: 160, height: 160) { _, _ in
            RGBA(r: UInt8(rng.next() % 256), g: UInt8(rng.next() % 256), b: UInt8(rng.next() % 256))
        }
        let result = ImageSegmenter().segment(picture, detail: .big)
        XCTAssertGreaterThan(result.regionCount, 0)
        XCTAssertLessThanOrEqual(result.regionCount, SegmentDetail.big.maxRegions)
    }

    func testRendererPaintsBlocksAndOutlines() throws {
        let picture = image(width: 40, height: 20) { x, _ in x < 20 ? RGBA(r: 240, g: 200, b: 0) : RGBA(r: 0, g: 120, b: 60) }
        let result = ImageSegmenter().segment(picture, detail: .medium)
        let left = try XCTUnwrap(region(result, 0.1, 0.5))
        var fills = Array(repeating: RGBA.white, count: result.regionCount)
        fills[left] = RGBA(r: 1, g: 2, b: 3)
        let cg = try XCTUnwrap(ColoringRenderer.render(result, fills: fills))
        let pixels = try XCTUnwrap(PixelImage(image: UIImage(cgImage: cg), maxDimension: 4096))
        func at(_ fx: Double) -> RGBA { pixels[Int(0.5 * Double(pixels.height)) * pixels.width + Int(fx * Double(pixels.width))] }
        XCTAssertEqual(at(0.1), RGBA(r: 1, g: 2, b: 3))
        XCTAssertEqual(at(0.9), .white)
        XCTAssertEqual(at(0.5), .ink)
    }

    func testSampleDrawingsSplitIntoManyBlocks() throws {
        for sample in SampleArt.all {
            let result = try XCTUnwrap(ImageSegmenter().segment(sample.image, detail: .medium))
            XCTAssertTrue(result.isLineArt, sample.name)
            XCTAssertGreaterThan(result.regionCount, 8, sample.name)
        }
    }
}
