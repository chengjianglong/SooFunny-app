import SwiftUI

/// The animated demo for each sport, by sport id: a scene and the actors moving through it.
enum SportDemos {
    static func demo(for id: String) -> SportDemo? { all[id] }

    // Shorthands so each demo reads like a little script.
    private static func k(_ t: Double, _ x: Double, _ y: Double, _ turn: Double = 0) -> DemoKey { DemoKey(t: t, x: x, y: y, turn: turn) }
    private static func e(_ emoji: String, _ keys: [DemoKey], size: Double = 0.2, face: DemoFacing? = nil, mirrored: Bool = false,
                          bob: Double = 0, bobs: Double = 6, visible: ClosedRange<Double> = 0...1, smooth: Bool = true) -> DemoActor {
        DemoActor(glyph: .emoji(emoji), keys: keys, size: size, facing: face, mirrored: mirrored, bob: bob, bobs: bobs, visible: visible, smooth: smooth)
    }
    private static func ball(_ color: Color, _ keys: [DemoKey], size: Double = 0.05, visible: ClosedRange<Double> = 0...1, smooth: Bool = true) -> DemoActor {
        DemoActor(glyph: .ball(color, size), keys: keys, visible: visible, smooth: smooth)
    }
    private static func still(_ emoji: String, _ x: Double, _ y: Double, size: Double = 0.2, mirrored: Bool = false,
                              visible: ClosedRange<Double> = 0...1, bob: Double = 0, bobs: Double = 6) -> DemoActor {
        e(emoji, [k(0, x, y)], size: size, mirrored: mirrored, bob: bob, bobs: bobs, visible: visible)
    }
    private static func beam(_ color: Color, from: (Double, Double), to: (Double, Double), visible: ClosedRange<Double>) -> DemoActor {
        DemoActor(glyph: .beam(color, to: CGPoint(x: to.0, y: to.1)), keys: [k(0, from.0, from.1)], visible: visible)
    }

