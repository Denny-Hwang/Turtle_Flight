import XCTest
import SceneKit
@testable import TurtleFlight

/// Sky-dex (W5) and companion flocks (W4), docs/FLIGHT_FUN_PLAN.md §4.
final class SkyDexCompanionTests: XCTestCase {

    private func freshLog() -> SetPieceLog {
        let defaults = UserDefaults(suiteName: "SkyDexTests-\(UUID().uuidString)")!
        return SetPieceLog(defaults: defaults)
    }

    // MARK: - Sky-dex rewards

    func testAWorldsThreePiecesPayOnce() {
        let log = freshLog()
        XCTAssertTrue(SetPieceReward.reached(log: log).isEmpty)
        for piece in SetPiece.pieces(for: .sky).prefix(2) { log.record(piece) }
        XCTAssertTrue(SetPieceReward.reached(log: log).isEmpty, "two of three is not yet")
        log.record(SetPiece.pieces(for: .sky)[2])
        XCTAssertEqual(SetPieceReward.reached(log: log),
                       [SetPieceReward(id: "setpiece.sky", stars: SetPieceReward.worldStars)])
        XCTAssertTrue(SetPieceReward.due(log: log, claimed: ["setpiece.sky"]).isEmpty)
    }

    func testAllTwentyOnePayTheBigReward() {
        let log = freshLog()
        SetPiece.allCases.forEach { log.record($0) }
        let reached = SetPieceReward.reached(log: log)
        XCTAssertEqual(reached.count, MapTheme.allCases.count + 1)
        XCTAssertEqual(reached.last, SetPieceReward(id: "setpiece.all", stars: SetPieceReward.allStars))
    }

    func testMissionViewModelCreditsDexRewardsOnce() {
        let vm = MissionViewModel()
        let log = freshLog()
        SetPiece.pieces(for: .ocean).forEach { log.record($0) }
        let before = vm.progress.starBalance
        let claimedBefore = vm.progress.claimedPostcardRewards
        defer { vm.progress.claimedPostcardRewards = claimedBefore }
        vm.progress.claimedPostcardRewards.remove("setpiece.ocean")
        let paid = vm.claimSetPieceRewards(log: log)
        XCTAssertEqual(paid.map(\.id), ["setpiece.ocean"])
        XCTAssertEqual(vm.progress.starBalance, before + SetPieceReward.worldStars)
        XCTAssertTrue(vm.claimSetPieceRewards(log: log).isEmpty, "paid once")
    }

    // MARK: - Companions

    func testEveryWorldHasAFlock() {
        for world in MapTheme.allCases {
            let companion = Companion.of(world)
            XCTAssertFalse(companion.formation.isEmpty)
            XCTAssertNotEqual(companion.displayName, "companion.\(companion.rawValue).name")
            XCTAssertEqual(CompanionFactory.build(companion).childNodes.count, companion.formation.count)
        }
        XCTAssertEqual(Set(MapTheme.allCases.map(Companion.of)).count, Companion.allCases.count)
    }

    func testSchedulerRhythm() {
        var s = CompanionScheduler(seed: 4)
        XCTAssertTrue(Companion.firstDelay.contains(s.nextTime))
        let first = s.nextTime
        let side = s.take(at: first)
        XCTAssertTrue(side == 1 || side == -1)
        XCTAssertTrue(Companion.interval.contains(s.nextTime - first))
        XCTAssertEqual(CompanionScheduler(seed: 4, forcedSoon: true).nextTime, 2)
    }

    /// Character flying north at 55 m/s from (0, 500, 0).
    private func fly(_ flight: inout CompanionFlight, seconds: Float, from z0: Float = 0,
                     offset: SIMD3<Float> = .zero) -> (greeted: Int, end: SIMD3<Float>) {
        var greeted = 0
        var z = z0
        var p = SIMD3<Float>(0, 500, z)
        for _ in 0..<Int(seconds * 60) {
            z -= 55.0 / 60
            p = SIMD3(0, 500, z) + offset
            if flight.step(deltaTime: 1.0 / 60, characterPosition: p, heading: 0, speedMetresPerSecond: 55) { greeted += 1 }
        }
        return (greeted, p)
    }

    func testFlockComesInFromAheadAndSettlesBeside() {
        var flight = CompanionFlight(companion: .geese, side: 1, characterPosition: SIMD3(0, 500, 0), heading: 0)
        XCTAssertLessThan(flight.position.z, -100, "starts well ahead")
        XCTAssertEqual(flight.opacity, 0)
        let (_, p) = fly(&flight, seconds: Companion.approachTime + 2)
        XCTAssertEqual(flight.phase, .cruise)
        let slot = flight.slot(characterPosition: p, heading: 0)
        XCTAssertLessThan(simd_distance(flight.position, slot), 8, "keeps pace in its slot")
        XCTAssertGreaterThan(flight.position.x, 0, "on the chosen side")
        XCTAssertEqual(flight.opacity, 1)
    }

    func testFlyingInClosePaysOnceThenTheFlockLeaves() {
        var flight = CompanionFlight(companion: .pigeons, side: -1, characterPosition: SIMD3(0, 500, 0), heading: 0)
        _ = fly(&flight, seconds: Companion.approachTime + 1)
        // Drift over toward the flock's side for a few seconds.
        let near = fly(&flight, seconds: 4, from: -55 * (Companion.approachTime + 1),
                       offset: SIMD3(-Companion.slotSide + 6, Companion.slotUp, 0))
        XCTAssertEqual(near.greeted, 1)
        _ = fly(&flight, seconds: Companion.cruiseTime + Companion.leaveTime)
        XCTAssertEqual(flight.phase, .done)
        XCTAssertEqual(flight.opacity, 0)
    }

    func testStayingAwayPaysNothing() {
        var flight = CompanionFlight(companion: .eagles, side: 1, characterPosition: SIMD3(0, 500, 0), heading: 0)
        let run = fly(&flight, seconds: Companion.approachTime + Companion.cruiseTime + Companion.leaveTime + 0.5)
        XCTAssertEqual(run.greeted, 0, "the slot is \(Companion.slotSide) m away, outside the greet radius")
        XCTAssertEqual(flight.phase, .done)
    }

    func testFlockInFlightAddsAndRemovesItsNode() {
        let vm = FlightViewModel()
        let scene = SCNScene()
        UserDefaults.standard.set(true, forKey: "TFCompanion")
        defer { UserDefaults.standard.removeObject(forKey: "TFCompanion") }
        vm.setUpFreeFlightExtras(scene: scene, theme: .city, mood: .day, festival: false,
                                 wonderSeed: 9, around: SCNVector3(0, 500, 0))
        var z: Float = 0
        for _ in 0..<(60 * 3) {
            z -= 55.0 / 60
            vm.updateCompanions(deltaTime: 1.0 / 60, position: SCNVector3(0, 500, z), heading: 0, speed: 55)
        }
        XCTAssertNotNil(vm.companionFlight)
        XCTAssertEqual(vm.companionNode?.name, "companion_pigeons")
        XCTAssertNotNil(vm.companionNode?.parent)
        let total = Companion.approachTime + Companion.cruiseTime + Companion.leaveTime
        for _ in 0..<Int(total * 60) {
            z -= 55.0 / 60
            vm.updateCompanions(deltaTime: 1.0 / 60, position: SCNVector3(0, 500, z), heading: 0, speed: 55)
        }
        XCTAssertNil(vm.companionFlight)
        XCTAssertNil(vm.companionNode)
        vm.tearDownFreeFlightExtras()
        XCTAssertNil(vm.companionScheduler)
    }
}
