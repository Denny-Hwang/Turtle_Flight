import Foundation
import Combine

final class MissionViewModel: ObservableObject {
    @Published var currentStageIndex: Int = 0
    @Published var missionState: MissionDisplayState = .selecting
    @Published var lastResult: StageResult?
    @Published var progress: PlayerProgress = .defaultProgress

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

    func startMission() {
        missionState = .playing
    }

    func completeMission(result: StageResult) {
        lastResult = result
        progress.updateStageResult(result)
        missionState = .completed
        save()
    }

    func failMission(reason: String) {
        missionState = .failed(reason)
    }

    func returnToSelect() {
        missionState = .selecting
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: "playerProgress")
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: "playerProgress"),
           let saved = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            progress = saved
        }
    }
}
