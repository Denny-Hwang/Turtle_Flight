import XCTest
import SceneKit
@testable import TurtleFlight

/// Ring flow + guidance (owner 2026-11-26: "stretches with no rings",
/// "guide me back to the ring when I drift away").
final class RingGuidanceTests: XCTestCase {

    private func deg(_ d: Double) -> Double { d * .pi / 180 }

    private func startedEngine(_ stage: StageDefinition = StageDefinition.allStages[0]) -> MissionEngine {
        let engine = MissionEngine(parentNode: SCNScene().rootNode)
        engine.startStage(stage) { _, _ in 0 }
        return engine
    }

    // MARK: - Missed rings move on

    func testFlyingWideOfARingCountsAsMissAndMovesOn() {
        let engine = startedEngine()
        let ring = engine.rings[0]
        let wide = ring.radius * MissionEngine.missAttemptRadiusMultiplier + 40
        let side = ring.sideAxis
        let c = ring.position
        let n = ring.normal
        let base = SCNVector3(c.x + side.x * wide, c.y, c.z + side.z * wide)
        engine.update(deltaTime: 0.016, playerPosition: base - n * 20)
        engine.update(deltaTime: 0.016, playerPosition: base + n * 20)
        XCTAssertEqual(engine.currentRingIndex, 1)
        XCTAssertEqual(engine.ringMisses, 1)
        XCTAssertEqual(engine.lastJudgement, .miss)
        XCTAssertEqual(engine.crossingCount, 1, "the HUD hears about it (MISS callout)")
    }

    func testDriftingFarPastARingMovesOn() {
        // Course turns: the player ends up beyond the ring's plane without
        // ever crossing it going forward.
        let engine = startedEngine()
        let ring = engine.rings[0]
        let past = ring.position + ring.normal * (MissionEngine.missSkipDistance + 10)
        engine.update(deltaTime: 0.016, playerPosition: past)
        engine.update(deltaTime: 0.016, playerPosition: past + SCNVector3(1, 0, 0))
        XCTAssertEqual(engine.currentRingIndex, 1)
    }

    func testMissingMoreThanHalfFailsTheCourse() {
        let engine = startedEngine()
        let total = engine.rings.count
        for _ in 0...(total / 2) {
            guard case .inProgress = engine.state else { break }
            let effective = engine.currentEffectiveRadius ?? 30
            engine.testPass(ringIndex: engine.currentRingIndex, lateralOffset: effective * 1.5)
        }
        guard case .failed = engine.state else { return XCTFail("should fail after missing over half") }
    }

    func testMissedRingsCapTheStars() {
        let engine = startedEngine()
        let effective = engine.currentEffectiveRadius ?? 30
        engine.testPass(ringIndex: 0, lateralOffset: effective * 1.5)
        engine.testPassAllRings()
        guard case .completed(let result) = engine.state else { return XCTFail("should clear") }
        XCTAssertLessThanOrEqual(result.stars, 2)
        XCTAssertEqual(result.ringsCompleted, engine.rings.count - 1)
    }

    func testKidsStillNeverFails() {
        let kids = StageDefinition.allStages[0].kidsVariant()
        let engine = startedEngine(kids)
        for _ in 0..<engine.rings.count {
            guard case .inProgress = engine.state else { break }
            engine.testPass(ringIndex: engine.currentRingIndex, lateralOffset: 400)
        }
        if case .failed = engine.state { XCTFail("Kids never fails") }
    }

    // MARK: - Next-ring preview + path (R1) and miss flash (R4)

    func testNextRingIsPreviewedAndTheRestDimmed() {
        let engine = startedEngine()
        XCTAssertEqual(engine.rings[0].node.opacity, 1)
        XCTAssertEqual(engine.rings[1].node.opacity, MissionEngine.previewOpacity)
        XCTAssertEqual(engine.rings[2].node.opacity, MissionEngine.distantOpacity)
        let path = try! XCTUnwrap(engine.pathNode)
        XCTAssertEqual(path.childNodes.count, MissionEngine.pathDots)
        // Dots lie between the target and the next ring.
        let a = engine.rings[0].position, b = engine.rings[1].position
        for dot in path.childNodes {
            XCTAssertLessThan(dot.position.z, max(a.z, b.z) + 0.01)
            XCTAssertGreaterThan(dot.position.z, min(a.z, b.z) - 0.01)
        }

        engine.testPass(ringIndex: 0)
        XCTAssertEqual(engine.rings[2].node.opacity, MissionEngine.previewOpacity, "preview moves on")
        let moved = try! XCTUnwrap(engine.pathNode)
        XCTAssertGreaterThan(moved.childNodes[0].position.z, engine.rings[2].position.z)
        XCTAssertLessThan(moved.childNodes[0].position.z, engine.rings[1].position.z)
    }

