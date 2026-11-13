import SwiftUI

// A tiny animation engine for the Sports tab: each sport has a looping demo made of a scene
// (pool, track, court, slope…) drawn with shapes, and actors (emoji, balls, arrows) that move
// along keyframed paths. Everything is drawn in one Canvas, so it stays smooth and needs no
// image files. Positions are fractions of the stage (0…1 across, 0…1 down).

/// One moment on an actor's path: when (0…1 through the loop), where, and how far it's turned.
struct DemoKey {
    var t: Double
    var x: Double
    var y: Double
    var turn: Double = 0
}

/// What an actor looks like.
enum DemoGlyph {
    case emoji(String)
    /// A plain ball (shuttlecock, golf ball, puck…): color and diameter as a fraction of the stage height.
    case ball(Color, Double)
    /// A flying arrow, pointing the way it's going.
    case arrow
    /// A short flash of light, like a laser shot, from the actor's position to `to`.
    case beam(Color, to: CGPoint)
}

/// Which way an emoji looks when drawn normally, so movers can be turned to face forward.
enum DemoFacing { case left, right }

struct DemoActor {
    var glyph: DemoGlyph
    var keys: [DemoKey]
    /// Height of the emoji as a fraction of the stage height.
    var size: Double = 0.2
    /// Turn the emoji to face the way it's moving.
    var facing: DemoFacing?
    /// Always mirror the emoji (for a player on the other side).
    var mirrored = false
    /// Bobbing up and down: how far (fraction of the stage height) and how many times per loop.
    var bob: Double = 0
    var bobs: Double = 6
    /// Only shown during this part of the loop (fading in and out).
    var visible: ClosedRange<Double> = 0...1
    /// Follow the path with smooth curves rather than straight lines.
    var smooth = true

    /// Where the actor is at loop time `t`, and how far it's turned (degrees).
    func place(at t: Double) -> (point: CGPoint, turn: Double) {
        guard let first = keys.first else { return (.zero, 0) }
        if keys.count == 1 || t <= first.t { return (CGPoint(x: first.x, y: first.y), first.turn) }
        guard let last = keys.last, t < last.t else { return (CGPoint(x: keys.last!.x, y: keys.last!.y), keys.last!.turn) }
        let i = keys.lastIndex { $0.t <= t } ?? 0
        let a = keys[i], b = keys[i + 1]
        let u = b.t > a.t ? (t - a.t) / (b.t - a.t) : 1
        let turn = a.turn + (b.turn - a.turn) * u
        guard smooth else { return (CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u), turn) }
        // Catmull-Rom through the neighbors, so paths bend gently through every point.
        let p0 = keys[max(i - 1, 0)], p3 = keys[min(i + 2, keys.count - 1)]
        func cr(_ v0: Double, _ v1: Double, _ v2: Double, _ v3: Double) -> Double {
            let u2 = u * u, u3 = u2 * u
            return 0.5 * (2 * v1 + (-v0 + v2) * u + (2 * v0 - 5 * v1 + 4 * v2 - v3) * u2 + (-v0 + 3 * v1 - 3 * v2 + v3) * u3)
        }
        return (CGPoint(x: cr(p0.x, a.x, b.x, p3.x), y: cr(p0.y, a.y, b.y, p3.y)), turn)
    }

    /// How visible the actor is at loop time `t` (fades in and out at the ends of its window).
    func opacity(at t: Double) -> Double {
        guard visible.contains(t) else { return 0 }
        let fade = 0.04
        var value = 1.0
        if visible.lowerBound > 0 { value = min(value, (t - visible.lowerBound) / fade) }
        if visible.upperBound < 1 { value = min(value, (visible.upperBound - t) / fade) }
        // Movers that jump back to the start fade at the loop's ends instead of popping.
        if let a = keys.first, let b = keys.last, hypot(a.x - b.x, a.y - b.y) > 0.05 {
            if visible.lowerBound == 0 { value = min(value, t / fade) }
            if visible.upperBound == 1 { value = min(value, (1 - t) / fade) }
        }
        return max(0, min(1, value))
    }
}

struct SportDemo {
    var scene: DemoScene
    /// Seconds for one loop.
    var duration: Double
    var actors: [DemoActor]
}

/// The animated demo, with a play / pause button. It starts paused when Reduce Motion is on.
struct SportDemoView: View {
    let demo: SportDemo
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playing = true
    @State private var start = Date()
    /// Loop time shown while paused.
    @State private var pausedAt = 0.18

