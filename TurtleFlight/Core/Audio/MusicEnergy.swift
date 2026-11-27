import Foundation

/// How much of the reactive music layer to mix in (M4, plan §5). The
/// song itself never changes; the energy layer (driving percussion + a
/// high arpeggio, same form) fades in when the flight heats up.
enum MusicEnergy {
    static func level(isBoosting: Bool, combo: Int, isTimeCritical: Bool, isPaused: Bool) -> Float {
        if isPaused { return 0 }
        if isBoosting { return 1 }
        if combo >= 5 { return 0.85 }
        if combo >= 3 { return 0.6 }
        if isTimeCritical { return 0.55 }
        return 0
    }
}
