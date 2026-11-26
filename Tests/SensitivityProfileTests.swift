import XCTest
@testable import TurtleFlight

final class SensitivityProfileTests: XCTestCase {

    private let all: [SensitivityProfile] = [.easy, .normal, .expert]

    func testEasyProfile() {
        let profile = SensitivityProfile.easy
        XCTAssertEqual(profile.level, .easy)
        XCTAssertEqual(profile.turnSpeed, 45)
        XCTAssertEqual(profile.pitchSpeed, 40)
        XCTAssertNotNil(profile.autoLevelDelay)
        XCTAssertFalse(profile.stallEnabled)
    }

    func testNormalProfile() {
        let profile = SensitivityProfile.normal
        XCTAssertEqual(profile.level, .normal)
        XCTAssertEqual(profile.turnSpeed, 90)
        XCTAssertEqual(profile.pitchSpeed, 70)
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

    func testProfileFactory() {
        XCTAssertEqual(SensitivityProfile.profile(for: .easy).level, .easy)
        XCTAssertEqual(SensitivityProfile.profile(for: .normal).level, .normal)
        XCTAssertEqual(SensitivityProfile.profile(for: .expert).level, .expert)
    }

    // MARK: - Comfort (owner, 2026-11-26: "tilting too far hides the screen")

    func testFullClimbNeedsOnlyASmallTilt() {
        for p in all {
            XCTAssertLessThanOrEqual(p.pitch.fullTilt, 15.0.rad, "\(p.level)")
            XCTAssertEqual(p.pitch.input(for: p.pitch.fullTilt), 1, accuracy: 1e-9)
            XCTAssertEqual(p.pitch.input(for: -p.pitch.fullTilt), -1, accuracy: 1e-9)
        }
    }

    func testFullTurnNeedsAComfortableTilt() {
        for p in all {
            XCTAssertLessThanOrEqual(p.roll.fullTilt, 25.0.rad, "\(p.level)")
            XCTAssertEqual(p.roll.input(for: p.roll.fullTilt), 1, accuracy: 1e-9)
        }
    }

    func testClimbRespondsMoreThanSteeringForTheSameTilt() {
        // Climb is the axis where tilting moves the screen out of view.
        for p in all {
            XCTAssertLessThan(p.pitch.fullTilt, p.roll.fullTilt, "\(p.level)")
        }
    }

    func testEightDegreesAlreadyGivesARealClimb() {
        // The old Easy profile gave 0 here (8° dead zone).
        for p in all {
            XCTAssertGreaterThan(p.pitch.input(for: 8.0.rad), 0.4, "\(p.level)")
        }
    }

    // MARK: - Dead zone + curve

    func testDeadZoneIgnoresHandJitter() {
        for p in all {
            XCTAssertEqual(p.roll.input(for: 0.8.rad), 0)
            XCTAssertEqual(p.pitch.input(for: -0.8.rad), 0)
        }
        XCTAssertEqual(SensitivityProfile.easy.roll.input(for: 2.5.rad), 0)
    }

    func testJustOutsideDeadZoneIsSmallButNonZero() {
        let axis = SensitivityProfile.easy.roll
        let value = axis.input(for: axis.deadZone + 0.001)
        XCTAssertGreaterThan(value, 0)
        XCTAssertLessThan(value, 0.05)
    }

    func testExpertIsLinear() {
        let axis = SensitivityProfile.expert.roll
        let half = axis.deadZone + (axis.fullTilt - axis.deadZone) / 2
        XCTAssertEqual(axis.input(for: half), 0.5, accuracy: 1e-9)
    }

    func testEasyIsGentlestNearCentre() {
        func atHalf(_ a: AxisResponse) -> Double { a.input(for: a.deadZone + (a.fullTilt - a.deadZone) / 2) }
        XCTAssertLessThan(atHalf(SensitivityProfile.easy.roll), atHalf(SensitivityProfile.normal.roll))
        XCTAssertLessThan(atHalf(SensitivityProfile.normal.roll), atHalf(SensitivityProfile.expert.roll))
    }

    func testBeyondFullTiltClamps() {
        for p in all {
            XCTAssertEqual(p.roll.input(for: 60.0.rad), 1)
            XCTAssertEqual(p.pitch.input(for: -60.0.rad), -1)
        }
    }

    func testResponseIsSymmetric() {
        for p in all {
            XCTAssertEqual(p.roll.input(for: 11.0.rad), -p.roll.input(for: -11.0.rad), accuracy: 1e-12)
            XCTAssertEqual(p.pitch.input(for: 7.0.rad), -p.pitch.input(for: -7.0.rad), accuracy: 1e-12)
        }
    }

    // MARK: - Smoothing alpha (spec)

    func testSmoothingAlpha() {
        XCTAssertEqual(SensitivityProfile.easy.smoothingAlpha, 0.08, accuracy: 0.001)
        XCTAssertEqual(SensitivityProfile.normal.smoothingAlpha, 0.15, accuracy: 0.001)
        XCTAssertEqual(SensitivityProfile.expert.smoothingAlpha, 0.35, accuracy: 0.001)
    }
}
