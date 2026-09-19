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
    /// Gate-precision score for the run (Phase 2). Optional so saved
    /// blobs from before scoring existed still decode; nil reads as "no
    /// score recorded".
    var score: Int? = nil
    /// Longest chain of consecutive passes in the run (Phase 2).
    var maxCombo: Int? = nil
    var bullseyes: Int? = nil

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

    // MARK: Phase 3 — retention fields (all optional-on-decode)

    /// Best Daily Run result per day key ("2026-09-19"). Trimmed to the
    /// most recent `maxDailyResults` entries on write.
    var dailyResults: [String: StageResult]
    /// Best Sky Run (endless) result ever.
    var endlessBest: StageResult?
    /// Stars paid out by daily quests. Count toward trail tiers via
    /// `effectiveStars` without touching campaign `totalStars`.
    var bonusStars: Int
    /// Opt-in Game Center (leaderboards / achievements). Off by default —
    /// PRIVACY.md promises no sign-in unless the player asks for it.
    var gameCenterEnabled: Bool
    /// Opt-in local reminder notifications (daily course / streak).
    var remindersEnabled: Bool

    static let maxDailyResults = 60

    /// Stars that count toward cosmetics: campaign + quest bonus.
    var effectiveStars: Int { totalStars + bonusStars }

    /// Number of Daily Runs completed (any star count).
    var dailyRunsCompleted: Int { dailyResults.count }

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

    /// Record a special-course result (daily / endless). Keeps the best
    /// per key. Returns true when it is a new best.
    @discardableResult
    mutating func updateSpecialResult(_ result: StageResult, dayKey: String) -> Bool {
        if result.stageIndex == DailyRun.stageIndex {
            let prior = dailyResults[dayKey]
            let better = prior == nil || Self.isBetter(result, than: prior!)
            if better { dailyResults[dayKey] = result }
            if dailyResults.count > Self.maxDailyResults {
                let sorted = dailyResults.keys.sorted()
                for key in sorted.prefix(dailyResults.count - Self.maxDailyResults) {
                    dailyResults.removeValue(forKey: key)
                }
            }
            return better
        }
        if result.stageIndex == EndlessCourse.stageIndex {
            let better = endlessBest == nil || Self.isBetter(result, than: endlessBest!)
            if better { endlessBest = result }
            return better
        }
        return false
    }

    /// Ordering for special courses: score first, then rings, then time.
    static func isBetter(_ a: StageResult, than b: StageResult) -> Bool {
        let sa = a.score ?? 0, sb = b.score ?? 0
        if sa != sb { return sa > sb }
        if a.ringsCompleted != b.ringsCompleted { return a.ringsCompleted > b.ringsCompleted }
        return a.completionTime < b.completionTime
    }

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
        case dailyResults, endlessBest, bonusStars, gameCenterEnabled, remindersEnabled
    }

    init(stageResults: [Int: StageResult],
         totalStars: Int,
         totalFlightTime: TimeInterval,
         bestFreeFlightStars: Int,
         selectedCharacter: CharacterType,
         selectedVehicle: VehicleType,
         sensitivityLevel: SensitivityLevel,
         selectedTrailTier: TrailColorTier = .vehicle,
         lastSeenTrailTierThreshold: Int = 0,
         dailyResults: [String: StageResult] = [:],
         endlessBest: StageResult? = nil,
         bonusStars: Int = 0,
         gameCenterEnabled: Bool = false,
         remindersEnabled: Bool = false) {
        self.stageResults = stageResults
        self.totalStars = totalStars
        self.totalFlightTime = totalFlightTime
        self.bestFreeFlightStars = bestFreeFlightStars
        self.selectedCharacter = selectedCharacter
        self.selectedVehicle = selectedVehicle
        self.sensitivityLevel = sensitivityLevel
        self.selectedTrailTier = selectedTrailTier
        self.lastSeenTrailTierThreshold = lastSeenTrailTierThreshold
        self.dailyResults = dailyResults
        self.endlessBest = endlessBest
        self.bonusStars = bonusStars
        self.gameCenterEnabled = gameCenterEnabled
        self.remindersEnabled = remindersEnabled
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
        // Phase 3 fields.
        self.dailyResults      = try c.decodeIfPresent([String: StageResult].self, forKey: .dailyResults) ?? [:]
        self.endlessBest       = try c.decodeIfPresent(StageResult.self, forKey: .endlessBest)
        self.bonusStars        = try c.decodeIfPresent(Int.self, forKey: .bonusStars) ?? 0
        self.gameCenterEnabled = try c.decodeIfPresent(Bool.self, forKey: .gameCenterEnabled) ?? false
        self.remindersEnabled  = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
    }
}
