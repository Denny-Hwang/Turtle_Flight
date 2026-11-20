import UIKit

/// Time of day for one flight. Open-sky worlds pick one per flight so
/// the same place looks different from run to run; space and ocean keep
/// their own lighting.
///
/// Purely cosmetic — no gameplay value changes, and the pick is a
/// deterministic function of the day and the flight number so it can be
/// tested and reproduced.
enum SkyMood: String, CaseIterable {
    case morning
    case day
    case sunset
    case night

    /// Out of 100. Daylight is the most common so the game reads bright
    /// by default; night is the rare treat.
    var weight: Int {
        switch self {
        case .day:     return 40
        case .morning: return 20
        case .sunset:  return 25
        case .night:   return 15
        }
    }

    static func pick(seed: Int) -> SkyMood {
        var rng = SeededRandom(seed: seed)
        var roll = rng.nextInt(in: 0...99)
        for mood in [SkyMood.day, .morning, .sunset, .night] {
            if roll < mood.weight { return mood }
            roll -= mood.weight
        }
        return .day
    }

    /// Mood for the given flight: stable within a flight, different on
    /// the next one, and different tomorrow.
    static func forFlight(number: Int, date: Date = Date(), world: MapTheme) -> SkyMood {
        guard world.hasOpenSky else { return .day }
        let day = Int(date.timeIntervalSince1970 / 86_400)
        return pick(seed: day &* 31 &+ number &* 7919 &+ Int(SeededRandom.stableHash(world.rawValue) % 997))
    }

    /// Colour the sky is blended toward, and how far.
    private var tint: (color: UIColor, amount: CGFloat) {
        switch self {
        case .day:     return (.white, 0)
        case .morning: return (UIColor(red: 1.00, green: 0.82, blue: 0.80, alpha: 1), 0.35)
        case .sunset:  return (UIColor(red: 0.99, green: 0.58, blue: 0.40, alpha: 1), 0.55)
        case .night:   return (UIColor(red: 0.07, green: 0.09, blue: 0.24, alpha: 1), 0.82)
        }
    }

    /// Multiplier on the world's light intensities.
    var lightScale: CGFloat {
        switch self {
        case .day:     return 1
        case .morning: return 0.95
        case .sunset:  return 0.85
        case .night:   return 0.6
        }
    }

    var lightColor: UIColor? {
        switch self {
        case .day:     return nil
        case .morning: return UIColor(red: 1.0, green: 0.93, blue: 0.88, alpha: 1)
        case .sunset:  return UIColor(red: 1.0, green: 0.78, blue: 0.60, alpha: 1)
        case .night:   return UIColor(red: 0.70, green: 0.76, blue: 1.0, alpha: 1)
        }
    }

    var showsStars: Bool { self == .night }

    func skyColor(base: UIColor) -> UIColor {
        let (target, amount) = tint
        guard amount > 0 else { return base }
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        target.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount, alpha: 1)
    }
}
