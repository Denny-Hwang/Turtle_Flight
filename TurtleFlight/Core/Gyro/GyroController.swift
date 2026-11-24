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
    /// True while the start-of-flight calibration is looking for the
    /// player's neutral pose. Inputs stay at zero meanwhile.
    @Published private(set) var isCalibrating: Bool = false
    /// 0…1 — how long the phone has been held still, for the overlay ring.
    @Published private(set) var calibrationProgress: Double = 0

    /// Player preference (Settings → Controls): steer by dragging on the
    /// screen instead of tilting. Tilt can be uncomfortable — or simply
    /// impossible lying down or in a car — and a large screen makes it
    /// worse, so the drag path is a first-class option rather than a
    /// Simulator-only fallback. Persisted; default off.
    static let touchControlKey = "controls.touchEnabled"
    static var touchControlEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: touchControlKey) }
        set { UserDefaults.standard.set(newValue, forKey: touchControlKey) }
    }

    /// True when drag input should drive the flight: no gyro, or the
    /// player chose touch controls.
    var usesTouchInput: Bool { !isAvailable || Self.touchControlEnabled }

    // MARK: - Properties
    private let motionManager = CMMotionManager()
    /// Neutral pose the player chose at the start of the flight.
    private var reference: ScreenTilt?
    private var latestTilt: ScreenTilt?
    private var calibrator = TiltCalibrator()
    private var onCalibrated: (() -> Void)?
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
        guard !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = Constants.Sensor.updateInterval

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            // Handler queue is `.main` (see above).
            let orientation = MainActor.assumeIsolated { TiltMapping.currentInterfaceOrientation() }
            let g = motion.gravity
            self.processTilt(TiltMapping.tilt(gravity: SIMD3(g.x, g.y, g.z), orientation: orientation),
                             at: motion.timestamp)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// Find the player's neutral pose afresh: inputs read zero until the
    /// phone has been held still briefly (or `TiltCalibrator.timeout`
    /// passes), then `completion` runs on main. Finishes at once when the
    /// sensor is not driving the flight (Simulator, touch controls).
    func beginCalibration(completion: (() -> Void)? = nil) {
        resetSmoothing()
        guard isAvailable, !Self.touchControlEnabled else {
            isCalibrating = false
            calibrationProgress = 1
            completion?()
            return
        }
        calibrator.reset()
        calibrationProgress = 0
        onCalibrated = completion
        isCalibrating = true
    }

    /// "Start now": take the pose the phone is in right now.
    func finishCalibrationNow() {
        guard isCalibrating else { return }
        completeCalibration(with: calibrator.currentAverage() ?? latestTilt)
    }

    /// Re-zero to the current pose (in-flight Calibrate button, resume).
    func calibrate() {
        beginCalibration()
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
        guard usesTouchInput else { return }

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
        guard usesTouchInput else { return }
        // Don't slam to zero — let the smoothing decay so the camera
        // doesn't jump back to neutral instantly.
        let alpha = profile.smoothingAlpha
        smoothedRoll  = smoothedRoll  * (1 - alpha)
        smoothedPitch = smoothedPitch * (1 - alpha)
        rollInput  = smoothedRoll.clamped(to: -1...1)
        pitchInput = smoothedPitch.clamped(to: -1...1)
    }

    // MARK: - Private Methods

    private func resetSmoothing() {
        smoothedRoll = 0
        smoothedPitch = 0
        rollInput = 0
        pitchInput = 0
        lastInputTime = Date()
        timeSinceLastInput = 0
    }

    private func completeCalibration(with neutral: ScreenTilt?) {
        reference = neutral ?? reference
        isCalibrating = false
        calibrationProgress = 1
        resetSmoothing()
        let done = onCalibrated
        onCalibrated = nil
        done?()
    }

    /// One sensor sample, already in landscape screen terms. Internal so
    /// tests can drive the pipeline without CoreMotion.
    func processTilt(_ tilt: ScreenTilt, at time: TimeInterval) {
        // Touch controls own the input; ignoring the sensor here keeps
        // the two from fighting.
        guard !Self.touchControlEnabled else { return }
        latestTilt = tilt

        if isCalibrating {
            let neutral = calibrator.add(tilt, at: time)
            if abs(calibrator.progress - calibrationProgress) > 0.05 || neutral != nil {
                calibrationProgress = calibrator.progress
            }
            if let neutral { completeCalibration(with: neutral) }
            return
        }
        // No flight has calibrated yet (e.g. onboarding preview): the
        // first sample is neutral.
        guard let reference else {
            self.reference = tilt
            return
        }

        let (rawRoll, rawPitch) = TiltMapping.inputs(tilt, reference: reference)

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
