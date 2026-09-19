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

    /// Non-campaign course currently selected (Daily Run / Sky Run).
    /// When set it overrides `currentStage`; cleared by `returnToSelect`.
    @Published var specialStage: StageDefinition?

    var currentStage: StageDefinition? {
        if let specialStage { return specialStage }
        guard currentStageIndex < stages.count else { return nil }
        return stages[currentStageIndex]
    }

    /// Select today's Daily Run as the active course.
    func selectDailyRun(date: Date = Date()) {
        specialStage = DailyRun.stage(for: date)
    }

    /// Select a fresh Sky Run (endless) course.
    func selectEndless() {
        specialStage = EndlessCourse.stage()
    }

    /// Today's best Daily Run result, if any.
    func todaysDailyBest(date: Date = Date()) -> StageResult? {
        progress.dailyResults[DailyRun.key(for: date)]
    }

    /// True when a special course's result was a new best (set by
    /// `completeMission`; read by the result screen).
    @Published private(set) var lastSpecialWasNewBest: Bool = false

    /// Character of the flight in progress (Phase 4 mastery attribution).
    var lastFlownCharacter: CharacterType?
    /// New mastery level reached by the last completion, if any.
    @Published private(set) var lastMasteryLevelUp: Int?

    /// Record a flight start for mastery. Returns a level-up if any.
    @discardableResult
    func recordFlightStart(character: CharacterType) -> Int? {
        lastFlownCharacter = character
        let up = progress.addMastery(.flightStarted, to: character)
        save()
        return up
    }

    /// Gate XP is batched by the flight view model and flushed here.
    func recordGateXP(passes: Int, bullseyes: Int) {
        guard let character = lastFlownCharacter, passes > 0 else { return }
        for _ in 0..<max(0, passes - bullseyes) { progress.addMastery(.gatePassed(bullseye: false), to: character) }
        for _ in 0..<bullseyes { progress.addMastery(.gatePassed(bullseye: true), to: character) }
        save()
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
        guard specialStage == nil else { return false }
        return currentStageIndex + 1 < stages.count
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
        lastResult = result
        if let special = specialStage, special.isSpecial {
            // Daily / endless: separate ladders, never campaign stars.
            let dayKey = DailyRun.key(for: Date())
            priorBestForLastResult = special.isDailyRun
                ? progress.dailyResults[dayKey]
                : progress.endlessBest
            lastSpecialWasNewBest = progress.updateSpecialResult(result, dayKey: dayKey)
        } else {
            // Capture prior best BEFORE merging the new result — drives the
            // "New Best!" badge in StageResultView.
            priorBestForLastResult = progress.stageResults[result.stageIndex]
            progress.updateStageResult(result)
        }
        progress.totalFlightTime += result.completionTime
        QuestTracker.shared.record(.courseCleared(collisions: result.collisions,
                                                  isDaily: specialStage?.isDailyRun == true))
        QuestTracker.shared.record(.flightTime(seconds: result.completionTime))
        if let combo = result.maxCombo {
            QuestTracker.shared.record(.comboReached(combo))
        }
        GameCenterManager.shared.report(result: result, stage: currentStage, progress: progress)
        // Mastery: course clear + minutes flown, to whichever character
        // flew it (FlightView sets `lastFlownCharacter` at flight start).
        if let character = lastFlownCharacter {
            lastMasteryLevelUp = progress.addMastery(.courseCleared(clean: result.collisions == 0), to: character)
            let minutes = Int(result.completionTime / 60)
            if minutes > 0 { progress.addMastery(.minutesFlown(minutes), to: character) }
        }
        Analytics.shared.track(.stageCompleted, [
            "stage": result.stageIndex,
            "stars": result.stars,
            "time": Int(result.completionTime),
            "collisions": result.collisions
        ])
        // Auto-promote the cosmetic trail tier if this clear crossed a
        // new star milestone. The next flight visually rewards the
        // achievement without the player having to discover Settings.
        // `lastSeenTrailTierThreshold` records the highest threshold
        // we've already auto-promoted past, so subsequent clears that
        // don't cross a new milestone leave the tier alone.
        let earned = TrailColorTier.highestUnlocked(totalStars: progress.effectiveStars)
        if earned.unlockStarThreshold > progress.lastSeenTrailTierThreshold {
            progress.lastSeenTrailTierThreshold = earned.unlockStarThreshold
            progress.selectedTrailTier = earned
        }
        missionState = .completed
        AudioManager.shared.playStageClear()
        save()
    }

    /// `elapsed` is the mission time spent before failing; it still
    /// counts toward the lifetime flight-time stat.
    func failMission(reason: String, elapsed: TimeInterval = 0) {
        missionState = .failed(reason)
        if elapsed > 0 {
            progress.totalFlightTime += elapsed
            QuestTracker.shared.record(.flightTime(seconds: elapsed))
            save()
        }
        Analytics.shared.track(.stageFailed, [
            "stage": currentStageIndex,
            "reason": reason,
            "time": Int(elapsed)
        ])
        AudioManager.shared.playStageFail()
    }

    /// Persist a finished Free Flight run. Returns true when the run set
    /// a new best star count — callers capture this *before* the blob is
    /// updated so the result screen can badge it. Until Phase 1 nothing
    /// ever wrote `totalFlightTime` / `bestFreeFlightStars`, so the Home
    /// stats row was permanently "Best: 0 | 00:00".
    @discardableResult
    func recordFreeFlight(flightTime: TimeInterval, starsCollected: Int) -> Bool {
        let isNewBest = starsCollected > progress.bestFreeFlightStars
        if isNewBest {
            progress.bestFreeFlightStars = starsCollected
        }
        progress.totalFlightTime += max(0, flightTime)
        QuestTracker.shared.record(.flightTime(seconds: max(0, flightTime)))
        Analytics.shared.track(.freeFlightEnded, [
            "time": Int(flightTime),
            "stars": starsCollected,
            "newBest": isNewBest
        ])
        save()
        return isNewBest
    }

    func returnToSelect() {
        missionState = .selecting
        specialStage = nil
        lastSpecialWasNewBest = false
    }

    /// Pay quest reward stars into the progress blob.
    func addBonusStars(_ stars: Int) {
        guard stars > 0 else { return }
        progress.bonusStars += stars
        let earned = TrailColorTier.highestUnlocked(totalStars: progress.effectiveStars)
        if earned.unlockStarThreshold > progress.lastSeenTrailTierThreshold {
            progress.lastSeenTrailTierThreshold = earned.unlockStarThreshold
            progress.selectedTrailTier = earned
        }
        save()
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(progress)
            UserDefaults.standard.set(data, forKey: "playerProgress")
            lastPersistenceError = nil
            if progress.cloudSyncEnabled {
                CloudSync.shared.push(progress)
            }
        } catch {
            log.error("Failed to encode PlayerProgress: \(error.localizedDescription, privacy: .public)")
            lastPersistenceError = error.localizedDescription
        }
    }

    /// Replace the in-memory progress with a blob accepted from iCloud
    /// and persist it locally (without pushing it straight back).
    func acceptRemoteProgress(_ remote: PlayerProgress) {
        progress = remote
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: "playerProgress")
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
            let earned = TrailColorTier.highestUnlocked(totalStars: progress.effectiveStars)
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
        guard tier.isUnlocked(totalStars: progress.effectiveStars) else { return }
        progress.selectedTrailTier = tier
        save()
    }
}
