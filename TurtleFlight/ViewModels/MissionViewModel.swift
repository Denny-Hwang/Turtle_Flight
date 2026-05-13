import Foundation
import Combine
import os

private let log = Logger(subsystem: "com.turtleflight.app", category: "MissionViewModel")

final class MissionViewModel: ObservableObject {
    @Published var currentStageIndex: Int = 0
    @Published var missionState: MissionDisplayState = .selecting
    @Published var lastResult: StageResult?
    /// Snapshot of the stage's best score *before* `lastResult` was merged
    /// into `progress`. StageResultView's "New Best!" / "First Clear!"
    /// badge logic compares against this; reading from
    /// `progress.stageResults` after the merge would always return the
    /// just-completed result and the badge would never fire.
    @Published var priorBestForLastResult: StageResult?
    @Published var progress: PlayerProgress = .defaultProgress
    /// Set when persistence fails so the UI can surface a non-blocking warning.
    @Published var lastPersistenceError: String?

    /// Equatable so views can branch on `state == .playing` without an
    /// `if case` ceremony. The associated `String` on `.failed` is itself
    /// Equatable, so the synthesised conformance covers all cases.
    enum MissionDisplayState: Equatable {
        case selecting
        case playing
        case completed
        case failed(String)
    }

    var stages: [StageDefinition] {
        StageDefinition.allStages
    }

    var currentStage: StageDefinition? {
        guard currentStageIndex < stages.count else { return nil }
        return stages[currentStageIndex]
    }

    func isStageUnlocked(_ index: Int) -> Bool {
        if index == 0 { return true }
        return progress.maxUnlockedStage >= index
    }

    func stageStars(_ index: Int) -> Int {
        progress.stageResults[index]?.stars ?? 0
    }

    func selectStage(_ index: Int) {
        guard isStageUnlocked(index) else { return }
        currentStageIndex = index
    }

    /// True iff there's a stage after the current one. The MissionHUD uses
    /// this to decide whether to render the "Next" button on the
    /// stage-clear overlay.
    var hasNextStage: Bool {
        currentStageIndex + 1 < stages.count
    }

    /// Advance to the next stage if one exists. Returns true on success so
    /// the caller can decide whether to fall through to a "campaign clear"
    /// flow vs. spinning up the next mission.
    @discardableResult
    func advanceToNextStage() -> Bool {
        guard hasNextStage else { return false }
        currentStageIndex += 1
        return true
    }

    func startMission() {
        missionState = .playing
    }

    func completeMission(result: StageResult) {
        // Capture prior best BEFORE merging the new result — drives the
        // "New Best!" badge in StageResultView.
        priorBestForLastResult = progress.stageResults[result.stageIndex]
        lastResult = result
        progress.updateStageResult(result)
        // Auto-promote the cosmetic trail tier if this clear crossed a
        // new star milestone. The next flight visually rewards the
        // achievement without the player having to discover Settings.
        // `lastSeenTrailTierThreshold` records the highest threshold
        // we've already auto-promoted past, so subsequent clears that
        // don't cross a new milestone leave the tier alone.
        let earned = TrailColorTier.highestUnlocked(totalStars: progress.totalStars)
        if earned.unlockStarThreshold > progress.lastSeenTrailTierThreshold {
            progress.lastSeenTrailTierThreshold = earned.unlockStarThreshold
            progress.selectedTrailTier = earned
        }
        missionState = .completed
        AudioManager.shared.playStageClear()
        save()
    }

    func failMission(reason: String) {
        missionState = .failed(reason)
        AudioManager.shared.playStageFail()
    }

    func returnToSelect() {
        missionState = .selecting
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(progress)
            UserDefaults.standard.set(data, forKey: "playerProgress")
            lastPersistenceError = nil
        } catch {
            log.error("Failed to encode PlayerProgress: \(error.localizedDescription, privacy: .public)")
            lastPersistenceError = error.localizedDescription
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: "playerProgress") else { return }
        do {
            progress = try JSONDecoder().decode(PlayerProgress.self, from: data)
            // Clamp the persisted trail tier down to whatever's actually
            // earned. Defends against (a) a Reset Progress that wiped
            // stars but left the previously-picked tier, and (b) old
            // saved blobs from before tier earning was enforced.
            let earned = TrailColorTier.highestUnlocked(totalStars: progress.totalStars)
            if progress.selectedTrailTier.unlockStarThreshold > earned.unlockStarThreshold {
                progress.selectedTrailTier = earned
            }
        } catch {
            // Corrupt payload - keep defaults and clear it so we don't loop on the bad blob.
            log.error("Failed to decode PlayerProgress, resetting: \(error.localizedDescription, privacy: .public)")
            UserDefaults.standard.removeObject(forKey: "playerProgress")
        }
    }

    // MARK: - Trail tier helpers

    /// Player-driven trail tier change from SettingsView. Persists
    /// immediately. No-op if the requested tier isn't unlocked yet —
    /// the Settings row is also disabled for locked tiers, so this is
    /// belt-and-suspenders against a logic error in the caller.
    func setSelectedTrailTier(_ tier: TrailColorTier) {
        guard tier.isUnlocked(totalStars: progress.totalStars) else { return }
        progress.selectedTrailTier = tier
        save()
    }
}
