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
        var flightTime: TimeInterval = 0
    }

    // MARK: - Properties
    private(set) var state = FlightState()
    private var profile: SensitivityProfile

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

        // Boost
        if isBoosting && state.boostTimeRemaining <= 0 {
            state.isBoosting = true
            state.boostTimeRemaining = Float(Constants.Flight.boostDuration)
        }
        if state.boostTimeRemaining > 0 {
            state.boostTimeRemaining -= deltaTime
            if state.boostTimeRemaining <= 0 {
                state.isBoosting = false
            }
        }

        let speedMultiplier: Float = state.isBoosting ? Constants.Flight.boostMultiplier : 1.0

        // Base speed
        let baseSpeed = Constants.Flight.defaultSpeed * speedMultiplier
        state.speed = baseSpeed

        // Heading (yaw) from roll input
        let turnRate = Float(profile.turnSpeed) * Float(rollInput) * deltaTime
        state.heading += turnRate
        if state.heading >= 360 { state.heading -= 360 }
        if state.heading < 0 { state.heading += 360 }

        // Vertical speed from pitch input
        let pitchRate = Float(profile.pitchSpeed) * Float(pitchInput)
        state.verticalSpeed = pitchRate

        // Auto-level
        if shouldAutoLevel {
            state.verticalSpeed *= 0.95 // Gradually reduce
        }

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

        // Update rotation (euler angles for SceneKit node)
        let bankAngle = -Float(rollInput) * Constants.Camera.bankingAngle * 2
        let pitchAngle = Float(pitchInput) * 0.2
        state.rotation = SCNVector3(pitchAngle, -headingRad, bankAngle)
    }

    /// Stall check
    var isStalling: Bool {
        guard profile.stallEnabled else { return false }
        return state.speed < 100
    }
}
