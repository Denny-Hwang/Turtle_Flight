import Foundation
import UIKit

/// How the phone is tilted, measured against the landscape screen the
/// player is looking at (not the device's portrait axes).
///
/// Read from the gravity vector rather than Euler angles: Euler roll /
/// pitch are defined on the device's *portrait* axes, so in landscape
/// "lean forward/back" came out as roll and "tilt left/right" as yaw —
/// steering and climbing were crossed (found on the iPhone, 2026-11-24).
/// Gravity also has no yaw drift and no gimbal flip near upright.
struct ScreenTilt: Equatable {
    /// Radians the screen's right edge sits below the left one.
    /// + = right side down (steer right).
    var lateral: Double
    /// Radians the screen leans back from upright, toward lying face-up.
    /// 0 = held straight up, π/2 = flat on a table. + = top edge tipped
    /// away from the player.
    var lean: Double
}

enum TiltMapping {
    /// Gravity (device frame, from `CMDeviceMotion.gravity`) expressed in
    /// screen axes: x = screen right, y = screen up, z = out of the screen.
    static func screenGravity(_ g: SIMD3<Double>, orientation: UIInterfaceOrientation) -> SIMD3<Double> {
        switch orientation {
        case .landscapeRight:
            // Home side on the right: the device's top points left.
            return SIMD3(-g.y, g.x, g.z)
        case .landscapeLeft:
            // Home side on the left: the device's top points right.
            return SIMD3(g.y, -g.x, g.z)
        case .portraitUpsideDown:
            return SIMD3(-g.x, -g.y, g.z)
        default:
            return g
        }
    }

    static func tilt(gravity g: SIMD3<Double>, orientation: UIInterfaceOrientation) -> ScreenTilt {
        let s = screenGravity(g, orientation: orientation)
        let length = max((s.x * s.x + s.y * s.y + s.z * s.z).squareRoot(), 1e-6)
        let lateral = asin((s.x / length).clamped(to: -1...1))
        let lean = atan2(-s.z, -s.y)
        return ScreenTilt(lateral: lateral, lean: lean)
    }

    /// Steering and climb angles (radians) relative to the calibrated
    /// neutral pose. roll + = turn right. pitch + = climb (stand the
    /// phone up from neutral); tipping the top edge away dives.
    static func inputs(_ tilt: ScreenTilt, reference: ScreenTilt) -> (roll: Double, pitch: Double) {
        let roll = tilt.lateral - reference.lateral
        let pitch = -wrap(tilt.lean - reference.lean)
        return (roll, pitch)
    }

    /// Wrap an angle into (-π, π].
    static func wrap(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a <= -.pi { a += 2 * .pi }
        return a
    }

    /// Interface orientation of the foreground window scene. Landscape
    /// right is the app's usual pose, so it is the fallback.
    @MainActor
    static func currentInterfaceOrientation() -> UIInterfaceOrientation {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let orientation = active?.interfaceOrientation ?? .landscapeRight
        return orientation == .unknown ? .landscapeRight : orientation
    }
}

/// Finds the player's neutral pose at the start of a flight: waits until
/// the phone is held still for `steadyDuration`, then takes the average of
/// that window. A shaky hand (or a child) never blocks the start: after
/// `timeout` it uses whatever the last window averaged.
struct TiltCalibrator {
    static let steadyDuration: TimeInterval = 0.6
    static let timeout: TimeInterval = 2.5
    /// Largest spread (radians, either axis) still counted as "held still".
    static let steadyTolerance: Double = 3.0 * .pi / 180

    private(set) var samples: [(time: TimeInterval, tilt: ScreenTilt)] = []
    private var startTime: TimeInterval?

    /// 0…1 — how much of the steady window has been filled. Drops back
    /// when the phone moves.
    private(set) var progress: Double = 0

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        startTime = nil
        progress = 0
    }

    /// Feed one sample. Returns the neutral pose once it is found.
    mutating func add(_ tilt: ScreenTilt, at time: TimeInterval) -> ScreenTilt? {
        if startTime == nil { startTime = time }
        samples.append((time, tilt))
        samples.removeAll { time - $0.time > Self.steadyDuration }

        // Walk back from the newest sample while the spread stays inside
        // the tolerance: that run is how long the phone has been still.
        var firstSteady = samples.count - 1
        var latRange = (tilt.lateral, tilt.lateral), leanRange = (tilt.lean, tilt.lean)
        while firstSteady > 0 {
            let t = samples[firstSteady - 1].tilt
            latRange = (min(latRange.0, t.lateral), max(latRange.1, t.lateral))
            leanRange = (min(leanRange.0, t.lean), max(leanRange.1, t.lean))
            if latRange.1 - latRange.0 > Self.steadyTolerance
                || leanRange.1 - leanRange.0 > Self.steadyTolerance { break }
            firstSteady -= 1
        }
        let stillFor = time - samples[firstSteady].time
        progress = min(1, stillFor / Self.steadyDuration)

        let elapsed = time - (startTime ?? time)
        if stillFor >= Self.steadyDuration * 0.95 {
            return average(samples[firstSteady...].map(\.tilt))
        }
        if elapsed >= Self.timeout {
            return average(samples.map(\.tilt))
        }
        return nil
    }

    /// Neutral pose from whatever has been collected (the "Start now"
    /// button). Nil before the first sample.
    func currentAverage() -> ScreenTilt? {
        samples.isEmpty ? nil : average(samples.suffix(10).map(\.tilt))
    }

    private func average(_ tilts: [ScreenTilt]) -> ScreenTilt {
        let n = Double(max(tilts.count, 1))
        return ScreenTilt(lateral: tilts.reduce(0) { $0 + $1.lateral } / n,
                          lean: tilts.reduce(0) { $0 + $1.lean } / n)
    }
}
