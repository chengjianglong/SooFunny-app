import SwiftUI

/// The backgrounds the sport demos play on, drawn with simple shapes.
enum DemoScene {
    case pool(lanes: Bool, goal: Bool = false)
    case divingPool
    case track(hurdles: [Double] = [])
    case field(Color, goals: Bool = true)
    case court(Color, floor: Color, netHeight: Double)
    case basketball
    case tableTennis
    case ring
    case mat(Color, edge: Color, round: Bool = false)
    case stage
    case sea(wave: Bool = false, buoys: Bool = false)
    case river
    case range(rings: Bool = true)
    case road
    case equestrian(fences: [Double])
    case piste
    case golf
    case beam
    case skatepark
    case climbingWall
    case rugby
    case platform
    case triathlon
    case pentathlon
    case slope(gates: Bool)
    case snowHills
    case iceChute
    case rink(hockey: Bool)
    case curling
    case skiJump
    case halfpipe
    case kicker
    case mountain
    case oval(small: Bool)
    case biathlon

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        func r(_ x: Double, _ y: Double, _ rw: Double, _ rh: Double) -> CGRect { CGRect(x: x * w, y: y * h, width: rw * w, height: rh * h) }
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * w, y: y * h) }
        func fill(_ rect: CGRect, _ color: Color) { context.fill(Path(rect), with: .color(color)) }
        func line(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ width: Double = 2, dash: [CGFloat] = []) {
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
        }
        func shape(_ points: [(Double, Double)], _ color: Color) {
            var path = Path()
            path.addLines(points.map { p($0.0, $0.1) })
            path.closeSubpath()
            context.fill(path, with: .color(color))
        }
        func oval(_ rect: CGRect, _ color: Color, stroke: Double = 0) {
            if stroke > 0 { context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: stroke) }
            else { context.fill(Path(ellipseIn: rect), with: .color(color)) }
        }
        func sky(_ to: Double = 1) {
            context.fill(Path(r(0, 0, 1, to)), with: .linearGradient(Gradient(colors: [Color(red: 0.55, green: 0.8, blue: 1), Color(red: 0.85, green: 0.94, blue: 1)]),
                                                                     startPoint: p(0, 0), endPoint: p(0, to)))
        }
        func water(_ from: Double) {
            context.fill(Path(r(0, from, 1, 1 - from)), with: .linearGradient(Gradient(colors: [Color(red: 0.3, green: 0.7, blue: 0.95), Color(red: 0.1, green: 0.45, blue: 0.8)]),
                                                                            startPoint: p(0, from), endPoint: p(0, 1)))
        }
        func waves(_ ys: [Double]) {
            for y in ys {
                var path = Path()
                path.move(to: p(0, y))
                for i in 0...20 { path.addLine(to: p(Double(i) / 20, y + (i % 2 == 0 ? 0 : 0.015))) }
                context.stroke(path, with: .color(.white.opacity(0.45)), lineWidth: 1.5)
            }
        }
        func snow(_ points: [(Double, Double)]) { shape(points + [(1, 1), (0, 1)], .white) }
        func tree(_ x: Double, _ y: Double, _ s: Double = 0.1) {
            shape([(x, y - s), (x - s * 0.45, y), (x + s * 0.45, y)], Color(red: 0.1, green: 0.45, blue: 0.25))
            fill(r(x - 0.008, y, 0.016, s * 0.25), .brown)
        }
        func goal(_ x: Double, _ y: Double, _ gw: Double, _ gh: Double, facingLeft: Bool = true) {
            let rect = r(x, y, gw, gh)
            var net = Path()
            for i in 1..<5 { net.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * Double(i) / 5)); net.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * Double(i) / 5)) }
            for i in 1..<3 { net.move(to: CGPoint(x: rect.minX + rect.width * Double(i) / 3, y: rect.minY)); net.addLine(to: CGPoint(x: rect.minX + rect.width * Double(i) / 3, y: rect.maxY)) }
            context.stroke(net, with: .color(.white.opacity(0.6)), lineWidth: 1)
            context.stroke(Path(rect), with: .color(.white), lineWidth: 3)
        }
        func target(_ x: Double, _ y: Double, _ radius: Double) {
            let colors: [Color] = [.white, .black, .blue, .red, .yellow]
            for (i, color) in colors.enumerated() {
                let rr = radius * (1 - Double(i) * 0.18)
                oval(CGRect(x: x * w - rr * h, y: y * h - rr * h, width: rr * 2 * h, height: rr * 2 * h), color)
            }
        }
        func flag(_ x: Double, _ y: Double, _ color: Color) {
            line(p(x, y), p(x, y - 0.14), .gray, 2)
            shape([(x, y - 0.14), (x + 0.05, y - 0.115), (x, y - 0.09)], color)
        }
        let grass = Color(red: 0.35, green: 0.7, blue: 0.3)
        let ice = Color(red: 0.88, green: 0.95, blue: 1)

        switch self {
        case .pool(let lanes, let hasGoal):
            water(0)
            fill(r(0, 0, 0.03, 1), Color(white: 0.9)); fill(r(0.97, 0, 0.03, 1), Color(white: 0.9))
            if lanes {
                for y in [0.27, 0.5, 0.73] { line(p(0.03, y), p(0.97, y), .red, 3, dash: [8, 6]) }
            } else {
                waves([0.2, 0.45, 0.7, 0.9])
            }
            if hasGoal { goal(0.88, 0.3, 0.09, 0.3) }
        case .divingPool:
            sky(0.6)
            fill(r(0, 0.6, 1, 0.4), Color(white: 0.85))
            water(0.62)
            fill(r(0.04, 0.22, 0.12, 0.38), Color(white: 0.6))
            fill(r(0.04, 0.2, 0.26, 0.03), Color(white: 0.45))
            waves([0.75, 0.88])
        case .track(let hurdles):
            fill(r(0, 0, 1, 1), grass)
            fill(r(0, 0.3, 1, 0.7), Color(red: 0.82, green: 0.35, blue: 0.28))
            for y in [0.3, 0.55, 0.8, 0.999] { line(p(0, y), p(1, y), .white, 2) }
            for i in 0..<8 { fill(r(0.9, 0.3 + Double(i) * 0.0875, 0.02, 0.0875), i % 2 == 0 ? .white : .black) }
            for x in hurdles {
                for (y0, y1) in [(0.62, 0.78)] {
                    line(p(x, y0), p(x, y1), .white, 3)
                    fill(r(x - 0.01, y0 - 0.02, 0.02, 0.03), .black)
                }
            }
        case .field(let color, let goals):
            fill(r(0, 0, 1, 1), color)
            for i in stride(from: 0, to: 10, by: 2) { fill(r(Double(i) / 10, 0, 0.1, 1), .white.opacity(0.06)) }
            line(p(0.5, 0.05), p(0.5, 0.95), .white.opacity(0.8))
            oval(r(0.42, 0.37, 0.16, 0.26), .white.opacity(0.8), stroke: 2)
            context.stroke(Path(r(0.02, 0.05, 0.96, 0.9)), with: .color(.white.opacity(0.8)), lineWidth: 2)
            if goals { goal(0.94, 0.36, 0.05, 0.28); goal(0.01, 0.36, 0.05, 0.28) }
        case .court(let color, let floor, let netHeight):
            fill(r(0, 0, 1, 1), floor)
            fill(r(0.05, 0.55, 0.9, 0.35), color)
            context.stroke(Path(r(0.05, 0.55, 0.9, 0.35)), with: .color(.white), lineWidth: 2)
            line(p(0.5, 0.92), p(0.5, 0.9 - netHeight), Color(white: 0.3), 4)
            var net = Path()
            for i in 0..<6 { let y = 0.9 - netHeight + Double(i) * netHeight / 10; net.move(to: p(0.49, y)); net.addLine(to: p(0.51, y)) }
            context.stroke(net, with: .color(.white), lineWidth: 1)
            line(p(0.5, 0.9 - netHeight), p(0.5, 0.9 - netHeight / 2), .white, 3)
        case .basketball:
            fill(r(0, 0, 1, 1), Color(red: 0.86, green: 0.68, blue: 0.45))
            for i in 0..<10 { line(p(Double(i) / 10, 0.55), p(Double(i) / 10, 1), .brown.opacity(0.25), 1) }
            fill(r(0, 0, 1, 0.55), Color(red: 0.75, green: 0.85, blue: 0.95))
            fill(r(0.95, 0.12, 0.02, 0.6), Color(white: 0.4))
            fill(r(0.92, 0.12, 0.015, 0.22), .white)
            context.stroke(Path(r(0.92, 0.12, 0.015, 0.22)), with: .color(.red), lineWidth: 2)
            line(p(0.82, 0.3), p(0.92, 0.3), .orange, 4)
            var netPath = Path()
            for i in 0...4 { let x = 0.82 + Double(i) * 0.025; netPath.move(to: p(x, 0.3)); netPath.addLine(to: p(0.835 + Double(i) * 0.017, 0.4)) }
            context.stroke(netPath, with: .color(.white), lineWidth: 1)
        case .tableTennis:
            fill(r(0, 0, 1, 1), Color(red: 0.45, green: 0.2, blue: 0.25))
            fill(r(0.12, 0.62, 0.76, 0.06), Color(red: 0.1, green: 0.35, blue: 0.7))
            line(p(0.12, 0.62), p(0.88, 0.62), .white, 2)
            fill(r(0.2, 0.68, 0.02, 0.25), Color(white: 0.2)); fill(r(0.78, 0.68, 0.02, 0.25), Color(white: 0.2))
            fill(r(0.497, 0.55, 0.006, 0.07), .white)
        case .ring:
            fill(r(0, 0, 1, 1), Color(red: 0.15, green: 0.15, blue: 0.25))
            shape([(0.05, 0.85), (0.95, 0.85), (0.85, 0.55), (0.15, 0.55)], Color(red: 0.25, green: 0.45, blue: 0.85))
            for (i, color) in [Color.red, .white, .blue].enumerated() {
                let y = 0.3 + Double(i) * 0.08
                line(p(0.05, y + 0.25), p(0.15, y), color, 3)
                line(p(0.15, y), p(0.85, y), color, 3)
                line(p(0.85, y), p(0.95, y + 0.25), color, 3)
            }
            fill(r(0.14, 0.25, 0.02, 0.32), .red); fill(r(0.84, 0.25, 0.02, 0.32), .blue)
        case .mat(let color, let edge, let round):
            fill(r(0, 0, 1, 1), Color(white: 0.92))
            if round {
                oval(r(0.18, 0.12, 0.64, 0.84), edge)
                oval(r(0.24, 0.2, 0.52, 0.68), color)
                oval(r(0.46, 0.5, 0.08, 0.1), .white.opacity(0.7), stroke: 2)
            } else {
                fill(r(0.1, 0.1, 0.8, 0.85), edge)
                fill(r(0.18, 0.18, 0.64, 0.7), color)
            }
        case .stage:
            fill(r(0, 0, 1, 1), Color(red: 0.2, green: 0.1, blue: 0.35))
            fill(r(0, 0.7, 1, 0.3), Color(red: 0.35, green: 0.25, blue: 0.45))
            for (x, color) in [(0.2, Color.pink), (0.5, .yellow), (0.8, .cyan)] {
                shape([(x - 0.03, 0), (x + 0.03, 0), (x + 0.15, 0.85), (x - 0.15, 0.85)], color.opacity(0.18))
            }
        case .sea(let wave, let buoys):
            sky(0.45)
            water(0.45)
            waves([0.55, 0.68, 0.82, 0.94])
            if wave {
                var path = Path()
                path.move(to: p(0, 0.75))
                path.addCurve(to: p(0.6, 0.3), control1: p(0.3, 0.75), control2: p(0.45, 0.25))
                path.addCurve(to: p(0.75, 0.42), control1: p(0.7, 0.33), control2: p(0.74, 0.36))
                path.addCurve(to: p(1, 0.75), control1: p(0.8, 0.6), control2: p(0.9, 0.75))
                path.addLine(to: p(1, 1)); path.addLine(to: p(0, 1)); path.closeSubpath()
                context.fill(path, with: .color(Color(red: 0.15, green: 0.55, blue: 0.85)))
                oval(r(0.56, 0.27, 0.12, 0.07), .white)
            }
            if buoys { for (x, y) in [(0.25, 0.62), (0.75, 0.62), (0.5, 0.88)] { oval(r(x - 0.02, y - 0.03, 0.04, 0.06), .orange) } }
        case .river:
            fill(r(0, 0, 1, 1), grass)
            fill(r(0, 0.15, 1, 0.75), Color(red: 0.25, green: 0.6, blue: 0.85))
            waves([0.3, 0.5, 0.7])
            for (x, color) in [(0.3, Color.green), (0.55, .red), (0.8, .green)] {
                line(p(x, 0.1), p(x, 0.45), .white, 1)
                fill(r(x - 0.008, 0.32, 0.016, 0.12), color)
                line(p(x + 0.1, 0.1), p(x + 0.1, 0.45), .white, 1)
                fill(r(x + 0.092, 0.32, 0.016, 0.12), color)
            }
        case .range(let rings):
            sky(0.55)
            fill(r(0, 0.55, 1, 0.45), grass)
            if rings {
                fill(r(0.855, 0.6, 0.01, 0.25), .brown)
                target(0.86, 0.45, 0.16)
            }
        case .road:
            sky(0.55)
            shape([(0, 0.55), (0.25, 0.35), (0.5, 0.55)], Color(red: 0.4, green: 0.65, blue: 0.4))
            shape([(0.35, 0.55), (0.65, 0.3), (0.95, 0.55)], Color(red: 0.3, green: 0.58, blue: 0.35))
            fill(r(0, 0.55, 1, 0.45), grass)
            fill(r(0, 0.65, 1, 0.25), Color(white: 0.4))
            line(p(0, 0.775), p(1, 0.775), .white, 3, dash: [16, 12])
        case .equestrian(let fences):
            sky(0.4)
            fill(r(0, 0.4, 1, 0.6), grass)
            for x in fences {
                line(p(x - 0.04, 0.8), p(x - 0.04, 0.6), .white, 3)
                line(p(x + 0.04, 0.8), p(x + 0.04, 0.6), .white, 3)
                for (i, y) in [0.63, 0.7].enumerated() { line(p(x - 0.04, y), p(x + 0.04, y), i == 0 ? .red : .white, 5) }
            }
        case .piste:
            fill(r(0, 0, 1, 1), Color(red: 0.12, green: 0.15, blue: 0.3))
            fill(r(0, 0.7, 1, 0.12), Color(white: 0.7))
            line(p(0.5, 0.7), p(0.5, 0.82), .white, 2)
            oval(r(0.05, 0.08, 0.08, 0.13), Color.green.opacity(0.3)); oval(r(0.87, 0.08, 0.08, 0.13), Color.red.opacity(0.3))
        case .golf:
            sky(0.45)
            fill(r(0, 0.45, 1, 0.55), Color(red: 0.4, green: 0.72, blue: 0.35))
            oval(r(0.6, 0.6, 0.38, 0.18), Color(red: 0.5, green: 0.85, blue: 0.45))
            oval(r(0.35, 0.78, 0.18, 0.1), Color(red: 0.95, green: 0.88, blue: 0.65))
            oval(r(0.845, 0.65, 0.03, 0.025), .black)
            flag(0.86, 0.67, .red)
        case .beam:
            fill(r(0, 0, 1, 1), Color(red: 0.95, green: 0.9, blue: 0.85))
            fill(r(0, 0.8, 1, 0.2), Color(red: 0.3, green: 0.45, blue: 0.85))
            fill(r(0.08, 0.58, 0.84, 0.04), Color(red: 0.85, green: 0.7, blue: 0.5))
            fill(r(0.15, 0.62, 0.02, 0.18), Color(white: 0.5)); fill(r(0.83, 0.62, 0.02, 0.18), Color(white: 0.5))
        case .skatepark:
            sky(1)
            var path = Path()
            path.move(to: p(0, 0.25))
            path.addQuadCurve(to: p(0.3, 0.85), control: p(0.02, 0.85))
            path.addLine(to: p(0.7, 0.85))
            path.addQuadCurve(to: p(1, 0.25), control: p(0.98, 0.85))
            path.addLine(to: p(1, 1)); path.addLine(to: p(0, 1)); path.closeSubpath()
            context.fill(path, with: .color(Color(white: 0.72)))
            line(p(0, 0.25), p(0.06, 0.25), Color(white: 0.4), 4); line(p(0.94, 0.25), p(1, 0.25), Color(white: 0.4), 4)
        case .climbingWall:
            fill(r(0, 0, 1, 1), Color(red: 0.75, green: 0.8, blue: 0.85))
            fill(r(0, 0.93, 1, 0.07), Color(red: 0.3, green: 0.3, blue: 0.4))
            let holds: [(Double, Double, Color)] = [(0.3, 0.82, .red), (0.42, 0.7, .yellow), (0.28, 0.6, .green), (0.4, 0.47, .purple), (0.3, 0.36, .orange),
                                                     (0.44, 0.24, .blue), (0.34, 0.12, .pink), (0.72, 0.85, .red), (0.72, 0.6, .red), (0.72, 0.35, .red), (0.72, 0.1, .red)]
            for (x, y, color) in holds { oval(r(x - 0.02, y - 0.025, 0.04, 0.05), color) }
            line(p(0.6, 0), p(0.6, 0.93), .white.opacity(0.5), 2)
        case .rugby:
            fill(r(0, 0, 1, 1), grass)
            for i in stride(from: 0, to: 10, by: 2) { fill(r(Double(i) / 10, 0, 0.1, 1), .white.opacity(0.06)) }
            line(p(0.85, 0.05), p(0.85, 0.95), .white, 3)
            line(p(0.9, 0.2), p(0.9, 0.7), .white, 4); line(p(0.96, 0.15), p(0.96, 0.65), .white, 4)
            line(p(0.9, 0.5), p(0.96, 0.45), .white, 4)
        case .platform:
            fill(r(0, 0, 1, 1), Color(red: 0.25, green: 0.25, blue: 0.3))
            fill(r(0.2, 0.75, 0.6, 0.2), Color(red: 0.75, green: 0.55, blue: 0.35))
            context.stroke(Path(r(0.2, 0.75, 0.6, 0.2)), with: .color(.black.opacity(0.4)), lineWidth: 2)
        case .triathlon:
            sky(0.5)
            fill(r(0, 0.5, 0.34, 0.5), Color(red: 0.2, green: 0.55, blue: 0.85))
            fill(r(0.34, 0.5, 0.66, 0.5), grass)
            fill(r(0.34, 0.66, 0.33, 0.2), Color(white: 0.4))
            fill(r(0.67, 0.66, 0.33, 0.2), Color(red: 0.82, green: 0.35, blue: 0.28))
            line(p(0.34, 0.45), p(0.34, 0.95), .white, 2, dash: [5, 4]); line(p(0.67, 0.45), p(0.67, 0.95), .white, 2, dash: [5, 4])
        case .pentathlon:
            fill(r(0, 0, 1, 1), grass)
            fill(r(0, 0.6, 1, 0.3), Color(red: 0.82, green: 0.35, blue: 0.28))
            fill(r(0.62, 0.4, 0.2, 0.2), Color(white: 0.85))
            for i in 0..<4 { oval(r(0.64 + Double(i) * 0.045, 0.45, 0.035, 0.055), .black) }
        case .slope(let gates):
            sky(1)
            snow([(0, 0.15), (1, 0.75)])
            tree(0.75, 0.42, 0.12); tree(0.88, 0.5, 0.1); tree(0.1, 0.12, 0.08)
            if gates { for (x, color) in [(0.3, Color.red), (0.52, .blue), (0.74, .red)] { flag(x, 0.15 + x * 0.6 + 0.12, color) } }
        case .snowHills:
            sky(1)
            snow([(0, 0.7), (0.2, 0.55), (0.45, 0.7), (0.7, 0.5), (1, 0.65)])
            tree(0.15, 0.55, 0.12); tree(0.62, 0.5, 0.1); tree(0.88, 0.58, 0.12)
            var tracks = Path()
            tracks.move(to: p(0, 0.82)); tracks.addLine(to: p(1, 0.8))
            context.stroke(tracks, with: .color(Color(white: 0.8)), lineWidth: 2)
        case .iceChute:
            sky(1)
            snow([(0, 0.5), (1, 0.85)])
            var path = Path()
            path.move(to: p(0, 0.12))
            path.addCurve(to: p(0.5, 0.55), control1: p(0.4, 0.05), control2: p(0.1, 0.55))
            path.addCurve(to: p(1, 0.75), control1: p(0.85, 0.55), control2: p(0.75, 0.85))
            context.stroke(path, with: .color(Color(red: 0.6, green: 0.8, blue: 0.95)), lineWidth: 0.16 * h)
            context.stroke(path, with: .color(ice), lineWidth: 0.11 * h)
        case .rink(let hockey):
            fill(r(0, 0, 1, 1), Color(white: 0.3))
            context.fill(Path(roundedRect: r(0.03, 0.08, 0.94, 0.84), cornerRadius: 0.2 * h), with: .color(ice))
            if hockey {
                line(p(0.5, 0.08), p(0.5, 0.92), .red, 3)
                line(p(0.33, 0.08), p(0.33, 0.92), .blue, 3); line(p(0.67, 0.08), p(0.67, 0.92), .blue, 3)
                oval(r(0.44, 0.4, 0.12, 0.2), .blue, stroke: 2)
                goal(0.9, 0.42, 0.04, 0.16)
            } else {
                oval(r(0.35, 0.3, 0.3, 0.4), .blue.opacity(0.3), stroke: 2)
            }
        case .curling:
            fill(r(0, 0, 1, 1), Color(white: 0.3))
            fill(r(0, 0.15, 1, 0.7), ice)
            for (rr, color) in [(0.3, Color.blue), (0.2, .white), (0.11, .red), (0.04, .white)] {
                oval(CGRect(x: 0.82 * w - rr * h, y: 0.5 * h - rr * h, width: rr * 2 * h, height: rr * 2 * h), color)
            }
            line(p(0.05, 0.5), p(0.97, 0.5), .black.opacity(0.15), 1)
            line(p(0.35, 0.15), p(0.35, 0.85), .red.opacity(0.6), 2)
        case .skiJump:
            sky(1)
            snow([(0, 0.9), (0.4, 0.55), (0.75, 0.95), (1, 0.97)])
            var ramp = Path()
            ramp.move(to: p(0, 0.08))
            ramp.addQuadCurve(to: p(0.33, 0.45), control: p(0.18, 0.45))
            context.stroke(ramp, with: .color(Color(white: 0.55)), lineWidth: 8)
            context.stroke(ramp, with: .color(.white), lineWidth: 4)
            tree(0.9, 0.9, 0.1)
        case .halfpipe:
            sky(1)
            var path = Path()
            path.move(to: p(0, 0.2))
            path.addQuadCurve(to: p(0.25, 0.85), control: p(0.02, 0.85))
            path.addLine(to: p(0.75, 0.85))
            path.addQuadCurve(to: p(1, 0.2), control: p(0.98, 0.85))
            path.addLine(to: p(1, 1)); path.addLine(to: p(0, 1)); path.closeSubpath()
            context.fill(path, with: .color(.white))
            context.stroke(path, with: .color(Color(red: 0.7, green: 0.85, blue: 1)), lineWidth: 2)
        case .kicker:
            sky(1)
            snow([(0, 0.35), (0.35, 0.7), (0.45, 0.62), (0.47, 0.7), (1, 0.95)])
            tree(0.85, 0.75, 0.12)
        case .mountain:
            sky(1)
            shape([(0, 1), (0.5, 0.08), (1, 1)], Color(red: 0.55, green: 0.6, blue: 0.7))
            shape([(0.36, 0.34), (0.5, 0.08), (0.64, 0.34), (0.55, 0.3), (0.5, 0.36), (0.44, 0.3)], .white)
            snow([(0, 0.9), (1, 0.9)])
            flag(0.5, 0.1, .red)
        case .oval(let small):
            fill(r(0, 0, 1, 1), Color(white: 0.3))
            context.fill(Path(roundedRect: r(0.03, 0.08, 0.94, 0.84), cornerRadius: 0.4 * h), with: .color(ice))
            let inset = small ? 0.22 : 0.16
            context.stroke(Path(roundedRect: r(inset, 0.24, 1 - inset * 2, 0.52), cornerRadius: 0.26 * h), with: .color(.blue.opacity(0.35)), lineWidth: 2)
            if !small { context.stroke(Path(roundedRect: r(0.08, 0.14, 0.84, 0.72), cornerRadius: 0.36 * h), with: .color(.red.opacity(0.3)), lineWidth: 2) }
        case .biathlon:
            sky(1)
            snow([(0, 0.6), (1, 0.6)])
            fill(r(0.7, 0.3, 0.26, 0.18), Color(white: 0.85))
            for i in 0..<5 { oval(r(0.72 + Double(i) * 0.048, 0.35, 0.04, 0.07), .black) }
            tree(0.1, 0.6, 0.12); tree(0.35, 0.58, 0.1)
        }
    }
}
