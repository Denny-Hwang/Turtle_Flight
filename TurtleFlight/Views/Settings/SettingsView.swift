import SwiftUI

/// User-facing settings surface. Closes the long-standing
/// DESIGN_GAP_REPORT §S8 (P1) item — until this PR there was no UI to
/// reach the audio toggles, no Reset Progress, no privacy/support
/// links, and no Credits screen, all of which Apple App Review
/// reasonably expects on a kids-rated game.
///
/// Layout: a SwiftUI `Form` with three sections (Audio / Progress /
/// About) inside a NavigationStack. Presented modally as a sheet from
/// the home-screen gear icon. Audio sliders are bound to local @State
/// and pushed live into `AudioManager` on each change so the player
/// can hear edits without dismissing the sheet.
struct SettingsView: View {

    // MARK: - Bindings

    @Binding var isPresented: Bool

    /// Mission VM for the Reset Progress action — it owns the
    /// `PlayerProgress` blob that the destructive button clears.
    @ObservedObject var missionVM: MissionViewModel

    /// Triggered when the user picks "Replay tutorial". The home view
    /// listens for this, dismisses the settings sheet, and re-presents
    /// `OnboardingView`. Decoupled via callback so the home view owns
    /// its own onboarding lifecycle (no nested fullScreenCovers).
    let onReplayOnboarding: () -> Void

    // MARK: - Local audio mirror

    @State private var isMuted: Bool
    @State private var bgmVolume: Float
    @State private var sfxVolume: Float
    @State private var showResetConfirm = false
    @State private var showCredits = false
    @State private var resetSuccess = false

    init(isPresented: Binding<Bool>,
         missionVM: MissionViewModel,
         onReplayOnboarding: @escaping () -> Void) {
        self._isPresented = isPresented
        self.missionVM = missionVM
        self.onReplayOnboarding = onReplayOnboarding
        let audio = AudioManager.shared
        self._isMuted = State(initialValue: audio.isMuted)
        self._bgmVolume = State(initialValue: audio.bgmVolume)
        self._sfxVolume = State(initialValue: audio.sfxVolume)
    }

