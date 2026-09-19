import XCTest
import SceneKit
import UserNotifications
@testable import TurtleFlight

/// Phase 3: Daily Run, Sky Run (endless), quests, ghosts, reminders and
/// the progress-blob additions that back them.
final class RetentionTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "RetentionTests.suite"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func date(_ ymd: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: ymd + " 12:00")!
    }

    // MARK: - Daily Run

    func testDailyRunIsIdenticalForTheSameDateAndDifferentAcrossDays() {
        let a = DailyRun.stage(for: date("2026-09-19"))
        let b = DailyRun.stage(for: date("2026-09-19"))
        let c = DailyRun.stage(for: date("2026-09-20"))
        XCTAssertEqual(a.course, b.course)
        XCTAssertEqual(a.ringRadius, b.ringRadius)
        XCTAssertNotEqual(a.course, c.course)
        XCTAssertEqual(a.index, DailyRun.stageIndex)
        XCTAssertTrue(a.isDailyRun)
        XCTAssertTrue(a.isSpecial)
        XCTAssertFalse(StageDefinition.allStages[0].isSpecial)
    }

    func testDailyRunGeneratesRingsInFrontOfSpawn() {
        let stage = DailyRun.stage(for: date("2026-09-19"))
        let rings = stage.generateRings()
        XCTAssertEqual(rings.count, DailyRun.ringCount)
        XCTAssertLessThan(rings[0].z, -100)
        for r in rings { XCTAssertGreaterThanOrEqual(r.y, CourseGenerator.minimumAltitude) }
    }

    func testDailyRunCompletesInEngine() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(DailyRun.stage(for: date("2026-09-19"))) { _, _ in 0 }
        engine.testPassAllRings()
        guard case .completed(let result) = engine.state else { return XCTFail("should complete") }
        XCTAssertEqual(result.stageIndex, DailyRun.stageIndex)
        XCTAssertEqual(result.ringsCompleted, DailyRun.ringCount)
    }

    // MARK: - Endless

    func testEndlessChunksAreDeterministicAndContinuous() {
        let first = EndlessCourse.chunk(seed: 42, startIndex: 0, previousEnd: nil)
        let again = EndlessCourse.chunk(seed: 42, startIndex: 0, previousEnd: nil)
        XCTAssertEqual(first, again)
        XCTAssertEqual(first.count, EndlessCourse.chunkSize)
        let second = EndlessCourse.chunk(seed: 42, startIndex: first.count, previousEnd: first.last!.position)
        XCTAssertLessThan(second[0].position.z, first.last!.position.z, "Next chunk continues forward")
        for i in 1..<first.count {
            XCTAssertLessThan(first[i].position.z, first[i - 1].position.z)
        }
    }

    func testEndlessDifficultyRamps() {
        XCTAssertGreaterThan(EndlessCourse.radius(at: 0), EndlessCourse.radius(at: 60))
        XCTAssertEqual(EndlessCourse.radius(at: 1000), 12)
        XCTAssertGreaterThan(EndlessCourse.spacing(at: 0), EndlessCourse.spacing(at: 100))
        let early = EndlessCourse.chunk(seed: 7, startIndex: 0, previousEnd: nil)
        XCTAssertTrue(early.prefix(8).allSatisfy { $0.kind == .standard }, "Warm-up rings are plain")
    }

    func testEndlessEngineRefillsAndEndsAfterThreeMisses() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(EndlessCourse.stage(seed: 99))
        XCTAssertTrue(engine.isEndless)
        XCTAssertEqual(engine.rings.count, EndlessCourse.chunkSize)
        XCTAssertEqual(engine.endlessLivesRemaining, EndlessCourse.maxMisses)

        // Pass 20 rings → a refill must have happened.
        for _ in 0..<20 { engine.testPass(ringIndex: engine.currentRingIndex) }
        XCTAssertGreaterThan(engine.rings.count, EndlessCourse.chunkSize)
        XCTAssertEqual(engine.currentRingIndex, 20)
        if case .inProgress = engine.state {} else { XCTFail("still running") }

        // Three near-misses end the run as a completion carrying the length.
        // Offset relative to the *effective* radius (combo shrink is on)
        // and modest enough that even a tilted slit reads it as a miss
        // rather than "not an attempt".
        for _ in 0..<EndlessCourse.maxMisses {
            let effective = engine.currentEffectiveRadius ?? 10
            engine.testPass(ringIndex: engine.currentRingIndex,
                            lateralOffset: effective * 1.2)
        }
        guard case .completed(let result) = engine.state else { return XCTFail("run should end") }
        XCTAssertEqual(result.ringsCompleted, 20)
        XCTAssertEqual(result.totalRings, 20)
        XCTAssertEqual(engine.endlessLivesRemaining, 0)
    }

    // MARK: - Progress blob

    func testSpecialResultsKeepBestAndDecodeFromOldBlob() throws {
        var progress = PlayerProgress.defaultProgress
        let r1 = StageResult(stageIndex: DailyRun.stageIndex, stars: 2, completionTime: 80,
                             collisions: 0, starsCollected: 0, ringsCompleted: 12, totalRings: 12,
                             date: Date(), score: 1200, maxCombo: 6, bullseyes: 2)
        XCTAssertTrue(progress.updateSpecialResult(r1, dayKey: "2026-09-19"))
        let worse = StageResult(stageIndex: DailyRun.stageIndex, stars: 3, completionTime: 60,
                                collisions: 0, starsCollected: 0, ringsCompleted: 12, totalRings: 12,
                                date: Date(), score: 900, maxCombo: 3, bullseyes: 0)
        XCTAssertFalse(progress.updateSpecialResult(worse, dayKey: "2026-09-19"))
        XCTAssertEqual(progress.dailyResults["2026-09-19"]?.score, 1200)
        XCTAssertTrue(progress.stageResults.isEmpty, "Special results never touch campaign stages")
        XCTAssertEqual(progress.totalStars, 0)

        let endless = StageResult(stageIndex: EndlessCourse.stageIndex, stars: 0, completionTime: 100,
                                  collisions: 0, starsCollected: 0, ringsCompleted: 31, totalRings: 31,
                                  date: Date(), score: 3100, maxCombo: 10, bullseyes: 4)
        XCTAssertTrue(progress.updateSpecialResult(endless, dayKey: "x"))
        XCTAssertEqual(progress.endlessBest?.ringsCompleted, 31)

        progress.bonusStars = 7
        XCTAssertEqual(progress.effectiveStars, 7)

        // Round trip + old-blob decode.
        let data = try JSONEncoder().encode(progress)
        let back = try JSONDecoder().decode(PlayerProgress.self, from: data)
        XCTAssertEqual(back.dailyResults.count, 1)
        XCTAssertEqual(back.endlessBest?.score, 3100)
        XCTAssertEqual(back.bonusStars, 7)
        XCTAssertFalse(back.gameCenterEnabled)

        let legacy = try JSONEncoder().encode(PlayerProgress.defaultProgress)
        var dict = try JSONSerialization.jsonObject(with: legacy) as! [String: Any]
        for key in ["dailyResults", "endlessBest", "bonusStars", "gameCenterEnabled", "remindersEnabled"] {
            dict.removeValue(forKey: key)
        }
        let stripped = try JSONSerialization.data(withJSONObject: dict)
        let old = try JSONDecoder().decode(PlayerProgress.self, from: stripped)
        XCTAssertEqual(old.bonusStars, 0)
        XCTAssertTrue(old.dailyResults.isEmpty)
    }

    func testMissionViewModelRoutesSpecialCompletions() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        vm.selectDailyRun(date: Date())
        XCTAssertTrue(vm.currentStage?.isDailyRun == true)
        XCTAssertFalse(vm.hasNextStage)
        let result = StageResult(stageIndex: DailyRun.stageIndex, stars: 3, completionTime: 70,
                                 collisions: 0, starsCollected: 0, ringsCompleted: 12, totalRings: 12,
                                 date: Date(), score: 2000, maxCombo: 12, bullseyes: 5)
        vm.completeMission(result: result)
        XCTAssertNotNil(vm.todaysDailyBest())
        XCTAssertTrue(vm.lastSpecialWasNewBest)
        XCTAssertTrue(vm.progress.stageResults.isEmpty)
        vm.returnToSelect()
        XCTAssertNil(vm.specialStage)
        XCTAssertEqual(vm.currentStage?.index, 0)
    }

    func testBonusStarsPromoteTrailTier() {
        let vm = MissionViewModel()
        vm.progress = .defaultProgress
        vm.addBonusStars(50)
        XCTAssertEqual(vm.progress.effectiveStars, 50)
        XCTAssertEqual(vm.progress.selectedTrailTier, .magenta)
    }

    // MARK: - Quests

    func testQuestSetIsDeterministicPerDayWithThreeDistinctKinds() {
        let a = QuestGenerator.quests(for: "2026-09-19")
        let b = QuestGenerator.quests(for: "2026-09-19")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(Set(a.map(\.kind)).count, 3)
        XCTAssertNotEqual(a, QuestGenerator.quests(for: "2026-09-20"))
    }

    func testQuestTrackerRollsOverAndAppliesEvents() {
        let tracker = QuestTracker(defaults: defaults)
        tracker.now = { self.date("2026-09-19") }
        let quests = tracker.todaysQuests()
        XCTAssertEqual(quests.count, 3)

        // Feed enough of everything to complete any quest kind.
        for _ in 0..<50 { tracker.record(.gatePassed) }
        for _ in 0..<10 { tracker.record(.bullseye) }
        tracker.record(.starsCollected(60))
        tracker.record(.courseCleared(collisions: 0, isDaily: true))
        tracker.record(.flightTime(seconds: 600))
        tracker.record(.comboReached(20))
        for c in CharacterType.allCases { for _ in 0..<2 { tracker.record(.flightStarted(character: c)) } }
        XCTAssertTrue(tracker.todaysQuests().allSatisfy(\.isComplete))

        var paid = 0
        tracker.onReward = { paid += $0 }
        let total = tracker.claimAllCompleted()
        XCTAssertGreaterThan(total, 0)
        XCTAssertEqual(total, paid)
        XCTAssertTrue(tracker.current.allClaimed)
        XCTAssertEqual(tracker.claim(tracker.current.quests[0].id), 0, "No double claim")

        // Next day → fresh set, progress gone.
        tracker.now = { self.date("2026-09-20") }
        let fresh = tracker.todaysQuests()
        XCTAssertEqual(tracker.current.day, "2026-09-20")
        XCTAssertTrue(fresh.allSatisfy { $0.progress == 0 && !$0.claimed })
    }

    func testQuestProgressPersistsAcrossInstances() {
        let a = QuestTracker(defaults: defaults)
        a.now = { self.date("2026-09-19") }
        _ = a.todaysQuests()
        a.record(.gatePassed)
        let b = QuestTracker(defaults: defaults)
        b.now = { self.date("2026-09-19") }
        _ = b.todaysQuests()
        XCTAssertEqual(b.current, a.current)
        XCTAssertEqual(b.current.quests.map(\.progress), a.current.quests.map(\.progress))
    }

    // MARK: - Ghost

    func testGhostTrackInterpolatesAndStoreKeepsOnlyBetter() {
        var recorder = GhostRecorder(interval: 0.5)
        recorder.record(time: 0, position: SCNVector3(0, 500, 0))
        recorder.record(time: 0.2, position: SCNVector3(5, 500, -10))   // dropped (< interval)
        recorder.record(time: 0.5, position: SCNVector3(10, 500, -20))
        recorder.record(time: 1.0, position: SCNVector3(20, 520, -40))
        XCTAssertEqual(recorder.samples.count, 3)
        let track = recorder.makeTrack(courseKey: "stage-0", score: 500, completionTime: 1, character: .turtle)
        let mid = track.position(at: 0.75)!
        XCTAssertEqual(mid.x, 15, accuracy: 0.001)
        XCTAssertEqual(mid.y, 510, accuracy: 0.001)
        XCTAssertEqual(track.position(at: -1)!.x, 0, accuracy: 0.001)
        XCTAssertEqual(track.position(at: 99)!.x, 20, accuracy: 0.001)

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ghosts-\(UUID().uuidString)", isDirectory: true)
        let store = GhostStore(directory: dir)
        XCTAssertTrue(store.saveIfBetter(track))
        XCTAssertEqual(store.load(courseKey: "stage-0")?.score, 500)
        let worse = GhostTrack(courseKey: "stage-0", score: 300, completionTime: 2,
                               character: .cat, samples: track.samples)
        XCTAssertFalse(store.saveIfBetter(worse))
        XCTAssertEqual(store.load(courseKey: "stage-0")?.character, .turtle)
        let better = GhostTrack(courseKey: "stage-0", score: 900, completionTime: 2,
                                character: .cat, samples: track.samples)
        XCTAssertTrue(store.saveIfBetter(better))
        XCTAssertEqual(store.load(courseKey: "stage-0")?.character, .cat)
        store.deleteAll()
        XCTAssertNil(store.load(courseKey: "stage-0"))
    }

    func testCourseKeysDistinguishDailyByDay() {
        XCTAssertEqual(FlightViewModel.courseKey(for: StageDefinition.allStages[2]), "stage-2")
        XCTAssertTrue(FlightViewModel.courseKey(for: DailyRun.stage()).hasPrefix("daily-"))
        XCTAssertEqual(FlightViewModel.courseKey(for: EndlessCourse.stage()), "endless")
    }

    // MARK: - Reminders

    private final class StubCenter: NotificationCenterLike {
        var granted = true
        var added: [UNNotificationRequest] = []
        var removed: [String] = []
        func requestAuthorization(options: UNAuthorizationOptions,
                                  completionHandler: @escaping (Bool, Error?) -> Void) {
            completionHandler(granted, nil)
        }
        func add(_ request: UNNotificationRequest, withCompletionHandler: ((Error?) -> Void)?) {
            added.append(request)
            withCompletionHandler?(nil)
        }
        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            removed.append(contentsOf: identifiers)
        }
    }

    func testReminderSchedulerSchedulesTwoRequestsWhenGranted() {
        let stub = StubCenter()
        let scheduler = ReminderScheduler(center: stub)
        var result: Bool?
        scheduler.enable(dailyBody: "d", streakBody: "s", title: "t") { result = $0 }
        XCTAssertEqual(result, true)
        XCTAssertEqual(Set(stub.added.map(\.identifier)),
                       [ReminderScheduler.Identifier.daily, ReminderScheduler.Identifier.streak])
        let daily = stub.added.first { $0.identifier == ReminderScheduler.Identifier.daily }!
        XCTAssertTrue((daily.trigger as? UNCalendarNotificationTrigger)?.repeats == true)
        scheduler.disable()
        XCTAssertTrue(stub.removed.contains(ReminderScheduler.Identifier.daily))
        XCTAssertTrue(scheduler.scheduledIdentifiers.isEmpty)
    }

    func testReminderSchedulerDoesNothingWhenDenied() {
        let stub = StubCenter()
        stub.granted = false
        let scheduler = ReminderScheduler(center: stub)
        var result: Bool?
        scheduler.enable(dailyBody: "d", streakBody: "s", title: "t") { result = $0 }
        XCTAssertEqual(result, false)
        XCTAssertTrue(stub.added.isEmpty)
    }

    // MARK: - Game Center gating

    func testGameCenterDoesNothingUntilEnabled() {
        let manager = GameCenterManager.shared
        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(manager.isAuthenticated)
        // Must be a no-op (no GameKit calls) while disabled.
        manager.submit(score: 10, to: .endless)
        manager.unlock(.combo10)
        manager.report(result: StageResult(stageIndex: 0, stars: 3, completionTime: 1, collisions: 0,
                                           starsCollected: 0, ringsCompleted: 1, totalRings: 1, date: Date()),
                       stage: StageDefinition.allStages[0], progress: .defaultProgress)
    }
}
