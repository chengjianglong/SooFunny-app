import SwiftUI

/// "SooFunny" with each letter gently bouncing in turn, at the top of every tab.
struct BouncyTitle: View {
    private let letters = Array("SooFunny")
    private let colors: [Color] = [.pink, .orange, .yellow, .green, .teal, .blue, .indigo, .purple]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 0) {
                ForEach(letters.indices, id: \.self) { i in
                    let phase = t * 3 - Double(i) * 0.45
                    Text(String(letters[i]))
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(colors[i % colors.count].gradient)
                        .shadow(color: .black.opacity(0.12), radius: 0, x: 2, y: 3)
                        .offset(y: -max(0, sin(phase)) * 10)
                        .rotationEffect(.degrees(sin(phase) * 4))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("SooFunny")
        .accessibilityAddTraits(.isHeader)
    }
}
