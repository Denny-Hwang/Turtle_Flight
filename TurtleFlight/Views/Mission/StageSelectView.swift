import SwiftUI

/// Step Goal stage chooser. Replaces the previous "implicit Stage 1 jump"
/// from HomeView when the user picks Step Goal — until this PR there was
/// no actual stage selection UI; the campaign quietly started at
/// `currentStageIndex` (whatever it last was) and the player had no way
/// to navigate to a specific stage.
///
/// Surfaces:
///   • One row per route (see `RouteCatalog`), each a chain of course cards
///   • Per-course ★ score earned (out of 3), ring count
///   • Lock icon on courses that haven't been unlocked yet; the next
///     locked course on a route can be opened early with stars
///   • Kids mode switch, star wallet (opens the shop)
///   • Tap unlocked → select course → push CharacterSelectView
struct StageSelectView: View {
    @ObservedObject var characterVM: CharacterViewModel
    @ObservedObject var flightVM: FlightViewModel
    @ObservedObject var missionVM: MissionViewModel

    @State private var pushCharacterSelect = false
    @State private var showShop = false
    @State private var showCode = false
    /// Locked course the player tapped "open with stars" on.
    @State private var openCandidate: StageDefinition?
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

            VStack(spacing: Theme.Spacing.s) {
                header
                // Header pinned; the rest scrolls when an iPhone in
                // landscape is too short for it.
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        kidsRow
                        ForEach(RouteID.allCases, id: \.self) { route in
                            routeRow(route)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.s)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShop) {
            ShopView(isPresented: $showShop, missionVM: missionVM,
                     character: characterVM.selectedCharacter)
        }
        .sheet(isPresented: $showCode) {
            SecretCodeSheet(isPresented: $showCode, missionVM: missionVM)
        }
        .alert(L10n.t("route.openEarly.confirmTitle"),
               isPresented: Binding(get: { openCandidate != nil },
                                    set: { if !$0 { openCandidate = nil } }),
               presenting: openCandidate) { course in
            if missionVM.progress.starBalance >= RouteCatalog.earlyOpenPrice {
                Button(L10n.format("route.openEarly.format", RouteCatalog.earlyOpenPrice)) {
                    missionVM.openCourseEarly(course.index)
                }
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        } message: { _ in
            Text(missionVM.progress.starBalance >= RouteCatalog.earlyOpenPrice
                 ? L10n.format("route.openEarly.balance", missionVM.progress.starBalance)
                 : L10n.format("route.openEarly.notEnough",
                               missionVM.progress.starBalance, RouteCatalog.earlyOpenPrice))
        }
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
            .accessibilityLabel(L10n.t("common.home"))
            Spacer()
            Text(L10n.t("stageSelect.title"))
                .font(Theme.Typography.titleSmall)
                .foregroundColor(Theme.Color.textPrimary)
            Spacer()
            walletChip
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
    }

