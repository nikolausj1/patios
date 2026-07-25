import SwiftUI

/// A polished navigation-pointer that rotates to point toward the target,
/// sitting inside a ticked compass bezel. Warm amber, glassy highlight,
/// soft glow that blooms when aligned.
struct ArrowView: View {
    /// Degrees to rotate. 0 = pointing straight up (toward the patio).
    var rotation: Double
    var isAligned: Bool
    var isActive: Bool          // false when heading/target unavailable → dimmed

    private let size: CGFloat = 300

    var body: some View {
        ZStack {
            // Soft radial glow that blooms when aligned.
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.accent.opacity(isAligned ? 0.30 : 0.10), .clear],
                    center: .center, startRadius: 20, endRadius: size * 0.55))

            bezel

            // Top marker: lights amber when you're pointed right at the patio.
            Capsule()
                .fill(isAligned ? Theme.accent : Color.primary.opacity(0.15))
                .frame(width: 4, height: 16)
                .offset(y: -(size / 2 - 8))

            arrow
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.25), value: isAligned)
    }

    // MARK: - Bezel (compass ticks)

    private var bezel: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: 1.5)

            ForEach(0..<60, id: \.self) { i in
                let isMajor = i % 15 == 0   // N / E / S / W positions
                Capsule()
                    .fill(Color.primary.opacity(isMajor ? 0.22 : 0.09))
                    .frame(width: isMajor ? 3 : 1.5, height: isMajor ? 13 : 6)
                    .offset(y: -(size / 2 - 18))
                    .rotationEffect(.degrees(Double(i) * 6))
            }
        }
    }

    // MARK: - Arrow

    private var arrow: some View {
        ZStack {
            NavArrowShape()
                .fill(arrowGradient)

            // Glassy specular highlight down the top half.
            NavArrowShape()
                .fill(LinearGradient(
                    colors: [.white.opacity(0.38), .white.opacity(0)],
                    startPoint: .top, endPoint: .center))

            // Hairline rim to lift it off the background.
            NavArrowShape()
                .stroke(LinearGradient(
                    colors: [.white.opacity(0.55), .white.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
        }
        .frame(width: 150, height: 162)
        .shadow(color: Theme.accent.opacity(isAligned ? 0.60 : 0.28),
                radius: isAligned ? 30 : 16, y: 8)
        .scaleEffect(isAligned ? 1.05 : 1)
        .rotationEffect(.degrees(rotation))
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: rotation)
        .opacity(isActive ? 1 : 0.25)
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

/// Classic navigation-pointer silhouette (tip up, notched tail) with
/// gently rounded vertices.
struct NavArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        let tip   = CGPoint(x: 0.50 * w, y: 0)
        let right = CGPoint(x: 0.94 * w, y: 0.88 * h)
        let notch = CGPoint(x: 0.50 * w, y: 0.64 * h)
        let left  = CGPoint(x: 0.06 * w, y: 0.88 * h)
        let r = 0.07 * w   // corner rounding radius

        var p = Path()
        p.move(to: along(tip, toward: left, by: r * 1.8))
        p.addQuadCurve(to: along(tip, toward: right, by: r * 1.8), control: tip)
        p.addLine(to: along(right, toward: tip, by: r))
        p.addQuadCurve(to: along(right, toward: notch, by: r), control: right)
        p.addLine(to: along(notch, toward: right, by: r))
        p.addQuadCurve(to: along(notch, toward: left, by: r), control: notch)
        p.addLine(to: along(left, toward: notch, by: r))
        p.addQuadCurve(to: along(left, toward: tip, by: r), control: left)
        p.closeSubpath()
        return p
    }

    /// Point `d` pts from `a` along the segment toward `b`.
    private func along(_ a: CGPoint, toward b: CGPoint, by d: CGFloat) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(sqrt(dx * dx + dy * dy), 0.0001)
        return CGPoint(x: a.x + dx / len * d, y: a.y + dy / len * d)
    }
}
