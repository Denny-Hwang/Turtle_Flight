import XCTest
@testable import TurtleFlight

final class GyroControllerTests: XCTestCase {

    func testInitialState() {
        let controller = GyroController(sensitivity: .easy)
        XCTAssertEqual(controller.rollInput, 0)
        XCTAssertEqual(controller.pitchInput, 0)
    }

    func testSensitivityUpdate() {
        let controller = GyroController(sensitivity: .easy)
        controller.updateSensitivity(.expert)
        // No crash = pass
        XCTAssertEqual(controller.rollInput, 0) // Still zero without motion data
    }

    func testAutoLevelCondition() {
        let controller = GyroController(sensitivity: .easy)
        // Initially no input, time since last input should grow
        // With easy mode, auto-level delay is 2 seconds
        XCTAssertFalse(controller.shouldAutoLevel) // Just started
    }

    func testStallDetection() {
        let controller = GyroController(sensitivity: .expert)
        XCTAssertTrue(controller.isStalling(speed: 50))   // Below 100
        XCTAssertFalse(controller.isStalling(speed: 150))  // Above 100
    }

    func testNoStallOnEasy() {
        let controller = GyroController(sensitivity: .easy)
        XCTAssertFalse(controller.isStalling(speed: 50))  // Easy has no stall
    }
}
