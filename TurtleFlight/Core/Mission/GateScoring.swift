import Foundation

/// How cleanly the player threaded a gate. Derived from
/// `MissionEngine.RingCrossing.accuracy` (0 = dead centre, 1 = rim).
///
/// The thresholds are the whole design: a 50m ring gives a 10m-radius
/// bullseye, which is precise enough to demand real tilt control but
/// wide enough that a kid on Easy hits it sometimes by feel. Everything
/// inside the rim still *passes* — judgement only changes points and
/// combo, never whether the stage progresses.
enum GateJudgement: String, Codable, CaseIterable, Equatable {
    case bullseye
    case great
    case ok
    case miss

    /// Localisation key for the HUD callout.
    var l10nKey: String { "gate.judgement.\(rawValue)" }

    /// Point multiplier applied to `GateScoring.basePoints`.
    var multiplier: Int {
        switch self {
        case .bullseye: return 3
        case .great:    return 2
        case .ok:       return 1
        case .miss:     return 0
        }
    }

    /// True when the crossing counts as a pass.
    var isPass: Bool { self != .miss }
}

enum GateScoring {

    /// Accuracy (fraction of radius) at or below which a pass is a bullseye.
    static let bullseyeAccuracy: Float = 0.20
    /// Accuracy at or below which a pass is "great".
    static let greatAccuracy: Float = 0.60
    /// Points for an OK pass with no combo.
    static let basePoints = 100
    /// Each combo step adds this fraction of the base value; capped so a
    /// long chain rewards consistency without making early misses
    /// unrecoverable. At the cap a bullseye is worth 3 × 100 × 2.0 = 600.
    static let comboStepBonus: Float = 0.10
    static let comboBonusCap: Float = 1.0

    /// Map a crossing accuracy to a judgement.
    static func judge(accuracy: Float) -> GateJudgement {
        if accuracy <= bullseyeAccuracy { return .bullseye }
        if accuracy <= greatAccuracy   { return .great }
        if accuracy <= 1               { return .ok }
        return .miss
    }

    /// Points for a judgement given the combo *before* this gate.
    static func points(for judgement: GateJudgement, combo: Int) -> Int {
        guard judgement.isPass else { return 0 }
        let bonus = min(Float(combo) * comboStepBonus, comboBonusCap)
        return Int((Float(basePoints * judgement.multiplier) * (1 + bonus)).rounded())
    }
}

/// Running score for one course attempt. Value type so the engine can
/// hand out snapshots to the HUD without aliasing.
struct RunScore: Codable, Equatable {
    var points: Int = 0
    /// Consecutive passes since the last miss.
    var combo: Int = 0
    var maxCombo: Int = 0
    var bullseyes: Int = 0
    var greats: Int = 0
    var oks: Int = 0
    var misses: Int = 0

    /// Number of gates that were passed (any judgement but miss).
    var passes: Int { bullseyes + greats + oks }

    /// Apply a judgement and return the points it earned.
    @discardableResult
    mutating func register(_ judgement: GateJudgement) -> Int {
        let earned = GateScoring.points(for: judgement, combo: combo)
        switch judgement {
        case .bullseye: bullseyes += 1
        case .great:    greats += 1
        case .ok:       oks += 1
        case .miss:     misses += 1
        }
        if judgement.isPass {
            combo += 1
            maxCombo = max(maxCombo, combo)
        } else {
            combo = 0
        }
        points += earned
        return earned
    }
}
