import Foundation

struct SensitivityProfile {
    let level: SensitivityLevel
    let deadZone: Double        // radians
    let maxTilt: Double         // radians
    let smoothingAlpha: Double
    let turnSpeed: Double       // degrees/sec
    let pitchSpeed: Double      // m/s
    let autoLevelDelay: Double? // seconds, nil = disabled
    let minAltitude: Double     // meters
    let stallEnabled: Bool

    /// Apply response curve based on sensitivity level
    func applyCurve(_ value: Double) -> Double {
        let normalized = (value / maxTilt).clamped(to: -1...1)
        switch level {
        case .easy:
            return normalized.sign * pow(abs(normalized), 3)  // Cubic
        case .normal:
            return normalized.sign * pow(abs(normalized), 2)  // Quadratic
        case .expert:
            return normalized  // Linear
        }
    }

    /// Check if input is within dead zone
    func isInDeadZone(_ value: Double) -> Bool {
        abs(value) < deadZone
    }

    /// Apply dead zone filtering
    func applyDeadZone(_ value: Double) -> Double {
        if isInDeadZone(value) { return 0.0 }
        // Remap remaining range to 0...1
        let sign = value > 0 ? 1.0 : -1.0
        let adjusted = abs(value) - deadZone
        let range = maxTilt - deadZone
        guard range > 0 else { return 0 }
        return sign * (adjusted / range) * maxTilt
    }

    // MARK: - Preset Profiles

    static let easy = SensitivityProfile(
        level: .easy,
        deadZone: 8.0.rad,
        maxTilt: 25.0.rad,
        smoothingAlpha: 0.08,
        turnSpeed: 45,
        pitchSpeed: 30,
        autoLevelDelay: 2.0,
        minAltitude: 50,
        stallEnabled: false
    )

    static let normal = SensitivityProfile(
        level: .normal,
        deadZone: 4.0.rad,
        maxTilt: 35.0.rad,
        smoothingAlpha: 0.15,
        turnSpeed: 90,
        pitchSpeed: 60,
        autoLevelDelay: 4.0,
        minAltitude: 20,
        stallEnabled: false
    )

    static let expert = SensitivityProfile(
        level: .expert,
        deadZone: 1.5.rad,
        maxTilt: 50.0.rad,
        smoothingAlpha: 0.35,
        turnSpeed: 180,
        pitchSpeed: 120,
        autoLevelDelay: nil,
        minAltitude: 5,
        stallEnabled: true
    )

    static func profile(for level: SensitivityLevel) -> SensitivityProfile {
        switch level {
        case .easy:   return .easy
        case .normal: return .normal
        case .expert: return .expert
        }
    }
}
