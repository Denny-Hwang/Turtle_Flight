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
        // Expert mode has stall
        // Speed starts at 200, which is above stall threshold
        XCTAssertFalse(engine.isStalling)
    }
}
