import Foundation
import CoreMotion
import Combine

/// THREADING INVARIANT — every CoreMotion callback is scheduled on
/// `.main` (see `start(...)`), every consumer (FlightViewModel) calls
/// us from the main thread, and the `@Published` properties are read
/// by SwiftUI on main. We do not mark the class `@MainActor` yet
/// because doing so cascades into the SCNView Coordinator and several
/// test fixtures; the invariant above is the v1.0 contract. Swift 6
/// strict-concurrency adoption is a v1.1 follow-up.
final class GyroController: ObservableObject {
    // MARK: - Published State
    @Published var rollInput: Double = 0.0   // -1...1
    @Published var pitchInput: Double = 0.0  // -1...1
    @Published var isAvailable: Bool = false
    @Published var timeSinceLastInput: TimeInterval = 0

    // MARK: - Properties
    private let motionManager = CMMotionManager()
    private var referenceAttitude: CMAttitude?
    private var profile: SensitivityProfile
    private var smoothedRoll: Double = 0
    private var smoothedPitch: Double = 0
    private var lastInputTime: Date = Date()

    // MARK: - Init
    init(sensitivity: SensitivityLevel = .easy) {
        self.profile = SensitivityProfile.profile(for: sensitivity)
    }

    // MARK: - Public Methods

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            isAvailable = false
            return
        }

        isAvailable = true
        motionManager.deviceMotionUpdateInterval = Constants.Sensor.updateInterval

        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            self.processMotion(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    func calibrate() {
        referenceAttitude = nil // Will be set on next motion update
    }

    func updateSensitivity(_ level: SensitivityLevel) {
        profile = SensitivityProfile.profile(for: level)
    }

    // MARK: - Fallback (Simulator / iPad-without-gyro)

    /// Inject a manual roll/pitch sample. Each component is a tilt
    /// approximation in [-1, 1] — typically sourced from a touch-drag
    /// gesture on the SCNView when `isAvailable == false`. Goes through
    /// the same dead-zone → response-curve → low-pass filter pipeline
    /// as a real gyro sample so the in-flight feel matches.
    ///
    /// Idempotent if `isAvailable == true` — when a real gyro is
    /// providing samples we ignore manual injection so an accidental
    /// touch on a connected device doesn't fight the sensor.
    func injectFallback(rollNormalized: Double, pitchNormalized: Double) {
        guard !isAvailable else { return }

        let clampedRoll  = rollNormalized.clamped(to: -1...1)
        let clampedPitch = pitchNormalized.clamped(to: -1...1)

        // Map the [-1, 1] virtual joystick into the same attitude space
        // the device-motion path produces — roughly profile.maxTilt
        // radians at full deflection. That way the dead-zone + curve
        // logic below is identical for both code paths.
        let virtualRoll  = clampedRoll  * profile.maxTilt
        let virtualPitch = clampedPitch * profile.maxTilt

        let filteredRoll  = profile.applyDeadZone(virtualRoll)
        let filteredPitch = profile.applyDeadZone(virtualPitch)

        let curvedRoll  = profile.applyCurve(filteredRoll)
        let curvedPitch = profile.applyCurve(filteredPitch)

        let alpha = profile.smoothingAlpha
        smoothedRoll  = smoothedRoll  * (1 - alpha) + curvedRoll  * alpha
        smoothedPitch = smoothedPitch * (1 - alpha) + curvedPitch * alpha

        rollInput  = smoothedRoll.clamped(to: -1...1)
        pitchInput = smoothedPitch.clamped(to: -1...1)

        if abs(rollInput) > 0.05 || abs(pitchInput) > 0.05 {
            lastInputTime = Date()
        }
        timeSinceLastInput = Date().timeIntervalSince(lastInputTime)
    }

    /// Drop fallback input back to neutral. Called when the user lifts
    /// their finger off the SCNView so the auto-level path can kick in
    /// after the configured delay.
    func releaseFallback() {
        guard !isAvailable else { return }
        // Don't slam to zero — let the smoothing decay so the camera
        // doesn't jump back to neutral instantly.
        let alpha = profile.smoothingAlpha
        smoothedRoll  = smoothedRoll  * (1 - alpha)
        smoothedPitch = smoothedPitch * (1 - alpha)
        rollInput  = smoothedRoll.clamped(to: -1...1)
        pitchInput = smoothedPitch.clamped(to: -1...1)
    }

    // MARK: - Private Methods

    private func processMotion(_ motion: CMDeviceMotion) {
        // Set reference attitude on first reading or after calibration
        if referenceAttitude == nil {
            referenceAttitude = motion.attitude.copy() as? CMAttitude
            return
        }

        // Get relative attitude from reference point
        guard let ref = referenceAttitude else { return }
        let attitude = motion.attitude
        attitude.multiply(byInverseOf: ref)

        let rawRoll = attitude.roll
        let rawPitch = attitude.pitch

        // Apply dead zone
        let filteredRoll = profile.applyDeadZone(rawRoll)
        let filteredPitch = profile.applyDeadZone(rawPitch)

        // Apply response curve
        let curvedRoll = profile.applyCurve(filteredRoll)
        let curvedPitch = profile.applyCurve(filteredPitch)

        // Low-pass filter (smoothing)
        let alpha = profile.smoothingAlpha
        smoothedRoll = smoothedRoll * (1 - alpha) + curvedRoll * alpha
        smoothedPitch = smoothedPitch * (1 - alpha) + curvedPitch * alpha

        // Clamp to -1...1
        rollInput = smoothedRoll.clamped(to: -1...1)
        pitchInput = smoothedPitch.clamped(to: -1...1)

        // Track last input time for auto-level
        if abs(rollInput) > 0.05 || abs(pitchInput) > 0.05 {
            lastInputTime = Date()
        }
        timeSinceLastInput = Date().timeIntervalSince(lastInputTime)
    }

    /// Check if auto-level should be applied
    var shouldAutoLevel: Bool {
        guard let delay = profile.autoLevelDelay else { return false }
        return timeSinceLastInput >= delay
    }

    /// Check if stall condition is active
    func isStalling(speed: Double) -> Bool {
        guard profile.stallEnabled else { return false }
        return speed < 100.0 // km/h
    }
}
