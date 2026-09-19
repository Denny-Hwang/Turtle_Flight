import XCTest
@testable import TurtleFlight

/// Phase 4: character mastery, iCloud progress merge rules, audio asset
/// hook, and the progress-blob additions.
final class Phase4PolishTests: XCTestCase {

    // MARK: - Mastery

    func testMasteryLevelsFollowThresholds() {
        XCTAssertEqual(CharacterMastery.level(for: 0), 1)
        XCTAssertEqual(CharacterMastery.level(for: 59), 1)
        XCTAssertEqual(CharacterMastery.level(for: 60), 2)
        XCTAssertEqual(CharacterMastery.level(for: 2600), 10)
        XCTAssertEqual(CharacterMastery.level(for: 99_999), CharacterMastery.maxLevel)
        XCTAssertEqual(CharacterMastery.thresholds.count, CharacterMastery.maxLevel)
        for i in 1..<CharacterMastery.thresholds.count {
            XCTAssertGreaterThan(CharacterMastery.thresholds[i], CharacterMastery.thresholds[i - 1])
        }
    }

    func testMasteryProgressWithinLevel() {
        let p = CharacterMastery.progress(for: 100)!     // level 2: 60…150
        XCTAssertEqual(p.into, 40)
        XCTAssertEqual(p.span, 90)
        XCTAssertNil(CharacterMastery.progress(for: 5000), "Max level has no next threshold")
    }

    func testMasteryTitlesCoverEveryLevel() {
        let keys = Set((1...CharacterMastery.maxLevel).map { CharacterMastery.titleKey(for: $0) })
        XCTAssertEqual(keys.count, 5)
    }

    func testProgressAccumulatesMasteryPerCharacterAndReportsLevelUps() {
        var progress = PlayerProgress.defaultProgress
        XCTAssertEqual(progress.masteryLevel(for: .penguin), 1)
        XCTAssertNil(progress.addMastery(.flightStarted, to: .penguin))                 // 10
        XCTAssertEqual(progress.addMastery(.courseCleared(clean: true), to: .penguin), 2) // 70 → Lv.2
        XCTAssertNil(progress.addMastery(.gatePassed(bullseye: true), to: .penguin))     // 75, still Lv.2
        XCTAssertEqual(progress.masteryXP(for: .penguin), 75)
        XCTAssertEqual(progress.masteryLevel(for: .penguin), 2)
        XCTAssertEqual(progress.masteryXP(for: .turtle), 0, "XP is per character")
    }