    static let all: [String: SportDemo] = [
        // MARK: Summer
        "swimming": SportDemo(scene: .pool(lanes: true), duration: 6, actors: [
            e("🏊", [k(0, 0.92, 0.15), k(0.8, 0.1, 0.15), k(1, 0.1, 0.15)], size: 0.17, face: .left, bob: 0.015, bobs: 16),
            e("🏊‍♀️", [k(0, 0.92, 0.39), k(0.9, 0.12, 0.39), k(1, 0.1, 0.39)], size: 0.17, face: .left, bob: 0.015, bobs: 16),
            e("🏊", [k(0, 0.92, 0.62), k(1, 0.16, 0.62)], size: 0.17, face: .left, bob: 0.015, bobs: 16),
            e("🏊‍♀️", [k(0, 0.92, 0.86), k(0.95, 0.12, 0.86), k(1, 0.1, 0.86)], size: 0.17, face: .left, bob: 0.015, bobs: 16),
            still("🥇", 0.18, 0.06, size: 0.1, visible: 0.8...1),
        ]),
        "diving": SportDemo(scene: .divingPool, duration: 4, actors: [
            e("🤸", [k(0, 0.22, 0.12), k(0.2, 0.25, 0.12), k(0.35, 0.36, 0.02, 200), k(0.6, 0.5, 0.62, 720), k(0.72, 0.52, 0.95, 720)],
              size: 0.16, visible: 0...0.72),
            still("💦", 0.5, 0.6, size: 0.18, visible: 0.6...0.85),
            still("🔟", 0.85, 0.15, size: 0.12, visible: 0.75...1),
        ]),
        "artistic-swimming": SportDemo(scene: .pool(lanes: false), duration: 6, actors: [
            e("💃", ovalKeys(cx: 0.5, cy: 0.55, rx: 0.25, ry: 0.22, from: 0), size: 0.16, bob: 0.03, bobs: 6),
            e("💃", ovalKeys(cx: 0.5, cy: 0.55, rx: 0.25, ry: 0.22, from: 120), size: 0.16, bob: 0.03, bobs: 6),
            e("💃", ovalKeys(cx: 0.5, cy: 0.55, rx: 0.25, ry: 0.22, from: 240), size: 0.16, bob: 0.03, bobs: 6),
            e("🤸", [k(0, 0.5, 0.6), k(0.4, 0.5, 0.6), k(0.55, 0.5, 0.18, 360), k(0.7, 0.5, 0.6, 360)], size: 0.16, visible: 0.35...0.75),
            e("🎵", [k(0, 0.1, 0.4), k(1, 0.2, 0.05)], size: 0.1),
            e("🎶", [k(0, 0.85, 0.45), k(1, 0.78, 0.08)], size: 0.1),
        ]),
        "water-polo": SportDemo(scene: .pool(lanes: false, goal: true), duration: 4, actors: [
            still("🤽", 0.25, 0.6, size: 0.2, bob: 0.02, bobs: 8),
            still("🤽", 0.55, 0.38, size: 0.2, bob: 0.02, bobs: 8),
            e("🤽", [k(0, 0.82, 0.38), k(0.5, 0.82, 0.55), k(1, 0.82, 0.38)], size: 0.18, mirrored: true),
            ball(.yellow, [k(0, 0.29, 0.5), k(0.25, 0.42, 0.18), k(0.4, 0.57, 0.3), k(0.5, 0.57, 0.3), k(0.7, 0.93, 0.4), k(1, 0.93, 0.42)], size: 0.07),
            still("🎉", 0.75, 0.15, size: 0.13, visible: 0.72...1),
        ]),
        "athletics": SportDemo(scene: .track(hurdles: [0.35, 0.65]), duration: 5, actors: [
            e("🏃", lineKeys(from: (0.05, 0.42), to: (0.95, 0.42)), size: 0.2, face: .right, bob: 0.015, bobs: 14),
            e("🏃‍♀️", [k(0, 0.05, 0.68), k(0.22, 0.27, 0.68), k(0.3, 0.35, 0.5), k(0.38, 0.43, 0.68), k(0.55, 0.57, 0.68),
                       k(0.63, 0.65, 0.5), k(0.71, 0.73, 0.68), k(1, 0.92, 0.68)], size: 0.2, face: .right),
            e("🏃", lineKeys(from: (0.05, 0.92), to: (0.88, 0.92)), size: 0.2, face: .right, bob: 0.015, bobs: 14),
        ]),
        "archery": SportDemo(scene: .range(), duration: 3, actors: [
            still("🏹", 0.12, 0.5, size: 0.28),
            DemoActor(glyph: .arrow, keys: [k(0, 0.2, 0.48), k(0.15, 0.2, 0.48), k(0.4, 0.55, 0.36), k(0.55, 0.85, 0.45), k(1, 0.85, 0.45)], visible: 0.1...0.95),
            still("✨", 0.86, 0.22, size: 0.12, visible: 0.55...0.95),
        ]),
        "badminton": SportDemo(scene: .court(Color(red: 0.2, green: 0.6, blue: 0.35), floor: Color(red: 0.8, green: 0.6, blue: 0.45), netHeight: 0.35), duration: 3, actors: [
            e("🏸", [k(0, 0.15, 0.5, -30), k(0.5, 0.18, 0.62, 0), k(1, 0.15, 0.5, -30)], size: 0.2, mirrored: true),
            e("🏸", [k(0, 0.85, 0.62, 0), k(0.5, 0.82, 0.5, 30), k(1, 0.85, 0.62, 0)], size: 0.2),
            ball(.white, [k(0, 0.22, 0.45), k(0.25, 0.5, 0.08), k(0.5, 0.78, 0.45), k(0.75, 0.5, 0.08), k(1, 0.22, 0.45)], size: 0.05),
        ]),
        "basketball": SportDemo(scene: .basketball, duration: 4, actors: [
            e("⛹️", [k(0, 0.25, 0.68), k(0.4, 0.3, 0.68), k(0.5, 0.3, 0.6), k(0.6, 0.3, 0.68), k(1, 0.25, 0.68)], size: 0.28),
            e("🏀", [k(0, 0.33, 0.62), k(0.1, 0.33, 0.85), k(0.2, 0.33, 0.62), k(0.3, 0.33, 0.85), k(0.42, 0.34, 0.5),
                    k(0.58, 0.62, 0.05), k(0.72, 0.87, 0.3), k(0.82, 0.87, 0.58), k(0.92, 0.85, 0.85), k(1, 0.85, 0.85)],
              size: 0.1, smooth: false),
            still("🎉", 0.7, 0.15, size: 0.13, visible: 0.72...1),
            still("3️⃣", 0.12, 0.15, size: 0.11, visible: 0.72...1),
        ]),
        "boxing": SportDemo(scene: .ring, duration: 2.4, actors: [
            e("🥊", [k(0, 0.3, 0.55), k(0.2, 0.44, 0.52), k(0.35, 0.3, 0.55), k(1, 0.3, 0.55)], size: 0.22, mirrored: true),
            e("🥊", [k(0, 0.7, 0.55), k(0.5, 0.7, 0.55), k(0.7, 0.56, 0.5), k(0.85, 0.7, 0.55), k(1, 0.7, 0.55)], size: 0.22),
            still("💥", 0.5, 0.45, size: 0.14, visible: 0.15...0.3),
            still("💥", 0.5, 0.45, size: 0.14, visible: 0.65...0.8),
        ]),
        "breaking": SportDemo(scene: .stage, duration: 5, actors: [
            e("🕺", [k(0, 0.3, 0.65), k(0.3, 0.5, 0.65, 0), k(0.45, 0.5, 0.65, 720), k(0.6, 0.5, 0.7, 900), k(0.85, 0.5, 0.7, 900), k(1, 0.3, 0.65, 1080)], size: 0.3),
            e("🎵", [k(0, 0.12, 0.5), k(1, 0.18, 0.08)], size: 0.1),
            e("🎶", [k(0, 0.85, 0.5), k(1, 0.8, 0.1)], size: 0.1),
            still("⭐", 0.5, 0.25, size: 0.12, visible: 0.62...0.85),
        ]),
        "canoeing": SportDemo(scene: .river, duration: 6, actors: [
            e("🛶", [k(0, 0.02, 0.55), k(0.2, 0.25, 0.6), k(0.32, 0.35, 0.35), k(0.45, 0.45, 0.65), k(0.58, 0.6, 0.35),
                    k(0.72, 0.72, 0.65), k(0.85, 0.85, 0.35), k(1, 1.02, 0.5)], size: 0.18),
        ]),
        "cycling": SportDemo(scene: .road, duration: 5, actors: [
            e("🚴", lineKeys(from: (0.0, 0.7), to: (1.0, 0.7)), size: 0.24, face: .left, bob: 0.008, bobs: 20),
            e("🚴‍♀️", lineKeys(from: (-0.15, 0.82), to: (0.9, 0.82)), size: 0.24, face: .left, bob: 0.008, bobs: 20),
        ]),
        "equestrian": SportDemo(scene: .equestrian(fences: [0.38, 0.72]), duration: 5, actors: [
            e("🏇", [k(0, 0.02, 0.72), k(0.25, 0.28, 0.72), k(0.33, 0.38, 0.48), k(0.41, 0.48, 0.72), k(0.58, 0.62, 0.72),
                    k(0.66, 0.72, 0.48), k(0.74, 0.82, 0.72), k(1, 1.02, 0.72)], size: 0.24, face: .left),
        ]),
        "fencing": SportDemo(scene: .piste, duration: 2.6, actors: [
            e("🤺", [k(0, 0.3, 0.6), k(0.25, 0.42, 0.6), k(0.35, 0.3, 0.6), k(0.6, 0.3, 0.6), k(0.7, 0.26, 0.6), k(1, 0.3, 0.6)], size: 0.3, mirrored: true),
            e("🤺", [k(0, 0.7, 0.6), k(0.25, 0.74, 0.6), k(0.5, 0.7, 0.6), k(0.65, 0.58, 0.6), k(0.8, 0.7, 0.6), k(1, 0.7, 0.6)], size: 0.3),
            still("🟢", 0.09, 0.145, size: 0.1, visible: 0.22...0.42),
            still("🔴", 0.91, 0.145, size: 0.1, visible: 0.62...0.82),
        ]),
        "football": SportDemo(scene: .field(Color(red: 0.3, green: 0.65, blue: 0.3)), duration: 5, actors: [
            e("🏃", [k(0, 0.1, 0.55), k(0.6, 0.62, 0.5), k(0.75, 0.66, 0.5), k(1, 0.66, 0.5)], size: 0.22, face: .right, bob: 0.012, bobs: 12),
            e("⚽", [k(0, 0.16, 0.62, 0), k(0.6, 0.7, 0.58, 1080), k(0.78, 0.96, 0.45, 1500), k(1, 0.96, 0.47, 1500)], size: 0.08),
            e("🧤", [k(0, 0.93, 0.5), k(0.3, 0.93, 0.42), k(0.6, 0.93, 0.58), k(0.8, 0.93, 0.6), k(1, 0.93, 0.5)], size: 0.12),
            still("🎉", 0.78, 0.15, size: 0.14, visible: 0.78...1),
        ]),
        "golf": SportDemo(scene: .golf, duration: 4.5, actors: [
            e("🏌️", [k(0, 0.14, 0.62, 0), k(0.15, 0.14, 0.62, -15), k(0.22, 0.14, 0.62, 10), k(1, 0.14, 0.62, 0)], size: 0.3),
            ball(.white, [k(0, 0.22, 0.75), k(0.2, 0.22, 0.75), k(0.45, 0.5, 0.08), k(0.65, 0.76, 0.66), k(0.72, 0.8, 0.6),
                          k(0.8, 0.84, 0.665), k(0.9, 0.86, 0.665), k(1, 0.86, 0.665)], size: 0.035, visible: 0...0.9),
            still("🎉", 0.7, 0.2, size: 0.13, visible: 0.85...1),
        ]),
        "gymnastics": SportDemo(scene: .beam, duration: 4, actors: [
            e("🤸", [k(0, 0.15, 0.47, 0), k(0.3, 0.38, 0.47, 360), k(0.5, 0.5, 0.25, 540), k(0.7, 0.62, 0.47, 720), k(1, 0.85, 0.47, 1080)], size: 0.2),
            still("✨", 0.5, 0.12, size: 0.12, visible: 0.4...0.65),
        ]),
        "handball": SportDemo(scene: .field(Color(red: 0.25, green: 0.5, blue: 0.85)), duration: 4, actors: [
            e("🤾", [k(0, 0.15, 0.6), k(0.4, 0.55, 0.6), k(0.55, 0.68, 0.35), k(0.7, 0.75, 0.55), k(1, 0.75, 0.6)], size: 0.24, face: .left),
            ball(.yellow, [k(0, 0.2, 0.55), k(0.4, 0.6, 0.55), k(0.55, 0.72, 0.28), k(0.7, 0.96, 0.48), k(1, 0.96, 0.52)], size: 0.06),
            still("🧤", 0.92, 0.6, size: 0.1),
            still("🎉", 0.8, 0.15, size: 0.14, visible: 0.72...1),
        ]),
        "hockey": SportDemo(scene: .field(Color(red: 0.2, green: 0.45, blue: 0.75)), duration: 4, actors: [
            e("🏑", [k(0, 0.12, 0.55, 0), k(0.5, 0.6, 0.55, 0), k(0.6, 0.62, 0.52, -40), k(0.68, 0.64, 0.55, 10), k(1, 0.64, 0.55, 0)], size: 0.2),
            ball(.white, [k(0, 0.2, 0.62), k(0.5, 0.68, 0.62), k(0.7, 0.97, 0.5), k(1, 0.97, 0.52)], size: 0.04),
            still("🎉", 0.8, 0.15, size: 0.14, visible: 0.72...1),
        ]),
        "judo": SportDemo(scene: .mat(Color(red: 0.95, green: 0.8, blue: 0.2), edge: Color(red: 0.2, green: 0.4, blue: 0.8)), duration: 4, actors: [
            e("🥋", [k(0, 0.32, 0.5), k(0.3, 0.44, 0.5), k(1, 0.44, 0.5)], size: 0.28),
            e("🥋", [k(0, 0.68, 0.5, 0), k(0.3, 0.56, 0.5, 0), k(0.45, 0.48, 0.15, 120), k(0.6, 0.3, 0.62, 270), k(1, 0.3, 0.62, 270)], size: 0.28),
            still("⭐", 0.5, 0.12, size: 0.12, visible: 0.62...1),
        ]),
        "modern-pentathlon": SportDemo(scene: .pentathlon, duration: 6, actors: [
            still("🤺", 0.12, 0.15, size: 0.12), still("🏊", 0.28, 0.15, size: 0.12),
            still("🎯", 0.44, 0.15, size: 0.12), still("🏃", 0.6, 0.15, size: 0.12),
            e("🏃", [k(0, 0.05, 0.75), k(0.35, 0.5, 0.75), k(0.55, 0.5, 0.75), k(1, 0.98, 0.75)], size: 0.2, face: .right),
            beam(.red, from: (0.53, 0.68), to: (0.66, 0.48), visible: 0.38...0.42),
            beam(.red, from: (0.53, 0.68), to: (0.71, 0.48), visible: 0.43...0.47),
            beam(.red, from: (0.53, 0.68), to: (0.75, 0.48), visible: 0.48...0.52),
            still("✅", 0.72, 0.32, size: 0.1, visible: 0.5...0.6),
        ]),
        "rowing": SportDemo(scene: .sea(), duration: 6, actors: [
            e("🚣", lineKeys(from: (0.02, 0.62), to: (1.02, 0.62)), size: 0.2, bob: 0.01, bobs: 12),
            e("🚣‍♀️", lineKeys(from: (-0.08, 0.85), to: (0.92, 0.85)), size: 0.2, bob: 0.01, bobs: 12),
        ]),
        "rugby-sevens": SportDemo(scene: .rugby, duration: 5, actors: [
            e("🏃", [k(0, 0.15, 0.4), k(0.35, 0.45, 0.4), k(0.5, 0.52, 0.35), k(1, 0.58, 0.32)], size: 0.2, face: .right),
            e("🏃‍♀️", [k(0, 0.05, 0.7), k(0.35, 0.35, 0.68), k(0.7, 0.8, 0.6), k(0.8, 0.9, 0.62, 70), k(1, 0.9, 0.62, 70)], size: 0.2, face: .right),
            e("🏉", [k(0, 0.2, 0.45, 20), k(0.35, 0.5, 0.45, 20), k(0.45, 0.42, 0.55, 300), k(0.5, 0.42, 0.63, 380), k(0.7, 0.84, 0.62, 380), k(0.8, 0.94, 0.68, 400), k(1, 0.94, 0.68, 400)],
              size: 0.08),
            still("🎉", 0.7, 0.12, size: 0.14, visible: 0.8...1),
        ]),
        "sailing": SportDemo(scene: .sea(buoys: true), duration: 8, actors: [
            e("⛵", [k(0, 0.15, 0.75, -5), k(0.25, 0.35, 0.56, 5), k(0.5, 0.82, 0.58, -5), k(0.75, 0.6, 0.92, 5), k(1, 0.15, 0.75, -5)], size: 0.22),
            e("💨", [k(0, 0.05, 0.3), k(1, 0.4, 0.3)], size: 0.12),
        ]),
        "shooting": SportDemo(scene: .range(rings: false), duration: 3, actors: [
            ball(.orange, [k(0, 0.95, 0.6), k(0.35, 0.65, 0.15), k(0.45, 0.58, 0.12)], size: 0.06, visible: 0...0.45),
            beam(.yellow, from: (0.05, 0.8), to: (0.58, 0.12), visible: 0.42...0.48),
            still("💥", 0.58, 0.12, size: 0.16, visible: 0.45...0.7),
            still("✅", 0.5, 0.35, size: 0.1, visible: 0.5...0.8),
        ]),
        "skateboarding": SportDemo(scene: .skatepark, duration: 4, actors: [
            e("🛹", [k(0, 0.06, 0.32, 70), k(0.15, 0.2, 0.78, 25), k(0.3, 0.5, 0.82, 0), k(0.45, 0.8, 0.78, -25), k(0.5, 0.94, 0.35, -70),
                    k(0.55, 0.96, 0.12, -250), k(0.6, 0.94, 0.32, -430), k(0.75, 0.6, 0.82, -360), k(1, 0.06, 0.32, -290)], size: 0.14),
            still("✨", 0.9, 0.08, size: 0.1, visible: 0.52...0.65),
        ]),
        "sport-climbing": SportDemo(scene: .climbingWall, duration: 6, actors: [
            e("🧗", [k(0, 0.3, 0.85), k(0.15, 0.42, 0.72), k(0.3, 0.28, 0.6), k(0.45, 0.4, 0.48), k(0.6, 0.3, 0.36),
                    k(0.75, 0.44, 0.24), k(0.9, 0.34, 0.13), k(1, 0.34, 0.13)], size: 0.18),
            e("🧗", [k(0, 0.72, 0.85), k(0.3, 0.72, 0.12), k(1, 0.72, 0.12)], size: 0.18),
            still("⏱️", 0.88, 0.12, size: 0.12, visible: 0.3...1),
        ]),
        "surfing": SportDemo(scene: .sea(wave: true), duration: 5, actors: [
            e("🏄", [k(0, 0.1, 0.72, 0), k(0.25, 0.35, 0.6, -20), k(0.45, 0.55, 0.32, -40), k(0.6, 0.66, 0.4, 30),
                    k(0.8, 0.8, 0.62, 10), k(1, 1.0, 0.72, 0)], size: 0.22, face: .right),
            still("💦", 0.62, 0.28, size: 0.12, visible: 0.45...0.62),
        ]),
        "table-tennis": SportDemo(scene: .tableTennis, duration: 2, actors: [
            e("🏓", [k(0, 0.08, 0.5), k(0.5, 0.1, 0.55), k(1, 0.08, 0.5)], size: 0.16, mirrored: true),
            e("🏓", [k(0, 0.92, 0.55), k(0.5, 0.9, 0.5), k(1, 0.92, 0.55)], size: 0.16),
            ball(.white, [k(0, 0.14, 0.5), k(0.25, 0.38, 0.6), k(0.5, 0.86, 0.48), k(0.75, 0.62, 0.6), k(1, 0.14, 0.5)], size: 0.035, smooth: false),
        ]),
        "taekwondo": SportDemo(scene: .mat(Color(red: 0.25, green: 0.45, blue: 0.9), edge: Color(red: 0.9, green: 0.3, blue: 0.3)), duration: 3, actors: [
            still("🥋", 0.35, 0.5, size: 0.28),
            still("🥋", 0.68, 0.5, size: 0.28),
            e("🦵", [k(0, 0.38, 0.62, 0), k(0.3, 0.38, 0.62, 0), k(0.45, 0.5, 0.35, -80), k(0.6, 0.38, 0.62, 0), k(1, 0.38, 0.62, 0)], size: 0.2,
              visible: 0.3...0.62),
            still("💥", 0.6, 0.3, size: 0.14, visible: 0.42...0.58),
        ]),
        "tennis": SportDemo(scene: .court(Color(red: 0.25, green: 0.45, blue: 0.75), floor: Color(red: 0.4, green: 0.65, blue: 0.4), netHeight: 0.18), duration: 2.6, actors: [
            e("🏃‍♀️", [k(0, 0.12, 0.62), k(0.5, 0.15, 0.7), k(1, 0.12, 0.62)], size: 0.22, face: .right, mirrored: false),
            e("🏃", [k(0, 0.88, 0.7), k(0.5, 0.85, 0.62), k(1, 0.88, 0.7)], size: 0.22, mirrored: true),
            e("🎾", [k(0, 0.18, 0.55), k(0.18, 0.4, 0.35), k(0.32, 0.68, 0.85), k(0.5, 0.82, 0.58), k(0.68, 0.6, 0.35),
                    k(0.82, 0.3, 0.85), k(1, 0.18, 0.55)], size: 0.06),
        ]),
        "triathlon": SportDemo(scene: .triathlon, duration: 7, actors: [
            e("🏊‍♀️", lineKeys(from: (0.02, 0.75), to: (0.32, 0.75), t0: 0, t1: 0.33), size: 0.17, face: .left, bob: 0.015, bobs: 30, visible: 0...0.34),
            e("🚴‍♀️", lineKeys(from: (0.34, 0.72), to: (0.66, 0.72), t0: 0.33, t1: 0.62), size: 0.2, face: .left, visible: 0.33...0.63),
            e("🏃‍♀️", lineKeys(from: (0.68, 0.72), to: (0.97, 0.72), t0: 0.62, t1: 0.95), size: 0.2, face: .right, bob: 0.015, bobs: 30, visible: 0.62...1),
            still("🏅", 0.9, 0.25, size: 0.14, visible: 0.93...1),
        ]),
        "volleyball": SportDemo(scene: .court(Color(red: 0.95, green: 0.6, blue: 0.3), floor: Color(red: 0.95, green: 0.85, blue: 0.6), netHeight: 0.45), duration: 3, actors: [
            e("🏃‍♀️", [k(0, 0.3, 0.72), k(0.25, 0.38, 0.72), k(0.38, 0.4, 0.4), k(0.5, 0.42, 0.72), k(1, 0.3, 0.72)], size: 0.22, face: .right),
            still("🏃", 0.78, 0.72, size: 0.22, mirrored: true),
            e("🏐", [k(0, 0.2, 0.3), k(0.2, 0.3, 0.12), k(0.38, 0.42, 0.25), k(0.55, 0.72, 0.85), k(0.62, 0.78, 0.6),
                    k(0.85, 0.5, 0.05), k(1, 0.2, 0.3)], size: 0.08),
            still("💥", 0.43, 0.25, size: 0.12, visible: 0.36...0.44),
        ]),
        "weightlifting": SportDemo(scene: .platform, duration: 3.5, actors: [
            e("🏋️", [k(0, 0.5, 0.72), k(0.3, 0.5, 0.72), k(0.45, 0.5, 0.58), k(0.85, 0.5, 0.58), k(1, 0.5, 0.72)], size: 0.38),
            still("💪", 0.22, 0.3, size: 0.12, visible: 0.5...0.85),
            still("✅", 0.78, 0.3, size: 0.12, visible: 0.55...0.85),
        ]),
        "wrestling": SportDemo(scene: .mat(Color(red: 0.95, green: 0.75, blue: 0.3), edge: Color(red: 0.25, green: 0.4, blue: 0.75), round: true), duration: 3, actors: [
            e("🤼", [k(0, 0.45, 0.55, -5), k(0.25, 0.55, 0.55, 5), k(0.5, 0.45, 0.55, -5), k(0.75, 0.55, 0.55, 5), k(1, 0.45, 0.55, -5)], size: 0.4),
        ]),

        // MARK: Winter
        "alpine-skiing": SportDemo(scene: .slope(gates: true), duration: 5, actors: [
            e("⛷️", [k(0, 0.05, 0.12), k(0.2, 0.25, 0.3), k(0.35, 0.36, 0.3), k(0.5, 0.5, 0.48), k(0.65, 0.6, 0.47),
                    k(0.8, 0.74, 0.62), k(1, 1.02, 0.7)], size: 0.18, face: .right),
            e("💨", [k(0, 0.0, 0.1), k(1, 0.95, 0.66)], size: 0.1),
        ]),
        "biathlon": SportDemo(scene: .biathlon, duration: 7, actors: [
            e("⛷️", [k(0, 0.02, 0.55), k(0.3, 0.45, 0.55), k(0.7, 0.45, 0.55), k(1, 1.02, 0.55)], size: 0.18, face: .right),
            beam(.yellow, from: (0.5, 0.5), to: (0.74, 0.385), visible: 0.35...0.38),
            beam(.yellow, from: (0.5, 0.5), to: (0.79, 0.385), visible: 0.42...0.45),
            beam(.yellow, from: (0.5, 0.5), to: (0.84, 0.385), visible: 0.49...0.52),
            beam(.yellow, from: (0.5, 0.5), to: (0.88, 0.385), visible: 0.56...0.59),
            beam(.yellow, from: (0.5, 0.5), to: (0.93, 0.385), visible: 0.63...0.66),
            still("⚪", 0.74, 0.385, size: 0.06, visible: 0.37...1), still("⚪", 0.79, 0.385, size: 0.06, visible: 0.44...1),
            still("⚪", 0.84, 0.385, size: 0.06, visible: 0.51...1), still("⚪", 0.88, 0.385, size: 0.06, visible: 0.58...1),
            still("⚪", 0.93, 0.385, size: 0.06, visible: 0.65...1),
        ]),
        "bobsleigh": SportDemo(scene: .iceChute, duration: 4, actors: [
            e("🏃", [k(0, 0.0, 0.08), k(0.15, 0.12, 0.07)], size: 0.12, face: .right, visible: 0...0.16),
            e("🛷", [k(0, 0.05, 0.12, 0), k(0.15, 0.17, 0.11, 0), k(0.35, 0.3, 0.32, 40), k(0.55, 0.5, 0.55, 0), k(0.75, 0.75, 0.62, 15), k(1, 1.05, 0.78, 20)],
              size: 0.14, face: .left),
            e("💨", [k(0, -0.05, 0.12), k(0.15, 0.08, 0.11), k(0.35, 0.22, 0.3), k(0.55, 0.42, 0.55), k(0.75, 0.66, 0.62), k(1, 0.96, 0.76)],
              size: 0.1, visible: 0.15...1),
        ]),
        "cross-country-skiing": SportDemo(scene: .snowHills, duration: 7, actors: [
            e("⛷️", lineKeys(from: (0.0, 0.76), to: (1.0, 0.74)), size: 0.18, face: .right, bob: 0.01, bobs: 20),
            e("⛷️", lineKeys(from: (-0.15, 0.86), to: (0.85, 0.84)), size: 0.18, face: .right, bob: 0.01, bobs: 20),
        ]),
        "curling": SportDemo(scene: .curling, duration: 5, actors: [
            e("🥌", [k(0, 0.05, 0.5), k(0.2, 0.3, 0.5), k(0.45, 0.6, 0.52), k(0.65, 0.76, 0.51), k(0.8, 0.81, 0.5), k(1, 0.81, 0.5)], size: 0.14),
            e("🧹", [k(0, 0.38, 0.38, -20), k(0.2, 0.38, 0.38, -20), k(0.45, 0.68, 0.38, 20), k(0.65, 0.8, 0.38, -20), k(0.7, 0.8, 0.3, 0)],
              size: 0.14, visible: 0.15...0.72),
            still("🎉", 0.6, 0.12, size: 0.12, visible: 0.8...1),
        ]),
        "figure-skating": SportDemo(scene: .rink(hockey: false), duration: 6, actors: [
            e("⛸️", [k(0, 0.15, 0.7, 0), k(0.25, 0.4, 0.75, 0), k(0.4, 0.5, 0.35, 720), k(0.55, 0.6, 0.72, 1080), k(0.8, 0.85, 0.45, 1080), k(1, 0.15, 0.7, 1080)],
              size: 0.16),
            still("✨", 0.5, 0.2, size: 0.12, visible: 0.35...0.55),
            e("🎵", [k(0, 0.1, 0.3), k(1, 0.2, 0.05)], size: 0.1),
        ]),
        "freestyle-skiing": SportDemo(scene: .kicker, duration: 4, actors: [
            e("⛷️", [k(0, 0.02, 0.3, 0), k(0.3, 0.32, 0.6, 0), k(0.38, 0.44, 0.55, -20), k(0.5, 0.55, 0.15, -200), k(0.65, 0.68, 0.62, -360),
                    k(1, 1.0, 0.85, -360)], size: 0.16, face: .right),
            still("⭐", 0.55, 0.06, size: 0.1, visible: 0.45...0.65),
        ]),
        "ice-hockey": SportDemo(scene: .rink(hockey: true), duration: 4, actors: [
            e("🏒", [k(0, 0.15, 0.48, 0), k(0.5, 0.62, 0.48, 0), k(0.6, 0.64, 0.45, 40), k(0.68, 0.66, 0.48, -10), k(1, 0.66, 0.48, 0)], size: 0.2,
              mirrored: true),
            ball(.black, [k(0, 0.22, 0.56), k(0.5, 0.7, 0.56), k(0.7, 0.92, 0.5), k(1, 0.92, 0.51)], size: 0.04),
            still("🚨", 0.9, 0.25, size: 0.12, visible: 0.7...1),
        ]),
        "luge": SportDemo(scene: .iceChute, duration: 4, actors: [
            e("🛷", [k(0, 0.0, 0.12, 0), k(0.25, 0.3, 0.32, 40), k(0.5, 0.5, 0.55, 0), k(0.75, 0.75, 0.62, 15), k(1, 1.05, 0.78, 20)], size: 0.13, face: .left),
            e("🙂", [k(0, 0.02, 0.09, 0), k(0.25, 0.32, 0.28, 40), k(0.5, 0.52, 0.51, 0), k(0.75, 0.77, 0.58, 15), k(1, 1.07, 0.74, 20)], size: 0.07),
        ]),
        "nordic-combined": SportDemo(scene: .skiJump, duration: 7, actors: [
            e("⛷️", [k(0, 0.02, 0.06, 30), k(0.12, 0.2, 0.36, 10), k(0.18, 0.33, 0.42, -10), k(0.32, 0.55, 0.38, -20), k(0.42, 0.66, 0.84, 10),
                    k(0.5, 0.75, 0.92, 0)], size: 0.15, face: .right, visible: 0...0.5),
            e("⛷️", lineKeys(from: (0.0, 0.92), to: (0.98, 0.92), t0: 0.5, t1: 1), size: 0.15, face: .right, bob: 0.01, bobs: 30, visible: 0.5...1),
            still("🦅", 0.55, 0.2, size: 0.1, visible: 0.15...0.4),
        ]),
        "short-track": SportDemo(scene: .oval(small: true), duration: 4, actors: [
            e("⛸️", ovalKeys(cx: 0.5, cy: 0.5, rx: 0.3, ry: 0.28, from: 90, turns: -1, steps: 20), size: 0.12),
            e("⛸️", ovalKeys(cx: 0.5, cy: 0.5, rx: 0.3, ry: 0.28, from: 60, turns: -1, steps: 20), size: 0.12),
            e("⛸️", ovalKeys(cx: 0.5, cy: 0.5, rx: 0.3, ry: 0.28, from: 30, turns: -1, steps: 20), size: 0.12),
        ]),
        "skeleton": SportDemo(scene: .iceChute, duration: 4, actors: [
            e("🛷", [k(0, 0.0, 0.12, 0), k(0.25, 0.3, 0.32, 40), k(0.5, 0.5, 0.55, 0), k(0.75, 0.75, 0.62, 15), k(1, 1.05, 0.78, 20)], size: 0.13, face: .left),
            e("⛑️", [k(0, 0.06, 0.1, 0), k(0.25, 0.35, 0.33, 40), k(0.5, 0.56, 0.53, 0), k(0.75, 0.81, 0.6, 15), k(1, 1.11, 0.77, 20)], size: 0.07),
        ]),
        "ski-jumping": SportDemo(scene: .skiJump, duration: 5, actors: [
            e("⛷️", [k(0, 0.02, 0.06, 30), k(0.2, 0.2, 0.36, 10), k(0.3, 0.33, 0.42, -15), k(0.55, 0.58, 0.4, -25), k(0.75, 0.72, 0.84, 5),
                    k(0.9, 0.88, 0.94, 0), k(1, 0.95, 0.95, 0)], size: 0.15, face: .right),
            e("🕊️", [k(0, 0.6, 0.25), k(1, 0.95, 0.15)], size: 0.1, face: .left),
            still("👏", 0.6, 0.6, size: 0.12, visible: 0.8...1),
        ]),
        "ski-mountaineering": SportDemo(scene: .mountain, duration: 8, actors: [
            e("⛷️", [k(0, 0.15, 0.85), k(0.12, 0.35, 0.72), k(0.24, 0.3, 0.58), k(0.36, 0.45, 0.44), k(0.48, 0.42, 0.3), k(0.58, 0.5, 0.14),
                    k(0.65, 0.52, 0.14), k(0.82, 0.72, 0.55), k(1, 0.95, 0.88)], size: 0.14, face: .right),
            still("⛺", 0.85, 0.85, size: 0.12),
        ]),
        "snowboarding": SportDemo(scene: .halfpipe, duration: 4, actors: [
            e("🏂", [k(0, 0.06, 0.25, 70), k(0.15, 0.22, 0.75, 20), k(0.3, 0.5, 0.8, 0), k(0.45, 0.78, 0.75, -20), k(0.5, 0.94, 0.25, -70),
                    k(0.55, 0.96, 0.05, -250), k(0.6, 0.94, 0.25, -430), k(0.75, 0.6, 0.8, -360), k(1, 0.06, 0.25, -290)], size: 0.16),
            still("✨", 0.9, 0.06, size: 0.1, visible: 0.52...0.65),
        ]),
        "speed-skating": SportDemo(scene: .oval(small: false), duration: 5, actors: [
            e("⛸️", ovalKeys(cx: 0.5, cy: 0.5, rx: 0.38, ry: 0.3, from: 90, turns: -1, steps: 20), size: 0.12),
            e("⛸️", ovalKeys(cx: 0.5, cy: 0.5, rx: 0.43, ry: 0.36, from: 70, turns: -1, steps: 20), size: 0.12),
        ]),
    ]
}
