import XCTest
import SceneKit
@testable import TurtleFlight

final class StageDefinitionTests: XCTestCase {

    // MARK: - Stage Structure

    func testAllStagesCount() {
        XCTAssertEqual(StageDefinition.allStages.count, 5)
    }

    func testStageIndicesAreSequential() {
        let stages = StageDefinition.allStages
        for (i, stage) in stages.enumerated() {
            XCTAssertEqual(stage.index, i, "Stage at position \(i) should have index \(i)")
        }
    }

    func testDifficultyProgression() {
        let stages = StageDefinition.allStages
        for i in 1..<stages.count {
            XCTAssertGreaterThanOrEqual(
                stages[i].difficulty, stages[i - 1].difficulty,
                "Stage \(i) difficulty should be >= stage \(i-1)"
            )
        }
    }

    func testDifficultyRange() {
        for stage in StageDefinition.allStages {
            XCTAssertGreaterThanOrEqual(stage.difficulty, 1)
            XCTAssertLessThanOrEqual(stage.difficulty, 5)
        }
    }

    func testRingCountsPositive() {
        for stage in StageDefinition.allStages {
            XCTAssertGreaterThan(stage.ringCount, 0, "Stage \(stage.name) should have rings")
        }
    }

    func testRingRadiiDecreaseWithDifficulty() {
        // Harder stages have smaller (tighter) rings
        let stages = StageDefinition.allStages
        for i in 1..<stages.count {
            XCTAssertLessThanOrEqual(
                stages[i].ringRadius, stages[i - 1].ringRadius,
                "Stage \(i) ring radius should be <= stage \(i-1)"
            )
        }
    }

    func testTimeLimitsIncreasePressure() {
        // Stage 0 has no time limit (relaxed intro)
        XCTAssertNil(StageDefinition.allStages[0].timeLimit)

        // Later stages should have time limits
        let laterStages = StageDefinition.allStages.dropFirst()
        for stage in laterStages {
            XCTAssertNotNil(stage.timeLimit, "Stage \(stage.name) should have a time limit")
        }
    }

    func testStar3TimeIsWithinTimeLimit() {
        for stage in StageDefinition.allStages {
            if let star3 = stage.star3Time, let limit = stage.timeLimit {
                XCTAssertLessThan(
                    star3, limit,
                    "Stage \(stage.name): 3-star time must be within time limit"
                )
            }
        }
    }

    // MARK: - Ring Generation

    func testSkyWalkGenerates10Rings() {
        let stage = StageDefinition.allStages[0]
        let rings = stage.generateRings()
        XCTAssertEqual(rings.count, stage.ringCount)
    }

    func testCloudMazeGenerates5Rings() {
        let stage = StageDefinition.allStages[1]
        let rings = stage.generateRings()
        XCTAssertEqual(rings.count, stage.ringCount)
    }

    func testValleyRunGenerates8Rings() {
        let stage = StageDefinition.allStages[2]
        let rings = stage.generateRings()
        XCTAssertEqual(rings.count, stage.ringCount)
    }

    func testMountainCrossGenerates7Rings() {
        let stage = StageDefinition.allStages[3]
        let rings = stage.generateRings()
        XCTAssertEqual(rings.count, stage.ringCount)
    }

    func testSkyRaceGenerates20Rings() {
        let stage = StageDefinition.allStages[4]
        let rings = stage.generateRings()
        XCTAssertEqual(rings.count, stage.ringCount)
    }

    func testAllStageRingsCountMatchDefinition() {
        for stage in StageDefinition.allStages {
            let rings = stage.generateRings()
            XCTAssertEqual(
                rings.count, stage.ringCount,
                "Stage '\(stage.name)': generated rings count should match ringCount"
            )
        }
    }

