import XCTest
import SceneKit
@testable import TurtleFlight

/// Pins the ground-clearance collision logic. Collisions feed
/// `MissionEngine.registerCollision()` which in turn drives the 2★/3★
/// star tier and the on-HUD "Hits: N" counter. Without this check, the
/// counter is permanently zero and every Stage Goal clear trivially earns
/// 3 stars — Sprint 0 added the check; these tests pin its behaviour.
final class CollisionDetectionTests: XCTestCase {

    // MARK: - Pure decision

    func testRegistersWhenClearanceBelowThreshold() {
        XCTAssertTrue(FlightViewModel.shouldRegisterCollision(
            clearance: 5.0, now: 1.0, lastCollisionTime: 0.0))
    }

    func testDoesNotRegisterWhenClearanceAboveThreshold() {
        XCTAssertFalse(FlightViewModel.shouldRegisterCollision(
            clearance: 50.0, now: 1.0, lastCollisionTime: 0.0))
    }

    func testRegistersAtZeroClearance() {
        XCTAssertTrue(FlightViewModel.shouldRegisterCollision(
            clearance: 0.0, now: 1.0, lastCollisionTime: 0.0))
    }

    func testRegistersAtNegativeClearance() {
        // Character below terrain mesh — definitely a collision.
        XCTAssertTrue(FlightViewModel.shouldRegisterCollision(
            clearance: -10.0, now: 1.0, lastCollisionTime: 0.0))
    }

    func testDebounceBlocksRapidRepeats() {
        // 0.1s after the last hit, still within the cooldown — no new hit.
        XCTAssertFalse(FlightViewModel.shouldRegisterCollision(
            clearance: 5.0, now: 0.6, lastCollisionTime: 0.5))
    }

    func testDebounceAllowsAfterCooldown() {
        // 0.6s after — past the 0.5s cooldown — fires again.
        XCTAssertTrue(FlightViewModel.shouldRegisterCollision(
            clearance: 5.0, now: 1.1, lastCollisionTime: 0.5))
    }

    func testThresholdMatchesConstant() {
        // Sanity: shouldRegister flips exactly at the threshold so any
        // future tweak to Constants.Collision.groundClearance shows up
        // here as an obvious failure. (Strictly less-than per the impl.)
        let threshold = Constants.Collision.groundClearance
        XCTAssertFalse(FlightViewModel.shouldRegisterCollision(
            clearance: threshold, now: 1.0, lastCollisionTime: 0.0))
        XCTAssertTrue(FlightViewModel.shouldRegisterCollision(
            clearance: threshold - 0.01, now: 1.0, lastCollisionTime: 0.0))
    }

    // MARK: - Terrain height accessor

    func testTerrainHeightAtIsDeterministicForSameSeed() {
        let scene = SCNScene()
        let a = TerrainGenerator(parentNode: scene.rootNode, seed: 42, theme: .sky)
        let b = TerrainGenerator(parentNode: scene.rootNode, seed: 42, theme: .sky)

        XCTAssertEqual(a.heightAt(x: 100, z: 200),
                       b.heightAt(x: 100, z: 200),
                       accuracy: 0.001,
                       "Same seed should yield same height — determinism is required for replays.")
    }

    func testTerrainHeightAtIsContinuous() {
        let scene = SCNScene()
        let tg = TerrainGenerator(parentNode: scene.rootNode, seed: 42, theme: .sky)

        let h1 = tg.heightAt(x: 100, z: 200)
        let h2 = tg.heightAt(x: 100.5, z: 200)

        // Half a unit step shouldn't produce a discontinuity larger than the
        // terrain's vertical scale. Concrete bound: 50 units (terrain max is
        // 300; smoothed Perlin doesn't slam between cells).
        XCTAssertLessThan(abs(h1 - h2), 50,
                          "Adjacent samples should be nearly continuous — sharp cliffs would feel terrible.")
    }

    func testTerrainHeightAtRespectsMaxHeight() {
        let scene = SCNScene()
        let tg = TerrainGenerator(parentNode: scene.rootNode, seed: 42, theme: .sky)
        for x in stride(from: -500, through: 500, by: 100) {
            for z in stride(from: -500, through: 500, by: 100) {
                let h = tg.heightAt(x: Float(x), z: Float(z))
                XCTAssertLessThanOrEqual(h, Constants.Terrain.maxHeight,
                                          "Terrain height must respect maxHeight cap")
                XCTAssertGreaterThanOrEqual(h, 0,
                                             "Terrain height should be non-negative")
            }
        }
    }

    // MARK: - MissionEngine.registerCollision is idempotent per call

    /// Sanity test: each `registerCollision()` call increments the counter.
    /// This was the regression baseline before Sprint 0 — the method was
    /// defined but never called from gameplay code, so this is now wired
    /// end-to-end (call site lives in `FlightViewModel.checkGroundCollision`).
    func testRegisterCollisionIncrementsCounter() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(StageDefinition.allStages[0])

        XCTAssertEqual(engine.collisions, 0)
        engine.registerCollision()
        XCTAssertEqual(engine.collisions, 1)
        engine.registerCollision()
        engine.registerCollision()
        XCTAssertEqual(engine.collisions, 3)
    }

    /// Three collisions degrade the result to 1★ even on a perfect-time run.
    /// This was previously unreachable because `registerCollision` was never
    /// invoked from the gameplay loop.
    func testThreePlusCollisionsDropTo1Star() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)
        engine.registerCollision()
        engine.registerCollision()
        engine.registerCollision()

        // Pass all rings within the 3-star time window.
        for ring in engine.rings {
            engine.update(deltaTime: 0.016, playerPosition: ring.position)
        }
        if case .completed(let result) = engine.state {
            XCTAssertEqual(result.stars, 1,
                           "3+ collisions should cap stars at 1 even on a fast clear")
        } else {
            XCTFail("Expected .completed state")
        }
    }
}
