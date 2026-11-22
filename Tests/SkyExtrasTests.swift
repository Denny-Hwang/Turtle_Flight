import XCTest
import SceneKit
@testable import TurtleFlight

/// Landmark bumps, sky wonders, postcard milestones and the Festival.
final class SkyExtrasTests: XCTestCase {

    // MARK: - Landmark colliders

    func testSphereConeAndBoxPushOutTheNearestWay() {
        let sphere = LandmarkShape.sphere(0, 0, 0, r: 10)
        let s = sphere.contact(SIMD3(0, 12, 0), pad: 4)
        XCTAssertEqual(s?.normal, SIMD3(0, 1, 0))
        XCTAssertEqual(s?.depth ?? 0, 2, accuracy: 0.001)
        XCTAssertNil(sphere.contact(SIMD3(0, 20, 0), pad: 4))

        let tower = LandmarkShape.cylinder(0, 0, 0, r: 10, h: 100)
        // Side: pushed out sideways.
        let side = tower.contact(SIMD3(8, 50, 0), pad: 0)
        XCTAssertEqual(side?.normal, SIMD3(1, 0, 0))
        XCTAssertEqual(side?.depth ?? 0, 2, accuracy: 0.001)
        // Just below the roof: pushed up.
        let roof = tower.contact(SIMD3(0, 98, 0), pad: 0)
        XCTAssertEqual(roof?.normal, SIMD3(0, 1, 0))
        XCTAssertNil(tower.contact(SIMD3(0, 120, 0), pad: 4))

        // A cone is thinner near the top.
        let spike = LandmarkShape.cone(0, 0, 0, bottom: 50, top: 0, h: 100)
        XCTAssertNotNil(spike.contact(SIMD3(30, 10, 0), pad: 0))
        XCTAssertNil(spike.contact(SIMD3(30, 90, 0), pad: 0))

        let box = LandmarkShape.box(0, 0, 0, 10, 10, 50)
        let b = box.contact(SIMD3(0, 0, 48), pad: 0)
        XCTAssertEqual(b?.normal, SIMD3(0, 0, 1))
        XCTAssertEqual(b?.depth ?? 0, 2, accuracy: 0.001)
    }

    func testOpeningsThatLookFlyableAreFlyable() {
        let openings: [(LandmarkKind, SIMD3<Float>)] = [
            (.grandArch, SIMD3(0, 60, 0)),        // under the arch
            (.ironLaceTower, SIMD3(0, 40, 0)),    // between the legs
            (.canyonArch, SIMD3(0, 90, 0)),       // through the canyon arch
            (.skyWheel, SIMD3(0, 120, 30)),       // through the wheel
            (.riverBridge, SIMD3(0, 15, 0)),      // under the deck
            (.rainbowGate, SIMD3(0, 0, 0)),       // through the rainbow
            (.greatFalls, SIMD3(0, 80, 10))       // behind the water sheet
        ]
        for (kind, point) in openings {
            let blocked = kind.colliders.contains { $0.contact(point, pad: LandmarkField.playerPad) != nil }
            XCTAssertFalse(blocked, "\(kind) should be open at \(point)")
        }
    }

    func testEverySolidLandmarkCanStillBeDiscovered() {
        // Somewhere inside the discovery sphere must be open air, or the
        // postcard could never be collected.
        for kind in LandmarkKind.allCases {
            let focus = SIMD3<Float>(0, kind.focusHeight, 0)
            let r = LandmarkField.discoveryRadius * 0.9
            var open = false
            for i in 0..<64 where !open {
                let a = Float(i) * .pi / 8, b = Float(i % 8) * .pi / 8 - .pi / 2
                let p = focus + SIMD3(cos(a) * cos(b), sin(b), sin(a) * cos(b)) * r
                open = !kind.colliders.contains { $0.contact(p, pad: LandmarkField.playerPad) != nil }
            }
            XCTAssertTrue(open, "\(kind) discovery sphere is entirely solid")
        }
    }

