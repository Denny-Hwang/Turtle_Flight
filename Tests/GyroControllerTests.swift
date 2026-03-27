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
        controller.updateSensitivity(.normal)
        XCTAssertEqual(controller.rollInput, 0)  // Still zero without motion data

        controller.updateSensitivity(.expert)
        XCTAssertEqual(controller.pitchInput, 0)  // Still zero

        controller.updateSensitivity(.easy)
        XCTAssertEqual(controller.rollInput, 0)  // Cycled back
    }

    func testAutoLevelInitiallyFalse() {
        // Just created controller — shouldAutoLevel should be false
        // because timeSinceLastInput starts at 0, which is < autoLevelDelay (2.0s)
        let controller = GyroController(sensitivity: .easy)
        XCTAssertFalse(controller.shouldAutoLevel,
                       "Auto-level should not trigger immediately on init")
    }

    func testAutoLevelDisabledForExpert() {
        // Expert has no autoLevelDelay (nil) — shouldAutoLevel should always be false
        let controller = GyroController(sensitivity: .expert)
        XCTAssertFalse(controller.shouldAutoLevel,
                       "Expert mode never auto-levels")
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
