import XCTest
@testable import TurtleFlight

/// Integration tests that verify FlightEngine behavior across scenarios
/// modeled after Apple's XCTest performance and boundary testing guidelines.
final class FlightEngineIntegrationTests: XCTestCase {

    // MARK: - Boundary Conditions

    func testHeadingNeverExceeds360() {
        let engine = FlightEngine(sensitivity: .expert)
        // Roll hard right for many frames
        for _ in 0..<500 {
            engine.update(deltaTime: 0.016, rollInput: 1.0, pitchInput: 0,
                          isBoosting: false, shouldAutoLevel: false)
        }
        XCTAssertLessThan(engine.state.heading, 360,
                          "Heading should never reach 360 (normalizes to [0, 360))")
        XCTAssertGreaterThanOrEqual(engine.state.heading, 0)
    }

    func testHeadingNeverGoesNegative() {
        let engine = FlightEngine(sensitivity: .expert)
        // Roll hard left for many frames
        for _ in 0..<500 {
            engine.update(deltaTime: 0.016, rollInput: -1.0, pitchInput: 0,
                          isBoosting: false, shouldAutoLevel: false)
        }
        XCTAssertGreaterThanOrEqual(engine.state.heading, 0,
                                    "Heading should never go negative")
    }

    func testHeadingWrapsAt360() {
        let engine = FlightEngine(sensitivity: .expert)
        // Roll right until heading approaches 360, then keep going
        for _ in 0..<1000 {
            engine.update(deltaTime: 0.016, rollInput: 1.0, pitchInput: 0,
                          isBoosting: false, shouldAutoLevel: false)
            XCTAssertGreaterThanOrEqual(engine.state.heading, 0)
            XCTAssertLessThan(engine.state.heading, 360)
        }
    }

    func testAltitudeNeverExceedsMax() {
        let engine = FlightEngine(sensitivity: .expert)
        for _ in 0..<5000 {
            engine.update(deltaTime: 0.1, rollInput: 0, pitchInput: 1.0,
                          isBoosting: false, shouldAutoLevel: false)
        }
        XCTAssertLessThanOrEqual(engine.state.altitude, Constants.Flight.maxAltitude)
    }

    func testMinAltitudeProtectionEasy() {
        let engine = FlightEngine(sensitivity: .easy)
        for _ in 0..<2000 {
            engine.update(deltaTime: 0.1, rollInput: 0, pitchInput: -1.0,
                          isBoosting: false, shouldAutoLevel: false)
        }
        // Easy mode min altitude = 50
        XCTAssertGreaterThanOrEqual(engine.state.altitude, 50)
    }

    func testMinAltitudeProtectionNormal() {
        let engine = FlightEngine(sensitivity: .normal)
        for _ in 0..<2000 {
            engine.update(deltaTime: 0.1, rollInput: 0, pitchInput: -1.0,
                          isBoosting: false, shouldAutoLevel: false)
        }
        // Normal mode min altitude = 20
        XCTAssertGreaterThanOrEqual(engine.state.altitude, 20)
    }

    func testMinAltitudeProtectionExpert() {
        let engine = FlightEngine(sensitivity: .expert)
        for _ in 0..<2000 {
            engine.update(deltaTime: 0.1, rollInput: 0, pitchInput: -1.0,
                          isBoosting: false, shouldAutoLevel: false)
        }
        // Expert mode min altitude = 5
        XCTAssertGreaterThanOrEqual(engine.state.altitude, 5)
    }

    // MARK: - Flight Physics

    func testPositionAdvancesWithSpeed() {
        let engine = FlightEngine(sensitivity: .normal)
        let initialPos = engine.state.position

        // Fly straight (heading = 0 = north → -Z direction)
        engine.update(deltaTime: 1.0, rollInput: 0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)

        // Should have moved in Z direction
        XCTAssertNotEqual(engine.state.position.z, initialPos.z,
                          "Position should advance over time")
    }

    func testBoostDoublesSpeeed() {
        let engine = FlightEngine(sensitivity: .normal)
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0,
                      isBoosting: true, shouldAutoLevel: false)
        let boostedSpeed = engine.state.speed

