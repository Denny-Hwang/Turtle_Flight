import XCTest
@testable import TurtleFlight

final class ExpressionLatchTests: XCTestCase {

    // MARK: - Default behaviour

    func testStartsAtDefault() {
        var latch = ExpressionLatch()
        let result = latch.update(missionStateKey: "notStarted", isBoosting: false, now: 0)
        XCTAssertEqual(result, .default)
        XCTAssertEqual(latch.current, .default)
    }

    func testBoostingFlipsToSpeed() {
        var latch = ExpressionLatch()
        XCTAssertEqual(
            latch.update(missionStateKey: "inProgress", isBoosting: true, now: 0),
            .speed
        )
        XCTAssertEqual(
            latch.update(missionStateKey: "inProgress", isBoosting: false, now: 0.1),
            .default
        )
    }

    // MARK: - Stage-clear: joy latch

    func testStageClearLatchesJoyForExpectedWindow() {
        var latch = ExpressionLatch(joyLatchDuration: 2.0, scaredLatchDuration: 1.5)
        // Bring up the in-progress state first.
        _ = latch.update(missionStateKey: "inProgress", isBoosting: false, now: 0)
        // Stage clears.
        XCTAssertEqual(
            latch.update(missionStateKey: "completed", isBoosting: false, now: 10.0),
            .joy,
            "joy should latch on the rising edge of `completed`"
        )
        // Still inside the latch window.
        XCTAssertEqual(
            latch.update(missionStateKey: "completed", isBoosting: false, now: 11.5),
            .joy,
            "joy should hold for the full latch window"
        )
        // Even when boosting, joy outranks speed.
        XCTAssertEqual(
            latch.update(missionStateKey: "completed", isBoosting: true, now: 11.5),
            .joy,
            "latched joy should outrank boosting"
        )
        // Past the window: joy releases, falls through to boost-vs-idle.
        XCTAssertEqual(
            latch.update(missionStateKey: "completed", isBoosting: false, now: 12.5),
            .default,
            "joy releases after the latch window expires"
        )
    }

    func testStageFailLatchesScared() {
        var latch = ExpressionLatch(joyLatchDuration: 2.0, scaredLatchDuration: 1.5)
        _ = latch.update(missionStateKey: "inProgress", isBoosting: false, now: 0)
        XCTAssertEqual(
            latch.update(missionStateKey: "failed", isBoosting: false, now: 5.0),
            .scared
        )
        XCTAssertEqual(
            latch.update(missionStateKey: "failed", isBoosting: false, now: 6.0),
            .scared,
            "scared should hold for 1.5s"
        )
        XCTAssertEqual(
            latch.update(missionStateKey: "failed", isBoosting: false, now: 6.6),
            .default,
            "scared releases after the latch window expires"
        )
    }

    // MARK: - Edge detection

    func testCompletedEventOnlyArmsLatchOnTransition() {
        var latch = ExpressionLatch()
        // Pre-arm: state was already `completed` when the flight started
        // (e.g. retry after clearing).
        _ = latch.update(missionStateKey: "completed", isBoosting: false, now: 0)
        // Stuck-in-completed should NOT keep re-extending the latch.
        XCTAssertEqual(
            latch.update(missionStateKey: "completed", isBoosting: false, now: 5.0),
            .default,
            "we should be past the initial latch by now if it didn't re-arm"
        )
    }

    func testInProgressFollowedByCompleteThenInProgressArmsTwice() {
        var latch = ExpressionLatch(joyLatchDuration: 2.0)
        _ = latch.update(missionStateKey: "inProgress", isBoosting: false, now: 0)
        XCTAssertEqual(
            latch.update(missionStateKey: "completed", isBoosting: false, now: 1.0),
            .joy
        )
        // Joy expires.
        _ = latch.update(missionStateKey: "completed", isBoosting: false, now: 4.0)
        // New flight: inProgress → completed should arm joy again.
        _ = latch.update(missionStateKey: "inProgress", isBoosting: false, now: 4.5)
        XCTAssertEqual(
            latch.update(missionStateKey: "completed", isBoosting: false, now: 5.0),
            .joy,
            "second stage clear should arm joy again"
        )
    }

    // MARK: - Reset

    func testResetReturnsAllStateToInitial() {
        var latch = ExpressionLatch(joyLatchDuration: 100)
        _ = latch.update(missionStateKey: "inProgress", isBoosting: false, now: 0)
        _ = latch.update(missionStateKey: "completed", isBoosting: false, now: 1)
        XCTAssertEqual(latch.current, .joy)

        latch.reset()
        XCTAssertEqual(latch.current, .default)
        // After reset, a `completed` key seen with no preceding inProgress
        // is a fresh edge so latch should arm again.
        XCTAssertEqual(
            latch.update(missionStateKey: "completed", isBoosting: false, now: 2),
            .joy
        )
    }

    // MARK: - FlightViewModel ↔ MissionEngine bridge

    func testMissionStateKeyMapsAllCases() {
        XCTAssertEqual(FlightViewModel.missionStateKey(nil), "notStarted")
        XCTAssertEqual(FlightViewModel.missionStateKey(.notStarted), "notStarted")
        XCTAssertEqual(FlightViewModel.missionStateKey(.inProgress), "inProgress")
        let dummyResult = StageResult(stageIndex: 0, stars: 3,
                                      completionTime: 10, collisions: 0,
                                      starsCollected: 5, ringsCompleted: 10,
                                      totalRings: 10, date: Date())
        XCTAssertEqual(FlightViewModel.missionStateKey(.completed(dummyResult)), "completed")
        XCTAssertEqual(FlightViewModel.missionStateKey(.failed(reason: "x")), "failed")
    }
}
