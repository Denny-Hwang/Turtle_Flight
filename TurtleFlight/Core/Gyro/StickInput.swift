import Foundation

/// On-screen joystick input, filtered per frame.
///
/// THREADING: `hold` / `release` come from the SwiftUI drag gesture on
/// main; `step` runs on the SceneKit render thread inside
/// `FlightViewModel.update`. The shared target is behind `lock`; the
/// filtered output and idle timer are render-thread only.
///
/// Replaces the old drag fallback in `GyroController`, which smoothed
/// only while the finger moved: a still finger never reached full input,
/// and lifting it left 65–92% of the last turn applied forever.
final class StickInput: @unchecked Sendable {
    /// Stick travel below this fraction of the radius reads as centred.
    static let deadZone = 0.1
    /// Per-frame (at 60 Hz) blend toward 0 after release: back to centre
    /// in about 0.15 s.
    static let releaseAlpha = 0.3

    private let lock = NSLock()
    private var target: SIMD2<Double>?

    private(set) var roll: Double = 0
    private(set) var pitch: Double = 0
    private var idleTime: TimeInterval = 0

    /// Finger at `x` (+ right), `y` (+ up = climb), each −1…1. Each
    /// axis is clamped on its own, so a full diagonal is full turn *and*
    /// full climb (`JoystickOverlay.normalized` maps the round knob onto
    /// this square).
    func hold(x: Double, y: Double) {
        let v = SIMD2(x.clamped(to: -1...1), y.clamped(to: -1...1))
        lock.lock(); target = v; lock.unlock()
    }

    func release() {
        lock.lock(); target = nil; lock.unlock()
    }

    var isHeld: Bool {
        lock.lock(); defer { lock.unlock() }
        return target != nil
    }

    func reset() {
        release()
        roll = 0
        pitch = 0
        idleTime = 0
    }

    /// Shape one stick axis: dead zone, then the level's curve exponent.
    static func shape(_ value: Double, exponent: Double) -> Double {
        let magnitude = abs(value)
        guard magnitude > deadZone else { return 0 }
        let normalized = min(1, (magnitude - deadZone) / (1 - deadZone))
        let shaped = pow(normalized, exponent)
        return value > 0 ? shaped : -shaped
    }

    /// Advance the filter one frame and return the inputs (−1…1).
    @discardableResult
    func step(deltaTime: Float, profile: SensitivityProfile) -> (roll: Double, pitch: Double) {
        lock.lock(); let held = target; lock.unlock()
        let frames = max(Double(deltaTime) * 60, 0)
        if let held {
            let wantRoll = Self.shape(held.x, exponent: profile.roll.exponent)
            let wantPitch = Self.shape(held.y, exponent: profile.pitch.exponent)
            // Same feel as the tilt path: the level's smoothing, made
            // frame-rate independent.
            let a = 1 - pow(1 - profile.smoothingAlpha, frames)
            roll += (wantRoll - roll) * a
            pitch += (wantPitch - pitch) * a
        } else {
            let a = 1 - pow(1 - Self.releaseAlpha, frames)
            roll -= roll * a
            pitch -= pitch * a
            if abs(roll) < 0.001 { roll = 0 }
            if abs(pitch) < 0.001 { pitch = 0 }
        }
        if abs(roll) > 0.05 || abs(pitch) > 0.05 {
            idleTime = 0
        } else {
            idleTime += Double(deltaTime)
        }
        return (roll, pitch)
    }

    /// Same rule as `GyroController.shouldAutoLevel`, on stick idle time.
    func shouldAutoLevel(profile: SensitivityProfile) -> Bool {
        guard let delay = profile.autoLevelDelay else { return false }
        return idleTime >= delay
    }
}
