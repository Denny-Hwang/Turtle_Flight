import XCTest
@testable import TurtleFlight

/// Pins the star-milestone trail tier system: threshold logic, Codable
/// migration of `PlayerProgress` against pre-tier saved blobs, and the
/// MissionViewModel auto-promotion path that fires on each stage clear.
final class TrailColorTierTests: XCTestCase {

    // MARK: - Tier thresholds

    func testTierUnlockThresholds() {
        // The four tiers come from the senior review (0/50/150/300★).
        // If a tier ever moves, the test surfaces it explicitly.
        XCTAssertEqual(TrailColorTier.vehicle.unlockStarThreshold, 0)
        XCTAssertEqual(TrailColorTier.magenta.unlockStarThreshold, 50)
        XCTAssertEqual(TrailColorTier.gold.unlockStarThreshold,    150)
        XCTAssertEqual(TrailColorTier.rainbow.unlockStarThreshold, 300)
    }

    func testHighestUnlockedAtBoundary() {
        XCTAssertEqual(TrailColorTier.highestUnlocked(totalStars: 0),   .vehicle)
        XCTAssertEqual(TrailColorTier.highestUnlocked(totalStars: 49),  .vehicle)
        XCTAssertEqual(TrailColorTier.highestUnlocked(totalStars: 50),  .magenta)
        XCTAssertEqual(TrailColorTier.highestUnlocked(totalStars: 149), .magenta)
        XCTAssertEqual(TrailColorTier.highestUnlocked(totalStars: 150), .gold)
        XCTAssertEqual(TrailColorTier.highestUnlocked(totalStars: 299), .gold)
        XCTAssertEqual(TrailColorTier.highestUnlocked(totalStars: 300), .rainbow)
        XCTAssertEqual(TrailColorTier.highestUnlocked(totalStars: 9999), .rainbow)
    }

    func testIsUnlocked() {
        XCTAssertTrue (TrailColorTier.vehicle.isUnlocked(totalStars: 0))
        XCTAssertFalse(TrailColorTier.magenta.isUnlocked(totalStars: 49))
        XCTAssertTrue (TrailColorTier.magenta.isUnlocked(totalStars: 50))
        XCTAssertFalse(TrailColorTier.rainbow.isUnlocked(totalStars: 299))
        XCTAssertTrue (TrailColorTier.rainbow.isUnlocked(totalStars: 300))
    }

    func testOverrideColorPresence() {
        // Vehicle and rainbow return nil; magenta and gold return an
        // explicit UIColor. Animator-driven tiers (rainbow) intentionally
        // skip the static override path.
        XCTAssertNil(TrailColorTier.vehicle.overrideColor)
        XCTAssertNotNil(TrailColorTier.magenta.overrideColor)
        XCTAssertNotNil(TrailColorTier.gold.overrideColor)
        XCTAssertNil(TrailColorTier.rainbow.overrideColor)
    }

    func testRainbowFlag() {
        XCTAssertTrue(TrailColorTier.rainbow.useRainbow)
        for tier in TrailColorTier.allCases where tier != .rainbow {
            XCTAssertFalse(tier.useRainbow, "\(tier) should not be rainbow")
        }
    }

    // MARK: - Codable on PlayerProgress (forwards)

    func testNewProgressEncodesAndDecodesAllFields() throws {
        var progress = PlayerProgress.defaultProgress
        progress.totalStars = 175
        progress.selectedTrailTier = .gold
        progress.lastSeenTrailTierThreshold = 150

        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: data)