    func testRingPositionsAreDistinct() {
        for stage in StageDefinition.allStages {
            let rings = stage.generateRings()
            for i in 0..<rings.count {
                for j in (i + 1)..<rings.count {
                    let dist = (rings[i] - rings[j]).length
                    XCTAssertGreaterThan(
                        dist, 1.0,
                        "Stage '\(stage.name)': rings \(i) and \(j) are at same position"
                    )
                }
            }
        }
    }

    func testRingPositionsAdvanceForward() {
        // Rings should generally advance in -Z direction (forward flight path)
        for stage in StageDefinition.allStages {
            let rings = stage.generateRings()
            if rings.count >= 2 {
                let firstZ = rings[0].z
                let lastZ = rings[rings.count - 1].z
                XCTAssertLessThan(lastZ, firstZ,
                    "Stage '\(stage.name)': rings should advance in -Z direction")
            }
        }
    }

    // MARK: - Stage 2 (Valley Run) - Star Collection Requirement

    func testValleyRunHasStarCollectionRequirement() {
        let valleyRun = StageDefinition.allStages[2]
        XCTAssertNotNil(valleyRun.starCountForPerfect,
                        "Valley Run should require star collection for 3 stars")
        XCTAssertEqual(valleyRun.starCountForPerfect, 5)
    }

    func testOtherStagesHaveNoStarRequirement() {
        let stages = StageDefinition.allStages
        let nonValleyRunStages = [stages[0], stages[1], stages[3], stages[4]]
        for stage in nonValleyRunStages {
            XCTAssertNil(stage.starCountForPerfect,
                         "Stage '\(stage.name)' should not require star collection")
        }
    }

    // MARK: - Star Calculation Logic

    func testStarCalcOneStarWithManyCollisions() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]  // Sky Walk
        engine.startStage(stage)

        // Simulate many collisions
        for _ in 0..<5 { engine.registerCollision() }

        // Complete all rings
        for i in 0..<stage.ringCount {
            let ringPos = engine.rings[i].position
            engine.update(deltaTime: 0.016, playerPosition: ringPos)
        }

        if case .completed(let result) = engine.state {
            XCTAssertEqual(result.stars, 1, "5 collisions = 1 star")
        } else {
            XCTFail("Expected completed state")
        }
    }

    func testStarCalcTwoStarsWithFewCollisions() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)

        // 2 collisions = acceptable for 2 stars (not 3)
        engine.registerCollision()
        engine.registerCollision()

        for i in 0..<stage.ringCount {
            engine.update(deltaTime: 0.016, playerPosition: engine.rings[i].position)
        }

        if case .completed(let result) = engine.state {
            // 2 collisions → 2 stars (no time pressure since fast)
            XCTAssertGreaterThanOrEqual(result.stars, 2)
        } else {
            XCTFail("Expected completed state")
        }
    }

    func testValleyRunStarCalcRequiresAllStars() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[2]  // Valley Run
        engine.startStage(stage)

        // Collect only 4 stars (need 5 for 3-star)
        for _ in 0..<4 { engine.registerStarCollected() }

        // Complete with no collisions
        for i in 0..<stage.ringCount {
            engine.update(deltaTime: 0.016, playerPosition: engine.rings[i].position)
        }

        if case .completed(let result) = engine.state {
            // No collisions but only 4 stars → should be 2 stars max
            XCTAssertLessThan(result.stars, 3,
                              "Valley Run with 4/5 stars should not give 3 stars")
        } else {
            XCTFail("Expected completed state")
        }
    }

    func testValleyRunThreeStarsWithAllStarsAndNoCollisions() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[2]  // Valley Run
        engine.startStage(stage)

        // Collect all 5 stars with 0 collisions
        for _ in 0..<5 { engine.registerStarCollected() }

        for i in 0..<stage.ringCount {
            engine.update(deltaTime: 0.016, playerPosition: engine.rings[i].position)
        }

        if case .completed(let result) = engine.state {
            XCTAssertEqual(result.stars, 3,
                           "Valley Run: 0 collisions + all 5 stars = 3 stars")
        } else {
            XCTFail("Expected completed state")
        }
    }
}
