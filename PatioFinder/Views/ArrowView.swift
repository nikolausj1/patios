import SwiftUI

/// A bold, rounded arrow that rotates to point toward the target.
/// Distinct from Find My: warm amber fill, soft glow when aligned.
struct ArrowView: View {
    /// Degrees to rotate. 0 = pointing straight up (toward the patio).
    var rotation: Double
    var isAligned: Bool
    var isActive: Bool          // false when heading/target unavailable → dimmed

    var body: some View {
        ZStack {
            // Faint guide ring, like a compass bezel.
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 2)

            // Tick at the top marking "straight ahead".
            Capsule()
                .fill(Color.primary.opacity(isAligned ? 0.0 : 0.12))
                .frame(width: 4, height: 14)
                .offset(y: -140)

            ArrowShape()
                .fill(arrowGradient)
                .frame(width: 120, height: 150)
                .shadow(color: Theme.accent.opacity(isAligned ? 0.55 : 0.25),
                        radius: isAligned ? 28 : 14, y: 6)
                .rotationEffect(.degrees(rotation))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: rotation)
                .opacity(isActive ? 1 : 0.25)
        }
        .frame(width: 300, height: 300)
        .animation(.easeInOut(duration: 0.25), value: isAligned)
    }

    private var arrowGradient: LinearGradient {
        LinearGradient(
            colors: isAligned
                ? [Theme.accentBright, Theme.accent]
                : [Theme.accent, Theme.accentDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// A rounded, tapered arrow pointing up.
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        let tip = CGPoint(x: w * 0.5, y: 0)
        let leftWing = CGPoint(x: w * 0.02, y: h * 0.62)
        let rightWing = CGPoint(x: w * 0.98, y: h * 0.62)
        let leftNotch = CGPoint(x: w * 0.5 - w * 0.16, y: h * 0.5)
        let rightNotch = CGPoint(x: w * 0.5 + w * 0.16, y: h * 0.5)
        let tailLeft = CGPoint(x: w * 0.5 - w * 0.16, y: h)
        let tailRight = CGPoint(x: w * 0.5 + w * 0.16, y: h)

        p.move(to: tip)
        p.addQuadCurve(to: rightWing, control: CGPoint(x: w * 0.72, y: h * 0.10))
        p.addQuadCurve(to: rightNotch, control: CGPoint(x: w * 0.62, y: h * 0.60))
        p.addLine(to: tailRight)
        p.addLine(to: tailLeft)
        p.addLine(to: leftNotch)
        p.addQuadCurve(to: leftWing, control: CGPoint(x: w * 0.38, y: h * 0.60))
        p.addQuadCurve(to: tip, control: CGPoint(x: w * 0.28, y: h * 0.10))
        p.closeSubpath()
        return p
    }
}
