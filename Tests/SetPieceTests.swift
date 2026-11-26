import XCTest
import SceneKit
@testable import TurtleFlight

/// Set pieces along the route (docs/FLIGHT_FUN_PLAN.md §4, owner 2026-11-26).
final class SetPieceTests: XCTestCase {

    private var savedLog: Any?

    override func setUp() {
        super.setUp()
        savedLog = UserDefaults.standard.object(forKey: "setpieces.v1")
        SetPieceLog.shared.reset()
    }

    override func tearDown() {
        SetPieceLog.shared.reset()
        if let savedLog { UserDefaults.standard.set(savedLog, forKey: "setpieces.v1") }
        super.tearDown()
    }

    // MARK: - Catalogue

    func testEveryWorldHasTwoFlyThroughsAndOneTouchPiece() {
        XCTAssertEqual(SetPiece.allCases.count, 21)
        for world in MapTheme.allCases {
            let pieces = SetPiece.pieces(for: world)
            XCTAssertEqual(pieces.count, 3, "\(world)")
            XCTAssertEqual(pieces.filter { $0.effect == .passThrough }.count, 2, "\(world)")
        }
    }

    func testEveryPieceHasAName() {
        for piece in SetPiece.allCases {
            XCTAssertNotEqual(piece.displayName, "setpiece.\(piece.rawValue).name", "\(piece) missing string")
        }
    }

    func testEveryPieceBuildsWithinASaneFootprint() {
        for piece in SetPiece.allCases {
            let node = SetPieceFactory.build(piece)
            let footprint = SetPieceFactory.footprint(of: node)
            XCTAssertGreaterThanOrEqual(footprint, 20, "\(piece) too small to notice (the comet is mostly particle tail)")
            XCTAssertLessThan(footprint, 300, "\(piece) too big")
            let still = try! XCTUnwrap(node.childNode(withName: "still", recursively: false))
            XCTAssertLessThanOrEqual(still.childNodes.count, 14, "\(piece): static parts baked into a few meshes")
        }
    }

    func testRingsStandUpFacingThePlayer() {
        // With `flattenedClone` these rings lost their rotation and lay
        // flat (simulator, 2026-11-26); now they are baked / kept upright.
        for piece in [SetPiece.coralGate, .ringedPlanet] {
            let still = try! XCTUnwrap(SetPieceFactory.build(piece).childNode(withName: "still", recursively: false))
            let (lo, hi) = SetPieceFactory.extent(of: still)
            XCTAssertGreaterThan(hi.y - lo.y, 0.8 * (hi.x - lo.x) * (piece == .ringedPlanet ? 0.9 : 1), "\(piece) lies flat")
            XCTAssertLessThan(hi.z - lo.z, 0.5 * (hi.y - lo.y), "\(piece) is not edge-on")
        }
    }

    // MARK: - Rhythm

    func testFirstPieceComesSoonThenEvery25To35Seconds() {
        var s = SetPieceScheduler(world: .sky, seed: 42)
        XCTAssertTrue(SetPieceScheduler.firstDelay.contains(s.nextTime))
        var clock = s.nextTime
        var seen: [SetPiece] = []
        for _ in 0..<12 {
            XCTAssertTrue(s.isDue(at: clock))
            let next = s.take(at: clock)
            XCTAssertTrue(SetPieceScheduler.spawnDistance.contains(next.distance))
            XCTAssertLessThanOrEqual(abs(next.lateral), SetPieceScheduler.lateralJitter)
            let gap = s.nextTime - clock
            XCTAssertTrue(SetPieceScheduler.interval.contains(gap), "gap \(gap)")
            seen.append(next.piece)
            clock = s.nextTime
        }
        XCTAssertEqual(Set(seen.prefix(3)), Set(SetPiece.pieces(for: .sky)), "each cycle shows all three")
        for i in 1..<seen.count { XCTAssertNotEqual(seen[i], seen[i - 1], "never twice in a row") }
        XCTAssertTrue(seen.allSatisfy { $0.world == .sky })
    }

    func testForcedPieceComesFirstAtThreeSeconds() {
        var s = SetPieceScheduler(world: .ocean, seed: 1, forced: .coralGate)
        XCTAssertEqual(s.nextTime, 3)
        XCTAssertEqual(s.take(at: 3).piece, .coralGate)
    }

    func testPostponeRetriesSoon() {
        var s = SetPieceScheduler(world: .sky, seed: 3)
        s.postpone(from: 20)
        XCTAssertEqual(s.nextTime, 20 + SetPieceScheduler.retryDelay)
    }

    // MARK: - Geometry

    private func active(_ piece: SetPiece) -> ActiveSetPiece {
        ActiveSetPiece(piece: piece, node: SCNNode(), center: SCNVector3(0, 500, -300), forward: SIMD2(0, -1))
    }

    func testFlyingThroughTheOpeningCounts() {
        let a = active(.rainbowArch)
        XCTAssertTrue(a.passes(from: SCNVector3(10, 510, -290), to: SCNVector3(10, 510, -310)))
        XCTAssertFalse(a.passes(from: SCNVector3(90, 500, -290), to: SCNVector3(90, 500, -310)), "wide of it")
        XCTAssertFalse(a.passes(from: SCNVector3(0, 500, -310), to: SCNVector3(0, 500, -290)), "backwards")
    }