    func testPathGoesAwayWhenTheCourseEnds() {
        let engine = startedEngine()
        engine.testPassAllRings()
        XCTAssertNil(engine.pathNode)
    }

    func testMissedRingFlashesRed() {
        let engine = startedEngine()
        let ring = engine.rings[0]
        let effective = engine.currentEffectiveRadius ?? 30
        engine.testPass(ringIndex: 0, lateralOffset: effective * 1.5)
        var red: CGFloat = 0, green: CGFloat = 0
        ring.node.enumerateChildNodes { node, _ in
            if let colour = (node.geometry as? SCNTorus)?.firstMaterial?.diffuse.contents as? UIColor {
                colour.getRed(&red, green: &green, blue: nil, alpha: nil)
            }
        }
        XCTAssertGreaterThan(red, 0.9)
        XCTAssertLessThan(green, 0.5)
    }

    // MARK: - Course start

    func testStageStartsAtTheCourseLevelWithTheFirstRing() {
        let vm = FlightViewModel()
        let scene = SCNScene()
        vm.missionEngine = MissionEngine(parentNode: scene.rootNode)
        // Somewhere far away, as after finishing a previous course.
        vm.flightEngine.place(at: SCNVector3(800, 1200, -3000), heading: 200)
        vm.missionEngine?.startStage(StageDefinition.allStages[2]) { _, _ in 0 }   // valley: low first ring
        vm.placeAtCourseStart()
        let first = vm.missionEngine!.rings[0].position
        let pos = vm.flightEngine.state.position
        XCTAssertEqual(pos.x, 0, accuracy: 0.01)
        XCTAssertEqual(pos.z, 0, accuracy: 0.01)
        XCTAssertEqual(pos.y, max(first.y, 40), accuracy: 0.01)
        let guide = RingGuide.make(bearing: 0, dx: first.x - pos.x, dy: first.y - pos.y, dz: first.z - pos.z)
        XCTAssertLessThan(abs(guide.elevation), deg(5), "first ring is roughly level ahead")
    }

    // MARK: - Guide geometry

    func testRingStraightAheadNeedsNoGuide() {
        let g = RingGuide.make(bearing: 0, dx: 0, dy: 0, dz: -300)
        XCTAssertTrue(g.isOnScreen)
        XCTAssertFalse(g.showsGuide)
    }

    func testRingOffToTheRightPointsRight() {
        let g = RingGuide(bearing: deg(75), elevation: 0, distance: 400)
        XCTAssertTrue(g.showsGuide)
        XCTAssertEqual(g.edgePoint.x, 1, accuracy: 1e-9)
    }

    func testRingHighAbovePointsUp() {
        let g = RingGuide(bearing: 0, elevation: deg(40), distance: 300)
        XCTAssertTrue(g.showsGuide)
        XCTAssertEqual(g.edgePoint.y, -1, accuracy: 1e-9, "y is down on screen")
    }

    func testRingBehindSitsLowOnTheTurnSide() {
        let left = RingGuide(bearing: deg(-160), elevation: 0, distance: 250)
        XCTAssertTrue(left.isBehind)
        XCTAssertTrue(left.showsGuide)
        XCTAssertEqual(left.edgePoint.x, -1, accuracy: 1e-9)
        XCTAssertGreaterThan(left.edgePoint.y, 0)
    }

    func testRingAShortWayAheadAndAboveCountsAsOnScreen() {
        // Sky Run capture: 110 m ahead, 30 m up showed a guide while the
        // ring was plainly in view.
        let g = RingGuide.fromCamera(ringDelta: SIMD3(0, 30, -110), heading: 0)
        XCTAssertTrue(g.isOnScreen)
        XCTAssertFalse(g.showsGuide)
        XCTAssertEqual(g.distance, (110 * 110 + 30 * 30 as Float).squareRoot(), accuracy: 0.01)
    }

    func testCameraGuideTurnsWithHeading() {
        // Heading east (90°): a ring to the north is on the left.
        let g = RingGuide.fromCamera(ringDelta: SIMD3(0, 0, -400), heading: 90)
        XCTAssertLessThan(g.bearing, -deg(60))
        XCTAssertTrue(g.showsGuide)
    }

    func testCloseRingHidesGuide() {
        XCTAssertFalse(RingGuide(bearing: deg(120), elevation: 0, distance: 20).showsGuide)
    }

    // MARK: - Stars follow the flight

    func testStarsLeftFarBehindAreDropped() {
        let items = ItemSystem(parentNode: SCNScene().rootNode)
        items.spawnStars(around: SCNVector3(0, 500, 0))
        XCTAssertEqual(items.uncollectedStarCount, 10)
        let dropped = items.dropStars(fartherThan: Constants.Items.starDropDistance,
                                      from: SCNVector3(0, 500, -2000))
        XCTAssertEqual(dropped, 10)
        XCTAssertEqual(items.uncollectedStarCount, 0)
    }
}