    /// Spendable stars; opens the shop.
    private var walletChip: some View {
        Button {
            AudioManager.shared.playButtonTap()
            showShop = true
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "star.fill").foregroundColor(Theme.Color.starGold)
                Text("\(missionVM.progress.starBalance)")
                Image(systemName: "bag.fill")
            }
            .font(Theme.Typography.label)
            .foregroundColor(Theme.Color.textPrimary)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(Capsule().fill(Theme.Color.surfaceMuted))
        }
        .accessibilityLabel(L10n.format("shop.wallet.a11y", missionVM.progress.starBalance))
    }

    private var kidsRow: some View {
        Toggle(isOn: Binding(get: { missionVM.progress.kidsMode },
                             set: { missionVM.setKidsMode($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("🧸  " + L10n.t("route.kids.toggle"))
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Color.textPrimary)
                Text(L10n.t("route.kids.caption"))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Color.textPrimary.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.Color.easyGreen)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.l).fill(Color.white.opacity(0.7)))
        .padding(.horizontal, Theme.Spacing.l)
    }

    private func routeRow(_ route: RouteID) -> some View {
        let courses = RouteCatalog.courses(in: route)
        let cleared = courses.filter { missionVM.progress.isCourseCleared($0.index) }.count
        let open = missionVM.progress.isRouteUnlocked(route)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.s) {
                Text("\(route.emoji)  \(route.displayName)")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Color.textPrimary)
                Text("\(cleared)/\(courses.count)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Color.textPrimary.opacity(0.6))
                if !open { Image(systemName: "lock.fill").font(.caption).foregroundColor(Theme.Color.textPrimary.opacity(0.6)) }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .accessibilityElement(children: .combine)

            if open {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(courses, id: \.index) { course in
                            courseCard(course)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.xs)
                }
            } else {
                finaleLockedCard
            }
        }
    }

    private func courseCard(_ base: StageDefinition) -> some View {
        let course = missionVM.progress.kidsMode ? base.kidsVariant() : base
        let unlocked = missionVM.isStageUnlocked(base.index)
        return StageCard(
            stage: course,
            step: (RouteCatalog.location(of: base.index)?.step ?? 0) + 1,
            unlocked: unlocked,
            starsEarned: missionVM.stageStars(base.index),
            openPrice: missionVM.progress.canOpenEarly(base.index) ? RouteCatalog.earlyOpenPrice : nil
        ) {
            if unlocked {
                AudioManager.shared.playButtonTap()
                if missionVM.selectCourse(base.index) { pushCharacterSelect = true }
            } else if missionVM.progress.canOpenEarly(base.index) {
                openCandidate = base
            } else {
                Haptics.shared.play(.boostDenied)
            }
        }
    }

    /// Star Road before it opens: how to open it, and the code shortcut.
    private var finaleLockedCard: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundColor(Theme.Color.textPrimary.opacity(0.6))
            Text(L10n.t("route.locked.finale"))
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Color.textPrimary.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.Spacing.s)
            if SecretCodes.isEnabled {
                Button(L10n.t("code.enter")) { showCode = true }
                    .font(Theme.Typography.label)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Color.brandPrimary)
            }
        }
        .padding(Theme.Spacing.m)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.l).fill(Color.white.opacity(0.5)))
        .padding(.horizontal, Theme.Spacing.l)
    }
}

// MARK: - Stage Card

private struct StageCard: View {
    let stage: StageDefinition
    /// 1-based position on its route.
    let step: Int
    let unlocked: Bool
    let starsEarned: Int
    /// Stars it costs to open this locked course now; nil when it can't be.
    let openPrice: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(badgeFill)
                        .frame(width: 44, height: 44)
                    if unlocked {
                        Text("\(step)")
                            .font(Theme.Typography.titleSmall)
                            .foregroundColor(Theme.Color.textOnDark)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Color.textOnDark.opacity(0.85))
                    }
                }

                Text(stage.displayName)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Color.textPrimary.opacity(unlocked ? 1 : 0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(height: 30)

                // What makes this course harder: how many rings, how big.
                HStack(spacing: 3) {
                    Image(systemName: "circle")
                        .font(.system(size: ringGlyph, weight: .bold))
                    Text("×\(stage.ringCount)")
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Color.textPrimary.opacity(unlocked ? 0.7 : 0.35))

                if let openPrice, !unlocked {
                    Label("\(openPrice)", systemImage: "star.fill")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Color.textPrimary)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.Color.starGold.opacity(0.45)))
                } else {
                    earnedStarsRow
                }
            }
            .adaptiveFrame(compactWidth: 112, compactHeight: 124)
            .padding(.vertical, Theme.Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.l)
                    .fill(Color.white.opacity(unlocked ? 0.85 : 0.45))
                    .elevation(Theme.Elevation.card)
            )
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(unlocked
            ? L10n.t("stageSelect.card.hint.unlocked")
            : (openPrice != nil
               ? L10n.format("route.openEarly.format", openPrice ?? 0)
               : L10n.t("stageSelect.card.hint.locked")))
    }

    /// Bigger rings draw a bigger glyph, so size reads without numbers.
    private var ringGlyph: CGFloat {
        CGFloat(min(18, max(9, stage.ringRadius / 3.2)))
    }

    private var badgeFill: Color {
        if !unlocked { return Theme.Color.surfaceOverlaySubtle }
        if stage.isKids { return Theme.Color.easyGreen }
        switch stage.difficulty {
        case 1: return Theme.Color.easyGreen
        case 2: return Color(hex: 0x29B6F6)
        case 3: return Theme.Color.normalYellow
        case 4: return Theme.Color.boostOrange
        default: return Theme.Color.expertRed
        }
    }

    private var earnedStarsRow: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < starsEarned ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(i < starsEarned ? Theme.Color.starGold : Theme.Color.textPrimary.opacity(0.25))
            }
        }
    }

    private var accessibilityLabel: String {
        if !unlocked {
            return L10n.format("stageSelect.card.label.locked", step)
        }
        return L10n.format(
            "stageSelect.card.label.unlocked",
            step,
            stage.displayName + ", " + stage.displayDescription,
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
