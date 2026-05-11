import SwiftUI
import CoreMotion

/// First-run gyro tutorial. Four swipeable cards:
///   1. Welcome — brand + character cameo
///   2. Hold flat + calibrate — explain neutral position
///   3. Tilt to steer — explain roll/pitch mapping
///   4. Try Tilt — live tilt-meter so the player feels the mechanic
///      before being asked to commit to a flight
///
/// Triggered from HomeView when `OnboardingState.completed` is false.
/// Once finished (Get Started tap OR Skip), persists `completed = true`
/// and never re-appears unless the user resets it from Settings.
struct OnboardingView: View {

    /// Called when the user finishes (Get Started or Skip).
    let onFinish: () -> Void

    @State private var pageIndex: Int = 0
    private static let pageCount = 4

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
                    .accessibilityHint(L10n.t("a11y.onboarding.skip.hint"))
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

                    // Live tilt-meter: the first place the player feels the
                    // gyro responding under their hand. The art is a stand-in
                    // for the turtle silhouette — its rotation/translation
                    // mirrors device roll/pitch so the player can hover-test
                    // before committing to a flight.
                    TryTiltCard(isActive: pageIndex == 3)
                        .tag(3)
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
                .accessibilityHint(pageIndex < Self.pageCount - 1
                    ? L10n.t("a11y.onboarding.next.hint")
                    : L10n.t("a11y.onboarding.start.hint"))
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

            // Dynamic Type aware — onboarding is the first text the
            // player reads, and a parent who has Larger Text enabled
            // for their child should not have to squint at the tutorial
            // because the title was hard-coded at 22pt.
            Text(title)
                .font(Theme.Typography.titleDynamic)
                .foregroundColor(Theme.Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Text(body)
                .font(Theme.Typography.bodyDynamic)
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

// MARK: - Try Tilt Card

/// Real-time tilt indicator powered by `CMMotionManager`. The icon mirrors
/// roll → rotation and pitch → vertical offset so the player feels the
/// mapping before being thrown into a 6-degree-of-freedom flight.
///
/// `isActive` is the TabView selection match — we only spin up CoreMotion
/// while this page is on-screen so the sensor doesn't stay warm if the
/// user backs out, and so simulator runs (no real motion) don't hold the
/// hardware open.
struct TryTiltCard: View {
    let isActive: Bool

    @State private var roll: Double = 0     // radians, [-π, π]
    @State private var pitch: Double = 0    // radians, [-π/2, π/2]
    @StateObject private var sampler = TiltSampler()

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            ZStack {
                // Soft horizon plate — gives the icon something to relate to.
                Capsule()
                    .fill(Theme.Color.brandPrimary.opacity(0.15))
                    .frame(width: 180, height: 8)
                    .rotationEffect(.radians(-roll))

                // The live indicator. SF symbol stands in for the turtle
                // until the in-flight character preview can be reused
                // here without dragging in SceneKit machinery.
                Image(systemName: "tortoise.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Theme.Color.brandPrimary)
                    .frame(width: 96, height: 96)
                    .rotationEffect(.radians(-roll))
                    .offset(y: CGFloat(pitch * 90))
                    .animation(.easeOut(duration: 0.08), value: roll)
                    .animation(.easeOut(duration: 0.08), value: pitch)
            }
            .frame(maxWidth: .infinity, maxHeight: 180)
            .accessibilityElement()
            .accessibilityLabel(L10n.t("onboarding.try.title"))

            Text(L10n.t("onboarding.try.title"))
                .font(Theme.Typography.titleDynamic)
                .foregroundColor(Theme.Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Text(L10n.t("onboarding.try.body"))
                .font(Theme.Typography.bodyDynamic)
                .foregroundColor(Theme.Color.textPrimary.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .onAppear { if isActive { sampler.start { roll = $0; pitch = $1 } } }
        .onChange(of: isActive) { active in
            if active {
                sampler.start { roll = $0; pitch = $1 }
            } else {
                sampler.stop()
            }
        }
        .onDisappear { sampler.stop() }
    }
}

/// Thin CMMotionManager wrapper scoped to the Try Tilt card lifetime.
/// Kept inside Onboarding rather than reusing GyroController because the
/// latter is wired through the flight stack (calibration, sensitivity
/// profiles, expression latching). For a 5-second feel test we just want
/// the raw attitude.
final class TiltSampler: ObservableObject {
    private let manager = CMMotionManager()

    func start(_ onUpdate: @escaping (Double, Double) -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let m = motion else { return }
            // Landscape-friendly mapping. In landscape, device pitch
            // becomes the "lean forward/back" axis and roll becomes
            // "tilt left/right" — same convention GyroController uses
            // in flight.
            onUpdate(m.attitude.roll, m.attitude.pitch)
        }
    }

    func stop() {
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
    }

    deinit {
        // stopDeviceMotionUpdates() is documented as thread-safe; the
        // motion queue (`.main`) is what we pass to start, and stop just
        // tears down the publisher. SwiftUI's onDisappear normally calls
        // stop() before deinit but the guard keeps us safe regardless.
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
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
        .accessibilityLabel(L10n.format("a11y.onboarding.page.format", index + 1, count))
        .accessibilityHint(L10n.t("a11y.onboarding.page.hint"))
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
