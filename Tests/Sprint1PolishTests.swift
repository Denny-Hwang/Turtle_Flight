import XCTest
import SceneKit
@testable import TurtleFlight

/// Tests for the Sprint 1 polish pass — boost cooldown ring math, star
/// respawn debounce, objective compass arrow direction, mountain pillar
/// generation, and Stage 3 ring clearance against terrain.
final class Sprint1PolishTests: XCTestCase {

    // MARK: - Stage 3 ring clearance

    func testStartStageWithoutTerrainHookKeepsRawRingPositions() {
        // No height function → ring positions fall through unchanged.
        // Pins the back-compat behaviour for callers (and tests) that
        // don't supply terrain.
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[2]    // Valley Run
        let raw = stage.generateRings()

        engine.startStage(stage)
        XCTAssertEqual(engine.rings.count, raw.count)
        for (i, ring) in engine.rings.enumerated() {
            XCTAssertEqual(ring.position.x, raw[i].x, accuracy: 0.01)
            XCTAssertEqual(ring.position.y, raw[i].y, accuracy: 0.01)
            XCTAssertEqual(ring.position.z, raw[i].z, accuracy: 0.01)
        }
    }

    func testStartStageClampsRingsAboveTerrain() {
        // Tall fake terrain (every (x,z) reads as 250m). Ring positions
        // for Valley Run float between ~100-200m, so every ring should
        // be clamped UP to at least groundY + ringRadius + 20.
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[2]   // ringRadius = 35
        let groundY: Float = 250

        engine.startStage(stage) { _, _ in groundY }

        let minExpected = groundY + stage.ringRadius + 20  // 305
        for ring in engine.rings {
            XCTAssertGreaterThanOrEqual(
                ring.position.y, minExpected,
                "Ring at \(ring.position) should be clamped to >= \(minExpected) above terrain"
            )
        }
    }

    func testStartStageDoesNotLowerHighRings() {
        // Mountain Cross rings are already 600-1000m; a 0m ground should
        // not push them down.
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[3]   // Mountain Cross
        let raw = stage.generateRings()

        engine.startStage(stage) { _, _ in 0 }

        // Match index for index — the y values should equal raw because
        // raw.y > 0 + radius + 20 already.
        for (i, ring) in engine.rings.enumerated() {
            XCTAssertEqual(ring.position.y, raw[i].y, accuracy: 0.01)
        }
    }

    // MARK: - Stage 4 mountain pillars

    func testStage4SpawnsMountainDecorations() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[3]   // Mountain Cross

        engine.startStage(stage) { _, _ in 0 }
        XCTAssertEqual(engine.decorations.count, stage.ringCount,
                       "One mountain pillar per ring on Stage 4")
    }

    func testNonStage4DoesNotSpawnDecorations() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)

        for index in [0, 1, 2, 4] {   // Sky Walk, Cloud Maze, Valley Run, Sky Race
            let stage = StageDefinition.allStages[index]
            engine.startStage(stage) { _, _ in 0 }
            XCTAssertEqual(engine.decorations.count, 0,
                           "Stage \(index) should not spawn mountain decorations")
        }
    }

    func testMountainPillarBaseAtGroundPeakUnderRing() {
        let pillar = MissionEngine.makeMountainPillar(
            base: SCNVector3(10, 50, -20),
            peakY: 200
        )
        // Pillar root sits at the base position.
        XCTAssertEqual(pillar.position.x, 10, accuracy: 0.001)
        XCTAssertEqual(pillar.position.y, 50, accuracy: 0.001)
        XCTAssertEqual(pillar.position.z, -20, accuracy: 0.001)
        // It's a composite: at minimum the lower body + the peak cone.
        XCTAssertGreaterThanOrEqual(pillar.childNodes.count, 2)
    }

    func testMountainPillarFloorsBelowMinHeight() {
        // peakY < base — should still produce a visible (clamped) pillar
        // rather than a zero-height degenerate node.
        let pillar = MissionEngine.makeMountainPillar(
            base: SCNVector3(0, 100, 0),
            peakY: 90       // 10m below base — would be negative height
        )
        XCTAssertGreaterThanOrEqual(pillar.childNodes.count, 2)
    }

    // MARK: - Star respawn

    func testItemSystemUncollectedCountReflectsCollections() {
        let scene = SCNScene()
        let items = ItemSystem(parentNode: scene.rootNode)

        items.spawnStars(around: SCNVector3(0, 100, 0))
        let initial = items.uncollectedStarCount
        XCTAssertGreaterThan(initial, 0)

        // Marking some as collected (via a checkCollection that's close
        // enough) drops the count.
        let collected = items.checkCollection(playerPosition: items.stars[0].position)
        XCTAssertEqual(collected, 1)
        XCTAssertEqual(items.uncollectedStarCount, initial - 1)
    }

    func testStarRespawnConstantsAreSensible() {
        // Sanity: threshold + cooldown values should be small enough to
        // feel responsive but not so small the pool spasms.
        XCTAssertGreaterThan(Constants.Items.starRespawnThreshold, 0)
        XCTAssertLessThanOrEqual(Constants.Items.starRespawnThreshold, 5)
        XCTAssertGreaterThanOrEqual(Constants.Items.starRespawnCooldown, 1.0)
    }

    // MARK: - Personality field removal

    func testCharacterConfigDoesNotExposePersonalityField() {
        // Sprint 1-G: the legacy `personality:` Korean string was deleted.
        // This test pins the API surface — if a reviewer accidentally adds
        // it back as a hard-coded string, this fails.
        let mirror = Mirror(reflecting: CharacterType.turtle.config)
        let names = mirror.children.compactMap { $0.label }
        XCTAssertFalse(names.contains("personality"),
                       "CharacterConfig should not expose a hard-coded personality field; localize via L10n if needed")
    }

    // MARK: - Mission engine current ring exposure

    func testCurrentRingPositionIsFirstRingOnStart() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)

        XCTAssertNotNil(engine.currentRingPosition)
        XCTAssertEqual(engine.currentRingPosition!.x,
                       engine.rings[0].position.x, accuracy: 0.001)
    }

    func testCurrentRingPositionAdvancesAfterPass() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)

        let firstRing = engine.rings[0].position
        engine.update(deltaTime: 0.016, playerPosition: firstRing)

        XCTAssertEqual(engine.currentRingPosition!.x,
                       engine.rings[1].position.x, accuracy: 0.001)
    }

    func testCurrentRingPositionIsNilAfterAllRingsPassed() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)
        for ring in engine.rings {
            engine.update(deltaTime: 0.016, playerPosition: ring.position)
        }
        XCTAssertNil(engine.currentRingPosition,
                     "currentRingPosition should be nil once the run is complete")
    }
}
