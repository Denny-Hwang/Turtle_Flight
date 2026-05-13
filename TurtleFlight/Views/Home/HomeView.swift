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

    /// Mirror of `AudioManager.shared.isMuted` so the home-screen mute
    /// chip can re-render its glyph each tap. Re-synced when the
    /// SettingsView sheet dismisses (where the player may have toggled
    /// mute via the Audio section) so the icon stays consistent.
    @State private var isMuted: Bool = AudioManager.shared.isMuted

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

                // Top-right controls: mute toggle + settings gear. Two
                // circular `.ultraThinMaterial` chips inside the safe
                // area. The mute toggle lives outside Settings because
                // App Review reasonably expects one-tap mute on a
                // music-playing kids game; a 3-tap path (gear →
                // Settings → Audio → Mute) reads as hidden.
                VStack {
                    HStack(spacing: Theme.Spacing.s) {
                        Spacer()
                        Button {
                            AudioManager.shared.toggleMute()
                            isMuted = AudioManager.shared.isMuted
                        } label: {
                            Image(systemName: isMuted
                                  ? "speaker.slash.fill"
                                  : "speaker.wave.2.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Theme.Color.textPrimary)
                                .padding(Theme.Spacing.s + 2)
                                .background(
                                    Circle().fill(.ultraThinMaterial)
                                )
                        }
                        .accessibilityLabel(L10n.t("a11y.mute.label"))
                        .accessibilityValue(isMuted
                                            ? L10n.t("a11y.mute.value.muted")
                                            : L10n.t("a11y.mute.value.unmuted"))
                        .accessibilityHint(isMuted
                                           ? L10n.t("a11y.mute.hint.unmute")
                                           : L10n.t("a11y.mute.hint.mute"))

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

                    // Currently-selected character cameo. Surfaces the
                    // identity the player will fly with the next time
                    // they tap a mode — until this chip existed, the
                    // home screen never showed *who* you were going to
                    // be, only what you were going to do.
                    SelectedCharacterCameo(character: characterVM.selectedCharacter)

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
                            // Pre-progress players see a literal mission
                            // count ("5 missions") so the chip reads as a
                            // promise of content rather than a cryptic
                            // "0/15". Once they earn any star the chip
                            // flips to the running score. The total cap
                            // stays dynamic via `stages.count * 3`.
                            subtitle: missionVM.progress.totalStars > 0
                                ? "\(missionVM.progress.totalStars)/\(missionVM.stages.count * 3)★"
                                : L10n.format("flight.mode.stepGoal.subtitle.firstRun", missionVM.stages.count),
                            icon: "target",
                            // brandPrimary (Turbo mint) so the button
                            // doesn't compete with the star-gold colour
                            // used for actual rewards across the HUD.
                            color: Theme.Color.brandPrimary
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
        .sheet(isPresented: $showSettings, onDismiss: {
            // SettingsView's Audio section may have flipped mute via its
            // own toggle / volume sliders. Re-sync the home-screen icon
            // so the speaker glyph reflects the latest state.
            isMuted = AudioManager.shared.isMuted
        }) {
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
            .adaptiveFrame(compactWidth: 140, compactHeight: 120)
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

// MARK: - Selected Character Cameo

/// Shows the currently-selected character on Home so the player sees
/// *who* they'll fly with the next time they pick a mode. Before this
/// chip existed, the home screen never surfaced character identity —
/// the only place the choice was visible was inside CharacterSelectView
/// itself. Adds a small "you are X" reinforcement to every visit.
///
/// Tap target is the chip itself: 44pt minimum tappable area satisfied
/// by the padded HStack. No tap action is wired right now (taps would
/// need a mode pre-selection); the chip is purely informational.
private struct SelectedCharacterCameo: View {
    let character: CharacterType

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image("\(character.assetPrefix)_icon")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .background(
                    Circle().fill(.ultraThinMaterial)
                )

            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.t("home.cameo.label"))
                    .font(Theme.Typography.microLabel)
                    .foregroundColor(Theme.Color.textPrimary.opacity(0.55))
                Text(character.config.name)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Color.textPrimary)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s - 2)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        // Re-identify on character change so the icon refresh triggers
        // a transition rather than swapping in place.
        .id(character)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format("a11y.home.cameo.format", character.config.name))
    }
}

#Preview {
    HomeView()
}
