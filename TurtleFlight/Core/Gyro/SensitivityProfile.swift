import Foundation

/// How one tilt axis turns into a -1…1 input: ignore `deadZone`, reach
/// full input at `fullTilt`, and shape the middle with `exponent`
/// (1 = linear, larger = gentler near centre).
struct AxisResponse: Equatable {
    let deadZone: Double    // radians
    let fullTilt: Double    // radians — tilt from neutral for full input
    let exponent: Double

    /// Tilt (radians from neutral) → input in -1…1.
    func input(for tilt: Double) -> Double {
        let magnitude = abs(tilt)
        guard magnitude > deadZone else { return 0 }
        let range = fullTilt - deadZone
        guard range > 0 else { return tilt > 0 ? 1 : -1 }
        let normalized = min(1, (magnitude - deadZone) / range)
        let shaped = pow(normalized, exponent)
        return tilt > 0 ? shaped : -shaped
    }
}

/// Per-level control feel.
///
/// 2026-11-26 (owner, on the iPhone): the old single-range profile asked
/// for 25–50° of tilt and a cubic/quadratic curve on top, so climbing
/// meant tipping the phone until the screen was hard to see, and steering
/// was tiring. Steering and climbing now have their own ranges, both
/// small: full climb at 12–15° (the screen stays readable), full turn at
/// 18–25° (wrist-comfortable), with gentler curves.
struct SensitivityProfile {
    let level: SensitivityLevel
    /// Left/right tilt → turn.
    let roll: AxisResponse
    /// Forward/back tilt → climb/dive (and, through the energy model,
    /// speed).
    let pitch: AxisResponse
    let smoothingAlpha: Double
    let turnSpeed: Double       // degrees/sec
    let pitchSpeed: Double      // m/s
    let autoLevelDelay: Double? // seconds, nil = disabled
    let minAltitude: Double     // meters
    let stallEnabled: Bool
    /// Phase 2 energy model: dive to gain speed, climb to lose it. On for
    /// every level since 2026-11-24 (owner: tipping the phone forward
    /// should feel faster). Easy's low `pitchSpeed` keeps it gentle —
    /// about 150–250 km/h at full tilt — and Easy never stalls.
    let energyModelEnabled: Bool

    /// Largest tilt either axis needs (Settings shows it).
    var maxTilt: Double { max(roll.fullTilt, pitch.fullTilt) }

    // MARK: - Preset Profiles

    static let easy = SensitivityProfile(
        level: .easy,
        roll: AxisResponse(deadZone: 3.0.rad, fullTilt: 18.0.rad, exponent: 1.6),
        pitch: AxisResponse(deadZone: 2.5.rad, fullTilt: 12.0.rad, exponent: 1.4),
        smoothingAlpha: 0.08,
        turnSpeed: 45,
        pitchSpeed: 40,
        autoLevelDelay: 2.0,
        minAltitude: 50,
        stallEnabled: false,
        energyModelEnabled: true
    )

    static let normal = SensitivityProfile(
        level: .normal,
        roll: AxisResponse(deadZone: 2.0.rad, fullTilt: 20.0.rad, exponent: 1.4),
        pitch: AxisResponse(deadZone: 2.0.rad, fullTilt: 12.0.rad, exponent: 1.25),
        smoothingAlpha: 0.15,
        turnSpeed: 90,
        pitchSpeed: 70,
        autoLevelDelay: 4.0,
        minAltitude: 20,
        stallEnabled: false,
        energyModelEnabled: true
    )

    static let expert = SensitivityProfile(
        level: .expert,
        roll: AxisResponse(deadZone: 1.0.rad, fullTilt: 25.0.rad, exponent: 1.0),
        pitch: AxisResponse(deadZone: 1.0.rad, fullTilt: 15.0.rad, exponent: 1.0),
        smoothingAlpha: 0.35,
        turnSpeed: 180,
        pitchSpeed: 120,
        autoLevelDelay: nil,
        minAltitude: 5,
        stallEnabled: true,
        energyModelEnabled: true
    )

    static func profile(for level: SensitivityLevel) -> SensitivityProfile {
        switch level {
        case .easy:   return .easy
        case .normal: return .normal
        case .expert: return .expert
        }
    }
}
