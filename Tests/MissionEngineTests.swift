import XCTest
import SceneKit
@testable import TurtleFlight

final class MissionEngineTests: XCTestCase {

    var scene: SCNScene!
    var engine: MissionEngine!

    override func setUp() {
        super.setUp()
        scene = SCNScene()
        engine = MissionEngine(parentNode: scene.rootNode)
    }

    func testInitialState() {
        if case .notStarted = engine.state {
            // pass
        } else {
            XCTFail("Expected notStarted state")
        }
    }

    func testStartStage() {
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)

        if case .inProgress = engine.state {
            // pass
        } else {
            XCTFail("Expected inProgress state")
        }

        XCTAssertEqual(engine.rings.count, stage.ringCount)
        XCTAssertEqual(engine.currentRingIndex, 0)
    }

    func testStageCount() {
        XCTAssertEqual(StageDefinition.allStages.count, 5)
    }

    func testStageDifficultyProgression() {
        let stages = StageDefinition.allStages
        for i in 1..<stages.count {
            XCTAssertGreaterThanOrEqual(stages[i].difficulty, stages[i - 1].difficulty)
        }
    }

    func testRingGeneration() {
        for stage in StageDefinition.allStages {
            let rings = stage.generateRings()
            XCTAssertGreaterThan(rings.count, 0)
        }
    }

    func testRingPassage() {
        let stage = StageDefinition.allStages[0] // Sky Walk
        engine.startStage(stage)

        // Move player to first ring position
        let firstRingPos = engine.rings[0].position
        engine.update(deltaTime: 0.016, playerPosition: firstRingPos)

        XCTAssertEqual(engine.currentRingIndex, 1)
    }

    func testCollisionTracking() {
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)

        engine.registerCollision()
        engine.registerCollision()
        XCTAssertEqual(engine.collisions, 2)
    }

    func testStarCollectedTracking() {
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)

        engine.registerStarCollected()
        XCTAssertEqual(engine.starsCollected, 1)
    }

    func testProgressText() {
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)
        XCTAssertTrue(engine.progressText.contains("0/\(stage.ringCount)"))
    }

    func testReset() {
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)
        engine.reset()

        if case .notStarted = engine.state {
            // pass
        } else {
            XCTFail("Expected notStarted after reset")
        }
        XCTAssertTrue(engine.rings.isEmpty)
    }

    func testPlayerProgressDefaults() {
        let progress = PlayerProgress.defaultProgress
        XCTAssertEqual(progress.totalStars, 0)
        XCTAssertEqual(progress.selectedCharacter, .turtle)
        XCTAssertEqual(progress.selectedVehicle, .shellJet)
        XCTAssertEqual(progress.sensitivityLevel, .easy)
        XCTAssertEqual(progress.maxUnlockedStage, 0)
    }

    func testStageUnlocking() {
        var progress = PlayerProgress.defaultProgress

        let result = StageResult(
            stageIndex: 0, stars: 2, completionTime: 45,
            collisions: 0, starsCollected: 3, ringsCompleted: 10,
            totalRings: 10, date: Date()
        )
        progress.updateStageResult(result)

        XCTAssertEqual(progress.totalStars, 2)
        XCTAssertEqual(progress.maxUnlockedStage, 1) // Stage 2 unlocked
    }
}