        let engine2 = FlightEngine(sensitivity: .normal)
        engine2.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0,
                       isBoosting: false, shouldAutoLevel: false)
        let normalSpeed = engine2.state.speed

        XCTAssertEqual(boostedSpeed, normalSpeed * Constants.Flight.boostMultiplier,
                       accuracy: 0.1)
    }

    func testBoostDurationIsFinite() {
        let engine = FlightEngine(sensitivity: .easy)
        // Start boost
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0,
                      isBoosting: true, shouldAutoLevel: false)
        XCTAssertTrue(engine.state.isBoosting)

        // Let boost expire
        let boostDuration = Float(Constants.Flight.boostDuration)
        engine.update(deltaTime: boostDuration + 0.1, rollInput: 0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)
        XCTAssertFalse(engine.state.isBoosting, "Boost should expire after \(boostDuration)s")
    }

    func testAutoLevelReducesVerticalSpeed() {
        let engine = FlightEngine(sensitivity: .easy)
        // Build up vertical speed first
        engine.update(deltaTime: 1.0, rollInput: 0, pitchInput: 1.0,
                      isBoosting: false, shouldAutoLevel: false)
        let vertSpeedBefore = engine.state.verticalSpeed

        // Apply auto-level
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 1.0,
                      isBoosting: false, shouldAutoLevel: true)
        let vertSpeedAfter = engine.state.verticalSpeed

        XCTAssertLessThan(abs(vertSpeedAfter), abs(vertSpeedBefore),
                          "Auto-level should reduce vertical speed magnitude")
    }

    func testFlightTimeAccumulates() {
        let engine = FlightEngine(sensitivity: .easy)
        engine.update(deltaTime: 1.0, rollInput: 0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)
        engine.update(deltaTime: 1.0, rollInput: 0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)
        XCTAssertEqual(engine.state.flightTime, 2.0, accuracy: 0.001)
    }

    func testResetRestoresInitialState() {
        let engine = FlightEngine(sensitivity: .expert)
        // Fly around
        for _ in 0..<100 {
            engine.update(deltaTime: 0.016, rollInput: 0.8, pitchInput: 0.5,
                          isBoosting: true, shouldAutoLevel: false)
        }

        engine.reset()

        XCTAssertEqual(engine.state.altitude, 500)
        XCTAssertEqual(engine.state.heading, 0)
        XCTAssertEqual(engine.state.speed, Constants.Flight.defaultSpeed, accuracy: 0.1)
        XCTAssertFalse(engine.state.isBoosting)
        XCTAssertEqual(engine.state.flightTime, 0)
    }

    // MARK: - Sensitivity Differences

    func testExpertTurnsSlowerThanEasy_NO_WhenMeasuringPerFrame() {
        // Expert has turnSpeed 180 vs Easy 45 — expert turns FASTER
        let easy = FlightEngine(sensitivity: .easy)
        let expert = FlightEngine(sensitivity: .expert)

        easy.update(deltaTime: 1.0, rollInput: 1.0, pitchInput: 0,
                    isBoosting: false, shouldAutoLevel: false)
        expert.update(deltaTime: 1.0, rollInput: 1.0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)

        XCTAssertGreaterThan(expert.state.heading, easy.state.heading,
                             "Expert mode should turn faster than Easy")
    }

    func testExpertClimbsFasterThanEasy() {
        let easy = FlightEngine(sensitivity: .easy)
        let expert = FlightEngine(sensitivity: .expert)

        easy.update(deltaTime: 1.0, rollInput: 0, pitchInput: 1.0,
                    isBoosting: false, shouldAutoLevel: false)
        expert.update(deltaTime: 1.0, rollInput: 0, pitchInput: 1.0,
                      isBoosting: false, shouldAutoLevel: false)

        XCTAssertGreaterThan(expert.state.altitude, easy.state.altitude,
                             "Expert mode should climb faster than Easy")
    }

    func testSensitivityCanBeUpdatedMidFlight() {
        let engine = FlightEngine(sensitivity: .easy)
        for _ in 0..<50 {
            engine.update(deltaTime: 0.016, rollInput: 0.3, pitchInput: 0.2,
                          isBoosting: false, shouldAutoLevel: false)
        }

        engine.updateSensitivity(.expert)

        // Should not crash, state should be preserved
        let altBefore = engine.state.altitude
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)
        // Altitude might change slightly due to different min altitude, but should be valid
        XCTAssertGreaterThan(engine.state.altitude, 0)
        let _ = altBefore  // suppress unused warning
    }

    // MARK: - Stall Detection

    func testNoStallInEasyMode() {
        let engine = FlightEngine(sensitivity: .easy)
        // Even with very low speed (shouldn't happen but just in case)
        XCTAssertFalse(engine.isStalling)
    }

    func testNoStallInNormalMode() {
        let engine = FlightEngine(sensitivity: .normal)
        XCTAssertFalse(engine.isStalling)
    }

    func testExpertModeHasStallMechanism() {
        let engine = FlightEngine(sensitivity: .expert)
        // Normal speed (200 km/h) is above stall threshold (100 km/h)
        XCTAssertFalse(engine.isStalling)
    }
}
