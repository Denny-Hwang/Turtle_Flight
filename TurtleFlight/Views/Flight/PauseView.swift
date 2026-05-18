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
    /// When true, the Restart button surfaces a confirmation dialog
    /// before firing `onRestart`. Used by Step Goal mid-mission so a
    /// player who tapped Pause to read the screen doesn't lose ring /
    /// star / time progress by a misplaced tap. Free Flight and
    /// stage-not-yet-started pauses bypass the dialog because there's
    /// no in-flight progress to protect.
    var restartRequiresConfirmation: Bool = false
    /// Optional in-flight sensitivity binding. When supplied, the pause
    /// modal surfaces a 3-button selector under the action buttons so
    /// the player can swap Easy/Normal/Expert without going Exit →
    /// Home → Settings → Done → Mode → Stage → Character → Fly. nil
    /// hides the selector entirely (useful for previews / contexts
    /// without a live FlightViewModel).
    var sensitivityLevel: Binding<SensitivityLevel>? = nil

    @State private var showRestartConfirm = false

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
                        action: {
                            if restartRequiresConfirmation {
                                showRestartConfirm = true
                            } else {
                                onRestart()
                            }
                        }
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

                // In-flight sensitivity selector. Surfaced only when the
                // caller passed a binding — previews and tests that omit
                // it get the original 3-button modal. The point of
                // surfacing this here is that swapping Easy↔Normal mid-
                // mission previously required Exit → Home → Settings →
                // 5 more taps; for a kids-rated game the "this feels
                // too sensitive" reaction needs to be 1 tap from where
                // the player is right now.
                if let sensitivityLevel {
                    SensitivityRow(selection: sensitivityLevel)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
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
        .confirmationDialog(
            L10n.t("flight.pause.restart.confirm.title"),
            isPresented: $showRestartConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.t("flight.pause.restart.confirm.action"),
                   role: .destructive) {
                onRestart()
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t("flight.pause.restart.confirm.message"))
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

// MARK: - Sensitivity row

/// Three-button picker shown inside PauseView when a sensitivity
/// binding is provided. The visual style matches Home's
/// `SensitivityButton` row at a smaller, denser scale — players
/// already recognise this layout from first-run.
private struct SensitivityRow: View {
    @Binding var selection: SensitivityLevel

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(L10n.t("home.sensitivity.label"))
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Color.textOnDarkMuted)
            HStack(spacing: Theme.Spacing.s) {
                ForEach(SensitivityLevel.allCases, id: \.self) { level in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selection = level
                    } label: {
                        Text("\(level.emoji)  \(level.displayName)")
                            .font(Theme.Typography.labelSmall)
                            .foregroundColor(selection == level
                                             ? Theme.Color.textOnDark
                                             : Theme.Color.textOnDarkMuted)
                            .padding(.vertical, Theme.Spacing.xs + 2)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.s)
                                    .fill(selection == level
                                          ? tint(for: level)
                                          : Theme.Color.surfaceOverlayStrong)
                            )
                    }
                    .accessibilityLabel(L10n.t("a11y.sensitivity.\(level.rawValue).label"))
                    .accessibilityHint(L10n.t("a11y.sensitivity.hint"))
                    .accessibilityAddTraits(selection == level ? .isSelected : [])
                }
            }
        }
    }

    private func tint(for level: SensitivityLevel) -> Color {
        switch level {
        case .easy:   return Theme.Color.easyGreen
        case .normal: return Theme.Color.normalYellow
        case .expert: return Theme.Color.expertRed
        }
    }
}

#Preview {
    PauseView(onResume: {}, onRestart: {}, onQuit: {})
}
