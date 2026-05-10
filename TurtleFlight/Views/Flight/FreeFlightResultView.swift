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
    let onHome: () -> Void
    let onAgain: () -> Void

    @State private var showButtons: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Theme.Color.brandSky)

                Text(L10n.t("freeFlight.result.title"))
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Color.textOnDark)

                Text(L10n.t("freeFlight.result.subtitle"))
                    .font(Theme.Typography.bodyDynamic)
                    .foregroundColor(Theme.Color.textOnDarkMuted)
                    .multilineTextAlignment(.center)

                // Stats card
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
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.l)
                        .fill(Theme.Color.surfaceOverlayStrong)
                )

                Spacer().frame(height: Theme.Spacing.s)

                HStack(spacing: Theme.Spacing.m) {
                    ResultActionButton(
                        title: L10n.t("common.home"),
                        color: Theme.Color.surfaceOverlay,
                        action: onHome
                    )
                    ResultActionButton(
                        title: L10n.t("freeFlight.result.again"),
                        color: Theme.Color.brandPrimary,
                        action: onAgain
                    )
                }
                .opacity(showButtons ? 1 : 0)
                .offset(y: showButtons ? 0 : 16)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 460)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) { showButtons = true }
            }
        }
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
