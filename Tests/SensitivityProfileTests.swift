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

    // MARK: - Dead Zone Values Match Spec (from CLAUDE.md)

    func testEasyDeadZoneIs8Degrees() {
        let profile = SensitivityProfile.easy
        // Dead zone should be 8°
        let eightDeg = 8.0.rad
        XCTAssertEqual(profile.deadZone, eightDeg, accuracy: 0.0001)
    }

    func testNormalDeadZoneIs4Degrees() {
        let profile = SensitivityProfile.normal
        let fourDeg = 4.0.rad
        XCTAssertEqual(profile.deadZone, fourDeg, accuracy: 0.0001)
    }

    func testExpertDeadZoneIs1Point5Degrees() {
        let profile = SensitivityProfile.expert
        let onePointFiveDeg = 1.5.rad
        XCTAssertEqual(profile.deadZone, onePointFiveDeg, accuracy: 0.0001)
    }

    // MARK: - Smoothing Alpha Values Match Spec

    func testEasySmoothingAlpha() {
        XCTAssertEqual(SensitivityProfile.easy.smoothingAlpha, 0.08, accuracy: 0.001)
    }

    func testNormalSmoothingAlpha() {
        XCTAssertEqual(SensitivityProfile.normal.smoothingAlpha, 0.15, accuracy: 0.001)
    }

    func testExpertSmoothingAlpha() {
        XCTAssertEqual(SensitivityProfile.expert.smoothingAlpha, 0.35, accuracy: 0.001)
    }

    // MARK: - Response Curves Ordering

    func testCubicIsMoreGentleThanQuadratic() {
        let easy = SensitivityProfile.easy    // cubic
        let normal = SensitivityProfile.normal  // quadratic
        let halfEasyTilt = easy.maxTilt * 0.5
        let halfNormalTilt = normal.maxTilt * 0.5
        // Both at 50% tilt, cubic (0.5^3=0.125) < quadratic (0.5^2=0.25)
        let cubicResult = easy.applyCurve(halfEasyTilt)
        let quadResult = normal.applyCurve(halfNormalTilt)
        XCTAssertLessThan(abs(cubicResult), abs(quadResult),
                          "Cubic curve should produce smaller output than quadratic at same relative input")
    }

    func testLinearCurveMaxTiltGivesOne() {
        let profile = SensitivityProfile.expert
        let result = profile.applyCurve(profile.maxTilt)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func testCubicCurveMaxTiltGivesOne() {
        let profile = SensitivityProfile.easy
        let result = profile.applyCurve(profile.maxTilt)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func testApplyCurveSymmetry() {
        // Positive and negative inputs should give symmetric outputs
        let profile = SensitivityProfile.normal
        let positive = profile.applyCurve(profile.maxTilt * 0.7)
        let negative = profile.applyCurve(-profile.maxTilt * 0.7)
        XCTAssertEqual(positive, -negative, accuracy: 0.001,
                       "Response curve should be symmetric around zero")
    }

    // MARK: - Dead Zone Remapping

    func testDeadZoneRemappingContinuity() {
        // Just outside dead zone should give a small but non-zero output
        let profile = SensitivityProfile.easy
        let justOutside = profile.deadZone + 0.001
        let result = profile.applyDeadZone(justOutside)
        XCTAssertGreaterThan(abs(result), 0, "Just outside dead zone should give non-zero output")
        XCTAssertLessThan(abs(result), 0.1, "Just outside dead zone should give very small output")
    }

    func testDeadZoneRemappingMaxTilt() {
        // At maxTilt, applyDeadZone should return maxTilt (full output before curve)
        let profile = SensitivityProfile.expert
        let result = profile.applyDeadZone(profile.maxTilt)
        XCTAssertEqual(result, profile.maxTilt, accuracy: 0.001)
    }
}
