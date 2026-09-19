import XCTest
import SceneKit
@testable import TurtleFlight

/// Phase 2: gate judgement + combo scoring, gate kinds (shrinking, tilt,
/// moving), combo-driven ring tightening, and result plumbing.
final class GateScoringTests: XCTestCase {

    // MARK: - Judgement thresholds

    func testJudgementThresholds() {
        XCTAssertEqual(GateScoring.judge(accuracy: 0), .bullseye)
        XCTAssertEqual(GateScoring.judge(accuracy: 0.2), .bullseye)
        XCTAssertEqual(GateScoring.judge(accuracy: 0.21), .great)
        XCTAssertEqual(GateScoring.judge(accuracy: 0.6), .great)
        XCTAssertEqual(GateScoring.judge(accuracy: 0.61), .ok)
        XCTAssertEqual(GateScoring.judge(accuracy: 1.0), .ok)
        XCTAssertEqual(GateScoring.judge(accuracy: 1.01), .miss)
    }

    func testPointsScaleWithMultiplierAndCombo() {
        XCTAssertEqual(GateScoring.points(for: .ok, combo: 0), 100)
        XCTAssertEqual(GateScoring.points(for: .great, combo: 0), 200)
        XCTAssertEqual(GateScoring.points(for: .bullseye, combo: 0), 300)
        XCTAssertEqual(GateScoring.points(for: .miss, combo: 5), 0)
        XCTAssertEqual(GateScoring.points(for: .bullseye, combo: 5), 450)   // +50%
        XCTAssertEqual(GateScoring.points(for: .bullseye, combo: 10), 600)  // capped +100%
        XCTAssertEqual(GateScoring.points(for: .bullseye, combo: 40), 600)
    }

    func testRunScoreTracksComboAndCounts() {
        var run = RunScore()
        run.register(.ok)        // 100, combo 1
        run.register(.great)     // 220, combo 2
        run.register(.bullseye)  // 360, combo 3
        XCTAssertEqual(run.points, 680)
        XCTAssertEqual(run.combo, 3)
        XCTAssertEqual(run.maxCombo, 3)
        run.register(.miss)
        XCTAssertEqual(run.combo, 0, "A miss resets the combo")
        XCTAssertEqual(run.maxCombo, 3, "…but not the best")
        XCTAssertEqual(run.misses, 1)
        XCTAssertEqual(run.passes, 3)
        run.register(.ok)
        XCTAssertEqual(run.combo, 1)
        XCTAssertEqual(run.points, 780)
    }

    // MARK: - Engine integration

