import Foundation

/// How the player flies (Settings → Controls, onboarding). 2026-11-26
/// owner request: an on-screen joystick for players who don't want to
/// tilt, and a mix where the thumb handles up/down so the screen never
/// has to be tipped away.
enum ControlMode: String, CaseIterable, Sendable {
    /// Tilt left/right to turn, forward/back to dive/climb.
    case tilt
    /// On-screen stick for both axes; the sensor is ignored.
    case joystick
    /// Tilt left/right to turn, stick up/down to climb/dive.
    case mixed

    var stickDrivesRoll: Bool { self == .joystick }
    var stickDrivesPitch: Bool { self != .tilt }
    var usesStick: Bool { self != .tilt }
    /// The sensor matters (and the start-of-flight calibration runs).
    var usesTilt: Bool { self != .joystick }

    var titleKey: String { "settings.controls.mode.\(rawValue)" }
    var captionKey: String { "settings.controls.mode.\(rawValue).caption" }
}

/// Persisted control preferences. UserDefaults is thread-safe; the
/// flight loop reads a cached copy (`FlightViewModel.controlMode`).
enum ControlPreferences {
    static let modeKey = "controls.mode"
    /// Pre-2026-11-26 "touch controls" toggle; true migrates to joystick.
    static let legacyTouchKey = "controls.touchEnabled"
    static let invertStickKey = "controls.stickInvert"
    static let stickOnLeftKey = "controls.stickOnLeft"

    static var mode: ControlMode {
        get {
            let defaults = UserDefaults.standard
            if let raw = defaults.string(forKey: modeKey), let mode = ControlMode(rawValue: raw) {
                return mode
            }
            return defaults.bool(forKey: legacyTouchKey) ? .joystick : .tilt
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: modeKey) }
    }

    /// Push up = dive (aeroplane style). Default off: up = climb.
    static var invertStickPitch: Bool {
        get { UserDefaults.standard.bool(forKey: invertStickKey) }
        set { UserDefaults.standard.set(newValue, forKey: invertStickKey) }
    }

    /// Left-handed: stick on the left, Boost on the right.
    static var stickOnLeft: Bool {
        get { UserDefaults.standard.bool(forKey: stickOnLeftKey) }
        set { UserDefaults.standard.set(newValue, forKey: stickOnLeftKey) }
    }
}
