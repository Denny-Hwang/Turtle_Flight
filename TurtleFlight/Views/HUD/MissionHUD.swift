import SwiftUI

/// Mission-specific HUD chrome: stage-title pill + remaining-time badge
/// at the top, ring progress + collision counter on the right.
///
/// The result/fail overlays previously rendered inline here have moved
/// to the full-screen `StageResultView` owned by FlightView. MissionHUD
/// is now purely the in-flight chrome.
struct MissionHUD: View {
    let missionEngine: MissionEngine
    @ObservedObject var missionVM: MissionViewModel

    var body: some View {
        VStack {
            // Top: Stage title + Timer
            HStack {
                Spacer()

                if let stage = missionVM.currentStage {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text(L10n.format("mission.stage.titleFormat", stage.index + 1, stage.displayName))
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Color.textOnDark)

                        if let remaining = missionEngine.remainingTime {
                            Text(remaining.mmss)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(missionEngine.isTimeCritical
                                    ? Theme.Color.expertRed
                                    : Theme.Color.textOnDark
                                )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.s + 2)
                            .fill(Theme.Color.surfaceOverlayStrong)
                    )
                }

                Spacer()
            }
            .padding(.top, 50)

            Spacer()

            // Right side: Progress + Collisions
            HStack {
                Spacer()

                VStack(alignment: .trailing, spacing: Theme.Spacing.s) {
                    // Ring progress
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "circle.dashed")
                            .foregroundColor(Theme.Color.hudCyan)
                        Text(missionEngine.progressText)
                            .font(Theme.Typography.hudGaugeSmall)
                            .foregroundColor(Theme.Color.textOnDark)
                    }
                    .padding(.horizontal, Theme.Spacing.s + 2)
                    .padding(.vertical, Theme.Spacing.s - 2)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.s)
                            .fill(Theme.Color.surfaceOverlay)
                    )

                    // Collision counter
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(missionEngine.collisions > 0
                                ? Theme.Color.expertRed
                                : Theme.Color.easyGreen
                            )
                        Text(L10n.format("mission.collisions.format", missionEngine.collisions))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Color.textOnDark)
                    }
                    .padding(.horizontal, Theme.Spacing.s + 2)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.xs)
                            .fill(Theme.Color.surfaceOverlaySubtle)
                    )
                }
                .padding(.trailing, Theme.Spacing.l)
            }

            Spacer()
        }
        // The HUD is purely informational; touches always pass through to
        // the SceneKit scene. Modal overlays (StageResultView, PauseView)
        // are siblings, not children, of this view.
        .allowsHitTesting(false)
    }
}
