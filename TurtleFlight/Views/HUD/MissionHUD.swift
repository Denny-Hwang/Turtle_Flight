import SwiftUI

struct MissionHUD: View {
    let missionEngine: MissionEngine
    @ObservedObject var missionVM: MissionViewModel
    var onExit: (() -> Void)?

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

            // Result overlay
            if case .completed = missionVM.missionState {
                resultOverlay
            }

            if case .failed(let reason) = missionVM.missionState {
                failOverlay(reason: reason)
            }
        }
        .allowsHitTesting(missionVM.missionState != .playing)
    }

    // MARK: - Result Overlay

    private var resultOverlay: some View {
        VStack(spacing: Theme.Spacing.l) {
            Text(L10n.t("mission.result.clear"))
                .font(Theme.Typography.displayMedium)
                .foregroundColor(Theme.Color.starGold)

            if let result = missionVM.lastResult {
                // Stars
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < result.stars ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Color.starGold)
                    }
                }

                Text(L10n.format("mission.result.timeFormat", result.completionTime.mmss))
                    .font(Theme.Typography.bodyLarge)
                    .foregroundColor(Theme.Color.textOnDark)

                Text(L10n.format("mission.result.collisionsFormat", result.collisions))
                    .font(Theme.Typography.bodyLarge)
                    .foregroundColor(Theme.Color.textOnDark)
            }

            HStack(spacing: Theme.Spacing.l) {
                Button(L10n.t("common.home")) {
                    missionVM.returnToSelect()
                    onExit?()
                }
                .buttonStyle(MissionButtonStyle(color: Theme.Color.surfaceOverlay))

                Button(L10n.t("common.retry")) {
                    restartCurrentStage()
                }
                .buttonStyle(MissionButtonStyle(color: Theme.Color.boostOrange))

                if missionVM.hasNextStage {
                    Button(L10n.t("common.next")) {
                        advanceToNextStage()
                    }
                    .buttonStyle(MissionButtonStyle(color: Theme.Color.easyGreen))
                }
            }
        }
        .padding(Theme.Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl)
                .fill(Theme.Color.surfacePanel)
        )
    }

    private func failOverlay(reason: String) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            Text(L10n.t("mission.result.failed"))
                .font(Theme.Typography.titleLarge)
                .foregroundColor(Theme.Color.expertRed)

            Text(reason)
                .font(Theme.Typography.bodyLarge)
                .foregroundColor(Theme.Color.textOnDark)

            HStack(spacing: Theme.Spacing.l) {
                Button(L10n.t("common.home")) {
                    missionVM.returnToSelect()
                    onExit?()
                }
                .buttonStyle(MissionButtonStyle(color: Theme.Color.surfaceOverlay))

                Button(L10n.t("common.retry")) {
                    restartCurrentStage()
                }
                .buttonStyle(MissionButtonStyle(color: Theme.Color.boostOrange))
            }
        }
        .padding(Theme.Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl)
                .fill(Theme.Color.surfacePanel)
        )
    }
}

    // MARK: - Stage transitions
    //
    // Both Retry and Next stay in-flight: we restart the MissionEngine
    // (which clears prior rings and resets timer/collisions) and flip
    // missionVM back into `.playing`. The character keeps flying — only
    // the objective layer changes underneath them.

    private func restartCurrentStage() {
        guard let stage = missionVM.currentStage else { return }
        missionEngine.startStage(stage)
        missionVM.startMission()
    }

    private func advanceToNextStage() {
        guard missionVM.advanceToNextStage(),
              let stage = missionVM.currentStage else { return }
        missionEngine.startStage(stage)
        missionVM.startMission()
    }
}

struct MissionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.button)
            .foregroundColor(Theme.Color.textOnDark)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.s + 2)
                    .fill(color)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
