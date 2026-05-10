import SwiftUI

struct HomeView: View {
    @StateObject private var characterVM = CharacterViewModel()
    @StateObject private var flightVM = FlightViewModel()
    @StateObject private var missionVM = MissionViewModel()

    @State private var selectedMode: FlightMode?
    @State private var showCharacterSelect = false
    /// True when the user picked Step Goal — pushes StageSelectView before
    /// CharacterSelect so the player explicitly chooses which stage to
    /// fly. Free Flight skips this (no stage to pick) and goes straight
    /// to character select.
    @State private var showStageSelect = false
    /// Drives the first-run onboarding fullScreenCover. Initialised lazily
    /// from persisted state in `.onAppear` so the cover lifecycle plays
    /// nicely with NavigationStack (true → cover dismisses cleanly when
    /// flipped back to false).
    @State private var showOnboarding = false
    /// True while the SettingsView sheet is on screen. Surfaces from the
    /// gear button in the top-right.
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Sky gradient background
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

                // Top-right settings gear. Sits inside the safe area so
                // it doesn't fight the title spacing. Use `.ultraThinMaterial`
                // for a soft contrast against the bright sky gradient.
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Theme.Color.textPrimary)
                                .padding(Theme.Spacing.s + 2)
                                .background(
                                    Circle().fill(.ultraThinMaterial)
                                )
                        }
                        .accessibilityLabel(L10n.t("a11y.settings.label"))
                        .accessibilityHint(L10n.t("a11y.settings.hint"))
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)
                    Spacer()
                }

                VStack(spacing: Theme.Spacing.xxl) {
                    // Title
                    VStack(spacing: Theme.Spacing.s) {
                        Text("Turtle Flight")
                            .font(Theme.Typography.displayLarge)
                            .foregroundColor(Theme.Color.textPrimary)

                        Text(L10n.t("home.subtitle"))
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundColor(Theme.Color.textPrimary.opacity(0.7))
                    }
                    .padding(.top, Theme.Spacing.xxxl)

                    Spacer()

                    // Mode Selection
                    HStack(spacing: Theme.Spacing.xl) {
                        ModeButton(
                            title: L10n.t("flight.mode.freePlay"),
                            subtitle: L10n.t("flight.mode.freePlay.subtitle"),
                            icon: "cloud.sun.fill",
                            color: Theme.Color.brandSky
                        ) {
                            selectedMode = .freePlay
                            showCharacterSelect = true
                        }
                        .accessibilityLabel(L10n.t("flight.mode.freePlay"))
                        .accessibilityHint(L10n.t("a11y.mode.freePlay.hint"))

                        ModeButton(
                            title: L10n.t("flight.mode.stepGoal"),
                            subtitle: "\(missionVM.progress.totalStars)/15",
                            icon: "target",
                            color: Theme.Color.starGold
                        ) {
                            selectedMode = .stepGoal
                            // Step Goal goes through StageSelect first so
                            // the player explicitly picks which stage to
                            // fly. CharacterSelect is then pushed from
                            // inside StageSelect.
                            showStageSelect = true
                        }
                        .accessibilityLabel(L10n.t("flight.mode.stepGoal"))
                        .accessibilityHint(L10n.t("a11y.mode.stepGoal.hint"))
                    }

                    // Sensitivity Selection
                    VStack(spacing: Theme.Spacing.m) {
                        Text(L10n.t("home.sensitivity.label"))
                            .font(Theme.Typography.bodyLarge)
                            .foregroundColor(Theme.Color.textPrimary.opacity(0.7))

                        HStack(spacing: Theme.Spacing.m) {
                            ForEach(SensitivityLevel.allCases, id: \.self) { level in
                                SensitivityButton(
                                    level: level,
                                    isSelected: flightVM.sensitivityLevel == level
                                ) {
                                    flightVM.sensitivityLevel = level
                                }
                                .accessibilityLabel(L10n.t("a11y.sensitivity.\(level.rawValue).label"))
                                .accessibilityHint(L10n.t("a11y.sensitivity.hint"))
                                .accessibilityAddTraits(flightVM.sensitivityLevel == level ? .isSelected : [])
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xxxl)

                    Spacer()

                    // Stats
                    HStack {
                        Label(
                            L10n.format("home.stats.bestStars", missionVM.progress.bestFreeFlightStars),
                            systemImage: "star.fill"
                        )
                        .foregroundColor(Theme.Color.starGold)

                        Text("|")
                            .foregroundColor(.gray)

                        Label(
                            L10n.format("home.stats.flightTime", missionVM.progress.totalFlightTime.mmss),
                            systemImage: "clock"
                        )
                        .foregroundColor(Theme.Color.hudCyan)
                    }
                    .font(Theme.Typography.label)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .navigationDestination(isPresented: $showCharacterSelect) {
                CharacterSelectView(
                    characterVM: characterVM,
                    flightVM: flightVM,
                    missionVM: missionVM,
                    flightMode: selectedMode ?? .freePlay
                )
            }
            .navigationDestination(isPresented: $showStageSelect) {
                StageSelectView(
                    characterVM: characterVM,
                    flightVM: flightVM,
                    missionVM: missionVM
                )
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onFinish: { showOnboarding = false })
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                isPresented: $showSettings,
                missionVM: missionVM,
                onReplayOnboarding: {
                    // Tear down the SettingsView before re-presenting
                    // onboarding — overlapping sheet/cover lifecycles on
                    // iOS 16 occasionally lose touches. The async hop
                    // gives SwiftUI a runloop to dismiss cleanly.
                    showSettings = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        var state = OnboardingState.load()
                        state.completed = false
                        state.save()
                        showOnboarding = true
                    }
                }
            )
        }
        .onAppear {
            characterVM.load()
            flightVM.load()
            missionVM.load()
            // Show onboarding on first launch only.
            if !OnboardingState.load().completed {
                showOnboarding = true
            }
        }
    }
}

// MARK: - Subviews

struct ModeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                Text(title)
                    .font(Theme.Typography.button)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .opacity(0.7)
            }
            .foregroundColor(Theme.Color.textOnDark)
            .frame(width: 140, height: 120)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.l)
                    .fill(color)
                    .shadow(color: color.opacity(0.4), radius: 8, y: 4)
            )
        }
    }
}

struct SensitivityButton: View {
    let level: SensitivityLevel
    let isSelected: Bool
    let action: () -> Void

    private var color: Color {
        switch level {
        case .easy:   return Theme.Color.easyGreen
        case .normal: return Theme.Color.normalYellow
        case .expert: return Theme.Color.expertRed
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Text(level.emoji)
                    .font(.system(size: 20))
                Text(level.displayName)
                    .font(Theme.Typography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.s)
                    .fill(isSelected ? color : Color.gray.opacity(0.2))
            )
            .foregroundColor(isSelected ? Theme.Color.textOnDark : Theme.Color.textPrimary)
        }
    }
}

#Preview {
    HomeView()
}
