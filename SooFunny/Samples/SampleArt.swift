import UIKit

/// Built-in coloring pages, drawn in code so the app works with no photos and no network.
struct SampleArt: Identifiable {
    let id: String
    let name: String
    let image: UIImage

    static let all: [SampleArt] = [
        SampleArt(id: "house", name: "House", image: draw(house)),
        SampleArt(id: "fish", name: "Fish", image: draw(fish)),
        SampleArt(id: "flower", name: "Flower", image: draw(flower)),
        SampleArt(id: "rocket", name: "Rocket", image: draw(rocket)),
    ]

    private static let canvas = CGSize(width: 800, height: 800)

    private static func draw(_ body: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setFillColor(UIColor.black.cgColor)
            cg.setLineWidth(10)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            body(cg)
        }
    }

    private static func polygon(_ cg: CGContext, _ points: [CGPoint]) {
        cg.addLines(between: points)
        cg.closePath()
        cg.strokePath()
    }

    private static func circle(_ cg: CGContext, _ center: CGPoint, _ radius: CGFloat) {
        cg.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private static func line(_ cg: CGContext, _ a: CGPoint, _ b: CGPoint) {
        cg.strokeLineSegments(between: [a, b])
    }

    private static func house(_ cg: CGContext) {
        line(cg, CGPoint(x: 30, y: 700), CGPoint(x: 770, y: 700))
        cg.stroke(CGRect(x: 520, y: 200, width: 60, height: 120))
        cg.stroke(CGRect(x: 180, y: 390, width: 440, height: 310))
        polygon(cg, [CGPoint(x: 140, y: 400), CGPoint(x: 400, y: 170), CGPoint(x: 660, y: 400)])
        cg.stroke(CGRect(x: 350, y: 530, width: 100, height: 170))
        circle(cg, CGPoint(x: 432, y: 620), 8)
        for x in [220.0, 480.0] {
            cg.stroke(CGRect(x: x, y: 440, width: 100, height: 90))
            line(cg, CGPoint(x: x + 50, y: 440), CGPoint(x: x + 50, y: 530))
            line(cg, CGPoint(x: x, y: 485), CGPoint(x: x + 100, y: 485))
        }
        circle(cg, CGPoint(x: 120, y: 120), 60)
        for i in 0..<8 {
            let a = Double(i) * .pi / 4
            line(cg, CGPoint(x: 120 + cos(a) * 80, y: 120 + sin(a) * 80),
                 CGPoint(x: 120 + cos(a) * 110, y: 120 + sin(a) * 110))
        }
        for (x, r) in [(560.0, 40.0), (610.0, 55.0), (670.0, 40.0)] {
            circle(cg, CGPoint(x: x, y: 110), r)
        }
        for x in stride(from: 60.0, through: 740.0, by: 70) where x < 170 || x > 630 {
            polygon(cg, [CGPoint(x: x - 18, y: 700), CGPoint(x: x, y: 655), CGPoint(x: x + 18, y: 700)])
        }
    }

    private static func fish(_ cg: CGContext) {
        cg.strokeEllipse(in: CGRect(x: 150, y: 250, width: 450, height: 300))
        polygon(cg, [CGPoint(x: 585, y: 400), CGPoint(x: 740, y: 270), CGPoint(x: 740, y: 530)])
        polygon(cg, [CGPoint(x: 330, y: 262), CGPoint(x: 400, y: 170), CGPoint(x: 470, y: 268)])
        polygon(cg, [CGPoint(x: 360, y: 470), CGPoint(x: 420, y: 520), CGPoint(x: 330, y: 520)])
        circle(cg, CGPoint(x: 250, y: 360), 32)
        cg.fillEllipse(in: CGRect(x: 238, y: 348, width: 24, height: 24))
        for x in [340.0, 430.0, 520.0] {
            cg.move(to: CGPoint(x: x, y: 262))
            cg.addQuadCurve(to: CGPoint(x: x, y: 538), control: CGPoint(x: x + 50, y: 400))
            cg.strokePath()
        }
        for (x, y, r) in [(110.0, 220.0, 22.0), (80.0, 140.0, 30.0), (130.0, 70.0, 18.0)] {
            circle(cg, CGPoint(x: x, y: y), r)
        }
        cg.move(to: CGPoint(x: 20, y: 700))
        for i in 0..<8 {
            let x = 20 + Double(i) * 95
            cg.addQuadCurve(to: CGPoint(x: x + 95, y: 700), control: CGPoint(x: x + 47, y: 650))
        }
        cg.strokePath()
        for x in [120.0, 650.0] {
            cg.move(to: CGPoint(x: x, y: 690))
            cg.addCurve(to: CGPoint(x: x, y: 560), control1: CGPoint(x: x - 40, y: 650), control2: CGPoint(x: x + 40, y: 600))
            cg.strokePath()
        }
    }

    private static func flower(_ cg: CGContext) {
        let center = CGPoint(x: 400, y: 280)
        polygon(cg, [CGPoint(x: 290, y: 620), CGPoint(x: 510, y: 620), CGPoint(x: 470, y: 770), CGPoint(x: 330, y: 770)])
        line(cg, CGPoint(x: 290, y: 660), CGPoint(x: 510, y: 660))
        line(cg, CGPoint(x: 400, y: 400), CGPoint(x: 400, y: 620))
        for side in [-1.0, 1.0] {
            cg.move(to: CGPoint(x: 400, y: 540))
            cg.addQuadCurve(to: CGPoint(x: 400 + side * 150, y: 480), control: CGPoint(x: 400 + side * 60, y: 450))
            cg.addQuadCurve(to: CGPoint(x: 400, y: 540), control: CGPoint(x: 400 + side * 110, y: 560))
            cg.strokePath()
        }
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            cg.saveGState()
            cg.translateBy(x: center.x, y: center.y)
            cg.rotate(by: angle)
            cg.strokeEllipse(in: CGRect(x: 50, y: -50, width: 170, height: 100))
            cg.restoreGState()
        }
        circle(cg, center, 75)
        circle(cg, CGPoint(x: 680, y: 110), 50)
        for (x, y) in [(110.0, 120.0), (680.0, 420.0)] {
            cg.strokeEllipse(in: CGRect(x: x - 45, y: y - 25, width: 40, height: 50))
            cg.strokeEllipse(in: CGRect(x: x + 5, y: y - 25, width: 40, height: 50))
        }
    }

    private static func rocket(_ cg: CGContext) {
        polygon(cg, [CGPoint(x: 330, y: 260), CGPoint(x: 400, y: 100), CGPoint(x: 470, y: 260)])
        cg.stroke(CGRect(x: 330, y: 260, width: 140, height: 320))
        circle(cg, CGPoint(x: 400, y: 360), 45)
        circle(cg, CGPoint(x: 400, y: 360), 25)
        line(cg, CGPoint(x: 330, y: 470), CGPoint(x: 470, y: 470))
        polygon(cg, [CGPoint(x: 330, y: 470), CGPoint(x: 250, y: 600), CGPoint(x: 330, y: 580)])
        polygon(cg, [CGPoint(x: 470, y: 470), CGPoint(x: 550, y: 600), CGPoint(x: 470, y: 580)])
        polygon(cg, [CGPoint(x: 350, y: 580), CGPoint(x: 400, y: 740), CGPoint(x: 450, y: 580)])
        polygon(cg, [CGPoint(x: 375, y: 590), CGPoint(x: 400, y: 680), CGPoint(x: 425, y: 590)])
        for (x, y, r) in [(140.0, 140.0, 40.0), (660.0, 220.0, 32.0), (160.0, 520.0, 28.0), (650.0, 620.0, 44.0)] {
            var points: [CGPoint] = []
            for i in 0..<10 {
                let a = Double(i) * .pi / 5 - .pi / 2
                let radius = i.isMultiple(of: 2) ? r : r * 0.45
                points.append(CGPoint(x: x + cos(a) * radius, y: y + sin(a) * radius))
            }
            polygon(cg, points)
        }
        circle(cg, CGPoint(x: 620, y: 420), 60)
        cg.strokeEllipse(in: CGRect(x: 530, y: 405, width: 180, height: 30))
    }
}
