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
    /// Drives the objective compass arrow under the stage title. The
    /// arrow rotates to always point at the next ring relative to the
    /// player's heading; published from FlightViewModel each frame as
    /// `directionToObjective`.
    @ObservedObject var flightVM: FlightViewModel

    var body: some View {
        GeometryReader { proxy in
            VStack {
                // Top: Stage title + Timer + Objective arrow
                HStack {
                    Spacer()

                    if let stage = missionVM.currentStage {
                        VStack(spacing: Theme.Spacing.xs) {
                            Text(L10n.format("mission.stage.titleFormat", stage.index + 1, stage.displayName))
                                .font(Theme.Typography.label)
                                .foregroundColor(Theme.Color.textOnDark)
                                .accessibilityAddTraits(.isHeader)

                            if let remaining = missionEngine.remainingTime {
                                Text(remaining.mmss)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(missionEngine.isTimeCritical
                                        ? Theme.Color.expertRed
                                        : Theme.Color.textOnDark
                                    )
                                    .accessibilityLabel(L10n.format("a11y.mission.remaining.format", remaining.mmss))
                            }

                            objectiveArrow
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
                // Safe-area-aware top inset. In landscape on Dynamic-Island
                // devices the top inset is ~0 but on iPad it grows; on
                // older iPhones with no notch it stays at 0. Adding a
                // minimum 12pt guarantees breathing room either way and
                // never crowds the Dynamic Island when the inset is real.
                .padding(.top, max(proxy.safeAreaInsets.top, Theme.Spacing.m))

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
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.format("a11y.mission.progress.format", missionEngine.progressText))

                        // Collision counter. Once collisions > 0 we
                        // (a) tint the icon red, (b) bold the count,
                        // and (c) draw a red rim around the chip. Three
                        // independent channels (icon shape + colour +
                        // border weight) so a colour-blind player still
                        // reads the warning even if red↔green looks the
                        // same to them.
                        let hit = missionEngine.collisions > 0
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: hit
                                  ? "exclamationmark.triangle.fill"
                                  : "checkmark.circle.fill")
                                .foregroundColor(hit
                                    ? Theme.Color.expertRed
                                    : Theme.Color.easyGreen
                                )
                            Text(L10n.format("mission.collisions.format", missionEngine.collisions))
                                .font(hit
                                      ? Theme.Typography.caption.weight(.bold)
                                      : Theme.Typography.caption)
                                .foregroundColor(Theme.Color.textOnDark)
                        }
                        .padding(.horizontal, Theme.Spacing.s + 2)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                                .fill(Theme.Color.surfaceOverlaySubtle)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.xs)
                                        .stroke(hit ? Theme.Color.expertRed : .clear,
                                                lineWidth: 2)
                                )
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.format("a11y.mission.collisions.format", missionEngine.collisions))
                    }
                    // Safe-area-aware trailing inset. Landscape on
                    // Dynamic-Island devices puts the inset on the leading
                    // edge, so the right side is usually zero — Theme.l
                    // alone is enough. Keeping max() guards iPad.
                    .padding(.trailing, max(proxy.safeAreaInsets.trailing, Theme.Spacing.l))
                }

                Spacer()
            }
        }
        // The HUD is purely informational; touches always pass through to
        // the SceneKit scene. Modal overlays (StageResultView, PauseView)
        // are siblings, not children, of this view.
        .allowsHitTesting(false)
    }

    /// Compass-style chevron under the stage title that always points at
    /// the next ring relative to the player's heading. Hidden when no
    /// objective is active (between stages, or on a completed/failed
    /// run). The bearing tint flips green when the player is roughly on
    /// course (±20°) so the visual reinforces "you're heading the right
    /// way" without needing words.
    @ViewBuilder
    private var objectiveArrow: some View {
        if let bearing = flightVM.directionToObjective {
            let onCourse = abs(bearing) < .pi / 9   // 20°
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(onCourse
                        ? Theme.Color.easyGreen
                        : Theme.Color.starGold
                    )
                    .rotationEffect(.radians(bearing))
                    .animation(.easeOut(duration: 0.15), value: bearing)
                Text(missionEngine.progressText)
                    .font(Theme.Typography.microLabel)
                    .foregroundColor(Theme.Color.textOnDarkMuted)
            }
        }
    }
}
