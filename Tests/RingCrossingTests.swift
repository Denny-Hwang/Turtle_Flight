import XCTest
import SceneKit
@testable import TurtleFlight

/// Pins the Phase 1 plane-crossing ring detection and the data-driven
/// `CourseSpec` generator that feeds it.
final class RingCrossingTests: XCTestCase {

    private func makeRing(radius: Float = 30,
                          position: SCNVector3 = SCNVector3(0, 500, -100),
                          normal: SCNVector3 = SCNVector3(0, 0, -1)) -> MissionEngine.Ring {
        MissionEngine.Ring(node: SCNNode(), position: position, radius: radius, normal: normal)
    }

    // MARK: - Pure crossing geometry

    func testCentreCrossingIsPassWithZeroAccuracy() {
        let ring = makeRing()
        let hit = MissionEngine.crossing(of: ring, index: 0,
                                         from: SCNVector3(0, 500, -80),
                                         to: SCNVector3(0, 500, -120))
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit!.accuracy, 0, accuracy: 0.001)
        XCTAssertTrue(hit!.isPass)
        XCTAssertEqual(hit!.hitPoint.z, -100, accuracy: 0.001)
    }

    func testRimCrossingAccuracyIsOne() {
        let ring = makeRing(radius: 30)
        let hit = MissionEngine.crossing(of: ring, index: 0,
                                         from: SCNVector3(30, 500, -80),
                                         to: SCNVector3(30, 500, -120))
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit!.accuracy, 1, accuracy: 0.001)
        XCTAssertTrue(hit!.isPass)
    }

    func testSidePassOutsideRadiusIsMissNotPass() {
        // Old sphere-distance check would have counted this: 49m to the
        // side of a 50m ring is "within radius" of the centre.
        let ring = makeRing(radius: 50)
        let hit = MissionEngine.crossing(of: ring, index: 0,
                                         from: SCNVector3(60, 500, -80),
                                         to: SCNVector3(60, 500, -120))
        XCTAssertNotNil(hit, "Within the attempt window → reported as a miss")
        XCTAssertFalse(hit!.isPass)
        XCTAssertGreaterThan(hit!.accuracy, 1)
    }

    func testFarCrossingIsNotAnAttempt() {
        let ring = makeRing(radius: 30)
        let far = ring.radius * MissionEngine.missAttemptRadiusMultiplier + 5
        let hit = MissionEngine.crossing(of: ring, index: 0,
                                         from: SCNVector3(far, 500, -80),
                                         to: SCNVector3(far, 500, -120))
        XCTAssertNil(hit)
    }

    func testBackwardsCrossingDoesNotCount() {
        let ring = makeRing()
        let hit = MissionEngine.crossing(of: ring, index: 0,
                                         from: SCNVector3(0, 500, -120),
                                         to: SCNVector3(0, 500, -80))
        XCTAssertNil(hit, "Flying through a ring from behind is not a pass")
    }

    func testSegmentThatStopsShortDoesNotCross() {
        let ring = makeRing()
        let hit = MissionEngine.crossing(of: ring, index: 0,
                                         from: SCNVector3(0, 500, -80),
                                         to: SCNVector3(0, 500, -95))
        XCTAssertNil(hit)
    }

    func testDiagonalSegmentInterpolatesHitPoint() {
        let ring = makeRing(radius: 40, position: SCNVector3(0, 500, -100))
        // Moves 40m in x while crossing: hit at t=0.5 → x = 20.
        let hit = MissionEngine.crossing(of: ring, index: 3,
                                         from: SCNVector3(0, 500, -80),
                                         to: SCNVector3(40, 500, -120))
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit!.ringIndex, 3)
        XCTAssertEqual(hit!.hitPoint.x, 20, accuracy: 0.001)
        XCTAssertEqual(hit!.accuracy, 0.5, accuracy: 0.001)
    }

    // MARK: - Engine integration

    func testEngineNeedsTwoFramesToDetectAPass() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(StageDefinition.allStages[0])
        // Teleporting onto the centre is not a pass any more.
        engine.update(deltaTime: 0.016, playerPosition: engine.rings[0].position)
        XCTAssertEqual(engine.currentRingIndex, 0)
        XCTAssertNil(engine.lastCrossing)
    }

    func testEngineRecordsCrossingAccuracy() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]     // radius 50
        engine.startStage(stage)
        engine.testPass(ringIndex: 0, lateralOffset: 25)
        XCTAssertEqual(engine.currentRingIndex, 1)
        XCTAssertEqual(engine.crossingCount, 1)
        XCTAssertNotNil(engine.lastCrossing)
        XCTAssertEqual(engine.lastCrossing!.accuracy, 0.5, accuracy: 0.01)
        XCTAssertEqual(engine.ringMisses, 0)
    }

    func testEngineCountsNearMissAndKeepsTargetRing() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = StageDefinition.allStages[0]     // radius 50
        engine.startStage(stage)
        engine.testPass(ringIndex: 0, lateralOffset: 70)  // 1.4 radii
        XCTAssertEqual(engine.currentRingIndex, 0, "A miss must not advance the ring")
        XCTAssertEqual(engine.ringMisses, 1)
        XCTAssertEqual(engine.crossingCount, 1)
        XCTAssertFalse(engine.lastCrossing!.isPass)

        // Loop back and take it properly.
        engine.testPass(ringIndex: 0)
        XCTAssertEqual(engine.currentRingIndex, 1)
        XCTAssertEqual(engine.crossingCount, 2)
    }

    func testAllStagesCompleteWhenFlownThroughEveryRing() {
        for stage in StageDefinition.allStages {
            let scene = SCNScene()
            let engine = MissionEngine(parentNode: scene.rootNode)
            engine.startStage(stage) { _, _ in 0 }
            engine.testPassAllRings()
            if case .completed(let result) = engine.state {
                XCTAssertEqual(result.ringsCompleted, stage.ringCount)
            } else {
                XCTFail("Stage \(stage.index) should complete")
            }
        }
    }

    func testRingNodesFaceCourseDirection() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(StageDefinition.allStages[2])   // S-curve
        for ring in engine.rings {
            XCTAssertEqual(ring.normal.length, 1, accuracy: 0.001)
            XCTAssertEqual(ring.normal.y, 0, accuracy: 0.001, "Normals stay horizontal")
            XCTAssertLessThan(ring.normal.z, 0, "Course advances along -Z")
        }
    }

    func testResetClearsCrossingState() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(StageDefinition.allStages[0])
        engine.testPass(ringIndex: 0)
        engine.reset()
        XCTAssertNil(engine.lastCrossing)
        XCTAssertEqual(engine.crossingCount, 0)
        XCTAssertEqual(engine.ringMisses, 0)
    }

    // MARK: - CourseSpec / CourseGenerator

    func testGeneratorIsDeterministicForSameSpec() {
        let spec = CourseSpec(pattern: .race, count: 12, spacing: 100, startZ: -100,
                              lateralAmplitude: 60, angleStep: 0.5,
                              baseAltitude: 400, altitudeAmplitude: 80,
                              jitter: 30, seed: 1234)
        let a = CourseGenerator.generate(spec)
        let b = CourseGenerator.generate(spec)
        XCTAssertEqual(a.count, 12)
        for i in 0..<a.count {
            XCTAssertEqual(a[i].x, b[i].x, accuracy: 0.0001)
            XCTAssertEqual(a[i].y, b[i].y, accuracy: 0.0001)
            XCTAssertEqual(a[i].z, b[i].z, accuracy: 0.0001)
        }
    }

    func testDifferentSeedsProduceDifferentJitter() {
        var spec = CourseSpec(pattern: .weave, count: 8, spacing: 100, startZ: -100,
                              lateralAmplitude: 60, angleStep: 0.5,
                              baseAltitude: 400, altitudeAmplitude: 10,
                              jitter: 30, seed: 1)
        let a = CourseGenerator.generate(spec)
        spec.seed = 2
        let b = CourseGenerator.generate(spec)
        let anyDifferent = zip(a, b).contains { abs($0.x - $1.x) > 0.01 || abs($0.y - $1.y) > 0.01 }
        XCTAssertTrue(anyDifferent)
    }

    func testZeroSeedIgnoresJitter() {
        let spec = CourseSpec(pattern: .weave, count: 5, spacing: 100, startZ: -100,
                              lateralAmplitude: 60, angleStep: 0.5,
                              baseAltitude: 400, altitudeAmplitude: 10,
                              jitter: 500, seed: 0)
        let rings = CourseGenerator.generate(spec)
        for (i, r) in rings.enumerated() {
            XCTAssertEqual(r.x, sin(Float(i) * 0.5) * 60, accuracy: 0.001)
        }
    }

    func testFirstRingIsAheadOfSpawnForEveryStage() {
        for stage in StageDefinition.allStages {
            let first = stage.generateRings()[0]
            XCTAssertLessThan(first.z, -50,
                              "Stage \(stage.index): first ring must be clearly ahead of the spawn point")
        }
    }

    func testGeneratorRespectsMinimumAltitude() {
        let spec = CourseSpec(pattern: .sCurve, count: 10, spacing: 100, startZ: -100,
                              lateralAmplitude: 60, angleStep: 0.8,
                              baseAltitude: 20, altitudeAmplitude: 200)
        for r in CourseGenerator.generate(spec) {
            XCTAssertGreaterThanOrEqual(r.y, CourseGenerator.minimumAltitude)
        }
    }

    func testCourseSpecRoundTripsThroughJSON() throws {
        let spec = CourseSpec(pattern: .peaks, count: 7, spacing: 200, startZ: -200,
                              lateralAmplitude: 80, angleStep: 0.9,
                              baseAltitude: 600, altitudeAmplitude: 200,
                              jitter: 12, seed: 99)
        let data = try JSONEncoder().encode(spec)
        let back = try JSONDecoder().decode(CourseSpec.self, from: data)
        XCTAssertEqual(back, spec)
    }

    func testSeededRandomIsReproducible() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        for _ in 0..<50 {
            XCTAssertEqual(a.next(), b.next())
        }
        let unit = a.nextUnit()
        XCTAssertGreaterThanOrEqual(unit, 0)
        XCTAssertLessThan(unit, 1)
        XCTAssertEqual(SeededRandom.stableHash("2026-09-19"),
                       SeededRandom.stableHash("2026-09-19"))
        XCTAssertNotEqual(SeededRandom.stableHash("2026-09-19"),
                          SeededRandom.stableHash("2026-09-20"))
    }
}
