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
    /// Player-picked cosmetic trail tier (see `TrailColorTier`). Defaults
    /// to `.vehicle` (stock colour) for new players and for any saved
    /// blob from before this field existed. Reading back a tier the
    /// player hasn't earned (e.g. they reset progress) is clamped at
    /// load time by `MissionViewModel.load()`.
    var selectedTrailTier: TrailColorTier
    /// Largest threshold the player has been notified about. The Home
    /// screen surfaces a one-time "🎉 새 트레일 색 잠금 해제!" banner when
    /// the total stars cross a new tier; persisting the last-seen
    /// threshold avoids re-showing the banner on every launch.
    var lastSeenTrailTierThreshold: Int

    static let defaultProgress = PlayerProgress(
        stageResults: [:],
        totalStars: 0,
        totalFlightTime: 0,
        bestFreeFlightStars: 0,
        selectedCharacter: .turtle,
        selectedVehicle: .shellJet,
        sensitivityLevel: .easy,
        selectedTrailTier: .vehicle,
        lastSeenTrailTierThreshold: 0
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

    // MARK: - Codable (backwards-compatible)
    //
    // Existing v1 saved blobs do NOT contain `selectedTrailTier` or
    // `lastSeenTrailTierThreshold`. A naive `Codable` synthesis would
    // throw at decode time and the entire progress would be reset.
    // The custom `init(from:)` below falls those two fields back to
    // their defaults via `decodeIfPresent`. Older fields stay required
    // because they've always existed.

    enum CodingKeys: String, CodingKey {
        case stageResults, totalStars, totalFlightTime, bestFreeFlightStars
        case selectedCharacter, selectedVehicle, sensitivityLevel
        case selectedTrailTier, lastSeenTrailTierThreshold
    }

    init(stageResults: [Int: StageResult],
         totalStars: Int,
         totalFlightTime: TimeInterval,
         bestFreeFlightStars: Int,
         selectedCharacter: CharacterType,
         selectedVehicle: VehicleType,
         sensitivityLevel: SensitivityLevel,
         selectedTrailTier: TrailColorTier = .vehicle,
         lastSeenTrailTierThreshold: Int = 0) {
        self.stageResults = stageResults
        self.totalStars = totalStars
        self.totalFlightTime = totalFlightTime
        self.bestFreeFlightStars = bestFreeFlightStars
        self.selectedCharacter = selectedCharacter
        self.selectedVehicle = selectedVehicle
        self.sensitivityLevel = sensitivityLevel
        self.selectedTrailTier = selectedTrailTier
        self.lastSeenTrailTierThreshold = lastSeenTrailTierThreshold
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.stageResults        = try c.decode([Int: StageResult].self, forKey: .stageResults)
        self.totalStars          = try c.decode(Int.self,                forKey: .totalStars)
        self.totalFlightTime     = try c.decode(TimeInterval.self,       forKey: .totalFlightTime)
        self.bestFreeFlightStars = try c.decode(Int.self,                forKey: .bestFreeFlightStars)
        self.selectedCharacter   = try c.decode(CharacterType.self,      forKey: .selectedCharacter)
        self.selectedVehicle     = try c.decode(VehicleType.self,        forKey: .selectedVehicle)
        self.sensitivityLevel    = try c.decode(SensitivityLevel.self,   forKey: .sensitivityLevel)
        // New fields — tolerate absence so v1 saved blobs decode clean.
        self.selectedTrailTier           = try c.decodeIfPresent(TrailColorTier.self,
                                                                  forKey: .selectedTrailTier) ?? .vehicle
        self.lastSeenTrailTierThreshold  = try c.decodeIfPresent(Int.self,
                                                                  forKey: .lastSeenTrailTierThreshold) ?? 0
    }
}
