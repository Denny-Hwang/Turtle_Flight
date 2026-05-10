import SwiftUI

/// Step Goal stage chooser. Replaces the previous "implicit Stage 1 jump"
/// from HomeView when the user picks Step Goal — until this PR there was
/// no actual stage selection UI; the campaign quietly started at
/// `currentStageIndex` (whatever it last was) and the player had no way
/// to navigate to a specific stage.
///
/// Surfaces:
///   • 5 horizontally-scrolling stage cards
///   • Per-stage ★ score earned (out of 3)
///   • Lock icon on stages that haven't been unlocked yet
///   • Difficulty pip ★☆☆☆☆ at the top of each card
///   • Tap unlocked → select stage → push CharacterSelectView
struct StageSelectView: View {
    @ObservedObject var characterVM: CharacterViewModel
    @ObservedObject var flightVM: FlightViewModel
    @ObservedObject var missionVM: MissionViewModel

    @State private var pushCharacterSelect = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Reuse the sky-theme background for visual continuity with
            // Home. The mission flow stays "warm" until you actually
            // start a flight in a different theme.
            LinearGradient(
                colors: MapTheme.sky.uiGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                header
                progressBar
                stageRow
                Spacer(minLength: Theme.Spacing.xxl)
                description
                Spacer(minLength: Theme.Spacing.xxl)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $pushCharacterSelect) {
            CharacterSelectView(
                characterVM: characterVM,
                flightVM: flightVM,
                missionVM: missionVM,
                flightMode: .stepGoal
            )
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(Theme.Color.textPrimary)
            }
            Spacer()
            Text(L10n.t("stageSelect.title"))
                .font(Theme.Typography.titleSmall)
                .foregroundColor(Theme.Color.textPrimary)
            Spacer()
            // Spacer that mirrors the back button's width so the title
            // stays optically centered.
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
    }

    /// "★ 7 / 15" total earned across the campaign.
    private var progressBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "star.fill")
                .foregroundColor(Theme.Color.starGold)
                .font(.system(size: 14))
            Text(L10n.format(
                "stageSelect.progress.format",
                missionVM.progress.totalStars,
                missionVM.stages.count * 3
            ))
            .font(Theme.Typography.label)
            .foregroundColor(Theme.Color.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.xs + 2)
        .background(
            Capsule()
                .fill(Theme.Color.surfaceMuted)
        )
    }

    private var stageRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.m) {
                ForEach(missionVM.stages, id: \.index) { stage in
                    StageCard(
                        stage: stage,
                        unlocked: missionVM.isStageUnlocked(stage.index),
                        starsEarned: missionVM.stageStars(stage.index),
                        isSelected: missionVM.currentStageIndex == stage.index
                    ) {
                        guard missionVM.isStageUnlocked(stage.index) else { return }
                        missionVM.selectStage(stage.index)
                        pushCharacterSelect = true
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
        }
    }

    private var description: some View {
        let stage = missionVM.stages[missionVM.currentStageIndex]
        let unlocked = missionVM.isStageUnlocked(stage.index)
        return VStack(spacing: Theme.Spacing.s) {
            Text(unlocked ? stage.displayDescription : L10n.t("stageSelect.locked.body"))
                .font(Theme.Typography.bodyLarge)
                .foregroundColor(Theme.Color.textPrimary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            if unlocked {
                Text(L10n.format("stageSelect.objective.format", stage.displayStar3Condition))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Color.textPrimary.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }
}

// MARK: - Stage Card

private struct StageCard: View {
    let stage: StageDefinition
    let unlocked: Bool
    let starsEarned: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.s) {
                // Top: stage badge / lock icon
                ZStack {
                    Circle()
                        .fill(badgeFill)
                        .frame(width: 68, height: 68)
                        .shadow(color: badgeFill.opacity(0.4), radius: 6, y: 3)
                    if unlocked {
                        Text("\(stage.index + 1)")
                            .font(Theme.Typography.displayMedium)
                            .foregroundColor(Theme.Color.textOnDark)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.Color.textOnDark.opacity(0.85))
                    }
                }

                // Middle: stage name
                Text(stage.displayName)
                    .font(Theme.Typography.label)
                    .foregroundColor(unlocked ? Theme.Color.textPrimary : Theme.Color.textPrimary.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 36)

                // Difficulty (★☆☆☆☆)
                difficultyPips

                // Earned stars (out of 3) — small below
                earnedStarsRow
            }
            .frame(width: 130, height: 220)
            .padding(.vertical, Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.l)
                    .fill(Color.white.opacity(unlocked ? 0.85 : 0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.l)
                            .stroke(isSelected ? Theme.Color.brandPrimary : Color.clear, lineWidth: 3)
                    )
                    .elevation(isSelected ? Theme.Elevation.cardHigh : Theme.Elevation.card)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.25), value: isSelected)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(unlocked
            ? L10n.t("stageSelect.card.hint.unlocked")
            : L10n.t("stageSelect.card.hint.locked"))
    }

    private var badgeFill: Color {
        if !unlocked { return Theme.Color.surfaceOverlaySubtle }
        // Color shifts with difficulty so the row reads as a ramp.
        switch stage.difficulty {
        case 1: return Theme.Color.easyGreen
        case 2: return Color(hex: 0x29B6F6)
        case 3: return Theme.Color.normalYellow
        case 4: return Theme.Color.boostOrange
        default: return Theme.Color.expertRed
        }
    }

    private var difficultyPips: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < stage.difficulty ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundColor(unlocked ? Theme.Color.normalYellow : Theme.Color.textPrimary.opacity(0.3))
            }
        }
    }

    private var earnedStarsRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < starsEarned ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundColor(i < starsEarned ? Theme.Color.starGold : Theme.Color.textPrimary.opacity(0.25))
            }
        }
    }

    private var accessibilityLabel: String {
        if !unlocked {
            return L10n.format("stageSelect.card.label.locked", stage.index + 1)
        }
        return L10n.format(
            "stageSelect.card.label.unlocked",
            stage.index + 1,
            stage.displayName,
            starsEarned
        )
    }
}

#Preview {
    NavigationStack {
        StageSelectView(
            characterVM: CharacterViewModel(),
            flightVM: FlightViewModel(),
            missionVM: MissionViewModel()
        )
    }
}
