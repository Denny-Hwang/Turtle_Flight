import XCTest
@testable import TurtleFlight

final class FlightEngineTests: XCTestCase {

    var engine: FlightEngine!

    override func setUp() {
        super.setUp()
        engine = FlightEngine(sensitivity: .easy)
    }

    func testInitialState() {
        XCTAssertEqual(engine.state.altitude, 500)
        XCTAssertEqual(engine.state.heading, 0)
        XCTAssertEqual(engine.state.speed, 200)
        XCTAssertFalse(engine.state.isBoosting)
    }

    func testHeadingChangesWithRollInput() {
        engine.update(deltaTime: 1.0, rollInput: 0.5, pitchInput: 0, isBoosting: false, shouldAutoLevel: false)
        XCTAssertGreaterThan(engine.state.heading, 0)
    }

    func testAltitudeChangesWithPitchInput() {
        let initialAlt = engine.state.altitude
        engine.update(deltaTime: 1.0, rollInput: 0, pitchInput: 0.5, isBoosting: false, shouldAutoLevel: false)
        XCTAssertGreaterThan(engine.state.altitude, initialAlt)
    }

    func testBoostIncreasesSpeed() {
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: true, shouldAutoLevel: false)
        XCTAssertTrue(engine.state.isBoosting)
        // Speed during boost should be boostMultiplier × defaultSpeed
        let expectedBoostedSpeed = Constants.Flight.defaultSpeed * Constants.Flight.boostMultiplier
        XCTAssertEqual(engine.state.speed, expectedBoostedSpeed, accuracy: 0.1)
    }

    func testMinAltitudeProtection() {
        // Push altitude down
        for _ in 0..<1000 {
            engine.update(deltaTime: 0.1, rollInput: 0, pitchInput: -1.0, isBoosting: false, shouldAutoLevel: false)
        }
        // Easy mode min altitude = 50
        XCTAssertGreaterThanOrEqual(engine.state.altitude, 50)
    }

    func testReset() {
        engine.update(deltaTime: 1.0, rollInput: 0.5, pitchInput: 0.5, isBoosting: true, shouldAutoLevel: false)
        engine.reset()
        XCTAssertEqual(engine.state.altitude, 500)
        XCTAssertEqual(engine.state.heading, 0)
    }

    func testSensitivityUpdate() {
        engine.updateSensitivity(.expert)
        // Expert mode has stall; but default speed (200 km/h) is above stall threshold (100 km/h)
        XCTAssertFalse(engine.isStalling)

        // Verify expert mode actually turns faster than easy
        let easyEngine = FlightEngine(sensitivity: .easy)
        easyEngine.update(deltaTime: 1.0, rollInput: 1.0, pitchInput: 0,
                          isBoosting: false, shouldAutoLevel: false)

        let expertEngine = FlightEngine(sensitivity: .expert)
        expertEngine.update(deltaTime: 1.0, rollInput: 1.0, pitchInput: 0,
                            isBoosting: false, shouldAutoLevel: false)
        XCTAssertGreaterThan(expertEngine.state.heading, easyEngine.state.heading,
                             "Expert mode should have faster turn rate than Easy")
    }

    func testNormalSpeedWithoutBoost() {
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)
        XCTAssertEqual(engine.state.speed, Constants.Flight.defaultSpeed, accuracy: 0.1)
    }

    func testHeadingStaysInRange() {
        // Full rotation test
        for _ in 0..<1000 {
            engine.update(deltaTime: 0.016, rollInput: 1.0, pitchInput: 0,
                          isBoosting: false, shouldAutoLevel: false)
            XCTAssertGreaterThanOrEqual(engine.state.heading, 0)
            XCTAssertLessThan(engine.state.heading, 360)
        }
    }
}
