import XCTest
import SceneKit
@testable import TurtleFlight

/// Worlds, landmarks, postcards, specialties and sky moods.
final class WorldTourTests: XCTestCase {

    // MARK: - Worlds

    func testEveryWorldHasAProfileAndLocalizedNames() {
        for world in MapTheme.allCases {
            let profile = WorldProfile.profile(for: world)
            XCTAssertGreaterThanOrEqual(profile.landmarks.count, 3, "\(world) needs landmarks")
            XCTAssertFalse(profile.ramp.isEmpty)
            XCTAssertEqual(profile.ramp.map(\.below), profile.ramp.map(\.below).sorted(), "\(world) ramp must ascend")
            XCTAssertFalse(world.displayName.hasPrefix("theme."), "missing name for \(world)")
            XCTAssertFalse(world.subtitle.hasPrefix("theme."), "missing subtitle for \(world)")
            XCTAssertFalse(world.regionNames.isEmpty)
        }
    }

    func testOriginalWorldsKeepTheirTerrainShape() {
        // The 1.0 worlds must not move under existing courses and ghosts.
        for world in [MapTheme.sky, .space, .ocean] {
            let p = WorldProfile.profile(for: world)
            XCTAssertEqual(p.noiseScale, 0.005)
            XCTAssertEqual(p.height(fromNoise: 0.5), 0.5 * Constants.Terrain.maxHeight)
            XCTAssertEqual(p.height(fromNoise: -0.25), -0.25 * Constants.Terrain.maxHeight)
        }
    }

    func testDesertHasNoWaterAndCityIsFlat() {
        let desert = WorldProfile.profile(for: .desert)
        XCTAssertGreaterThan(desert.height(fromNoise: -0.8), 0)
        XCTAssertGreaterThan(desert.height(fromNoise: 0), 0)
        let city = WorldProfile.profile(for: .city)
        XCTAssertLessThan(city.height(fromNoise: 1), 40, "city plain stays low")
        XCTAssertLessThan(city.height(fromNoise: -0.5), 0, "…with a river below zero")
    }

    // MARK: - Landmarks

    func testEveryLandmarkBelongsToExactlyOneWorld() {
        var seen: [LandmarkKind: MapTheme] = [:]
        for world in MapTheme.allCases {
            for kind in LandmarkKind.kinds(in: world) {
                XCTAssertNil(seen[kind], "\(kind) listed twice")
                XCTAssertEqual(kind.world, world)
                seen[kind] = world
            }
        }
        XCTAssertEqual(Set(seen.keys), Set(LandmarkKind.allCases))
    }

    func testEveryLandmarkHasANameAndBuilds() {
        for kind in LandmarkKind.allCases {
            XCTAssertFalse(kind.displayName.hasPrefix("landmark."), "missing name for \(kind)")
            XCTAssertNotNil(UIImage(systemName: kind.symbol), "bad SF Symbol for \(kind)")
            let node = LandmarkFactory.build(kind)
            // The static part is flattened into one geometry (whose
            // sources SceneKit fills in lazily), so just check it exists.
            var geometries = 0
            node.enumerateHierarchy { child, _ in if child.geometry != nil { geometries += 1 } }
            XCTAssertGreaterThan(geometries, 0, "\(kind) built nothing")
        }
    }

