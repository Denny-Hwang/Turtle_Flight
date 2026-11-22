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
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var compact: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            // Dim the 3D scene behind us, but don't fully blackout —
            // keeps the spatial context so resume doesn't feel like a
            // hard cut.
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // A landscape iPhone has ~390pt of height: the tall stack
            // (icon + title + 3 buttons + sensitivity) ran off both the
            // top and the bottom there. Compact height drops the icon
            // and puts Restart / Quit side by side; the ScrollView is
            // the last resort for large Dynamic Type.
            ViewThatFits(in: .vertical) {
                panelContent
                ScrollView(.vertical, showsIndicators: false) { panelContent }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: compact ? 460 : 380)
            .background(
                // Opaque, like the result cards: at 90% the 3D scene
                // behind showed through the buttons.
                RoundedRectangle(cornerRadius: Theme.Radius.xl)
                    .fill(Color(hex: Constants.Colors.panelDark))
                    .elevation(Theme.Elevation.cardHigh)
            )
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.s)
            .deviceCanvas()
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

    // MARK: - Panel

    private var panelContent: some View {
        VStack(spacing: compact ? Theme.Spacing.m : Theme.Spacing.l) {
            if !compact {
                Image(systemName: "pause.circle.fill")
                    .resizable()
                    .frame(width: 56, height: 56)
                    .foregroundColor(Theme.Color.textOnDark)
            }

            Text(L10n.t("flight.pause.title"))
                .font(compact ? Theme.Typography.title : Theme.Typography.displayMedium)
                .foregroundColor(Theme.Color.textOnDark)

            Text(L10n.t("flight.pause.subtitle"))
                .font(Theme.Typography.bodyDynamic)
                .foregroundColor(Theme.Color.textOnDarkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.m) {
                resumeButton
                if compact {
                    HStack(spacing: Theme.Spacing.m) {
                        restartButton
                        quitButton
                    }
                } else {
                    restartButton
                    quitButton
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // In-flight sensitivity selector. Surfaced only when the
            // caller passed a binding. Swapping Easy↔Normal mid-mission
            // otherwise needs Exit → Home → Settings → 5 more taps; for
            // a kids-rated game "this feels too sensitive" has to be one
            // tap from where the player is.
            if let sensitivityLevel {
                SensitivityRow(selection: sensitivityLevel)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }

    private var resumeButton: some View {
        PauseButton(
            title: L10n.t("flight.pause.resume"),
            systemImage: "play.fill",
            color: Theme.Color.brandPrimary,
            action: onResume
        )
        .accessibilityHint(L10n.t("flight.pause.resume.hint"))
    }

    private var restartButton: some View {
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
    }

    private var quitButton: some View {
        PauseButton(
            title: L10n.t("flight.pause.quit"),
            systemImage: "xmark",
            // Panel-coloured fill read as bare text on the opaque panel.
            color: Theme.Color.textOnDark.opacity(0.14),
            action: onQuit
        )
        .accessibilityHint(L10n.t("flight.pause.quit.hint"))
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
            Haptics.shared.play(.tap)
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
                        Haptics.shared.play(.tap)
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
                                          : Theme.Color.textOnDark.opacity(0.1))
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
