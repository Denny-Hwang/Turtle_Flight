import Foundation

struct StageResult: Codable {
    let stageIndex: Int
    let stars: Int          // 0~3
    let completionTime: TimeInterval
    let collisions: Int
    let starsCollected: Int
    let ringsCompleted: Int
    let totalRings: Int
    let date: Date

    var isCompleted: Bool {
        stars > 0
    }
}

struct PlayerProgress: Codable {
    var stageResults: [Int: StageResult]  // stageIndex -> best result
    var totalStars: Int
    var totalFlightTime: TimeInterval
    var bestFreeFlightStars: Int
    var selectedCharacter: CharacterType
    var selectedVehicle: VehicleType
    var sensitivityLevel: SensitivityLevel

    static let defaultProgress = PlayerProgress(
        stageResults: [:],
        totalStars: 0,
        totalFlightTime: 0,
        bestFreeFlightStars: 0,
        selectedCharacter: .turtle,
        selectedVehicle: .shellJet,
        sensitivityLevel: .easy
    )

    var maxUnlockedStage: Int {
        var maxStage = 0
        for (index, result) in stageResults {
            if result.isCompleted && index >= maxStage {
                maxStage = index + 1
            }
        }
        return min(maxStage, 4) // 0-indexed, max Stage 5 (index 4)
    }

    mutating func updateStageResult(_ result: StageResult) {
        let existing = stageResults[result.stageIndex]
        if existing == nil || result.stars > (existing?.stars ?? 0) {
            stageResults[result.stageIndex] = result
        }
        recalculateTotalStars()
    }

    private mutating func recalculateTotalStars() {
        totalStars = stageResults.values.reduce(0) { $0 + $1.stars }
    }
}
