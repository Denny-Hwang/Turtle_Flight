import XCTest
import SceneKit
@testable import TurtleFlight

/// Free Flight ring trails (R2, owner 2026-11-27).
final class RingTrailTests: XCTestCase {

    private let flat: (Float, Float) -> Float = { _, _ in 0 }

    private func headingOf(_ f: SIMD2<Float>) -> Float {
        var h = atan2(f.x, -f.y) * 180 / .pi
        if h < 0 { h += 360 }
        return h
    }

    func testStraightTrailAhead() {
        let trail = RingTrail(position: SIMD3(0, 500, 0), heading: 0, targetBearing: nil, seed: 1, ground: flat)
        XCTAssertEqual(trail.gates.count, RingTrail.count)
        XCTAssertEqual(trail.gates[0].center.z, -RingTrail.firstOffset, accuracy: 0.01)
        for i in 1..<trail.gates.count {
            let a = trail.gates[i - 1].center, b = trail.gates[i].center
            let flat = simd_length(SIMD2(b.x - a.x, b.z - a.z))
            XCTAssertEqual(flat, RingTrail.spacing, accuracy: 0.01)
            XCTAssertLessThanOrEqual(abs(b.y - a.y), flat * RingTrail.maxSlope + 0.01, "gentle climbs only")
        }
    }

    func testTrailBendsTowardTheLandmarkGradually() {
        let trail = RingTrail(position: SIMD3(0, 500, 0), heading: 0, targetBearing: 50, seed: 2, ground: flat)
        var previous: Float = 0
        for gate in trail.gates.dropFirst() {
            let h = headingOf(gate.forward)
            XCTAssertLessThanOrEqual(h - previous, RingTrail.maxTurn + 0.01)
            XCTAssertGreaterThanOrEqual(h, previous)
            previous = h
        }
        XCTAssertEqual(previous, 50, accuracy: 0.01, "reaches the landmark's bearing and stops turning")
        XCTAssertGreaterThan(trail.gates.last!.center.x, 50, "bent to the right")
    }

    func testRingsStayClearOfHighGround() {
        let hills: (Float, Float) -> Float = { _, z in z < -500 ? 520 : 0 }
        let trail = RingTrail(position: SIMD3(0, 500, 0), heading: 0, targetBearing: nil, seed: 3, ground: hills)
        for gate in trail.gates where gate.center.z < -500 {
            XCTAssertGreaterThanOrEqual(gate.center.y, 520 + RingTrail.groundClearance + RingTrail.radius - 0.01)
        }
    }

    func testFlyingThroughInOrder() {
        var trail = RingTrail(position: SIMD3(0, 500, 0), heading: 0, targetBearing: nil, seed: 4, ground: flat)
        for i in 0..<RingTrail.count {
            let c = trail.gates[i].center
            XCTAssertEqual(trail.step(deltaTime: 0.2, from: c + SIMD3(0, 0, 6), to: c - SIMD3(0, 0, 6)), i)
        }
        XCTAssertTrue(trail.allPassed)
        XCTAssertTrue(trail.isFinished(playerPosition: trail.gates.last!.center - SIMD3(0, 0, 60)))
    }

    func testMissingOneMovesOnWithoutPayingTheBonus() {
        var trail = RingTrail(position: SIMD3(0, 500, 0), heading: 0, targetBearing: nil, seed: 5, ground: flat)
        let c0 = trail.gates[0].center + SIMD3(RingTrail.radius + 20, 0, 0)
        XCTAssertNil(trail.step(deltaTime: 0.2, from: c0 + SIMD3(0, 0, 6), to: c0 - SIMD3(0, 0, 6)))
        XCTAssertEqual(trail.next, 1)
        let c1 = trail.gates[1].center
        XCTAssertEqual(trail.step(deltaTime: 0.2, from: c1 + SIMD3(0, 0, 6), to: c1 - SIMD3(0, 0, 6)), 1)
        XCTAssertFalse(trail.allPassed)
    }

    func testTrailGoesAwayWhenLeftBehindOrTooOld() {
        var trail = RingTrail(position: SIMD3(0, 500, 0), heading: 0, targetBearing: nil, seed: 6, ground: flat)
        XCTAssertFalse(trail.isFinished(playerPosition: SIMD3(0, 500, 0)))
        let last = trail.gates.last!.center
        XCTAssertTrue(trail.isFinished(playerPosition: last - SIMD3(0, 0, RingTrail.leaveDistance + 10)))
        _ = trail.step(deltaTime: RingTrail.lifetime + 1, from: SIMD3(0, 500, 0), to: SIMD3(0, 500, -1))
        XCTAssertTrue(trail.isFinished(playerPosition: SIMD3(0, 500, 0)))
    }

    func testSchedulerWaitsForTheTrailToEnd() {
        var s = RingTrailScheduler(seed: 9)
        XCTAssertTrue(RingTrailScheduler.firstDelay.contains(s.nextTime))
        s.taken()
        XCTAssertFalse(s.isDue(at: 10_000))
        s.finished(at: 100)
        XCTAssertTrue(RingTrailScheduler.interval.contains(s.nextTime - 100))
    }

    func testFlyingAFullTrailInFreeFlightPaysStarsAndBoost() {
        let vm = FlightViewModel()
        let scene = SCNScene()
        UserDefaults.standard.set(true, forKey: "TFRingTrail")
        defer { UserDefaults.standard.removeObject(forKey: "TFRingTrail") }
        vm.setUpFreeFlightExtras(scene: scene, theme: .sky, mood: .day, festival: false,
                                 wonderSeed: 3, around: SCNVector3(0, 500, 0))
        vm.setPieceScheduler = nil   // keep the sky to the trail for this test
        // Spend the boost gauge so the refill shows.
        vm.flightEngine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: true, shouldAutoLevel: false)
        for _ in 0..<220 {
            vm.flightEngine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: false, shouldAutoLevel: false)
        }
        let charge = vm.flightEngine.state.boostCharge
        vm.updateRingTrail(deltaTime: 2.2, position: SCNVector3(0, 500, 0), heading: 0)
        let trail = try! XCTUnwrap(vm.ringTrail)
        XCTAssertNotNil(vm.ringTrailNode?.parent)
        let stars = vm.simStarsCollected
        // Fly the trail's line, 11 m per tick, through each centre.
        var pos = SIMD3<Float>(0, 500, 0)
        for gate in trail.gates {
            while pos.z > gate.center.z - 11 {
                let toward = gate.center - pos
                let flat = simd_length(SIMD2(toward.x, toward.z))
                var stepV = SIMD3<Float>(toward.x, toward.y, toward.z) / max(flat, 0.001) * 11
                if flat < 11 { stepV = SIMD3(0, 0, -11) }
                pos += stepV
                vm.updateRingTrail(deltaTime: 0.2, position: SCNVector3(pos.x, pos.y, pos.z), heading: 0)
            }
        }
        XCTAssertEqual(vm.simStarsCollected, stars + RingTrail.completeStars)
        XCTAssertGreaterThan(vm.flightEngine.state.boostCharge, charge + 0.4)
        // Fly on: the trail clears and the next one is scheduled.
        for _ in 0..<10 {
            pos.z -= 11
            vm.updateRingTrail(deltaTime: 0.2, position: SCNVector3(pos.x, pos.y, pos.z), heading: 0)
        }
        XCTAssertNil(vm.ringTrail)
        XCTAssertLessThan(vm.ringTrailScheduler!.nextTime, .greatestFiniteMagnitude)
    }
}
