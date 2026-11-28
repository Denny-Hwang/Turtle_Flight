import SwiftUI

/// Floating thumb stick (joystick / mixed control modes).
///
/// Touch anywhere in the lower half on the stick side and the stick
/// appears under the thumb; drag to steer (left/right) and climb (up) or
/// dive (down). Let go and the knob springs back. While idle, a faint
/// stick rests in the corner so the player knows where to put a thumb.
/// In mixed mode the knob moves only up/down — tilt does the turning.
struct JoystickOverlay: View {
    let stick: StickInput
    /// Left-handed layout (Boost swaps to the right).
    let onLeft: Bool
    /// Only the vertical axis is live (mixed mode).
    let verticalOnly: Bool
    /// Push up = dive.
    let invertPitch: Bool

    static let radius: CGFloat = 60      // knob travel; base is 2 × radius
    static let knobSize: CGFloat = 56
    /// The idle hint is drawn smaller so it clears the mission chips.
    static let idleScale: CGFloat = 0.8

    @State private var origin: CGPoint?
    @State private var knob: CGSize = .zero
    @State private var atEdge = false

    var body: some View {
        GeometryReader { proxy in
            let zone = Self.touchZone(in: proxy.size, onLeft: onLeft)
            let rest = Self.restingCenter(in: proxy.size, onLeft: onLeft)
            let center = origin ?? rest
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: zone.width, height: zone.height)
                    .position(x: zone.midX, y: zone.midY)
                    .gesture(drag)

                Circle()
                    .fill(Theme.Color.surfacePanel.opacity(0.35))
                    .overlay(Circle().stroke(Theme.Color.textOnDark.opacity(0.6), lineWidth: 2))
                    .frame(width: Self.radius * 2, height: Self.radius * 2)
                    .overlay(verticalOnly ? guideLine : nil)
                    .scaleEffect(origin == nil ? Self.idleScale : 1)
                    .position(center)
                    .allowsHitTesting(false)

                Circle()
                    .fill(atEdge ? Theme.Color.starGold : Theme.Color.textOnDark)
                    .frame(width: Self.knobSize, height: Self.knobSize)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .scaleEffect(origin == nil ? Self.idleScale : 1)
                    .position(x: center.x + knob.width, y: center.y + knob.height)
                    .allowsHitTesting(false)
            }
            .opacity(origin == nil ? 0.45 : 0.9)
            .coordinateSpace(name: Self.space)
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.t("a11y.joystick"))
        .accessibilityHint(L10n.t(verticalOnly ? "a11y.joystick.hint.vertical" : "a11y.joystick.hint"))
    }

    private static let space = "joystick"

    private var guideLine: some View {
        Capsule()
            .fill(Theme.Color.textOnDark.opacity(0.35))
            .frame(width: 4, height: Self.radius * 1.6)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if origin == nil { origin = value.startLocation }
                let offset = Self.knobOffset(translation: value.translation, verticalOnly: verticalOnly)
                knob = offset
                let v = Self.normalized(offset, invertPitch: invertPitch)
                stick.hold(x: v.x, y: v.y)
                let edge = (offset.width * offset.width + offset.height * offset.height)
                    > Self.radius * Self.radius * 0.95
                if edge && !atEdge { Haptics.shared.play(.tap) }
                atEdge = edge
            }
            .onEnded { _ in
                stick.release()
                atEdge = false
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    knob = .zero
                    origin = nil
                }
            }
    }

    // MARK: - Geometry (static for tests)

    /// Lower 70% of the stick-side half of the screen.
    static func touchZone(in size: CGSize, onLeft: Bool) -> CGRect {
        CGRect(x: onLeft ? 0 : size.width / 2, y: size.height * 0.3,
               width: size.width / 2, height: size.height * 0.7)
    }

    /// Idle stick: tucked low in the corner, under the mission chips
    /// (score / rings / bumps sit mid-height on the right).
    static func restingCenter(in size: CGSize, onLeft: Bool) -> CGPoint {
        let side = radius + 36
        return CGPoint(x: onLeft ? side : size.width - side, y: size.height - radius - 6)
    }

    /// Knob offset for a drag, clamped to the base.
    static func knobOffset(translation: CGSize, verticalOnly: Bool) -> CGSize {
        var dx = verticalOnly ? 0 : translation.width
        var dy = translation.height
        let length = (dx * dx + dy * dy).squareRoot()
        if length > radius {
            dx *= radius / length
            dy *= radius / length
        }
        return CGSize(width: dx, height: dy)
    }

    /// Knob offset → stick value: x + right, y + climb (screen up). The
    /// round base is stretched onto a square so pushing to the rim on a
    /// diagonal gives full turn and full climb together.
    static func normalized(_ offset: CGSize, invertPitch: Bool) -> SIMD2<Double> {
        var x = Double(offset.width / radius)
        var y = Double(-offset.height / radius)
        let length = (x * x + y * y).squareRoot()
        let major = max(abs(x), abs(y))
        if major > 1e-9 {
            let stretch = length / major
            x *= stretch
            y *= stretch
        }
        return SIMD2(x.clamped(to: -1...1), (invertPitch ? -y : y).clamped(to: -1...1))
    }
}
