import SwiftUI

/// Screen-edge pointer to the target ring when it is out of view: a gold
/// arrow on the edge in the ring's direction plus the distance. Behind
/// the player it sits low on the side to turn toward and says so.
struct RingGuideIndicator: View {
    let guide: RingGuide?

    /// Distance from the screen edge to the chip centre.
    private let inset: CGFloat = 56

    var body: some View {
        GeometryReader { proxy in
            if let guide, guide.showsGuide {
                let p = guide.edgePoint
                let w = proxy.size.width / 2 - inset
                let h = proxy.size.height / 2 - inset
                let angle = Angle(radians: atan2(Double(p.y * h), Double(p.x * w)))
                chip(guide: guide, angle: angle)
                    .position(x: proxy.size.width / 2 + p.x * w,
                              y: proxy.size.height / 2 + p.y * h)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: guide?.displayKey)
        .allowsHitTesting(false)
    }

    private func chip(guide: RingGuide, angle: Angle) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Theme.Color.surfacePanel.opacity(0.75))
                    .frame(width: 40, height: 40)
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Color.starGold)
                    .rotationEffect(angle)
            }
            Text(guide.isBehind
                 ? L10n.t("hud.ringGuide.behind")
                 : "\(Int(guide.distance.rounded() / 10) * 10) m")
                .font(Theme.Typography.labelSmall)
                .foregroundColor(Theme.Color.textOnDark)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.Color.surfacePanel.opacity(0.75)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("hud.ringGuide.a11y", Int(guide.distance)))
    }
}
