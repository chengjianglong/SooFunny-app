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

    func testPhotoWithTwoColorsGivesTwoBlocks() {
        let red = RGBA(r: 230, g: 40, b: 40), blue = RGBA(r: 40, g: 60, b: 220)
        let picture = image(width: 120, height: 80) { x, _ in x < 60 ? red : blue }
        let result = ImageSegmenter().segment(picture, detail: .medium)
        XCTAssertFalse(result.isLineArt)
        XCTAssertEqual(result.regionCount, 2)
        XCTAssertNotEqual(result.region(atX: 10, y: 40), result.region(atX: 110, y: 40))
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
        XCTAssertEqual(result.labels[21 * 100 + 21], -1, "line pixels are outline")
        XCTAssertNotEqual(result.region(atX: 5, y: 5), result.region(atX: 50, y: 50))
    }

    func testTappingALineFindsTheNearestBlock() {
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

    func testRendererPaintsBlocksWithTheirFill() throws {
        let picture = image(width: 40, height: 20) { x, _ in x < 20 ? RGBA(r: 240, g: 200, b: 0) : RGBA(r: 0, g: 120, b: 60) }
        let result = ImageSegmenter().segment(picture, detail: .medium)
        let left = try XCTUnwrap(result.region(atX: 5, y: 10))
        var fills = Array(repeating: RGBA.white, count: result.regionCount)
        fills[left] = RGBA(r: 1, g: 2, b: 3)
        let cg = try XCTUnwrap(ColoringRenderer.render(result, fills: fills))
        let pixels = try XCTUnwrap(PixelImage(image: UIImage(cgImage: cg), maxDimension: 100))
        XCTAssertEqual(pixels[10 * 40 + 5], RGBA(r: 1, g: 2, b: 3))
        XCTAssertEqual(pixels[10 * 40 + 35], .white)
    }

    func testSampleDrawingsSplitIntoManyBlocks() throws {
        for sample in SampleArt.all {
            let result = try XCTUnwrap(ImageSegmenter().segment(sample.image, detail: .medium))
            XCTAssertTrue(result.isLineArt, sample.name)
            XCTAssertGreaterThan(result.regionCount, 8, sample.name)
        }
    }
}