        XCTAssertEqual(decoded.totalStars, 175)
        XCTAssertEqual(decoded.selectedTrailTier, .gold)
        XCTAssertEqual(decoded.lastSeenTrailTierThreshold, 150)
    }

    // MARK: - Codable migration (legacy v1 blobs)

    func testLegacyBlobWithoutTierFieldsDecodesToDefaults() throws {
        // A v1 PlayerProgress saved before this PR has no
        // `selectedTrailTier` or `lastSeenTrailTierThreshold` keys.
        // `init(from:)` must tolerate that and fall back to defaults.
        let legacyJSON = """
        {
          "stageResults": {},
          "totalStars": 12,
          "totalFlightTime": 345.6,
          "bestFreeFlightStars": 4,
          "selectedCharacter": "turtle",
          "selectedVehicle": "shellJet",
          "sensitivityLevel": "easy"
        }
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: data)

        XCTAssertEqual(decoded.totalStars, 12)
        XCTAssertEqual(decoded.selectedTrailTier, .vehicle,
            "Pre-tier saved blob should fall back to .vehicle (stock)")
        XCTAssertEqual(decoded.lastSeenTrailTierThreshold, 0)
    }

    // MARK: - MissionViewModel auto-promote on completeMission

    func testCompleteMissionPromotesTierWhenMilestoneCrossed() {
        // Seed 15 prior 3★ clears (45 stars total) — just shy of the
        // 50★ magenta gate. Note: `stageResults[i] = ...` does NOT
        // recalc `totalStars`; the next `updateStageResult` call (via
        // `completeMission`) is what runs the sum.
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        for i in 0..<15 {
            vm.progress.stageResults[i] = StageResult(stageIndex: i,
                stars: 3, completionTime: 60, collisions: 0,
                starsCollected: 0, ringsCompleted: 0, totalRings: 0,
                date: Date())
        }

        // Below-gate clear: 16th entry → 48 ★ total. No promotion.
        let belowGate = StageResult(stageIndex: 20, stars: 3, completionTime: 30,
                                     collisions: 0, starsCollected: 0,
                                     ringsCompleted: 0, totalRings: 0, date: Date())
        vm.completeMission(result: belowGate)
        XCTAssertEqual(vm.progress.totalStars, 48)
        XCTAssertEqual(vm.progress.selectedTrailTier, .vehicle,
            "48★ should still be stock — magenta gates at 50★")
        XCTAssertEqual(vm.progress.lastSeenTrailTierThreshold, 0)

        // Crossing clear: 17th entry → 51 ★ total. Promote to magenta.
        let crossesGate = StageResult(stageIndex: 21, stars: 3, completionTime: 30,
                                       collisions: 0, starsCollected: 0,
                                       ringsCompleted: 0, totalRings: 0, date: Date())
        vm.completeMission(result: crossesGate)
        XCTAssertEqual(vm.progress.totalStars, 51)
        XCTAssertEqual(vm.progress.selectedTrailTier, .magenta,
            "Crossing 50★ should auto-promote to .magenta")
        XCTAssertEqual(vm.progress.lastSeenTrailTierThreshold, 50)
    }

    func testCompleteMissionDoesNotPromoteIfAlreadySeen() {
        // Player previously crossed 50★, picked a tier in Settings, and
        // is now stacking more clears. The auto-promote must NOT keep
        // re-firing past the same threshold.
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        vm.progress.lastSeenTrailTierThreshold = 50
        vm.progress.selectedTrailTier = .vehicle  // user opted back to stock

        // Seed 60★ worth of past clears.
        for i in 0..<20 {
            vm.progress.stageResults[i] = StageResult(stageIndex: i,
                stars: 3, completionTime: 60, collisions: 0,
                starsCollected: 0, ringsCompleted: 0, totalRings: 0,
                date: Date())
        }
        let next = StageResult(stageIndex: 99, stars: 1, completionTime: 30,
                                collisions: 0, starsCollected: 0,
                                ringsCompleted: 0, totalRings: 0, date: Date())
        vm.completeMission(result: next)

        XCTAssertEqual(vm.progress.selectedTrailTier, .vehicle,
            "User's manual downgrade must not be overridden by auto-promote on an already-seen tier")
        XCTAssertEqual(vm.progress.lastSeenTrailTierThreshold, 50,
            "Threshold should stay at 50 — no new milestone was crossed")
    }

    // MARK: - MissionViewModel.setSelectedTrailTier guard

    func testSetSelectedTrailTierRejectsLockedTier() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        vm.progress.totalStars = 10   // far below any unlock

        vm.setSelectedTrailTier(.gold)

        XCTAssertEqual(vm.progress.selectedTrailTier, .vehicle,
            "setSelectedTrailTier should silently no-op when the tier is locked")
    }

    func testSetSelectedTrailTierAcceptsUnlockedTier() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        // Seed the totalStars directly (separate from stageResults).
        vm.progress.totalStars = 200

        vm.setSelectedTrailTier(.gold)

        XCTAssertEqual(vm.progress.selectedTrailTier, .gold)
    }

    // MARK: - load() clamps over-claimed tier

    func testLoadClampsTierToEarnedLevel() throws {
        // Simulate a Reset Progress that wiped stars but left the
        // previously-selected tier persisted at .gold. `load()` should
        // clamp the tier back down.
        let blob = """
        {
          "stageResults": {},
          "totalStars": 0,
          "totalFlightTime": 0,
          "bestFreeFlightStars": 0,
          "selectedCharacter": "turtle",
          "selectedVehicle": "shellJet",
          "sensitivityLevel": "easy",
          "selectedTrailTier": 150,
          "lastSeenTrailTierThreshold": 150
        }
        """
        let data = Data(blob.utf8)
        UserDefaults.standard.set(data, forKey: "playerProgress")
        defer { UserDefaults.standard.removeObject(forKey: "playerProgress") }

        let vm = MissionViewModel()
        vm.load()

        XCTAssertEqual(vm.progress.selectedTrailTier, .vehicle,
            "load() must clamp an over-claimed tier back to what's actually earned")
    }
}