    var body: some View {
        TimelineView(.animation(paused: !playing)) { timeline in
            let t = playing ? (timeline.date.timeIntervalSince(start) / demo.duration).truncatingRemainder(dividingBy: 1) : pausedAt
            SportDemoCanvas(demo: demo, t: t)
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .bottomTrailing) {
            Button {
                if playing {
                    pausedAt = (Date().timeIntervalSince(start) / demo.duration).truncatingRemainder(dividingBy: 1)
                } else {
                    start = Date().addingTimeInterval(-pausedAt * demo.duration)
                }
                playing.toggle()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(10)
            .accessibilityLabel(playing ? "Pause the animation" : "Play the animation")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .onAppear {
            start = Date()
            playing = !reduceMotion
        }
    }

}

/// One frame of a demo, at loop time `t`.
struct SportDemoCanvas: View {
    let demo: SportDemo
    let t: Double

    var body: some View {
        Canvas { context, size in
            demo.scene.draw(in: &context, size: size)
            for actor in demo.actors { draw(actor, at: t, in: &context, size: size) }
        }
    }

    private func draw(_ actor: DemoActor, at t: Double, in context: inout GraphicsContext, size: CGSize) {
        let alpha = actor.opacity(at: t)
        guard alpha > 0 else { return }
        var (p, turn) = actor.place(at: t)
        if actor.bob > 0 { p.y -= actor.bob * abs(sin(t * .pi * actor.bobs)) }
        let point = CGPoint(x: p.x * size.width, y: p.y * size.height)
        var ctx = context
        ctx.opacity = alpha
        ctx.translateBy(x: point.x, y: point.y)

        // Which way it's heading, to face movers forward and point arrows.
        let ahead = actor.place(at: min(t + 0.01, 0.999)).point, behind = actor.place(at: max(t - 0.01, 0)).point
        let dx = (ahead.x - behind.x) * size.width, dy = (ahead.y - behind.y) * size.height

        switch actor.glyph {
        case .emoji(let emoji):
            var flip = actor.mirrored
            if let facing = actor.facing, abs(dx) > 0.5 {
                flip = (facing == .left) == (dx > 0)
            }
            if flip { ctx.scaleBy(x: -1, y: 1) }
            ctx.rotate(by: .degrees(flip ? -turn : turn))
            let text = ctx.resolve(Text(emoji).font(.system(size: actor.size * size.height)))
            ctx.draw(text, at: .zero)
        case .ball(let color, let diameter):
            ctx.rotate(by: .degrees(turn))
            let d = diameter * size.height
            let rect = CGRect(x: -d / 2, y: -d / 2, width: d, height: d)
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
            ctx.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.35)), lineWidth: 1)
        case .arrow:
            ctx.rotate(by: .radians(atan2(dy, dx == 0 ? 1 : dx)))
            let l = 0.16 * size.height
            var shaft = Path()
            shaft.move(to: CGPoint(x: -l, y: 0))
            shaft.addLine(to: CGPoint(x: 0, y: 0))
            ctx.stroke(shaft, with: .color(.brown), lineWidth: 3)
            var head = Path()
            head.move(to: CGPoint(x: 6, y: 0))
            head.addLine(to: CGPoint(x: -6, y: -5))
            head.addLine(to: CGPoint(x: -6, y: 5))
            head.closeSubpath()
            ctx.fill(head, with: .color(.gray))
            var feathers = Path()
            feathers.move(to: CGPoint(x: -l, y: 0))
            feathers.addLine(to: CGPoint(x: -l - 7, y: -6))
            feathers.move(to: CGPoint(x: -l, y: 0))
            feathers.addLine(to: CGPoint(x: -l - 7, y: 6))
            ctx.stroke(feathers, with: .color(.red), lineWidth: 2)
        case .beam(let color, let to):
            var line = Path()
            line.move(to: .zero)
            line.addLine(to: CGPoint(x: to.x * size.width - point.x, y: to.y * size.height - point.y))
            ctx.stroke(line, with: .color(color.opacity(0.35)), lineWidth: 8)
            ctx.stroke(line, with: .color(color), lineWidth: 3)
        }
    }
}

// MARK: - Path helpers

/// Keys around an oval: center, radii, start angle (degrees, 0 = right, 90 = down) and turns.
func ovalKeys(cx: Double, cy: Double, rx: Double, ry: Double, from start: Double = 0, turns: Double = 1,
              steps: Int = 16, t0: Double = 0, t1: Double = 1, lean: Double = 0) -> [DemoKey] {
    (0...steps).map { i in
        let f = Double(i) / Double(steps)
        let a = (start + 360 * turns * f) * .pi / 180
        return DemoKey(t: t0 + (t1 - t0) * f, x: cx + rx * cos(a), y: cy + ry * sin(a), turn: lean)
    }
}

/// Keys along a straight line, with an optional series of hops (`hops` jumps of height `hop`).
func lineKeys(from a: (Double, Double), to b: (Double, Double), t0: Double = 0, t1: Double = 1,
              hops: Int = 0, hop: Double = 0, steps: Int = 12) -> [DemoKey] {
    (0...steps).map { i in
        let f = Double(i) / Double(steps)
        let lift = hops > 0 ? hop * abs(sin(f * .pi * Double(hops))) : 0
        return DemoKey(t: t0 + (t1 - t0) * f, x: a.0 + (b.0 - a.0) * f, y: a.1 + (b.1 - a.1) * f - lift)
    }
}