    var body: some View {
        NavigationStack {
            Form {
                audioSection
                sensitivityGuideSection
                progressSection
                aboutSection
            }
            .navigationTitle(L10n.t("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { isPresented = false }
                        .accessibilityLabel(L10n.t("common.done"))
                }
            }
            .confirmationDialog(
                L10n.t("settings.progress.reset.confirm.title"),
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.t("settings.progress.reset.confirm.action"),
                       role: .destructive) {
                    performReset()
                }
                Button(L10n.t("common.cancel"), role: .cancel) {}
            } message: {
                Text(L10n.t("settings.progress.reset.confirm.message"))
            }
            .sheet(isPresented: $showCredits) {
                CreditsView(onClose: { showCredits = false })
            }
        }
    }

    // MARK: - Sections

    private var audioSection: some View {
        Section(L10n.t("settings.section.audio")) {
            Toggle(L10n.t("settings.audio.mute"), isOn: $isMuted)
                .onChange(of: isMuted) { newValue in
                    AudioManager.shared.setMuted(newValue)
                }
                .accessibilityHint(L10n.t("settings.audio.mute"))

            volumeRow(
                icon: "music.note",
                label: L10n.t("settings.audio.bgm"),
                value: $bgmVolume,
                onCommit: { AudioManager.shared.setBGMVolume(bgmVolume) }
            )
            volumeRow(
                icon: "waveform",
                label: L10n.t("settings.audio.sfx"),
                value: $sfxVolume,
                onCommit: {
                    AudioManager.shared.setSFXVolume(sfxVolume)
                    // Play a quick chirp so the slider feels connected.
                    AudioManager.shared.playButtonTap()
                }
            )
        }
    }

    /// Comparison table of the three sensitivity profiles. The actual
    /// selection lives on Home (`SensitivityButton`s), but the player
    /// has no way to learn *what* each level changes without picking
    /// one and feeling it. This section spells out the dead zone,
    /// response curve, and auto-level behaviour up-front so the player
    /// can make an informed pick before flying.
    private var sensitivityGuideSection: some View {
        Section(L10n.t("settings.section.sensitivity")) {
            sensitivityRow(
                level: .easy,
                tint: Theme.Color.easyGreen,
                caption: L10n.t("settings.sensitivity.easy.caption")
            )
            sensitivityRow(
                level: .normal,
                tint: Theme.Color.normalYellow,
                caption: L10n.t("settings.sensitivity.normal.caption")
            )
            sensitivityRow(
                level: .expert,
                tint: Theme.Color.expertRed,
                caption: L10n.t("settings.sensitivity.expert.caption")
            )
        }
    }

    private func sensitivityRow(level: SensitivityLevel,
                                tint: Color,
                                caption: String) -> some View {
        let profile = SensitivityProfile.profile(for: level)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.s) {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                Text("Lv.\(level.levelNumber)  \(level.displayName)")
                    .font(Theme.Typography.bodyDynamicBold)
                Spacer()
                Text(L10n.format("settings.sensitivity.tilt.format", Int(profile.maxTilt * 180 / .pi)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Text(caption)
                .font(Theme.Typography.captionDynamic)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private var progressSection: some View {
        Section(L10n.t("settings.section.progress")) {
            // Inline confirmation banner shown briefly after a reset so the
            // user sees the destructive action took effect (the rest of the
            // row state — totals, unlocks — also flips immediately).
            if resetSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Color.easyGreen)
                    Text(L10n.t("settings.progress.reset.confirm.action"))
                        .font(Theme.Typography.label)
                }
                .accessibilityElement(children: .combine)
            }

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(L10n.t("settings.progress.reset"))
                }
            }
            .disabled(missionVM.progress.totalStars == 0
                      && missionVM.progress.totalFlightTime == 0)

            Button {
                onReplayOnboarding()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle")
                    Text(L10n.t("settings.progress.replayOnboarding"))
                }
            }
        }
    }

    private var aboutSection: some View {
        Section(L10n.t("settings.section.about")) {
            HStack {
                Text(L10n.t("settings.about.version"))
                Spacer()
                Text(Self.appVersionString)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(Self.appVersionString)
            }

            Link(destination: Self.privacyURL) {
                HStack {
                    Image(systemName: "hand.raised")
                    Text(L10n.t("settings.about.privacy"))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityHint(L10n.t("settings.about.privacy"))

            Link(destination: Self.supportURL) {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text(L10n.t("settings.about.support"))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityHint(L10n.t("settings.about.support"))

            Button {
                showCredits = true
            } label: {
                HStack {
                    Image(systemName: "person.2")
                    Text(L10n.t("settings.about.credits"))
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func volumeRow(icon: String,
                           label: String,
                           value: Binding<Float>,
                           onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: icon)
                Text(label)
                Spacer()
                Text(percentLabel(value.wrappedValue))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            Slider(value: value, in: 0...1, step: 0.05) { editing in
                // `editing == false` fires on touch-up and on every step
                // change committed by VoiceOver — we use it as the
                // "commit" signal so the audio player is updated without
                // 60Hz spam during a drag.
                if !editing { onCommit() }
            }
            .disabled(isMuted)
            .accessibilityLabel(label)
            .accessibilityValue(percentLabel(value.wrappedValue))
        }
    }

    private func performReset() {
        missionVM.progress = .defaultProgress
        missionVM.save()
        // Also reset the lastResult so the result screen doesn't try to
        // re-display a stale clear after the user reopens Step Goal.
        missionVM.lastResult = nil
        missionVM.priorBestForLastResult = nil
        missionVM.currentStageIndex = 0
        // Banner stays visible briefly so the destructive action reads
        // as confirmed rather than silently working.
        withAnimation(.easeInOut) { resetSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut) { resetSuccess = false }
        }
    }

    private func percentLabel(_ value: Float) -> String {
        "\(Int(round(value * 100)))%"
    }

    /// "1.0 (1)" style version string. Pulled from `Info.plist`'s
    /// CFBundle keys so it stays in lockstep with the binary the user
    /// is actually running.
    static var appVersionString: String {
        let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let b = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        return "\(v) (\(b))"
    }

    /// Privacy policy and support URLs. Public statics so a future
    /// release-config refactor can swap them without spelunking the
    /// view body. Apple App Review requires the privacy URL at metadata
    /// submission time — point this at the live policy before TestFlight.
    static let privacyURL = URL(
        string: "https://github.com/Denny-Hwang/Turtle_Flight/blob/main/PRIVACY.md"
    )!
    static let supportURL = URL(
        string: "https://github.com/Denny-Hwang/Turtle_Flight/issues"
    )!
}

// MARK: - Credits

/// Minimal credits sheet — pinned as a separate view so it can grow
/// (designer credits, asset attribution, OSS licenses) without bloating
/// SettingsView. Currently reads as the brand line + a thank-you.
private struct CreditsView: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.Color.starGold)
                        .padding(.top, Theme.Spacing.xl)
                    Text(L10n.t("settings.about.credits.body"))
                        .font(Theme.Typography.bodyLarge)
                        .foregroundColor(Theme.Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(L10n.t("settings.about.credits"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done"), action: onClose)
                }
            }
        }
    }
}

#Preview {
    SettingsView(
        isPresented: .constant(true),
        missionVM: MissionViewModel(),
        onReplayOnboarding: {}
    )
}
