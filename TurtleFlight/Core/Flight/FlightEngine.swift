import Foundation
import SceneKit

final class FlightEngine {
    // MARK: - Flight State
    struct FlightState {
        var position: SCNVector3 = SCNVector3(0, 500, 0)
        var rotation: SCNVector3 = .init(0, 0, 0) // euler angles
        var heading: Float = 0       // degrees, 0 = North
        var speed: Float = 200       // km/h
        var altitude: Float = 500    // meters
        var verticalSpeed: Float = 0 // m/s
        var isBoosting: Bool = false
        var boostTimeRemaining: Float = 0
        /// Boost gauge in [0, 1]. A boost needs a full gauge and drains it;
        /// stars refill it (`registerStarCollected`) and it trickles back
        /// on its own. Starts full so the first flight can boost at once.
        var boostCharge: Float = 1
        /// True while the energy model has the character stalled (Expert
        /// only): too slow to hold altitude, nose drops until speed returns.
        var isStalled: Bool = false
        var flightTime: TimeInterval = 0
    }

    // MARK: - Properties
    private(set) var state = FlightState()
    private var profile: SensitivityProfile
    /// Per-vehicle multipliers applied on top of the sensitivity profile
    /// each frame. Defaults to `.neutral` (all 1.0) for unit tests and
    /// pre-vehicle-selection state. FlightViewModel sets this in
    /// `startFlight(...)` to the current vehicle's handling.
    var vehicleHandling: VehicleHandling = .neutral

    /// Un-boosted cruise speed the energy model relaxes toward (km/h).
    /// Separate from `state.speed` so boost can be layered on top as an
    /// instantaneous multiplier without feeding back into the model.
    private var energySpeed: Float = Constants.Flight.defaultSpeed

    // MARK: - Init
    init(sensitivity: SensitivityLevel = .easy) {
        self.profile = SensitivityProfile.profile(for: sensitivity)
    }

    // MARK: - Public Methods

    func updateSensitivity(_ level: SensitivityLevel) {
        profile = SensitivityProfile.profile(for: level)
    }

    func reset() {
        state = FlightState()
        energySpeed = Constants.Flight.defaultSpeed
    }

    /// A collected star tops up the boost gauge.
    func registerStarCollected() {
        state.boostCharge = min(1, state.boostCharge + Constants.Flight.boostChargePerStar)
    }

    /// True when tapping Boost right now would start one.
    var canBoost: Bool {
        !state.isBoosting && state.boostCharge >= 1
    }

    /// Main update loop - call every frame
    func update(
        deltaTime: Float,
        rollInput: Double,
        pitchInput: Double,
        isBoosting: Bool,
        shouldAutoLevel: Bool
    ) {
        state.flightTime += Double(deltaTime)

        // Boost: needs a full gauge, drains it, then the gauge trickles
        // back (and jumps on every star) so the player has a reason to
        // chase stars and a rhythm to when they can punch it again.
        if isBoosting && state.boostTimeRemaining <= 0 && state.boostCharge >= 1 {
            state.isBoosting = true
            state.boostTimeRemaining = Float(Constants.Flight.boostDuration)
            state.boostCharge = 0
        }
        if state.boostTimeRemaining > 0 {
            state.boostTimeRemaining -= deltaTime
            if state.boostTimeRemaining <= 0 {
                state.isBoosting = false
            }
        } else {
            state.boostCharge = min(1, state.boostCharge
                                    + Constants.Flight.boostRechargePerSecond * deltaTime)
        }

        let speedMultiplier: Float = state.isBoosting ? Constants.Flight.boostMultiplier : 1.0

        // Vertical speed from pitch input, with per-vehicle pitch multiplier
        // (e.g. balloon body has the highest lift at 1.15).
        let pitchRate = Float(profile.pitchSpeed) * vehicleHandling.pitch * Float(pitchInput)
        state.verticalSpeed = pitchRate

        // Auto-level
        if shouldAutoLevel {
            state.verticalSpeed *= 0.95 // Gradually reduce
        }

        // Energy model (Normal / Expert): diving trades altitude for
        // speed, climbing bleeds it, and drag pulls the speed back toward
        // cruise. Easy keeps the flat constant-speed model so a first
        // flight never has to think about airspeed.
        if profile.energyModelEnabled {
            let base = Constants.Flight.defaultSpeed
            let energyGain = -state.verticalSpeed * Constants.Flight.energyExchangeRate
            let drag = (energySpeed - base) * Constants.Flight.energyDrag
            energySpeed += (energyGain - drag) * deltaTime
            energySpeed = energySpeed.clamped(to: Constants.Flight.minEnergySpeed...Constants.Flight.maxEnergySpeed)
        } else {
            energySpeed = Constants.Flight.defaultSpeed
        }

        // Stall (Expert): below the stall speed the nose drops regardless
        // of input and turning authority collapses until speed recovers.
        let stalled = profile.stallEnabled && energySpeed < Constants.Flight.stallSpeed
        state.isStalled = stalled
        if stalled {
            state.verticalSpeed = min(state.verticalSpeed, -Constants.Flight.stallSinkRate)
        }

        state.speed = energySpeed * speedMultiplier

        // Heading (yaw) from roll input, scaled by the current vehicle's
        // turn multiplier so e.g. the carrot jet (1.10) feels noticeably
        // sharper than the cushion balloon (0.85).
        let turnAuthority: Float = stalled ? 0.35 : 1.0
        let turnRate = Float(profile.turnSpeed) * vehicleHandling.turn * Float(rollInput) * deltaTime * turnAuthority
        state.heading += turnRate
        if state.heading >= 360 { state.heading -= 360 }
        if state.heading < 0 { state.heading += 360 }

        // Update altitude
        state.altitude += state.verticalSpeed * deltaTime

        // Min altitude protection
        let minAlt = Float(profile.minAltitude)
        if state.altitude < minAlt {
            state.altitude = minAlt
            state.verticalSpeed = max(state.verticalSpeed, 0)
        }

        // Max altitude
        if state.altitude > Constants.Flight.maxAltitude {
            state.altitude = Constants.Flight.maxAltitude
            state.verticalSpeed = min(state.verticalSpeed, 0)
        }

        // Update position based on heading and speed
        let headingRad = state.heading.rad
        let speedMS = state.speed / 3.6 * deltaTime // km/h to m/s
        let dx = sin(headingRad) * speedMS
        let dz = -cos(headingRad) * speedMS

        state.position.x += dx
        state.position.y = state.altitude
        state.position.z += dz

        // Authoritative euler for the character node.
        // CharacterAnimator may layer additional per-vehicle motion on top
        // of these axes (additive on .x for bellyGlider, override on .z
        // for cloudSurf, etc.) but no longer recomputes the base bank/pitch.
        // Bank carries the per-vehicle bias so a carrot-jet hard turn reads
        // as committed and a cushion-balloon turn stays politely level.
        let bankAngle = -Float(rollInput) * Constants.Camera.bankingAngle * 2 * vehicleHandling.bank
        let pitchAngle = Float(pitchInput) * 0.2
        state.rotation = SCNVector3(pitchAngle, -headingRad, bankAngle)
    }

    /// Stall check
    var isStalling: Bool {
        guard profile.stallEnabled else { return false }
        return state.isStalled
    }
}
