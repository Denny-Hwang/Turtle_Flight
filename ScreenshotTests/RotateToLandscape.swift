import XCTest

/// Used only by `scripts/screenshots/capture.sh`: `simctl` has no way to
/// rotate a simulator, and iPadOS letterboxes a landscape-only app on a
/// portrait iPad. XCUIDevice can rotate it, and the orientation sticks
/// after the test ends, so the capture script runs this once per device.
final class RotateToLandscape: XCTestCase {
    func testRotateDeviceToLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertEqual(XCUIDevice.shared.orientation, .landscapeLeft)
    }
}
