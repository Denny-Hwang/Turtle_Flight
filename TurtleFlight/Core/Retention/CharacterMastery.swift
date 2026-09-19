import Foundation

/// Per-character progression. Flying a character earns mastery XP;
/// levels unlock titles shown on the character tile and the Home cameo.
/// It is the "why fly Pip today instead of Turbo again" answer, and it
/// pairs with the `flyCharacter` daily quest.
///
/// XP sources (all fed from the game loop):
///   • flight started      +10
///   • gate passed          +2   (+3 more for a bullseye)
///   • course cleared       +40  (+20 for a clean clear)
///   • per minute of flight +5
enum CharacterMastery {

    static let maxLevel = 10

    /// Cumulative XP needed to *reach* each level (index = level - 1).
    /// Level 1 is free; level 10 is ~2,600 XP ≈ 25–30 solid runs.
    static let thresholds: [Int] = [0, 60, 150, 280, 450, 680, 980, 1360, 1850, 2600]

    static func level(for xp: Int) -> Int {
        var level = 1
        for (i, t) in thresholds.enumerated() where xp >= t {
            level = i + 1
        }
        return min(level, maxLevel)
    }

    /// XP into the current level and the size of the level (nil at max).
    static func progress(for xp: Int) -> (into: Int, span: Int)? {
        let lvl = level(for: xp)
        guard lvl < maxLevel else { return nil }
        let start = thresholds[lvl - 1]
        let next = thresholds[lvl]
        return (xp - start, next - start)
    }

    /// Localisation key for the level's title ("Hatchling" … "Sky Legend").
    static func titleKey(for level: Int) -> String {
        switch level {
        case ..<3:  return "mastery.title.1"
        case 3..<5: return "mastery.title.2"
        case 5..<7: return "mastery.title.3"
        case 7..<9: return "mastery.title.4"
        default:    return "mastery.title.5"
        }
    }

    enum Gain {
        case flightStarted
        case gatePassed(bullseye: Bool)
        case courseCleared(clean: Bool)
        case minutesFlown(Int)

        var xp: Int {
            switch self {
            case .flightStarted:               return 10
            case .gatePassed(let bullseye):    return bullseye ? 5 : 2
            case .courseCleared(let clean):    return clean ? 60 : 40
            case .minutesFlown(let minutes):   return max(0, minutes) * 5
            }
        }
    }
}

extension PlayerProgress {
    /// Mastery XP for a character (0 when never flown).
    func masteryXP(for character: CharacterType) -> Int {
        masteryXP[character.rawValue] ?? 0
    }

    func masteryLevel(for character: CharacterType) -> Int {
        CharacterMastery.level(for: masteryXP(for: character))
    }

    /// Add XP; returns the new level if it went up, else nil.
    @discardableResult
    mutating func addMastery(_ gain: CharacterMastery.Gain, to character: CharacterType) -> Int? {
        let before = masteryLevel(for: character)
        masteryXP[character.rawValue, default: 0] += gain.xp
        let after = masteryLevel(for: character)
        return after > before ? after : nil
    }
}
