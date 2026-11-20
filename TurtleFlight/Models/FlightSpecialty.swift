import Foundation

/// What makes each friend fly differently once the Boost button is in
/// play. Vehicles already change the handling a little
/// (`VehicleType.handling`); the specialty belongs to the character and
/// is the same on their own vehicle and on Cloud Surf.
///
/// Every specialty is a trade or a different rhythm rather than a flat
/// upgrade, so there is no "best" character — just a favourite.
struct FlightSpecialty: Equatable {
    /// × `Constants.Flight.boostDuration`.
    var boostDuration: Float = 1
    /// × `Constants.Flight.boostMultiplier` (speed while boosting).
    var boostSpeed: Float = 1
    /// × passive gauge refill.
    var recharge: Float = 1
    /// × star pick-up radius.
    var starMagnet: Float = 1
    /// Extra climb (m/s) while boosting.
    var boostLift: Float = 0
    /// Gauge fraction refunded by a bullseye.
    var bullseyeCharge: Float = 0

    static let neutral = FlightSpecialty()

    static func of(_ character: CharacterType) -> FlightSpecialty {
        switch character {
        case .turtle:  return FlightSpecialty(boostDuration: 1.5)                    // long burn
        case .penguin: return FlightSpecialty(boostDuration: 0.8, boostSpeed: 1.2)   // short, fastest dash
        case .hamster: return FlightSpecialty(recharge: 1.6)                         // quick refill
        case .cat:     return FlightSpecialty(starMagnet: 2.2)                       // star magnet
        case .frog:    return FlightSpecialty(boostLift: 16)                         // boost hops upward
        case .bunny:   return FlightSpecialty(bullseyeCharge: 0.34)                  // bullseyes refill
        }
    }
}

extension CharacterType {
    var specialty: FlightSpecialty { .of(self) }
    /// One-line description shown on the selection screen.
    var specialtyText: String { L10n.t("specialty.\(rawValue)") }
}
