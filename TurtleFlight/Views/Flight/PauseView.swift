import SwiftUI

/// In-flight pause modal. Three actions:
///   • Resume   — close the modal, recalibrate gyro, continue flight
///   • Restart  — respawn the character at the start position; for Step
///                Goal, also restart the current stage's rings
///   • Quit     — stop the flight and dismiss the FlightView (back to
///                home / character-select)
///
/// Triggered by the explicit Pause button on ControlButtons OR by the
/// app moving to the background. The latter is critical for Apple HIG
/// compliance — players who get a phone call should NOT lose progress.
struct PauseView: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            // Dim the 3D scene behind us, but don't fully blackout —
            // keeps the spatial context so resume doesn't feel like a
            // hard cut.
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                Image(systemName: "pause.circle.fill")
                    .resizable()
                    .frame(width: 56, height: 56)
                    .foregroundColor(Theme.Color.textOnDark)

                Text(L10n.t("flight.pause.title"))
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Color.textOnDark)

                Text(L10n.t("flight.pause.subtitle"))
                    .font(Theme.Typography.bodyDynamic)
                    .foregroundColor(Theme.Color.textOnDarkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.m) {
                    PauseButton(
                        title: L10n.t("flight.pause.resume"),
                        systemImage: "play.fill",
                        color: Theme.Color.brandPrimary,
                        action: onResume
                    )
                    .accessibilityHint(L10n.t("flight.pause.resume.hint"))

                    PauseButton(
                        title: L10n.t("flight.pause.restart"),
                        systemImage: "arrow.counterclockwise",
                        color: Theme.Color.boostOrange,
                        action: onRestart
                    )
                    .accessibilityHint(L10n.t("flight.pause.restart.hint"))

                    PauseButton(
                        title: L10n.t("flight.pause.quit"),
                        systemImage: "xmark",
                        color: Theme.Color.surfaceOverlayStrong,
                        action: onQuit
                    )
                    .accessibilityHint(L10n.t("flight.pause.quit.hint"))
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xl)
                    .fill(Theme.Color.surfacePanel)
                    .elevation(Theme.Elevation.cardHigh)
            )
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }
}

// MARK: - Pause action button

private struct PauseButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            // Light haptic so the modal feels responsive even before the
            // underlying view-state animates.
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(Theme.Typography.button)
            }
            .foregroundColor(Theme.Color.textOnDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.m + 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .fill(color)
            )
        }
    }
}

#Preview {
    PauseView(onResume: {}, onRestart: {}, onQuit: {})
}
