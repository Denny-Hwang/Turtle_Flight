import XCTest
@testable import TurtleFlight

/// Pins the new settings-surface contract introduced in Sprint 2:
///   • `AudioManager` volume API clamps + persists across launches.
///   • `MissionViewModel.progress` reset is idempotent and clears
///     downstream stage/star state.
///   • `OnboardingState` reset → re-load round-trip works.
///
/// We deliberately don't try to assert on the SwiftUI layout — that's
/// integration territory. Instead we lock down the underlying state
/// machinery the SettingsView reads/writes so a regression in the
/// destructive paths surfaces as a unit-test failure, not a TestFlight
/// support email.
final class SettingsAndAudioTests: XCTestCase {

    // MARK: - AudioManager volume API

    func testSetBGMVolumeClampsToUnitRange() {
        let audio = AudioManager.shared
        audio.setBGMVolume(0.5)
        XCTAssertEqual(audio.bgmVolume, 0.5, accuracy: 0.001)

        audio.setBGMVolume(2.0)
        XCTAssertEqual(audio.bgmVolume, 1.0, accuracy: 0.001,
                       "Out-of-range high values should clamp to 1.0")

        audio.setBGMVolume(-0.5)
        XCTAssertEqual(audio.bgmVolume, 0.0, accuracy: 0.001,
                       "Out-of-range low values should clamp to 0.0")
    }

    func testSetSFXVolumeClampsToUnitRange() {
        let audio = AudioManager.shared
        audio.setSFXVolume(0.7)
        XCTAssertEqual(audio.sfxVolume, 0.7, accuracy: 0.001)

        audio.setSFXVolume(99.0)
        XCTAssertEqual(audio.sfxVolume, 1.0, accuracy: 0.001)

        audio.setSFXVolume(-1.0)
        XCTAssertEqual(audio.sfxVolume, 0.0, accuracy: 0.001)
    }

    func testVolumeChangesPersistAcrossUserDefaultsRoundtrip() {
        // setBGMVolume writes through UserDefaults synchronously. Read it
        // back manually and confirm the wire format matches.
        let audio = AudioManager.shared
        audio.setBGMVolume(0.42)
        let stored = UserDefaults.standard.object(forKey: "audio.bgmVolume") as? Float
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored ?? 0, 0.42, accuracy: 0.001)
    }

    func testMuteTogglePersists() {
        let audio = AudioManager.shared
        let original = audio.isMuted
        audio.setMuted(!original)
        let stored = UserDefaults.standard.bool(forKey: "audio.muted")
        XCTAssertEqual(stored, !original)
        // Restore so we don't mute the test runner's other suites.
        audio.setMuted(original)
    }

    func testDefaultVolumesAreSensible() {
        // Sanity: the design defaults should sit in a comfortable middle
        // range — not zero (silent app), not full blast (annoying).
        XCTAssertGreaterThan(AudioManager.defaultBGMVolume, 0)
        XCTAssertLessThan(AudioManager.defaultBGMVolume, 1)
        XCTAssertGreaterThan(AudioManager.defaultSFXVolume, 0)
        XCTAssertLessThan(AudioManager.defaultSFXVolume, 1)
        // BGM should be quieter than SFX by convention so action sounds
        // cut through the music bed.
        XCTAssertLessThan(AudioManager.defaultBGMVolume,
                          AudioManager.defaultSFXVolume)
    }

    // MARK: - MissionViewModel reset

    func testProgressResetClearsAllScores() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        // Pre-condition: simulate a run.
        let result = StageResult(
            stageIndex: 0, stars: 2, completionTime: 45,
            collisions: 1, starsCollected: 0, ringsCompleted: 10,
            totalRings: 10, date: Date()
        )
        vm.completeMission(result: result)
        XCTAssertEqual(vm.progress.totalStars, 2)
        XCTAssertEqual(vm.progress.maxUnlockedStage, 1)

        // Mirror the SettingsView reset action (also clears lastResult /
        // priorBest / currentStageIndex so a follow-up Step Goal entry
        // doesn't see stale state).
        vm.progress = .defaultProgress
        vm.lastResult = nil
        vm.priorBestForLastResult = nil
        vm.currentStageIndex = 0
        vm.save()

        XCTAssertEqual(vm.progress.totalStars, 0)
        XCTAssertEqual(vm.progress.maxUnlockedStage, 0)
        XCTAssertNil(vm.lastResult)
        XCTAssertNil(vm.priorBestForLastResult)
        XCTAssertEqual(vm.currentStageIndex, 0)
    }

    // MARK: - OnboardingState reset round-trip

    func testReplayOnboardingRoundtrip() {
        // Flush any prior test state from the same UserDefaults bucket.
        UserDefaults.standard.removeObject(forKey: OnboardingState.storageKey)

        // Simulate the user finishing onboarding once.
        var state = OnboardingState.load()
        state.completed = true
        XCTAssertTrue(state.save())
        XCTAssertTrue(OnboardingState.load().completed)

        // SettingsView "Replay tutorial" path: flip back to false + save.
        var resetState = OnboardingState.load()
        resetState.completed = false
        XCTAssertTrue(resetState.save())

        // Next HomeView.onAppear would re-trigger the cover.
        XCTAssertFalse(OnboardingState.load().completed,
                       "After Replay-tutorial reset, OnboardingState should re-arm the first-run cover")
    }

    // MARK: - SettingsView.appVersionString

    func testAppVersionStringFormat() {
        let s = SettingsView.appVersionString
        // Always contains parens around the build number, no matter what
        // CFBundleVersion the test bundle exposes.
        XCTAssertTrue(s.contains("(") && s.contains(")"),
                      "appVersionString should format as 'X.Y (build)'; got \(s)")
        XCTAssertFalse(s.isEmpty)
    }

    func testPrivacyAndSupportURLsAreValid() {
        // App Review checks both URLs; this protects against typos that
        // would otherwise only fail in production.
        XCTAssertEqual(SettingsView.privacyURL.scheme, "https")
        XCTAssertEqual(SettingsView.supportURL.scheme, "https")
    }
}
