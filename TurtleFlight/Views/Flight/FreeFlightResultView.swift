import SwiftUI

/// End-of-run summary for Free Flight. Until now, exiting Free Flight
/// just dismissed the FlightView and the player's stats vanished
/// immediately. Closes DESIGN_GAP_REPORT §S7 (P0).
///
/// Shown as an overlay on top of the FlightView's frozen scene when
/// the player taps Exit (Free Flight only — Step Goal has its own
/// stage-result flow).
struct FreeFlightResultView: View {
    let flightTime: TimeInterval
    let starsCollected: Int
    let isNewBestStars: Bool
    /// Treats this flight paid into the wallet.
    var reward = RewardGrant()
    let onHome: () -> Void
    let onAgain: () -> Void
    /// Phase 4: present the ReplayKit preview. Nil hides the button
    /// (recording disabled or unavailable).
    var onShareClip: (() -> Void)? = nil

    @State private var showButtons: Bool = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compact: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: compact ? Theme.Spacing.m : Theme.Spacing.l) {
                if compact {
                    // iPhone landscape: stacked, the summary ran off the
                    // top and bottom of the screen. Title on the left,
                    // stats on the right, buttons underneath.
                    HStack(alignment: .center, spacing: Theme.Spacing.xl) {
                        titleBlock
                        statsCard
                    }
                } else {
                    titleBlock
                    statsCard
                    Spacer().frame(height: Theme.Spacing.s)
                }

                actionButtons
                    .opacity(showButtons ? 1 : 0)
                    .offset(y: showButtons ? 0 : 16)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, compact ? Theme.Spacing.l : Theme.Spacing.xl)
            .frame(maxWidth: compact ? 760 : 460)
            // Same solid card as StageResultView.
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xl)
                    .fill(Color(hex: Constants.Colors.panelDark))
                    .elevation(Theme.Elevation.cardHigh)
            )
            // iPad: scaled up with the rest of the UI (DeviceCanvas).
            .deviceCanvas()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) { showButtons = true }
            }
        }
    }

    // MARK: - Sections

    private var titleBlock: some View {
        VStack(spacing: compact ? Theme.Spacing.s : Theme.Spacing.l) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: compact ? 44 : 56))
                .foregroundColor(Theme.Color.brandSky)

            Text(L10n.t("freeFlight.result.title"))
                .font(Theme.Typography.displayMedium)
                .foregroundColor(Theme.Color.textOnDark)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text(L10n.t("freeFlight.result.subtitle"))
                .font(Theme.Typography.bodyDynamic)
                .foregroundColor(Theme.Color.textOnDarkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statsCard: some View {
        VStack(spacing: Theme.Spacing.m) {
            statRow(
                icon: "clock",
                label: L10n.t("freeFlight.result.flightTime"),
                value: flightTime.mmss,
                badge: nil
            )
            statRow(
                icon: "star.fill",
                label: L10n.t("freeFlight.result.stars"),
                value: "\(starsCollected)",
                badge: isNewBestStars ? L10n.t("mission.result.newBest") : nil
            )
            if !reward.isEmpty {
                statRow(icon: "gift", label: L10n.t("reward.earned"),
                        value: reward.summary, badge: nil)
                    .accessibilityLabel(reward.accessibilityText)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.l)
                .fill(Theme.Color.textOnDark.opacity(0.06))
        )
    }

    /// Home / Share / Fly again, plus Share clip when recording. On a
    /// compact height the clip button joins the row instead of adding
    /// a second one.
    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                ResultActionButton(
                    title: L10n.t("common.home"),
                    // The card's own colour read as bare text.
                    color: Theme.Color.textOnDark.opacity(0.14),
                    action: onHome
                )
                // Share — bridges the bare result number into the
                // viral loop. ShareLink (iOS 16+) handles the
                // UIActivityViewController dance for us and gives a
                // proper iPad popover anchor automatically.
                ShareLink(
                    item: shareMessage,
                    subject: Text(L10n.t("freeFlight.result.share.subject"))
                ) {
                    Text(L10n.t("freeFlight.result.share"))
                        .font(Theme.Typography.button)
                        .foregroundColor(Theme.Color.textOnDark)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.m)
                                .fill(Theme.Color.brandSky)
                        )
                }
                .simultaneousGesture(TapGesture().onEnded {
                    Haptics.shared.play(.tap)
                })
                .accessibilityLabel(L10n.t("freeFlight.result.share"))

                ResultActionButton(
                    title: L10n.t("freeFlight.result.again"),
                    color: Theme.Color.brandPrimary,
                    action: onAgain
                )
                if compact { shareClipButton }
            }
            if !compact { shareClipButton }
        }
    }

    @ViewBuilder
    private var shareClipButton: some View {
        if let onShareClip {
            ResultActionButton(
                title: L10n.t("result.shareClip"),
                color: Color(hex: 0x6C5CE7),
                action: onShareClip
            )
            .accessibilityHint(L10n.t("a11y.result.shareClip.hint"))
        }
    }

    /// Plain-text share blurb. Formatted via L10n so KR/EN both read
    /// naturally. The flight time uses the same mm:ss helper as the HUD
    /// so the receiver sees identical numbers.
    private var shareMessage: String {
        L10n.format("freeFlight.result.share.body.format", flightTime.mmss, starsCollected)
    }

    private func statRow(icon: String, label: String, value: String, badge: String?) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .foregroundColor(Theme.Color.hudCyan)
                .frame(width: 24)
            Text(label)
                .font(Theme.Typography.bodyLarge)
                .foregroundColor(Theme.Color.textOnDark)
            Spacer(minLength: Theme.Spacing.s)
            Text(value)
                .font(Theme.Typography.hudGaugeSmall)
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
        }
    }
}

private struct ResultActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.shared.play(.tap)
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