    func testMissionViewModelAttributesXPToTheFlownCharacter() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        vm.recordFlightStart(character: .cat)
        vm.recordGateXP(passes: 5, bullseyes: 2)
        XCTAssertEqual(vm.progress.masteryXP(for: .cat), 10 + 3 * 2 + 2 * 5)
        let result = StageResult(stageIndex: 0, stars: 3, completionTime: 125, collisions: 0,
                                 starsCollected: 0, ringsCompleted: 10, totalRings: 10, date: Date(),
                                 score: 1000, maxCombo: 10, bullseyes: 2)
        vm.completeMission(result: result)
        // + clean clear 60 + 2 minutes × 5
        XCTAssertEqual(vm.progress.masteryXP(for: .cat), 26 + 60 + 10)
        XCTAssertEqual(vm.lastMasteryLevelUp, 2)
    }

    // MARK: - Cloud sync merge rules

    private final class StubStore: KeyValueStoreLike {
        var storage: [String: Data] = [:]
        var synchronizeCount = 0
        func data(forKey key: String) -> Data? { storage[key] }
        func set(_ data: Data?, forKey key: String) { storage[key] = data }
        func synchronize() -> Bool { synchronizeCount += 1; return true }
    }

    private func progress(stars: Int, bonus: Int = 0, time: TimeInterval = 0) -> PlayerProgress {
        var p = PlayerProgress.defaultProgress
        for i in 0..<min(stars / 3, 5) {
            p.updateStageResult(StageResult(stageIndex: i, stars: 3, completionTime: 30, collisions: 0,
                                            starsCollected: 0, ringsCompleted: 1, totalRings: 1, date: Date()))
        }
        p.bonusStars = bonus
        p.totalFlightTime = time
        return p
    }

    func testIsAheadOrdering() {
        XCTAssertTrue(CloudSync.isAhead(progress(stars: 6), of: progress(stars: 3)))
        XCTAssertFalse(CloudSync.isAhead(progress(stars: 3), of: progress(stars: 6)))
        XCTAssertTrue(CloudSync.isAhead(progress(stars: 3, bonus: 5), of: progress(stars: 3, bonus: 0)))
        XCTAssertTrue(CloudSync.isAhead(progress(stars: 3, time: 100), of: progress(stars: 3, time: 10)))
        XCTAssertFalse(CloudSync.isAhead(progress(stars: 3), of: progress(stars: 3)), "Equal is not ahead")
    }

    func testPushWritesUnlessRemoteIsAhead() {
        let store = StubStore()
        let sync = CloudSync(store: store)
        sync.push(progress(stars: 3))
        XCTAssertNotNil(store.storage[CloudSync.progressKey])
        XCTAssertEqual(sync.remoteProgress()?.totalStars, 3)

        sync.push(progress(stars: 0))          // behind → must not clobber
        XCTAssertEqual(sync.remoteProgress()?.totalStars, 3)

        sync.push(progress(stars: 9))          // ahead → replaces
        XCTAssertEqual(sync.remoteProgress()?.totalStars, 9)
    }

    func testPullAcceptsOnlyAheadRemote() {
        let store = StubStore()
        let sync = CloudSync(store: store)
        var accepted: PlayerProgress?
        sync.onRemoteProgress = { accepted = $0 }

        XCTAssertEqual(sync.pull(local: progress(stars: 3)).totalStars, 3, "No remote → local")

        sync.push(progress(stars: 9))
        let merged = sync.pull(local: progress(stars: 3))
        XCTAssertEqual(merged.totalStars, 9)
        XCTAssertEqual(accepted?.totalStars, 9)

        accepted = nil
        let kept = sync.pull(local: progress(stars: 12))
        XCTAssertEqual(kept.totalStars, 12, "Local ahead → keep local")
        XCTAssertNil(accepted)
    }

    func testMissionViewModelAcceptsRemoteWithoutPushingBack() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        vm.acceptRemoteProgress(progress(stars: 6, bonus: 4))
        XCTAssertEqual(vm.progress.totalStars, 6)
        XCTAssertEqual(vm.progress.bonusStars, 4)
    }

    // MARK: - Progress blob

    func testPhase4FieldsDefaultAndDecodeFromOlderBlob() throws {
        let legacy = try JSONEncoder().encode(PlayerProgress.defaultProgress)
        var dict = try JSONSerialization.jsonObject(with: legacy) as! [String: Any]
        for key in ["cloudSyncEnabled", "clipRecordingEnabled", "masteryXP"] {
            dict.removeValue(forKey: key)
        }
        let old = try JSONDecoder().decode(PlayerProgress.self,
                                           from: try JSONSerialization.data(withJSONObject: dict))
        XCTAssertFalse(old.cloudSyncEnabled)
        XCTAssertFalse(old.clipRecordingEnabled)
        XCTAssertTrue(old.masteryXP.isEmpty)

        var p = PlayerProgress.defaultProgress
        p.addMastery(.flightStarted, to: .bunny)
        p.clipRecordingEnabled = true
        let back = try JSONDecoder().decode(PlayerProgress.self, from: try JSONEncoder().encode(p))
        XCTAssertEqual(back.masteryXP(for: .bunny), 10)
        XCTAssertTrue(back.clipRecordingEnabled)
    }

    // MARK: - Audio asset hook

    func testAssetLookupReturnsNilWhenNothingIsBundled() {
        XCTAssertNil(AudioManager.assetURL(named: "bgm_sky"))
        XCTAssertNil(AudioManager.assetURL(named: "definitely-not-a-sound"))
    }

    func testAssetLookupFindsAFileInAnyAcceptedExtension() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data([0, 1, 2]).write(to: dir.appendingPathComponent("bgm_ocean.caf"))
        let bundle = Bundle(url: dir)!
        XCTAssertNotNil(AudioManager.assetURL(named: "bgm_ocean", bundle: bundle))
        XCTAssertNil(AudioManager.assetURL(named: "bgm_sky", bundle: bundle))
    }

    func testSynthBGMIsLoopLengthAndNonSilent() {
        let data = SynthAudio.generateBGM(theme: "sky", durationSeconds: 2)
        // 44-byte WAV header + 22050 Hz × 2 s × 2 bytes.
        XCTAssertEqual(data.count, 44 + 22050 * 2 * 2)
        let body = data.dropFirst(44)
        let nonZero = body.contains { $0 != 0 }
        XCTAssertTrue(nonZero)
        // Different themes are different signals.
        let space = SynthAudio.generateBGM(theme: "space", durationSeconds: 2)
        XCTAssertNotEqual(data, space)
    }
}