    func testBumpTurnsTheCharacterAwayFromTheWall() {
        let engine = FlightEngine()
        // Heading north (-Z) into a wall whose outward normal faces +Z.
        engine.resolveContact(normal: SIMD3(0, 0, 1), depth: 5)
        XCTAssertEqual(engine.state.position.z, 5, accuracy: 0.001)
        XCTAssertEqual(engine.state.heading, 180, accuracy: 0.5)
        // Glancing contact keeps most of the heading.
        let glance = FlightEngine()
        glance.resolveContact(normal: SIMD3(-1, 0, 0), depth: 1)   // moving north, wall to the east
        XCTAssertEqual(glance.state.heading, 0, accuracy: 0.5)
        // Landing on a roof lifts the character and stops the sink.
        let roof = FlightEngine()
        roof.resolveContact(normal: SIMD3(0, 1, 0), depth: 3)
        XCTAssertEqual(roof.state.altitude, 503, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(roof.state.verticalSpeed, 0)
    }

    func testFreeFlightBumpsOffALoadedLandmark() {
        let vm = FlightViewModel()
        let scene = SCNScene()
        let flat: (Float, Float) -> Float = { _, _ in 0 }
        let field = LandmarkField(parentNode: scene.rootNode, world: .desert, seed: 42, heightAt: flat)
        let cell = SIMD2<Int32>(1, 0)
        guard let placement = LandmarkField.placement(cell: cell, kinds: LandmarkKind.kinds(in: .desert),
                                                      seed: 42, heightAt: flat),
              let shape = placement.kind.colliders.first else {
            return XCTFail("expected a solid landmark in cell \(cell)")
        }
        field.update(playerPosition: placement.position)
        vm.landmarkField = field
        // Put the character inside the first solid part.
        let inside: SIMD3<Float>
        switch shape {
        case let .sphere(c, _): inside = c
        case let .cone(base, _, _, h): inside = base + SIMD3(0, h * 0.3, 0)
        case let .box(c, _): inside = c
        }
        let start = SCNVector3(placement.position.x + inside.x, placement.position.y + inside.y,
                               placement.position.z + inside.z)
        XCTAssertNotNil(field.contact(at: start))
        #if DEBUG
        vm.flightEngine.debugSetPose(position: start, heading: 0)
        for _ in 0..<40 { vm.bumpOffLandmarks() }
        XCTAssertNil(field.contact(at: vm.flightEngine.state.position), "character should end up outside")
        #endif
        field.clear()
    }

    // MARK: - Sky wonders

    func testWonderPlanIsDeterministicRareAndFitsTheSky() {
        XCTAssertEqual(SkyWonder.plan(world: .sky, mood: .day, seed: 77),
                       SkyWonder.plan(world: .sky, mood: .day, seed: 77))
        var hits = 0
        for seed in 0..<2000 {
            guard let plan = SkyWonder.plan(world: .sky, mood: .day, seed: seed) else { continue }
            hits += 1
            XCTAssertTrue(plan.wonder.isPossible(in: .sky, mood: .day))
            XCTAssertTrue((35...110).contains(plan.startTime))
        }
        XCTAssertEqual(Double(hits) / 2000, Double(SkyWonder.chancePercent) / 100, accuracy: 0.05)
        for seed in 0..<300 {
            if let p = SkyWonder.plan(world: .ocean, mood: .day, seed: seed) { XCTAssertEqual(p.wonder, .glowTide) }
            if let p = SkyWonder.plan(world: .desert, mood: .night, seed: seed) { XCTAssertEqual(p.wonder, .meteorShower) }
            if let p = SkyWonder.plan(world: .space, mood: .day, seed: seed) { XCTAssertEqual(p.wonder, .meteorShower) }
        }
    }

    func testEveryWonderCanHappenSomewhereAndHasAName() {
        for wonder in SkyWonder.allCases {
            let somewhere = MapTheme.allCases.contains { world in
                SkyMood.allCases.contains { wonder.isPossible(in: world, mood: $0) }
            }
            XCTAssertTrue(somewhere, "\(wonder) can never appear")
            XCTAssertFalse(wonder.displayName.hasPrefix("wonder."), "missing name for \(wonder)")
            XCTAssertNotNil(UIImage(systemName: wonder.symbol))
            let node = WonderFactory.build(wonder)
            XCTAssertFalse(node.childNodes.isEmpty, "\(wonder) built nothing")
        }
    }

    func testWonderLogRemembersFirstSighting() {
        let suite = "SkyExtrasTests.wonders"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let log = WonderLog(defaults: defaults)
        XCTAssertTrue(log.record(.cloudWhale))
        XCTAssertFalse(log.record(.cloudWhale))
        XCTAssertEqual(WonderLog(defaults: defaults).seenCount, 1)
        log.reset()
        XCTAssertFalse(WonderLog(defaults: defaults).hasSeen(.cloudWhale))
        defaults.removePersistentDomain(forName: suite)
    }

    func testWonderAppearsInFreeFlightAndPaysOnce() {
        let vm = FlightViewModel()
        let scene = SCNScene()
        vm.setUpFreeFlightExtras(scene: scene, theme: .ocean, mood: .day, festival: true,
                                 wonderSeed: 1, around: SCNVector3(0, 500, 0))
        XCTAssertNotNil(vm.festivalLayer)
        vm.wonderPlan = SkyWonder.Plan(wonder: .glowTide, startTime: 0.5)
        let p = vm.flightEngine.state.position
        vm.updateWondersAndFestival(deltaTime: 1, position: p, heading: 0)
        guard let active = vm.activeWonder else { return XCTFail("wonder should be in the sky") }
        XCTAssertNotNil(active.node.parent)
        let anchor = WonderFactory.anchor(of: active.node)
        let before = vm.starsCollected
        vm.updateWondersAndFestival(deltaTime: 0.2, position: anchor, heading: 0)
        vm.updateWondersAndFestival(deltaTime: 0.2, position: anchor, heading: 0)
        XCTAssertTrue(vm.activeWonder?.bonusPaid == true)
        // Stars reach the HUD through the next frame; check the sim side
        // via the toast instead of the published mirror.
        if case .wonderBonus(_, let stars) = vm.flightToast?.kind {
            XCTAssertEqual(stars, SkyWonder.bonusStars)
        } else {
            XCTFail("expected a bonus toast, got \(String(describing: vm.flightToast))")
        }
        XCTAssertEqual(vm.starsCollected, before, "published count only moves on the next frame")
        // Missions drop it (and the festival).
        vm.startStage(StageDefinition.allStages[0])
        XCTAssertNil(vm.activeWonder)
        XCTAssertNil(vm.wonderPlan)
        XCTAssertNil(vm.festivalLayer)
        XCTAssertNil(scene.rootNode.childNode(withName: "festival", recursively: false))
    }

    // MARK: - Postcard milestones + Festival

    func testMilestoneThresholds() {
        XCTAssertEqual(PostcardMilestone.half.required(of: 4), 2)
        XCTAssertEqual(PostcardMilestone.half.required(of: 3), 2)
        XCTAssertEqual(PostcardMilestone.complete.required(of: 3), 3)
        XCTAssertEqual(PostcardRewards.crossed(world: .desert, found: 2), .half)
        XCTAssertEqual(PostcardRewards.crossed(world: .desert, found: 4), .complete)
        XCTAssertNil(PostcardRewards.crossed(world: .desert, found: 3))
        XCTAssertNil(PostcardRewards.crossed(world: .desert, found: 0))
    }

    func testMilestonesPayOnceAndUnlockTheFestival() {
        let suite = "SkyExtrasTests.album"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let album = PostcardAlbum(defaults: defaults)
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        let wallet = vm.progress.starBalance

        XCTAssertTrue(vm.claimPostcardRewards(album: album).isEmpty)
        let space = LandmarkKind.kinds(in: .space)
        album.recordVisit(space[0], by: .turtle)
        album.recordVisit(space[1], by: .cat)
        let half = vm.claimPostcardRewards(album: album)
        XCTAssertEqual(half, [PostcardReward(world: .space, milestone: .half)])
        XCTAssertEqual(vm.progress.starBalance, wallet + PostcardMilestone.half.stars)
        XCTAssertTrue(vm.claimPostcardRewards(album: album).isEmpty, "paid once")
        XCTAssertFalse(vm.progress.festivalEnabled(in: .space, album: album))

        for kind in space { album.recordVisit(kind, by: .bunny) }
        XCTAssertEqual(vm.claimPostcardRewards(album: album), [PostcardReward(world: .space, milestone: .complete)])
        XCTAssertTrue(vm.progress.festivalEnabled(in: .space, album: album))
        vm.progress.festivalOff.insert(MapTheme.space.rawValue)
        XCTAssertFalse(vm.progress.festivalEnabled(in: .space, album: album), "switch in the album")
        XCTAssertFalse(vm.progress.festivalEnabled(in: .sky, album: album))
        defaults.removePersistentDomain(forName: suite)
    }

    func testOldSavesDecodeAndCloudMergeKeepsClaims() throws {
        // A blob from before these fields existed.
        var old = PlayerProgress.defaultProgress
        let data = try JSONEncoder().encode(old)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "claimedPostcardRewards")
        json.removeValue(forKey: "festivalOff")
        let decoded = try JSONDecoder().decode(PlayerProgress.self,
                                               from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.claimedPostcardRewards.isEmpty)
        XCTAssertTrue(decoded.festivalOff.isEmpty)

        old.claimedPostcardRewards = ["sky.half"]
        old.festivalOff = ["sky"]
        var remote = PlayerProgress.defaultProgress
        remote.claimedPostcardRewards = ["ocean.complete"]
        let merged = CloudSync.merge(local: old, remote: remote)
        XCTAssertEqual(merged.claimedPostcardRewards, ["sky.half", "ocean.complete"])
        XCTAssertEqual(merged.festivalOff, ["sky"], "festival switch is a local preference")
    }

    func testFestivalLayerRecyclesLanternsAroundThePlayer() {
        let scene = SCNScene()
        let layer = FestivalLayer(parentNode: scene.rootNode, world: .seoul, around: SCNVector3(0, 300, 0))
        guard let root = scene.rootNode.childNode(withName: "festival", recursively: false) else {
            return XCTFail("festival root missing")
        }
        let lanterns = root.childNodes.filter { $0.name == "lantern" }
        XCTAssertEqual(lanterns.count, FestivalLayer.lanternCount)
        // Fly far east: every lantern follows within the span.
        let far = SCNVector3(5000, 300, 0)
        for _ in 0..<10 { layer.update(deltaTime: 0.2, playerPosition: far, heading: 90) }
        for lantern in lanterns {
            XCTAssertLessThanOrEqual(abs(lantern.position.x - far.x), FestivalLayer.span / 2 + 1)
        }
        layer.remove()
        XCTAssertNil(scene.rootNode.childNode(withName: "festival", recursively: false))
    }
}
