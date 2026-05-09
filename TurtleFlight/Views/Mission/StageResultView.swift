import SwiftUI

/// Full-screen Step Goal result view. Replaces the previous in-HUD
/// overlay (DESIGN_GAP_REPORT §S6/§4 mention this as P0). Adds:
///   • Animated star count-up (0 → result.stars)
///   • Best-time delta vs prior best, when applicable
///   • Buttons appear with a slight delay after the stars resolve so
///     the player has a moment to read the score before deciding.
///
/// Outcomes:
///   • .success(StageResult) → shows ★★★, time, hits, plus three action
///     buttons (Home / Retry / Next-if-available)
///   • .failure(reason:) → shows the failure reason and two buttons
///     (Home / Retry)
struct StageResultView: View {
    enum Outcome {
        case success(StageResult)
        case failure(reason: String)
    }

    let stage: StageDefinition
    let outcome: Outcome
    /// The user's previous best for this stage, or nil if this is the
    /// first clear. Drives the "new record" badge on success.
    let priorBest: StageResult?
    let hasNextStage: Bool
    let onHome: () -> Void
    let onRetry: () -> Void
    let onNext: () -> Void

    @State private var displayedStars: Int = 0
    @State private var showButtons: Bool = false

    var body: some View {
        ZStack {
            // Full-screen dim — replaces the inline panel of the old
            // in-HUD overlay. We own the whole screen so the stars and
            // buttons can breathe.
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                // Headline
                Text(headline)
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(headlineColor)
                    .multilineTextAlignment(.center)

                Text(L10n.format("mission.stage.titleFormat",
                                 stage.index + 1, stage.displayName))
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Color.textOnDarkMuted)

                // Result body
                switch outcome {
                case .success(let result):
                    successBody(result: result)
                case .failure(let reason):
                    failureBody(reason: reason)
                }

                Spacer().frame(height: Theme.Spacing.s)

                // Action buttons (delayed entrance so the score can
                // resolve before the user is offered a choice).
                actionButtons
                    .opacity(showButtons ? 1 : 0)
                    .offset(y: showButtons ? 0 : 16)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 460)
        }
        .onAppear { runEntranceAnimation() }
    }

    // MARK: - Subsections

    private func successBody(result: StageResult) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            // Star count-up
            HStack(spacing: Theme.Spacing.m) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < displayedStars ? "star.fill" : "star")
                        .font(.system(size: 56))
                        .foregroundColor(i < displayedStars
                                         ? Theme.Color.starGold
                                         : Theme.Color.textOnDark.opacity(0.25))
                        .scaleEffect(i < displayedStars ? 1.0 : 0.85)
                        .animation(.spring(response: 0.35, dampingFraction: 0.55),
                                   value: displayedStars)
                }
            }
            .padding(.vertical, Theme.Spacing.s)
            .accessibilityLabel(L10n.format(
                "mission.result.starsLabel", result.stars))

            // Stats row
            VStack(spacing: Theme.Spacing.s) {
                statLine(
                    icon: "clock",
                    text: L10n.format("mission.result.timeFormat",
                                      result.completionTime.mmss),
                    badge: timeBadge(for: result)
                )
                statLine(
                    icon: "exclamationmark.triangle",
                    text: L10n.format("mission.result.collisionsFormat",
                                      result.collisions),
                    badge: nil
                )
                if let perfect = stage.starCountForPerfect, perfect > 0 {
                    statLine(
                        icon: "star",
                        text: L10n.format("mission.result.starsCollectedFormat",
                                          result.starsCollected, perfect),
                        badge: nil
                    )
                }
            }
        }
    }

    private func failureBody(reason: String) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.Color.expertRed)
            Text(reason)
                .font(Theme.Typography.bodyLarge)
                .foregroundColor(Theme.Color.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
        }
        .padding(.vertical, Theme.Spacing.l)
    }

    private func statLine(icon: String, text: String, badge: String?) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .foregroundColor(Theme.Color.hudCyan)
                .frame(width: 22)
            Text(text)
                .font(Theme.Typography.bodyLarge)
                .foregroundColor(Theme.Color.textOnDark)
            if let badge = badge {
                Text(badge)
                    .font(Theme.Typography.microLabel)
                    .foregroundColor(Theme.Color.starGold)
                    .padding(.horizontal, Theme.Spacing.s - 2)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Theme.Color.starGold.opacity(0.2))
                    )
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 280)
    }

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.m) {
            ResultButton(
                title: L10n.t("common.home"),
                color: Theme.Color.surfaceOverlay,
                action: onHome
            )
            ResultButton(
                title: L10n.t("common.retry"),
                color: Theme.Color.boostOrange,
                action: onRetry
            )
            if case .success = outcome, hasNextStage {
                ResultButton(
                    title: L10n.t("common.next"),
                    color: Theme.Color.brandPrimary,
                    action: onNext
                )
            }
        }
    }

    // MARK: - Helpers

    private var headline: String {
        switch outcome {
        case .success: return L10n.t("mission.result.clear")
        case .failure: return L10n.t("mission.result.failed")
        }
    }

    private var headlineColor: Color {
        switch outcome {
        case .success: return Theme.Color.starGold
        case .failure: return Theme.Color.expertRed
        }
    }

    /// "★ NEW BEST" badge if this run beats the prior best time AND
    /// hits the same star tier (so a slower 2★ doesn't flag NEW BEST
    /// over a faster 3★).
    private func timeBadge(for result: StageResult) -> String? {
        guard let prior = priorBest else {
            // First clear ever for this stage — that's worth a badge.
            return L10n.t("mission.result.firstClear")
        }
        guard result.stars >= prior.stars else { return nil }
        guard result.completionTime < prior.completionTime else { return nil }
        return L10n.t("mission.result.newBest")
    }

    private func runEntranceAnimation() {
        switch outcome {
        case .success(let result):
            // Beat-by-beat star reveal. Tuned to feel celebratory but
            // not slow (~1s for 3 stars).
            for i in 1...result.stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(i)) {
                    displayedStars = i
                    AudioManager.shared.playStarCollect()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(max(result.stars, 1)) + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) { showButtons = true }
            }
        case .failure:
            // No countup on failure — just fade the buttons in promptly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) { showButtons = true }
            }
        }
    }
}

// MARK: - Button

private struct ResultButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(title)
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Color.textOnDark)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.m)
                        .fill(color)
                )
        }
    }
}
