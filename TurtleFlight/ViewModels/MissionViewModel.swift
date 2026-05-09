import Foundation
import Combine
import os

private let log = Logger(subsystem: "com.turtleflight.app", category: "MissionViewModel")

final class MissionViewModel: ObservableObject {
    @Published var currentStageIndex: Int = 0
    @Published var missionState: MissionDisplayState = .selecting
    @Published var lastResult: StageResult?
    @Published var progress: PlayerProgress = .defaultProgress
    /// Set when persistence fails so the UI can surface a non-blocking warning.
    @Published var lastPersistenceError: String?

    enum MissionDisplayState {
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
        lastResult = result
        progress.updateStageResult(result)
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
        } catch {
            // Corrupt payload - keep defaults and clear it so we don't loop on the bad blob.
            log.error("Failed to decode PlayerProgress, resetting: \(error.localizedDescription, privacy: .public)")
            UserDefaults.standard.removeObject(forKey: "playerProgress")
        }
    }
}
