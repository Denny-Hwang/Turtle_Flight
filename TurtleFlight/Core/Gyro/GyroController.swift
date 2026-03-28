import Foundation
import CoreMotion
import Combine

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