    func testPlacementIsDeterministicAndSpawnCellIsEmpty() {
        let kinds = LandmarkKind.kinds(in: .desert)
        let flat: (Float, Float) -> Float = { _, _ in 12 }
        XCTAssertNil(LandmarkField.placement(cell: SIMD2(0, 0), kinds: kinds, seed: 42, heightAt: flat))
        let a = LandmarkField.placement(cell: SIMD2(1, -2), kinds: kinds, seed: 42, heightAt: flat)
        let b = LandmarkField.placement(cell: SIMD2(1, -2), kinds: kinds, seed: 42, heightAt: flat)
        XCTAssertNotNil(a)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a?.position.x, b?.position.x)
        XCTAssertEqual(a?.position.y, 12)
        // Stays inside its own cell.
        let cell = LandmarkField.cell(for: a!.position)
        XCTAssertEqual(cell, SIMD2<Int32>(1, -2))
    }

    func testNeighbouringCellsHoldDifferentLandmarks() {
        let flat: (Float, Float) -> Float = { _, _ in 0 }
        for world in MapTheme.allCases {
            let kinds = LandmarkKind.kinds(in: world)
            let here = LandmarkField.placement(cell: SIMD2(3, 3), kinds: kinds, seed: 42, heightAt: flat)?.kind
            let east = LandmarkField.placement(cell: SIMD2(4, 3), kinds: kinds, seed: 42, heightAt: flat)?.kind
            let south = LandmarkField.placement(cell: SIMD2(3, 4), kinds: kinds, seed: 42, heightAt: flat)?.kind
            XCTAssertNotEqual(here, east, "\(world)")
            XCTAssertNotEqual(here, south, "\(world)")
        }
    }

    func testFieldLoadsNearbyLandmarksAndFindsTheNearest() {
        let scene = SCNScene()
        let field = LandmarkField(parentNode: scene.rootNode, world: .seoul, seed: 42) { _, _ in 0 }
        field.update(playerPosition: SCNVector3(0, 500, 0))
        XCTAssertEqual(field.placements.count, 8, "3×3 cells minus the empty spawn cell")
        let nearest = field.nearest(to: SCNVector3(0, 500, 0))
        XCTAssertNotNil(nearest)
        let everything = Set(field.placements.map(\.kind))
        XCTAssertNil(field.nearest(to: SCNVector3(0, 500, 0), excluding: everything))
        field.clear()
        XCTAssertTrue(field.placements.isEmpty)
    }

    func testLandmarkHintPointsTheRightWay() {
        let origin = SCNVector3(0, 0, 0)
        // Heading 0 = north (−Z). A landmark due east is 90° to the right.
        let east = FlightViewModel.LandmarkHint.make(kind: .greatPyramids, from: origin, heading: 0,
                                                     to: SCNVector3(500, 0, 0))
        XCTAssertEqual(east.bearing, .pi / 2, accuracy: 0.01)
        XCTAssertEqual(east.distance, 500)
        let ahead = FlightViewModel.LandmarkHint.make(kind: .greatPyramids, from: origin, heading: 90,
                                                      to: SCNVector3(500, 0, 0))
        XCTAssertEqual(ahead.bearing, 0, accuracy: 0.01)
    }

    // MARK: - Postcards

    func testAlbumStampsPerCharacterAndCountsPostcardsOnce() {
        let suite = "WorldTourTests.album"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let album = PostcardAlbum(defaults: defaults)
        XCTAssertEqual(album.recordVisit(.hilltopTower, by: .turtle), .newPostcard)
        XCTAssertEqual(album.recordVisit(.hilltopTower, by: .turtle), .alreadyStamped)
        XCTAssertEqual(album.recordVisit(.hilltopTower, by: .cat), .newStamp)
        XCTAssertEqual(album.postcardCount, 1)
        XCTAssertEqual(album.postcardCount(in: .seoul), 1)
        XCTAssertEqual(album.visitors(of: .hilltopTower), [.turtle, .cat])
        // Survives a relaunch.
        XCTAssertTrue(PostcardAlbum(defaults: defaults).hasStamp(.hilltopTower, by: .cat))
        album.reset()
        XCTAssertEqual(PostcardAlbum(defaults: defaults).postcardCount, 0)
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - Specialties

    func testEveryCharacterHasADistinctSpecialty() {
        let all = CharacterType.allCases.map(\.specialty)
        for (i, a) in all.enumerated() {
            XCTAssertNotEqual(a, .neutral, "\(CharacterType.allCases[i]) has no specialty")
            for b in all[(i + 1)...] { XCTAssertNotEqual(a, b) }
        }
        for character in CharacterType.allCases {
            XCTAssertFalse(character.specialtyText.hasPrefix("specialty."))
        }
    }

    func testSpecialtyChangesBoostLengthAndBullseyeRefund() {
        let engine = FlightEngine()
        engine.specialty = CharacterType.turtle.specialty
        engine.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: true, shouldAutoLevel: false)
        XCTAssertEqual(engine.state.boostTimeRemaining,
                       Float(Constants.Flight.boostDuration) * 1.5, accuracy: 0.05)

        let bunny = FlightEngine()
        bunny.specialty = CharacterType.bunny.specialty
        bunny.update(deltaTime: 0.016, rollInput: 0, pitchInput: 0, isBoosting: true, shouldAutoLevel: false)
        // No refund while the boost is still burning…
        bunny.addBoostCharge(bunny.specialty.bullseyeCharge)
        XCTAssertEqual(bunny.state.boostCharge, 0, accuracy: 0.001)
    }

    // MARK: - Sky mood

    func testSkyMoodIsDeterministicAndCoversEveryMood() {
        XCTAssertEqual(SkyMood.pick(seed: 1234), SkyMood.pick(seed: 1234))
        let picks = Set((0..<400).map { SkyMood.pick(seed: $0) })
        XCTAssertEqual(picks, Set(SkyMood.allCases))
        XCTAssertEqual(SkyMood.allCases.map(\.weight).reduce(0, +), 100)
    }

    func testSpaceAndOceanKeepTheirOwnSky() {
        for n in 0..<50 {
            XCTAssertEqual(SkyMood.forFlight(number: n, world: .space), .day)
            XCTAssertEqual(SkyMood.forFlight(number: n, world: .ocean), .day)
        }
        XCTAssertEqual(SkyMood.day.skyColor(base: .red), .red)
    }
}