    func testEngineScoresEachCrossing() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(StageDefinition.allStages[0])   // r = 50, standard gates
        engine.testPass(ringIndex: 0)                      // bullseye
        XCTAssertEqual(engine.lastJudgement, .bullseye)
        XCTAssertEqual(engine.lastPointsEarned, 300)
        engine.testPass(ringIndex: 1, lateralOffset: 20)   // 0.4 → great, combo 1 → 220
        XCTAssertEqual(engine.lastJudgement, .great)
        XCTAssertEqual(engine.lastPointsEarned, 220)
        engine.testPass(ringIndex: 2, lateralOffset: 70)   // 1.4 → miss
        XCTAssertEqual(engine.lastJudgement, .miss)
        XCTAssertEqual(engine.lastPointsEarned, 0)
        XCTAssertEqual(engine.score.combo, 0)
        XCTAssertEqual(engine.score.points, 520)
        XCTAssertEqual(engine.currentRingIndex, 2)
    }

    func testCompletedResultCarriesScore() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]
        engine.startStage(stage)
        engine.testPassAllRings()
        guard case .completed(let result) = engine.state else {
            return XCTFail("Expected completion")
        }
        XCTAssertEqual(result.score, engine.score.points)
        XCTAssertEqual(result.maxCombo, stage.ringCount)
        XCTAssertEqual(result.bullseyes, stage.ringCount)
        XCTAssertGreaterThan(result.score ?? 0, 0)
    }

    func testStageResultDecodesWithoutScoreFields() throws {
        // A pre-Phase-2 saved blob has no score / maxCombo / bullseyes.
        let json = """
        {"stageIndex":0,"stars":2,"completionTime":40,"collisions":1,
         "starsCollected":0,"ringsCompleted":10,"totalRings":10,"date":0}
        """
        let result = try JSONDecoder().decode(StageResult.self, from: Data(json.utf8))
        XCTAssertNil(result.score)
        XCTAssertNil(result.maxCombo)
        XCTAssertEqual(result.stars, 2)
    }

    // MARK: - Gate recipes

    func testRecipesAssignExpectedKinds() {
        XCTAssertEqual(GateRecipe.standard.kinds(count: 4).map(\.name),
                       ["standard", "standard", "standard", "standard"])
        XCTAssertEqual(GateRecipe.shrinkingEveryThird.kinds(count: 6).map(\.name),
                       ["standard", "standard", "shrinking", "standard", "standard", "shrinking"])
        XCTAssertEqual(GateRecipe.tiltAlternate.kinds(count: 4).map(\.name),
                       ["standard", "tilt", "standard", "tilt"])
        XCTAssertEqual(GateRecipe.mixed.kinds(count: 5).map(\.name),
                       ["standard", "shrinking", "tilt", "moving", "standard"])
        XCTAssertEqual(GateRecipe.mixedAfterWarmup.kinds(count: 5).map(\.name),
                       ["standard", "standard", "standard", "standard", "shrinking"])
    }

    func testCampaignRecipesAreApplied() {
        let stages = StageDefinition.allStages
        XCTAssertEqual(stages[0].course.gateRecipe, .standard)
        XCTAssertEqual(stages[1].course.gateRecipe, .shrinkingEveryThird)
        XCTAssertEqual(stages[3].course.gateRecipe, .tiltAlternate)
        XCTAssertEqual(stages[4].course.gateRecipe, .mixedAfterWarmup)
        XCTAssertTrue(stages[4].course.comboShrink)
        XCTAssertFalse(stages[0].course.comboShrink)
    }

    func testGateKindRoundTripsThroughJSON() throws {
        let kinds: [GateKind] = [.standard, .defaultShrinking, .defaultTilt, .defaultMoving]
        let data = try JSONEncoder().encode(kinds)
        let back = try JSONDecoder().decode([GateKind].self, from: data)
        XCTAssertEqual(back, kinds)
    }

    // MARK: - Shrinking gate

    private func makeRing(kind: GateKind, radius: Float = 30,
                          position: SCNVector3 = SCNVector3(0, 500, -100)) -> MissionEngine.Ring {
        MissionEngine.Ring(node: SCNNode(), position: position, radius: radius,
                           normal: SCNVector3(0, 0, -1), kind: kind)
    }

    func testShrinkingGateShrinksFromTargetTime() {
        var ring = makeRing(kind: .shrinking(minScale: 0.5, duration: 4))
        XCTAssertEqual(ring.shrinkScale(at: 10), 1, "Untargeted rings don't shrink")
        ring.targetedAt = 10
        XCTAssertEqual(ring.shrinkScale(at: 10), 1, accuracy: 0.001)
        XCTAssertEqual(ring.shrinkScale(at: 12), 0.75, accuracy: 0.001)
        XCTAssertEqual(ring.shrinkScale(at: 14), 0.5, accuracy: 0.001)
        XCTAssertEqual(ring.shrinkScale(at: 30), 0.5, accuracy: 0.001, "Floors at minScale")
        XCTAssertEqual(ring.effectiveRadius(at: 12, comboFactor: 1), 22.5, accuracy: 0.001)
    }

    func testShrinkingGateTurnsALatePassIntoAMiss() {
        var ring = makeRing(kind: .shrinking(minScale: 0.5, duration: 4), radius: 30)
        ring.targetedAt = 0
        let from = SCNVector3(20, 500, -80)
        let to = SCNVector3(20, 500, -120)
        let early = MissionEngine.crossing(of: ring, index: 0, from: from, to: to, at: 0)
        XCTAssertNotNil(early)
        XCTAssertTrue(early!.isPass, "20m offset inside a 30m ring at t=0")
        let late = MissionEngine.crossing(of: ring, index: 0, from: from, to: to, at: 4)
        XCTAssertNotNil(late)
        XCTAssertFalse(late!.isPass, "Same line at t=4 is outside the 15m ring")
    }

    func testEngineStampsTargetTimeOnHighlight() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(StageDefinition.allStages[1])   // shrinking every third
        XCTAssertEqual(engine.rings[0].targetedAt, 0)
        XCTAssertNil(engine.rings[1].targetedAt)
        engine.testPass(ringIndex: 0)
        XCTAssertNotNil(engine.rings[1].targetedAt)
        XCTAssertEqual(engine.rings[1].targetedAt!, engine.elapsedTime, accuracy: 0.05)
    }

    // MARK: - Tilt gate

    func testTiltGateIsAnEllipse() {
        // 45° slit, minor axis 0.45 × 30 = 13.5. A point 15m to the side
        // and 15m up lies *along* the 45° major axis → inside. The same
        // point mirrored (15 side, -15 down) lies along the minor axis →
        // outside.
        let ring = makeRing(kind: .tilt(angleDegrees: 45, slitRatio: 0.45))
        let along = MissionEngine.crossing(of: ring, index: 0,
                                           from: SCNVector3(15, 515, -80),
                                           to: SCNVector3(15, 515, -120))
        XCTAssertNotNil(along)
        XCTAssertTrue(along!.isPass, "Along the slit's major axis")
        let across = MissionEngine.crossing(of: ring, index: 0,
                                            from: SCNVector3(15, 485, -80),
                                            to: SCNVector3(15, 485, -120))
        XCTAssertNotNil(across)
        XCTAssertFalse(across!.isPass, "Across the slit's minor axis")
        let centre = MissionEngine.crossing(of: ring, index: 0,
                                            from: SCNVector3(0, 500, -80),
                                            to: SCNVector3(0, 500, -120))
        XCTAssertEqual(centre!.accuracy, 0, accuracy: 0.001)
    }

    // MARK: - Moving gate

    func testMovingGateCentreOscillates() {
        let ring = makeRing(kind: .moving(axis: .lateral, amplitude: 40, period: 4))
        let c0 = ring.center(at: 0)
        XCTAssertEqual(c0.x, 0, accuracy: 0.001)
        let c1 = ring.center(at: 1)      // quarter period → +amplitude along side axis
        XCTAssertEqual(abs(c1.x), 40, accuracy: 0.01)
        XCTAssertEqual(c1.y, 500, accuracy: 0.001)
        let vertical = makeRing(kind: .moving(axis: .vertical, amplitude: 25, period: 2))
        let v = vertical.center(at: 0.5)
        XCTAssertEqual(v.y, 525, accuracy: 0.01)
        XCTAssertEqual(v.x, 0, accuracy: 0.001)
    }

    func testMovingGateHitTestUsesLiveCentre() {
        let ring = makeRing(kind: .moving(axis: .vertical, amplitude: 40, period: 2), radius: 20)
        // At t = 0.5 the centre is at y = 540; a level line at y = 500 misses.
        let miss = MissionEngine.crossing(of: ring, index: 0,
                                          from: SCNVector3(0, 500, -80),
                                          to: SCNVector3(0, 500, -120), at: 0.5)
        XCTAssertNotNil(miss)
        XCTAssertFalse(miss!.isPass)
        let hit = MissionEngine.crossing(of: ring, index: 0,
                                         from: SCNVector3(0, 540, -80),
                                         to: SCNVector3(0, 540, -120), at: 0.5)
        XCTAssertTrue(hit!.isPass)
    }

    // MARK: - Combo shrink

    func testComboShrinkTightensRadiusOnlyWhenEnabled() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(StageDefinition.allStages[0])    // comboShrink off
        engine.testPass(ringIndex: 0)
        engine.testPass(ringIndex: 1)
        XCTAssertEqual(engine.comboRadiusFactor, 1, accuracy: 0.001)

        let race = MissionEngine(parentNode: scene.rootNode)
        race.startStage(StageDefinition.allStages[4])      // comboShrink on, r = 15
        XCTAssertEqual(race.comboRadiusFactor, 1, accuracy: 0.001)
        race.testPass(ringIndex: 0)
        race.testPass(ringIndex: 1)
        XCTAssertEqual(race.comboRadiusFactor, 0.92, accuracy: 0.001)
        XCTAssertEqual(race.currentEffectiveRadius!, 15 * 0.92, accuracy: 0.01)
        for _ in 0..<12 { race.testPass(ringIndex: race.currentRingIndex) }
        XCTAssertEqual(race.comboRadiusFactor, MissionEngine.comboShrinkFloor, accuracy: 0.001,
                       "Floors so the ring never closes completely")
    }

    func testEveryCampaignStageStillCompletesWithGateKinds() {
        for stage in StageDefinition.allStages {
            let scene = SCNScene()
            let engine = MissionEngine(parentNode: scene.rootNode)
            engine.startStage(stage) { _, _ in 0 }
            engine.testPassAllRings()
            if case .completed = engine.state {
                // ok
            } else {
                XCTFail("Stage \(stage.index) did not complete; ring \(engine.currentRingIndex)/\(engine.rings.count)")
            }
        }
    }
}
