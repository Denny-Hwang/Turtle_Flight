import XCTest
import SceneKit
@testable import TurtleFlight

/// Pins the bridge between `MissionEngine.state` (which flips internally
/// when all rings are passed or the timer elapses) and the `FlightViewModel`
/// callback that the `FlightView` uses to call into `MissionViewModel`.
///
/// Without this bridge, Step Goal mode silently never ends from the
/// player's POV: the StageResultView never appears, star scores never
/// persist, and Stage 2+ never unlocks. Sprint 0 wired the bridge; these
/// tests make sure it doesn't regress.
final class MissionTerminalBridgeTests: XCTestCase {

    // MARK: - Pure edge-detection helper

    func testDoesNotEmitWhileStateUnchanged() {
        XCTAssertFalse(FlightViewModel.shouldEmitMissionTerminalEvent(
            currentKey: "inProgress", lastKey: "inProgress"))
        XCTAssertFalse(FlightViewModel.shouldEmitMissionTerminalEvent(
            currentKey: "notStarted", lastKey: "notStarted"))
        XCTAssertFalse(FlightViewModel.shouldEmitMissionTerminalEvent(
            currentKey: "completed", lastKey: "completed"))
    }

    func testEmitsOnTransitionToCompleted() {
        XCTAssertTrue(FlightViewModel.shouldEmitMissionTerminalEvent(
            currentKey: "completed", lastKey: "inProgress"))
    }

    func testEmitsOnTransitionToFailed() {
        XCTAssertTrue(FlightViewModel.shouldEmitMissionTerminalEvent(
            currentKey: "failed", lastKey: "inProgress"))
    }

    func testDoesNotEmitOnTransitionToInProgress() {
        // notStarted → inProgress is just "stage started" — no terminal
        // event to bridge.
        XCTAssertFalse(FlightViewModel.shouldEmitMissionTerminalEvent(
            currentKey: "inProgress", lastKey: "notStarted"))
    }

    func testDoesNotEmitOnTransitionToNotStarted() {
        // After the user taps Retry from a result screen the engine is
        // reset back to notStarted. That should NOT re-fire a callback.
        XCTAssertFalse(FlightViewModel.shouldEmitMissionTerminalEvent(
            currentKey: "notStarted", lastKey: "completed"))
        XCTAssertFalse(FlightViewModel.shouldEmitMissionTerminalEvent(
            currentKey: "notStarted", lastKey: "failed"))
    }

    // MARK: - missionStateKey

    func testMissionStateKeyForNil() {
        XCTAssertEqual(FlightViewModel.missionStateKey(nil), "notStarted")
    }

    func testMissionStateKeyForEachCase() {
        XCTAssertEqual(FlightViewModel.missionStateKey(.notStarted), "notStarted")
        XCTAssertEqual(FlightViewModel.missionStateKey(.inProgress), "inProgress")

        let result = StageResult(
            stageIndex: 0, stars: 3, completionTime: 30,
            collisions: 0, starsCollected: 0, ringsCompleted: 10,
            totalRings: 10, date: Date()
        )
        XCTAssertEqual(FlightViewModel.missionStateKey(.completed(result)), "completed")
        XCTAssertEqual(FlightViewModel.missionStateKey(.failed(reason: "timeout")), "failed")
    }

    // MARK: - Integration: callback fires when the engine completes

    func testCallbackFiresExactlyOnceOnEngineCompletion() {
        let vm = FlightViewModel()
        let scene = SCNScene()

        let charNode = SCNNode()
        charNode.position = SCNVector3(0, 500, 0)
        vm.characterNode = charNode

        // Terrain generator stays nil → checkGroundCollision short-circuits
        // (it requires terrain) which is fine for this test — we only care
        // about the mission-terminal observer.

        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]    // 10 rings, no time limit
        engine.startStage(stage)
        vm.missionEngine = engine

        var observed: [MissionEngine.MissionState] = []
        vm.onMissionTerminalState = { observed.append($0) }

