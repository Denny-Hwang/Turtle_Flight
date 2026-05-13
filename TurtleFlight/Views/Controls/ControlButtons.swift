import SwiftUI

struct ControlButtons: View {
    let onBoost: () -> Void
    /// Optional fire-item handler. Nil hides the bottom-right item button
    /// entirely — v1 keeps it hidden because the underlying projectile has
    /// no impact behaviour yet (DESIGN_GAP_REPORT P1-2). A future release
    /// that adds scoring targets re-introduces a non-nil handler.
    let onFire: (() -> Void)?
    let onCalibrate: () -> Void
    let onPause: () -> Void
    let onExit: () -> Void
    /// Boost ring fill in [0, 1]. 0 = idle (no ring drawn), 1 = full
    /// duration just-fired. Drains as the boost timer counts down so the
    /// player can read remaining boost at a glance.
    var boostProgress: Float = 0

    var body: some View {
        VStack {
            // Top-right: Calibrate + Pause + Exit
            HStack {
                Spacer()

                HStack(spacing: Theme.Spacing.m) {
                    // Calibrate button
                    SmallButton(icon: "scope", label: L10n.t("flight.control.calibrate")) {
                        onCalibrate()
                    }
                    .accessibilityLabel(L10n.t("a11y.calibrate.label"))
                    .accessibilityHint(L10n.t("a11y.calibrate.hint"))

                    // Pause button
                    SmallButton(icon: "pause.fill", label: L10n.t("flight.control.pause")) {
                        onPause()
                    }
                    .accessibilityLabel(L10n.t("a11y.pause.label"))
                    .accessibilityHint(L10n.t("a11y.pause.hint"))

                    // Exit button
                    SmallButton(icon: "xmark", label: L10n.t("flight.control.exit")) {
                        onExit()
                    }
                    .accessibilityLabel(L10n.t("a11y.exit.label"))
                    .accessibilityHint(L10n.t("a11y.exit.hint"))
                }
                .padding(.trailing, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
            }

            Spacer()

            // Bottom: Boost (left) + Fire (right)
            HStack {
                // Boost Button (left bottom). The progress ring drains
                // from full → empty as the boost timer counts down so
                // the player can read remaining boost at a glance.
                ThumbButton(
                    icon: "flame.fill",
                    label: L10n.t("flight.control.boost"),
                    color: Theme.Color.boostOrange,
                    progress: boostProgress,
                    action: onBoost
                )
                .padding(.leading, Constants.Controls.buttonPadding)
                .accessibilityLabel(L10n.t("a11y.boost.label"))
                .accessibilityHint(L10n.t("a11y.boost.hint"))

                Spacer()

                // Fire Button (right bottom). v1 hides this entirely
                // because the projectile has no impact behaviour yet —
                // showing a useless button trains the player to ignore
                // controls, which is worse than just not offering them.
                // A future release that wires up a scoring target
                // re-introduces this by passing a non-nil onFire.
                if let onFire {
                    ThumbButton(
                        icon: "star.fill",
                        label: L10n.t("flight.control.item"),
                        color: Theme.Color.starGold,
                        action: onFire
                    )
                    .padding(.trailing, Constants.Controls.buttonPadding)
                    .accessibilityLabel(L10n.t("a11y.item.label"))
                    .accessibilityHint(L10n.t("a11y.item.hint"))
                } else {
                    // Reserve symmetric trailing space so the boost
                    // button doesn't drift to centre when the item slot
                    // is empty.
                    Color.clear
                        .frame(width: Constants.Controls.buttonSize,
                               height: Constants.Controls.buttonSize)
                        .padding(.trailing, Constants.Controls.buttonPadding)
                        .accessibilityHidden(true)
                }
            }
            .padding(.bottom, Constants.Controls.buttonPadding)
        }
    }
}

// MARK: - Thumb Button (72pt minimum)

struct ThumbButton: View {
    let icon: String
    let label: String
    let color: Color
    /// Optional progress ring overlay in [0, 1]. 0 hides the ring; >0
    /// draws a circular stroke that fills clockwise from the top so the
    /// player can read remaining time at a glance. Used by the boost
    /// button — the fire button just leaves it at the default.
    var progress: Float = 0
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                Text(label)
                    .font(Theme.Typography.tileLabel)
            }
            .foregroundColor(Theme.Color.textOnDark)
            .frame(width: Constants.Controls.buttonSize, height: Constants.Controls.buttonSize)
            .background(
                Circle()
                    .fill(color)
                    .shadow(color: color.opacity(0.5), radius: 6, y: 2)
            )
            .overlay(progressRing)
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    /// Circular progress overlay drawn just outside the button's circle.
    /// Hidden when progress is zero so idle buttons don't get a 0%-arc
    /// ghost. The white stroke + drop shadow lifts the ring off the
    /// button colour without needing a translucent fill.
    @ViewBuilder
    private var progressRing: some View {
        if progress > 0.001 {
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    Color.white.opacity(0.92),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(2)
                .animation(.linear(duration: 0.12), value: progress)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Small Button (for exit, calibrate)

struct SmallButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundColor(Theme.Color.textOnDark)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(Theme.Color.surfaceOverlay)
            )
        }
    }
}
