import XCTest
import SceneKit
@testable import TurtleFlight

/// Phase 1 foundation fixes: lifetime stats that were never written,
/// and the coalesced HUD publishing path on `FlightViewModel`.
final class Phase1FoundationTests: XCTestCase {

    // MARK: - Free Flight / flight-time stats (previously never persisted)

    func testRecordFreeFlightUpdatesBestStarsAndFlightTime() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress

        let first = vm.recordFreeFlight(flightTime: 90, starsCollected: 12)
        XCTAssertTrue(first, "First run is always a new best")
        XCTAssertEqual(vm.progress.bestFreeFlightStars, 12)
        XCTAssertEqual(vm.progress.totalFlightTime, 90, accuracy: 0.001)

        let worse = vm.recordFreeFlight(flightTime: 30, starsCollected: 5)
        XCTAssertFalse(worse)
        XCTAssertEqual(vm.progress.bestFreeFlightStars, 12, "Worse run must not lower the best")
        XCTAssertEqual(vm.progress.totalFlightTime, 120, accuracy: 0.001,
                       "Flight time accumulates across every run")

        let equal = vm.recordFreeFlight(flightTime: 10, starsCollected: 12)
        XCTAssertFalse(equal, "Equalling the best is not a new best")
    }

    func testRecordFreeFlightIgnoresNegativeTime() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        vm.recordFreeFlight(flightTime: -5, starsCollected: 0)
        XCTAssertEqual(vm.progress.totalFlightTime, 0, accuracy: 0.001)
    }

    func testCompleteMissionAddsCompletionTimeToLifetimeTotal() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        let result = StageResult(stageIndex: 0, stars: 2, completionTime: 47,
                                 collisions: 1, starsCollected: 0,
                                 ringsCompleted: 10, totalRings: 10, date: Date())
        vm.completeMission(result: result)
        XCTAssertEqual(vm.progress.totalFlightTime, 47, accuracy: 0.001)
    }

    func testFailMissionAddsElapsedToLifetimeTotal() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        vm.failMission(reason: "timeout", elapsed: 180)
        XCTAssertEqual(vm.progress.totalFlightTime, 180, accuracy: 0.001)
        if case .failed = vm.missionState {
            // expected
        } else {
            XCTFail("missionState should be .failed")
        }
    }

    // MARK: - HUD frame coalescing

    func testHUDFrameDisplaysSameIgnoresSubDigitChanges() {
        let a = FlightViewModel.HUDFrame(
            speed: 200.0, altitude: 500.2, heading: 10.4, flightTime: 3.1,
            isBoosting: false, starsCollected: 2, boostProgress: 0.501,
            directionToObjective: 0.10, currentRegion: "A")
        var b = a
        b.altitude = 500.9
        b.heading = 10.9
        b.flightTime = 3.9
        b.boostProgress = 0.505
        b.directionToObjective = 0.105
        XCTAssertTrue(a.displaysSame(as: b))

        b.altitude = 501.0
        XCTAssertFalse(a.displaysSame(as: b))
    }

    func testHUDFrameDetectsVisibleChanges() {
        let a = FlightViewModel.HUDFrame(
            speed: 200, altitude: 500, heading: 0, flightTime: 0,
            isBoosting: false, starsCollected: 0, boostProgress: 0,
            directionToObjective: nil, currentRegion: "A")
        var b = a
        b.starsCollected = 1
        XCTAssertFalse(a.displaysSame(as: b))
        b = a
        b.isBoosting = true
        XCTAssertFalse(a.displaysSame(as: b))
        b = a
        b.currentRegion = "B"
        XCTAssertFalse(a.displaysSame(as: b))
        b = a
        b.directionToObjective = 1.0
        XCTAssertFalse(a.displaysSame(as: b))
    }

    func testUpdateOnMainPublishesSynchronously() {
        let vm = FlightViewModel()
        vm.characterNode = SCNNode()
        vm.isFlying = true
        vm.update(deltaTime: 1.0)
        XCTAssertEqual(vm.flightTime, 1.0, accuracy: 0.001,
                       "On the main thread the frame is applied immediately")
        XCTAssertEqual(vm.speed, Constants.Flight.defaultSpeed, accuracy: 0.001)
        XCTAssertEqual(vm.publishedFrameCount, 1)
    }

    func testSteadyCruiseDoesNotRepublishEveryFrame() {
        let vm = FlightViewModel()
        vm.characterNode = SCNNode()
        vm.isFlying = true
        // 30 frames of level flight inside the same display second.
        for _ in 0..<30 {
            vm.update(deltaTime: 0.01)
        }
        XCTAssertLessThanOrEqual(vm.publishedFrameCount, 2,
            "Constant speed / altitude / heading within one second should coalesce to a single publish")
    }

    func testTickEstablishesBaselineThenAdvances() {
        let vm = FlightViewModel()
        vm.characterNode = SCNNode()
        vm.isFlying = true
        vm.tick(at: 10.0)
        XCTAssertEqual(vm.flightEngine.state.flightTime, 0, accuracy: 0.001,
                       "First tick only sets the baseline")
        vm.tick(at: 10.5)
        XCTAssertEqual(vm.flightEngine.state.flightTime, 0.05, accuracy: 0.001,
                       "Delta is clamped to 50ms so a debugger pause can't teleport the player")
        vm.tick(at: 10.52)
        XCTAssertEqual(vm.flightEngine.state.flightTime, 0.07, accuracy: 0.001)
    }

    func testPauseResetsTickBaseline() {
        let vm = FlightViewModel()
        vm.characterNode = SCNNode()
        vm.isFlying = true
        vm.tick(at: 1.0)
        vm.tick(at: 1.02)
        vm.pauseFlight()
        vm.resumeFlight()
        vm.tick(at: 30.0)     // long gap while paused
        XCTAssertEqual(vm.flightEngine.state.flightTime, 0.02, accuracy: 0.001,
                       "The first tick after resume must not apply the paused interval")
    }

    func testBoostRequestIsConsumedOnce() {
        let vm = FlightViewModel()
        vm.characterNode = SCNNode()
        vm.isFlying = true
        vm.activateBoost()
        vm.update(deltaTime: 0.016)
        XCTAssertTrue(vm.isBoosting)
        // Run out the boost.
        vm.update(deltaTime: Float(Constants.Flight.boostDuration) + 0.1)
        XCTAssertFalse(vm.isBoosting, "Boost must end and NOT re-trigger from the mirror")
        vm.update(deltaTime: 0.016)
        XCTAssertFalse(vm.isBoosting)
    }

    func testLevelFlightPastRingBelowIsObservedAsMiss() {
        // Sky Walk ring 0 sits at (0, 400, -150) r=50. The player spawns
        // at (0, 500, 0) heading north; flying level crosses the ring's
        // plane 100m above its centre → a near miss (accuracy 2.0), not
        // a pass. The old sphere check would have ignored it entirely.
        let vm = FlightViewModel()
        let scene = SCNScene()
        vm.characterNode = SCNNode()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(StageDefinition.allStages[0])
        vm.missionEngine = engine
        vm.isFlying = true

        for _ in 0..<250 {          // 4s at 60fps ≈ 220m of travel
            vm.update(deltaTime: 0.016)
        }
        XCTAssertEqual(engine.currentRingIndex, 0)
        XCTAssertEqual(engine.crossingCount, 1)
        XCTAssertEqual(engine.ringMisses, 1)
        XCTAssertEqual(engine.lastCrossing!.accuracy, 2.0, accuracy: 0.05)
    }
}
