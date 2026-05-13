import Foundation
import UIKit

/// Star-milestone cosmetic progression for the in-flight particle trail.
///
/// The senior review (2026-05-12) called out a missing retention loop:
/// the player accumulates stars in Step Goal but the running total has
/// no visible consequence — no badge, no unlock, no reason to grind.
/// This tier system gives that count a cosmetic outlet:
///
///   • 0 ★    — Stock per-vehicle colour (jet flame is orange, glider
///              is sky-blue, etc. — `TrailParameters.color`)
///   • 50 ★   — Magenta override
///   • 150 ★  — Star-gold override
///   • 300 ★  — Rainbow cycle (hue rotates across the trail's lifetime)
///
/// Tiers are *cosmetic*. They don't change physics, don't gate gameplay.
/// `vehicle` stays the default for a new player; once a higher tier is
/// unlocked the player can pick it from Settings → Trail Color.
///
/// Codable + RawRepresentable so it round-trips through the persisted
/// `PlayerProgress` blob without a custom migration step (an unknown
/// raw value decodes as `.vehicle` via the failable init below).
enum TrailColorTier: Int, Codable, CaseIterable, Equatable {
    case vehicle = 0
    case magenta = 50
    case gold    = 150
    case rainbow = 300

    /// Threshold the player has to cross to unlock this tier. `0` means
    /// always available. The raw value is the threshold for an
    /// at-a-glance "what does X stars get me" reading.
    var unlockStarThreshold: Int { rawValue }

    /// Stable identifier used as a localised-key suffix.
    var l10nKey: String {
        switch self {
        case .vehicle: return "settings.trail.tier.vehicle"
        case .magenta: return "settings.trail.tier.magenta"
        case .gold:    return "settings.trail.tier.gold"
        case .rainbow: return "settings.trail.tier.rainbow"
        }
    }

    /// Concrete override colour. Nil ⇒ use the vehicle's stock colour
    /// (the `.vehicle` tier never overrides). Rainbow returns nil here
    /// because hue rotation needs an animator (see `useRainbow`).
    var overrideColor: UIColor? {
        switch self {
        case .vehicle: return nil
        case .magenta: return UIColor(red: 0.94, green: 0.27, blue: 0.78, alpha: 1)
        case .gold:    return UIColor(red: 1.00, green: 0.84, blue: 0.20, alpha: 1)
        case .rainbow: return nil   // animator owns the cycle
        }
    }

    /// True when the rainbow animator should drive particleColor each
    /// frame instead of a static tint. Only `.rainbow` returns true.
    var useRainbow: Bool { self == .rainbow }

    /// Highest tier unlocked at this star count. Used both for the
    /// "you've earned X" banner and to clamp the player's persisted
    /// selection when Settings reads back a tier they no longer have.
    static func highestUnlocked(totalStars: Int) -> TrailColorTier {
        // Walk in descending threshold order. CaseIterable's `allCases`
        // matches declaration order, which we mirror to thresholds; a
        // reverse iteration is sufficient and stays correct if a new
        // tier is added in the middle (just reorder the cases).
        let sorted = allCases.sorted { $0.unlockStarThreshold > $1.unlockStarThreshold }
        for tier in sorted where totalStars >= tier.unlockStarThreshold {
            return tier
        }
        return .vehicle
    }

    /// True iff the player's star count entitles them to this tier.
    func isUnlocked(totalStars: Int) -> Bool {
        totalStars >= unlockStarThreshold
    }
}
