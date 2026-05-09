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
                    VStack(spacing: 4) {
                        Text(L10n.format("mission.stage.titleFormat", stage.index + 1, stage.displayName))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        if let remaining = missionEngine.remainingTime {
                            Text(remaining.mmss)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(missionEngine.isTimeCritical ?
                                    Color(hex: Constants.Colors.expertRed) :
                                    Color.white
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: Constants.Colors.panelDark).opacity(0.8))
                    )
                }

                Spacer()
            }
            .padding(.top, 50)

            Spacer()

            // Right side: Progress + Collisions
            HStack {
                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    // Ring progress
                    HStack(spacing: 4) {
                        Image(systemName: "circle.dashed")
                            .foregroundColor(Color(hex: Constants.Colors.hudCyan))
                        Text(missionEngine.progressText)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: Constants.Colors.panelDark).opacity(0.7))
                    )

                    // Collision counter
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(missionEngine.collisions > 0 ?
                                Color(hex: Constants.Colors.expertRed) :
                                Color(hex: Constants.Colors.easyGreen)
                            )
                        Text(L10n.format("mission.collisions.format", missionEngine.collisions))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: Constants.Colors.panelDark).opacity(0.6))
                    )
                }
                .padding(.trailing, 16)
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
        VStack(spacing: 16) {
            Text(L10n.t("mission.result.clear"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(hex: Constants.Colors.starGold))

            if let result = missionVM.lastResult {
                // Stars
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < result.stars ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: Constants.Colors.starGold))
                    }
                }

                Text(L10n.format("mission.result.timeFormat", result.completionTime.mmss))
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                Text(L10n.format("mission.result.collisionsFormat", result.collisions))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }

            HStack(spacing: 16) {
                Button(L10n.t("common.home")) {
                    missionVM.returnToSelect()
                    onExit?()
                }
                .buttonStyle(MissionButtonStyle(color: Color(hex: Constants.Colors.panelDark)))

                Button(L10n.t("common.retry")) {
                    missionVM.returnToSelect()
                }
                .buttonStyle(MissionButtonStyle(color: Color(hex: Constants.Colors.boostOrange)))

                Button(L10n.t("common.next")) {
                    missionVM.returnToSelect()
                }
                .buttonStyle(MissionButtonStyle(color: Color(hex: Constants.Colors.easyGreen)))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: Constants.Colors.panelDark).opacity(0.9))
        )
    }

    private func failOverlay(reason: String) -> some View {
        VStack(spacing: 16) {
            Text(L10n.t("mission.result.failed"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: Constants.Colors.expertRed))

            Text(reason)
                .font(.system(size: 14))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                Button(L10n.t("common.home")) {
                    missionVM.returnToSelect()
                    onExit?()
                }
                .buttonStyle(MissionButtonStyle(color: Color(hex: Constants.Colors.panelDark)))

                Button(L10n.t("common.retry")) {
                    missionVM.returnToSelect()
                }
                .buttonStyle(MissionButtonStyle(color: Color(hex: Constants.Colors.boostOrange)))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: Constants.Colors.panelDark).opacity(0.9))
        )
    }
}

struct MissionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