        vm.isFlying = true

        // First update: engine is .inProgress — no terminal event.
        vm.update(deltaTime: 0.016)
        XCTAssertEqual(observed.count, 0)

        // Drive the engine through every ring so it flips to .completed.
        for ring in engine.rings {
            engine.update(deltaTime: 0.016, playerPosition: ring.position)
        }
        if case .completed = engine.state {
            // expected
        } else {
            XCTFail("Engine should be completed after passing all rings")
        }

        // The very next vm.update should fire the bridge callback exactly once.
        vm.update(deltaTime: 0.016)
        XCTAssertEqual(observed.count, 1, "Callback should fire on terminal transition")
        if case .completed = observed.first! {
            // expected
        } else {
            XCTFail("Expected .completed event")
        }

        // Subsequent updates in the same terminal state must NOT re-fire.
        vm.update(deltaTime: 0.016)
        vm.update(deltaTime: 0.016)
        XCTAssertEqual(observed.count, 1,
                       "Callback should be edge-triggered, not level-triggered")
    }

    func testCallbackFiresOnEngineFailure() {
        let vm = FlightViewModel()
        let scene = SCNScene()
        vm.characterNode = SCNNode()

        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[1]    // 180s time limit
        engine.startStage(stage)
        vm.missionEngine = engine

        var observed: [MissionEngine.MissionState] = []
        vm.onMissionTerminalState = { observed.append($0) }

        vm.isFlying = true

        // Push the engine past its time limit so it fails.
        engine.update(deltaTime: Float(stage.timeLimit!) + 1.0,
                      playerPosition: SCNVector3(999, 999, 999))
        if case .failed = engine.state {
            // expected
        } else {
            XCTFail("Engine should fail past time limit")
        }

        vm.update(deltaTime: 0.016)
        XCTAssertEqual(observed.count, 1)
        if case .failed = observed.first! {
            // expected
        } else {
            XCTFail("Expected .failed event")
        }
    }

    // MARK: - End-to-end: the bridge actually persists scores

    /// Mirrors the wiring from `FlightView.setupScene`:
    ///   flightVM.onMissionTerminalState = { missionVM.completeMission(...) }
    /// Verifies that a terminal completion ends up in the player's
    /// `progress.stageResults`.
    func testEndToEndMissionCompletionPersistsToProgress() {
        let flightVM = FlightViewModel()
        let missionVM = MissionViewModel()
        // Use a clean defaults bucket for the test so we don't pollute the
        // real key. MissionViewModel.save() writes to UserDefaults.standard
        // — out of scope for this test, but harmless.
        missionVM.progress = .defaultProgress

        let scene = SCNScene()
        flightVM.characterNode = SCNNode()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)
        flightVM.missionEngine = engine
        flightVM.isFlying = true

        // Wire the bridge — this is the same line that lives in
        // FlightView.setupScene.
        flightVM.onMissionTerminalState = { state in
            switch state {
            case .completed(let result):
                missionVM.completeMission(result: result)
            case .failed(let reason):
                missionVM.failMission(reason: reason)
            case .notStarted, .inProgress:
                break
            }
        }

        // Pre-condition: no result for stage 0 yet.
        XCTAssertNil(missionVM.progress.stageResults[0])

        // Pass all rings → engine completes → bridge fires.
        for ring in engine.rings {
            engine.update(deltaTime: 0.016, playerPosition: ring.position)
        }
        flightVM.update(deltaTime: 0.016)

        // Post-condition: result was persisted, missionState is .completed,
        // priorBest is nil (it was the first clear).
        XCTAssertNotNil(missionVM.progress.stageResults[0])
        XCTAssertNil(missionVM.priorBestForLastResult)
        if case .completed = missionVM.missionState {
            // expected
        } else {
            XCTFail("missionVM.missionState should be .completed after bridge")
        }
        XCTAssertEqual(missionVM.progress.maxUnlockedStage, 1,
                       "Stage 2 should unlock after Stage 1 clear")
    }
}
