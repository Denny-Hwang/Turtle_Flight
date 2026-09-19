import XCTest
import SceneKit
@testable import TurtleFlight

/// Phase 2: energy model (dive = speed, climb = bleed, stall) and the
/// star-charged boost gauge.
final class EnergyModelTests: XCTestCase {

    private func run(_ engine: FlightEngine, seconds: Float, pitch: Double, boost: Bool = false) {
        let frames = Int(seconds / 0.016)
        for _ in 0..<frames {
            engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: pitch,
                          isBoosting: boost, shouldAutoLevel: false)
        }
    }

    func testEasyKeepsConstantSpeedRegardlessOfPitch() {
        let engine = FlightEngine(sensitivity: .easy)
        run(engine, seconds: 2, pitch: -1)
        XCTAssertEqual(engine.state.speed, Constants.Flight.defaultSpeed, accuracy: 0.01)
        run(engine, seconds: 2, pitch: 1)
        XCTAssertEqual(engine.state.speed, Constants.Flight.defaultSpeed, accuracy: 0.01)
        XCTAssertFalse(engine.isStalling)
    }

    func testNormalDiveGainsSpeedAndClimbLosesIt() {
        let engine = FlightEngine(sensitivity: .normal)
        run(engine, seconds: 2, pitch: -1)
        XCTAssertGreaterThan(engine.state.speed, Constants.Flight.defaultSpeed + 20,
                             "A 2s dive should add real speed")
        XCTAssertLessThanOrEqual(engine.state.speed, Constants.Flight.maxEnergySpeed)
        let afterDive = engine.state.speed
        run(engine, seconds: 3, pitch: 1)
        XCTAssertLessThan(engine.state.speed, afterDive)
        XCTAssertGreaterThanOrEqual(engine.state.speed, Constants.Flight.minEnergySpeed)
        XCTAssertFalse(engine.isStalling, "Normal never stalls")
    }

    func testDragReturnsToCruiseAfterLevellingOff() {
        let engine = FlightEngine(sensitivity: .normal)
        run(engine, seconds: 2, pitch: -1)
        run(engine, seconds: 8, pitch: 0)
        XCTAssertEqual(engine.state.speed, Constants.Flight.defaultSpeed, accuracy: 5)
    }

    func testExpertStallsOnSustainedClimbAndRecoversOnDive() {
        let engine = FlightEngine(sensitivity: .expert)
        XCTAssertFalse(engine.isStalling)
        run(engine, seconds: 4, pitch: 1)
        XCTAssertTrue(engine.isStalling, "Four seconds of full climb bleeds Expert below stall speed")
        XCTAssertLessThan(engine.state.verticalSpeed, 0, "Stall forces the nose down")
        let stalledAltitude = engine.state.altitude
        run(engine, seconds: 0.5, pitch: 1)
        XCTAssertLessThan(engine.state.altitude, stalledAltitude,
                          "Pulling up while stalled still loses altitude")
        run(engine, seconds: 3, pitch: -1)
        XCTAssertFalse(engine.isStalling, "A dive restores airspeed")
    }

    func testStallCutsTurnAuthority() {
        // Half a second of full roll while stalled vs. while flying.
        // (Drag lifts a stalled Expert back over the stall line in ~0.7s
        // of level flight, so keep the window short.)
        let stalled = FlightEngine(sensitivity: .expert)
        run(stalled, seconds: 4, pitch: 1)
        XCTAssertTrue(stalled.isStalling)
        let headingBefore = stalled.state.heading
        for _ in 0..<30 {
            stalled.update(deltaTime: 0.016, rollInput: 1, pitchInput: 0,
                           isBoosting: false, shouldAutoLevel: false)
        }
        let stalledTurn = abs(stalled.state.heading - headingBefore)

        let flying = FlightEngine(sensitivity: .expert)
        for _ in 0..<30 {
            flying.update(deltaTime: 0.016, rollInput: 1, pitchInput: 0,
                          isBoosting: false, shouldAutoLevel: false)
        }
        let normalTurn = abs(flying.state.heading)
        XCTAssertLessThan(stalledTurn, normalTurn * 0.5)
    }

    func testBoostStillDoublesEnergySpeedInstantly() {
        let engine = FlightEngine(sensitivity: .normal)
        run(engine, seconds: 1, pitch: -1)
        let cruise = engine.state.speed
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: -1, isBoosting: true, shouldAutoLevel: false)
        XCTAssertEqual(engine.state.speed, cruise * Constants.Flight.boostMultiplier, accuracy: 3)
    }

    // MARK: - Boost gauge

    func testBoostNeedsFullGaugeAndDrainsIt() {
        let engine = FlightEngine(sensitivity: .easy)
        XCTAssertTrue(engine.canBoost)
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: true, shouldAutoLevel: false)
        XCTAssertTrue(engine.state.isBoosting)
        XCTAssertEqual(engine.state.boostCharge, 0, accuracy: 0.001)
        XCTAssertFalse(engine.canBoost)
        // Let it expire, then try again immediately: gauge is empty.
        engine.update(deltaTime: Float(Constants.Flight.boostDuration) + 0.1, rollInput: 0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)
        XCTAssertFalse(engine.state.isBoosting)
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: true, shouldAutoLevel: false)
        XCTAssertFalse(engine.state.isBoosting, "No boost without a full gauge")
    }

    func testStarsRefillTheGauge() {
        let engine = FlightEngine(sensitivity: .easy)
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: true, shouldAutoLevel: false)
        engine.update(deltaTime: Float(Constants.Flight.boostDuration) + 0.1, rollInput: 0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)
        let before = engine.state.boostCharge
        for _ in 0..<5 { engine.registerStarCollected() }
        XCTAssertEqual(engine.state.boostCharge, 1, accuracy: 0.001)
        XCTAssertGreaterThan(engine.state.boostCharge, before)
        XCTAssertTrue(engine.canBoost)
    }

    func testGaugeTricklesBackOnItsOwn() {
        let engine = FlightEngine(sensitivity: .easy)
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: true, shouldAutoLevel: false)
        engine.update(deltaTime: Float(Constants.Flight.boostDuration) + 0.1, rollInput: 0, pitchInput: 0,
                      isBoosting: false, shouldAutoLevel: false)
        let start = engine.state.boostCharge
        run(engine, seconds: 10, pitch: 0)
        XCTAssertGreaterThan(engine.state.boostCharge, start + 0.2)
        run(engine, seconds: 40, pitch: 0)
        XCTAssertEqual(engine.state.boostCharge, 1, accuracy: 0.001)
    }

    func testViewModelBoostProgressShowsChargeWhenIdle() {
        let vm = FlightViewModel()
        vm.characterNode = SCNNode()
        vm.isFlying = true
        vm.update(deltaTime: 0.016)
        XCTAssertEqual(vm.boostProgress, 1, accuracy: 0.001, "Full gauge → full ring")
        vm.activateBoost()
        vm.update(deltaTime: 0.016)
        XCTAssertTrue(vm.isBoosting)
        XCTAssertGreaterThan(vm.boostProgress, 0.9, "Just fired → ring nearly full and draining")
        vm.update(deltaTime: Float(Constants.Flight.boostDuration) + 0.1)
        XCTAssertFalse(vm.isBoosting)
        XCTAssertLessThan(vm.boostProgress, 0.1, "Drained gauge → nearly empty ring")
    }
}