    func testLiftIsATallColumn() {
        let a = active(.thermal)
        XCTAssertTrue(a.contains(SCNVector3(20, 650, -300)))
        XCTAssertTrue(a.contains(SCNVector3(0, 320, -300)))
        XCTAssertFalse(a.contains(SCNVector3(60, 500, -300)))
    }

    func testEngineLiftClimbsWithoutSlowingDown() {
        let lifted = FlightEngine(sensitivity: .normal)
        let plain = FlightEngine(sensitivity: .normal)
        lifted.externalLift = SetPiece.liftRate
        for _ in 0..<60 {
            lifted.update(deltaTime: 1.0 / 60, rollInput: 0, pitchInput: 0, isBoosting: false, shouldAutoLevel: false)
            plain.update(deltaTime: 1.0 / 60, rollInput: 0, pitchInput: 0, isBoosting: false, shouldAutoLevel: false)
        }
        XCTAssertEqual(lifted.state.altitude - plain.state.altitude, SetPiece.liftRate, accuracy: 0.5)
        XCTAssertEqual(lifted.state.speed, plain.state.speed, accuracy: 0.001)
    }

    // MARK: - In flight

    /// Free Flight with `piece` forced at 3 s; returns the VM after it
    /// spawned, with the character at (0, 500, 0) heading north.
    private func flight(with piece: SetPiece, world: MapTheme) -> FlightViewModel {
        let vm = FlightViewModel()
        let scene = SCNScene()
        UserDefaults.standard.set(piece.rawValue, forKey: "TFSetPiece")
        defer { UserDefaults.standard.removeObject(forKey: "TFSetPiece") }
        vm.setUpFreeFlightExtras(scene: scene, theme: world, mood: .day, festival: false,
                                 wonderSeed: 1, around: SCNVector3(0, 500, 0))
        vm.updateSetPieces(deltaTime: 3.2, position: SCNVector3(0, 500, 0), heading: 0)
        return vm
    }

    private func fly(_ vm: FlightViewModel, from z0: Float, to z1: Float, y: Float = 500) {
        var z = z0
        while z > z1 {
            z -= 11
            vm.updateSetPieces(deltaTime: 0.2, position: SCNVector3(0, y, z), heading: 0)
        }
    }

    func testPieceSpawnsAheadAtTheCharactersHeight() {
        let vm = flight(with: .cloudTunnel, world: .sky)
        let spawned = try! XCTUnwrap(vm.activeSetPieces.first)
        XCTAssertEqual(spawned.piece, .cloudTunnel)
        XCTAssertEqual(spawned.center.x, 0, accuracy: 0.01)
        XCTAssertTrue(SetPieceScheduler.spawnDistance.contains(-spawned.center.z))
        XCTAssertEqual(spawned.center.y, 500, accuracy: 0.01)
        XCTAssertNotNil(spawned.node.parent)
    }

    func testFlyThroughPaysAStarOnce() {
        let vm = flight(with: .rainbowArch, world: .sky)
        let before = vm.simStarsCollected
        fly(vm, from: 0, to: -700)
        XCTAssertEqual(vm.simStarsCollected, before + SetPiece.passStars)
        XCTAssertTrue(SetPieceLog.shared.hasSeen(.rainbowArch))
    }

    func testStarBundleAndBoostRefill() {
        let oasis = flight(with: .mirageOasis, world: .desert)
        fly(oasis, from: 0, to: -700)
        XCTAssertEqual(oasis.simStarsCollected, SetPiece.bundleStars)

        let comet = flight(with: .cometTail, world: .space)
        XCTAssertEqual(comet.flightEngine.state.boostCharge, 1, "starts full")
        // Spend the gauge on a boost, let it end, then fly into the comet.
        comet.flightEngine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: true, shouldAutoLevel: false)
        for _ in 0..<200 {
            comet.flightEngine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: false, shouldAutoLevel: false)
        }
        let drained = comet.flightEngine.state.boostCharge
        fly(comet, from: 0, to: -700)
        XCTAssertGreaterThan(comet.flightEngine.state.boostCharge, drained + 0.4)
    }

    func testUpdraftLiftsOnlyInsideTheColumn() {
        let vm = flight(with: .thermal, world: .sky)
        let center = vm.activeSetPieces[0].center
        vm.updateSetPieces(deltaTime: 0.2, position: SCNVector3(0, 500, center.z + 5), heading: 0)
        XCTAssertEqual(vm.flightEngine.externalLift, SetPiece.liftRate)
        vm.updateSetPieces(deltaTime: 0.2, position: SCNVector3(0, 500, center.z - 80), heading: 0)
        XCTAssertEqual(vm.flightEngine.externalLift, 0)
    }

    func testLeftBehindPiecesAreCleared() {
        let vm = flight(with: .coralGate, world: .ocean)
        fly(vm, from: 0, to: -1200)
        XCTAssertTrue(vm.activeSetPieces.allSatisfy { $0.piece != .coralGate })
    }

    func testTearDownClearsEverything() {
        let vm = flight(with: .thermal, world: .sky)
        vm.flightEngine.externalLift = 30
        vm.tearDownFreeFlightExtras()
        XCTAssertTrue(vm.activeSetPieces.isEmpty)
        XCTAssertNil(vm.setPieceScheduler)
        XCTAssertEqual(vm.flightEngine.externalLift, 0)
    }
}
