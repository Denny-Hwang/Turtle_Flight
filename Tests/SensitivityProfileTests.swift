import XCTest
@testable import TurtleFlight

final class SensitivityProfileTests: XCTestCase {

    func testEasyProfile() {
        let profile = SensitivityProfile.easy
        XCTAssertEqual(profile.level, .easy)
        XCTAssertEqual(profile.turnSpeed, 45)
        XCTAssertEqual(profile.pitchSpeed, 30)
        XCTAssertNotNil(profile.autoLevelDelay)
        XCTAssertFalse(profile.stallEnabled)
    }

    func testNormalProfile() {
        let profile = SensitivityProfile.normal
        XCTAssertEqual(profile.level, .normal)
        XCTAssertEqual(profile.turnSpeed, 90)
        XCTAssertEqual(profile.pitchSpeed, 60)
        XCTAssertNotNil(profile.autoLevelDelay)
        XCTAssertFalse(profile.stallEnabled)
    }

    func testExpertProfile() {
        let profile = SensitivityProfile.expert
        XCTAssertEqual(profile.level, .expert)
        XCTAssertEqual(profile.turnSpeed, 180)
        XCTAssertEqual(profile.pitchSpeed, 120)
        XCTAssertNil(profile.autoLevelDelay)
        XCTAssertTrue(profile.stallEnabled)
    }

    func testCubicCurve() {
        let profile = SensitivityProfile.easy
        let result = profile.applyCurve(profile.maxTilt * 0.5) // Half tilt
        // Cubic: 0.5^3 = 0.125 (approx, scaled)
        XCTAssertLessThan(abs(result), 0.5) // Cubic is gentler than linear
    }

    func testLinearCurve() {
        let profile = SensitivityProfile.expert
        let halfTilt = profile.maxTilt * 0.5
        let result = profile.applyCurve(halfTilt)
        // Linear: should be close to 0.5
        XCTAssertEqual(result, 0.5, accuracy: 0.01)
    }

    func testDeadZone() {
        let profile = SensitivityProfile.easy
        let smallInput = 5.0.rad // 5 degrees, within 8° dead zone
        XCTAssertTrue(profile.isInDeadZone(smallInput))

        let largeInput = 15.0.rad // 15 degrees, outside dead zone
        XCTAssertFalse(profile.isInDeadZone(largeInput))
    }

    func testProfileFactory() {
        let easy = SensitivityProfile.profile(for: .easy)
        XCTAssertEqual(easy.level, .easy)

        let normal = SensitivityProfile.profile(for: .normal)
        XCTAssertEqual(normal.level, .normal)

        let expert = SensitivityProfile.profile(for: .expert)
        XCTAssertEqual(expert.level, .expert)
    }
}
