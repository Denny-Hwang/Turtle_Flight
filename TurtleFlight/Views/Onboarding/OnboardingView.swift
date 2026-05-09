import SwiftUI

/// First-run gyro tutorial. Three swipeable cards:
///   1. Welcome — brand + character cameo
///   2. Hold flat + calibrate — explain neutral position
///   3. Tilt to steer — explain roll/pitch mapping
///
/// Triggered from HomeView when `OnboardingState.completed` is false.
/// Once finished (Get Started tap OR Skip), persists `completed = true`
/// and never re-appears unless the user resets it from Settings.
struct OnboardingView: View {

    /// Called when the user finishes (Get Started or Skip).
    let onFinish: () -> Void

    @State private var pageIndex: Int = 0
    private static let pageCount = 3

    var body: some View {
        ZStack {
            // Brand sky gradient background
            LinearGradient(
                colors: [
                    Theme.Color.brandSky,
                    Theme.Color.brandSky.opacity(0.6),
                    Color.white.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                // Top: Skip button (always available; respects Apple HIG
                // first-run guidance — the user can bail at any step)
                HStack {
                    Spacer()
                    Button(action: finish) {
                        Text(L10n.t("onboarding.skip"))
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Color.textPrimary.opacity(0.7))
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.vertical, Theme.Spacing.s)
                    }
                    .accessibilityLabel(L10n.t("onboarding.skip"))
                }
                .padding(.top, Theme.Spacing.s)

                // Middle: swipeable card stack
                TabView(selection: $pageIndex) {
                    OnboardingCard(
                        illustration: .image("turbo_default"),
                        title: L10n.t("onboarding.welcome.title"),
                        body:  L10n.t("onboarding.welcome.body")
                    )
                    .tag(0)

                    OnboardingCard(
                        illustration: .symbol("iphone.gen3"),
                        title: L10n.t("onboarding.calibrate.title"),
                        body:  L10n.t("onboarding.calibrate.body")
                    )
                    .tag(1)

                    OnboardingCard(
                        illustration: .symbol("arrow.left.arrow.right"),
                        title: L10n.t("onboarding.tilt.title"),
                        body:  L10n.t("onboarding.tilt.body")
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots — explicit so we can theme them.
                PageDots(count: Self.pageCount, index: pageIndex)

                // Bottom CTA — copy changes on the last card.
                Button(action: advanceOrFinish) {
                    Text(pageIndex < Self.pageCount - 1
                         ? L10n.t("onboarding.next")
                         : L10n.t("onboarding.start"))
                        .font(Theme.Typography.button)
                        .foregroundColor(Theme.Color.textOnDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.m + 2)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.l)
                                .fill(Theme.Color.brandPrimary)
                                .elevation(Theme.Elevation.button)
                        )
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
                .accessibilityHint(L10n.t("onboarding.cta.hint"))
            }
        }
    }

    // MARK: - Actions

    private func advanceOrFinish() {
        if pageIndex < Self.pageCount - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                pageIndex += 1
            }
        } else {
            finish()
        }
    }

    private func finish() {
        var state = OnboardingState.load()
        state.completed = true
        state.save()
        onFinish()
    }
}

// MARK: - Card

/// Single onboarding step. The illustration swaps between an asset image
/// (for the welcome card showing a character) and an SF Symbol (for the
/// instructional cards).
struct OnboardingCard: View {

    enum Illustration {
        case image(String)
        case symbol(String)
    }

    let illustration: Illustration
    let title: String
    let body: String

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            illustrationView
                .frame(maxWidth: .infinity, maxHeight: 180)

            Text(title)
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Text(body)
                .font(Theme.Typography.bodyLarge)
                .foregroundColor(Theme.Color.textPrimary.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    @ViewBuilder
    private var illustrationView: some View {
        switch illustration {
        case .image(let name):
            Image(name)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(Theme.Color.brandPrimary)
                .padding(Theme.Spacing.xl)
        }
    }
}

// MARK: - Page Dots

struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index
                        ? Theme.Color.brandPrimary
                        : Theme.Color.textPrimary.opacity(0.25))
                    .frame(width: 8, height: 8)
                    .scaleEffect(i == index ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("onboarding.page.label", index + 1, count))
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
