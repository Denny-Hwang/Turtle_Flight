import XCTest
import SceneKit
@testable import TurtleFlight

/// Routes, Kids mode, haptics, wallet / shop and secret codes.
final class RoutesRewardsTests: XCTestCase {

    private var savedBlob: Data?

    override func setUp() {
        super.setUp()
        savedBlob = UserDefaults.standard.data(forKey: "playerProgress")
        UserDefaults.standard.removeObject(forKey: "playerProgress")
    }

    override func tearDown() {
        UserDefaults.standard.set(savedBlob, forKey: "playerProgress")
        super.tearDown()
    }

    private func cleared(_ index: Int, stars: Int = 1) -> StageResult {
        StageResult(stageIndex: index, stars: stars, completionTime: 30, collisions: 0,
                    starsCollected: 0, ringsCompleted: 5, totalRings: 5, date: Date())
    }

    // MARK: - Haptics

    func testEveryHapticEventHasItsOwnFeel() {
        for event in HapticEvent.allCases {
            XCTAssertFalse(Haptics.pattern(for: event).isEmpty, "\(event)")
        }
        let ground = Haptics.pattern(for: .groundHit)
        XCTAssertEqual(ground.first?.kind, .heavy)
        XCTAssertEqual(ground.count, 3, "ground hit is the longest rumble")
        let rim = Haptics.pattern(for: .ringRim)
        XCTAssertEqual(rim.count, 2)
        XCTAssertNotEqual(rim, ground)
        let passes = [HapticEvent.ringBullseye, .ringGreat, .ringOk].map(Haptics.pattern(for:))
        XCTAssertEqual(Set(passes.map { "\($0)" }).count, 3)
        XCTAssertNotEqual(Haptics.pattern(for: .ringMiss), rim)
    }

    func testCrossingAccuracyPicksTheHaptic() {
        XCTAssertEqual(Haptics.event(forCrossingAccuracy: 0.1, judgement: .bullseye), .ringBullseye)
        XCTAssertEqual(Haptics.event(forCrossingAccuracy: 0.5, judgement: .great), .ringGreat)
        XCTAssertEqual(Haptics.event(forCrossingAccuracy: 0.9, judgement: .ok), .ringOk)
        XCTAssertEqual(Haptics.event(forCrossingAccuracy: 1.1, judgement: .miss), .ringRim)
        XCTAssertEqual(Haptics.event(forCrossingAccuracy: 2.0, judgement: .miss), .ringMiss)
    }

    func testHapticsToggleSilencesEverything() {
        let suite = "RoutesRewardsTests.haptics"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let haptics = Haptics(defaults: defaults)
        XCTAssertTrue(haptics.isEnabled, "on by default")
        haptics.play(.ringGreat)
        XCTAssertEqual(haptics.playedCount, 1)
        haptics.isEnabled = false
        haptics.play(.groundHit)
        XCTAssertEqual(haptics.playedCount, 1)
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - Routes

    func testFiveRoutesWithUniqueCourses() {
        XCTAssertEqual(RouteID.allCases.count, 5)
        XCTAssertEqual(RouteCatalog.allCourses.count, 21)
        XCTAssertEqual(Set(RouteCatalog.allCourses.map(\.index)).count, 21)
        XCTAssertEqual(RouteCatalog.courses(in: .skySchool).map(\.index), [0, 1, 2, 3, 4],
                       "the original campaign keeps its indices")
        for course in RouteCatalog.allCourses {
            XCTAssertFalse(course.isSpecial)
            let here = RouteCatalog.location(of: course.index)
            XCTAssertNotNil(here)
            XCTAssertFalse(course.displayName.contains("route."), course.displayName)
            XCTAssertFalse(course.displayDescription.isEmpty)
            XCTAssertEqual(course.generateRings().count, course.ringCount)
        }
        XCTAssertEqual(RouteID.allCases.filter(\.isFinale), [.starRoad])
        for route in RouteID.allCases {
            XCTAssertFalse(route.displayName.hasPrefix("route."))
        }
    }

    func testEachWorldRouteGetsHarderStepByStep() {
        for route in RouteID.allCases where route != .skySchool {
            let courses = RouteCatalog.courses(in: route)
            XCTAssertEqual(courses.count, 4)
            for (a, b) in zip(courses, courses.dropFirst()) {
                XCTAssertGreaterThanOrEqual(b.ringCount, a.ringCount, "\(route)")
                XCTAssertLessThan(b.ringRadius, a.ringRadius, "\(route)")
            }
            XCTAssertTrue(courses.allSatisfy { $0.world != nil })
        }
        XCTAssertEqual(Set(RouteCatalog.courses(in: .sunRoad).compactMap(\.world)), [.desert, .city])
        XCTAssertEqual(Set(RouteCatalog.courses(in: .starRoad).compactMap(\.world)), [.space])
        // Different maps really do differ in ring count and size.
        let firsts = RouteID.allCases.compactMap { RouteCatalog.courses(in: $0).first }
        XCTAssertGreaterThan(Set(firsts.map(\.ringCount)).count, 2)
        XCTAssertGreaterThan(Set(firsts.map(\.ringRadius)).count, 2)
    }

    func testOnlyTheFirstCourseOfEachOpenRouteStartsUnlocked() {
        let fresh = PlayerProgress.defaultProgress
        for route in RouteID.allCases {
            let courses = RouteCatalog.courses(in: route)
            XCTAssertEqual(fresh.isCourseUnlocked(courses[0].index), !route.isFinale, "\(route)")
            for later in courses.dropFirst() {
                XCTAssertFalse(fresh.isCourseUnlocked(later.index))
            }
        }
        XCTAssertFalse(fresh.isRouteUnlocked(.starRoad))
    }

    func testClearingACourseOpensTheNextOnThatRouteOnly() {
        var progress = PlayerProgress.defaultProgress
        progress.updateStageResult(cleared(10))
        XCTAssertTrue(progress.isCourseUnlocked(11))
        XCTAssertFalse(progress.isCourseUnlocked(12))
        XCTAssertFalse(progress.isCourseUnlocked(21))
        XCTAssertEqual(progress.maxUnlockedStage, 0, "route clears don't unlock Sky School stages")
    }

    func testStarRoadOpensAfterTheOtherFourRoutes() {
        var progress = PlayerProgress.defaultProgress
        for route in RouteID.allCases where !route.isFinale {
            XCTAssertFalse(progress.isRouteUnlocked(.starRoad))
            progress.updateStageResult(cleared(RouteCatalog.courses(in: route).last!.index))
        }
        XCTAssertTrue(progress.isRouteUnlocked(.starRoad))
        XCTAssertTrue(progress.isCourseUnlocked(40))
        XCTAssertFalse(progress.isCourseUnlocked(41))
    }

    func testStarsOpenOnlyTheNextCourseInLine() {
        var progress = PlayerProgress.defaultProgress
        XCTAssertTrue(progress.canOpenEarly(11))
        XCTAssertFalse(progress.canOpenEarly(12), "two ahead")
        XCTAssertFalse(progress.canOpenEarly(10), "already open")
        XCTAssertFalse(progress.canOpenEarly(40), "Star Road can't be bought")
        XCTAssertFalse(progress.openCourseEarly(11), "no stars yet")
        progress.earnStars(RouteCatalog.earlyOpenPrice + 1)
        XCTAssertTrue(progress.openCourseEarly(11))
        XCTAssertEqual(progress.starBalance, 1)
        XCTAssertTrue(progress.isCourseUnlocked(11))
        XCTAssertTrue(progress.canOpenEarly(12))
    }

    // MARK: - Kids mode

    func testKidsCourseIsBiggerShorterAndHasNoClock() {
        for course in RouteCatalog.allCourses {
            let kids = course.kidsVariant()
            XCTAssertTrue(kids.isKids)
            XCTAssertEqual(kids.index, course.index)
            XCTAssertGreaterThan(kids.ringRadius, course.ringRadius)
            XCTAssertGreaterThanOrEqual(kids.ringRadius, 45)
            XCTAssertLessThanOrEqual(kids.ringCount, course.ringCount)
            XCTAssertGreaterThanOrEqual(kids.ringCount, 4)
            XCTAssertNil(kids.timeLimit)
            XCTAssertTrue(kids.course.gateKinds.allSatisfy { $0 == .standard })
            XCTAssertFalse(kids.course.comboShrink)
        }
        XCTAssertFalse(DailyRun.stage().kidsVariant().isKids, "shared ladders stay as they are")
    }

    func testKidsCourseCannotBeFailedEvenWhenEveryRingIsMissed() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        let stage = RouteCatalog.course(index: 13)!.kidsVariant()
        engine.startStage(stage)
        // Dawdle far longer than the normal course's limit…
        engine.update(deltaTime: 600, playerPosition: SCNVector3(0, 500, 0))
        guard case .inProgress = engine.state else { return XCTFail("kids course timed out") }
        // …then fly past every ring a long way off to the side.
        var guardCount = 0
        while case .inProgress = engine.state, guardCount < 100 {
            guardCount += 1
            engine.testPass(ringIndex: engine.currentRingIndex, lateralOffset: 2000)
        }
        guard case .completed(let result) = engine.state else { return XCTFail("did not finish") }
        XCTAssertEqual(result.stars, 1)
        XCTAssertEqual(result.ringsCompleted, 0)
        XCTAssertTrue(result.isCompleted, "still a clear")
        XCTAssertEqual(engine.ringsSkipped, stage.ringCount)
    }

    func testKidsCourseGivesThreeStarsForEveryRingAndIgnoresBumps() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(RouteCatalog.course(index: 0)!.kidsVariant())
        for _ in 0..<5 { engine.registerCollision() }
        engine.testPassAllRings()
        guard case .completed(let result) = engine.state else { return XCTFail("did not finish") }
        XCTAssertEqual(result.stars, 3)
        XCTAssertEqual(result.ringsCompleted, result.totalRings)
    }

    func testNormalCourseStillSendsThePlayerBackAfterAMiss() {
        let scene = SCNScene()
        let engine = MissionEngine(parentNode: scene.rootNode)
        engine.startStage(RouteCatalog.course(index: 10)!)
        engine.testPass(ringIndex: 0, lateralOffset: 2000)
        XCTAssertEqual(engine.currentRingIndex, 0)
        XCTAssertEqual(engine.ringsSkipped, 0)
    }

    // MARK: - Mission view model

    func testKidsModeSwapsTheSelectedCourse() {
        let vm = MissionViewModel()
        XCTAssertTrue(vm.selectCourse(20))
        XCTAssertEqual(vm.currentStage?.index, 20)
        XCTAssertEqual(vm.currentStage?.isKids, false)
        XCTAssertEqual(vm.currentStage?.world, .seoul)
        XCTAssertFalse(vm.selectCourse(21), "locked")
        vm.setKidsMode(true)
        XCTAssertTrue(vm.selectCourse(0))
        XCTAssertEqual(vm.currentStage?.isKids, true)
        XCTAssertEqual(vm.currentStage?.index, 0)
        XCTAssertEqual(FlightViewModel.courseKey(for: vm.currentStage!), "stage-0-kids")
    }

    func testNextIsOfferedOnlyWithinTheSameWorld() {
        let vm = MissionViewModel()
        vm.selectCourse(10)
        XCTAssertTrue(vm.hasNextStage, "desert 1 → desert 2")
        XCTAssertTrue(vm.advanceToNextStage())
        XCTAssertEqual(vm.currentStage?.index, 11)
        XCTAssertFalse(vm.hasNextStage, "desert 2 → city 1 needs a new scene")
    }

    func testClearingPaysStarsAndTheFlyingCharactersTreats() {
        let vm = MissionViewModel()
        vm.recordFlightStart(character: .bunny)
        vm.selectCourse(10)
        var result = cleared(10, stars: 3)
        result.bullseyes = 4
        vm.completeMission(result: result)
        XCTAssertEqual(vm.progress.starBalance, 3)
        XCTAssertEqual(vm.progress.treatBalance(.bunny), 1 + 3 + 2)
        XCTAssertEqual(vm.progress.treatBalance(.turtle), 0)
        XCTAssertEqual(vm.lastReward, RewardGrant(stars: 3, treats: 6, character: .bunny))
        XCTAssertTrue(vm.isStageUnlocked(11))
        // A replay pays again.
        vm.completeMission(result: cleared(10, stars: 1))
        XCTAssertEqual(vm.progress.starBalance, 4)
        XCTAssertEqual(vm.progress.totalStars, 3, "best result is kept")
    }

    // MARK: - Wallet and shop

    func testTwoCurrenciesBuyDifferentThings() {
        let starIDs = Set(Shop.starItems.map(\.id))
        for character in CharacterType.allCases {
            let items = Shop.treatItems(for: character)
            XCTAssertEqual(items.count, 3)
            XCTAssertTrue(starIDs.isDisjoint(with: items.map(\.id)))
            for item in items {
                XCTAssertEqual(item.currency, .treat(character))
                XCTAssertNotNil(item.trailLook)
                XCTAssertEqual(Shop.item(id: item.id), item)
                XCTAssertFalse(item.displayName.contains("shop."))
            }
            XCTAssertFalse(character.treatName.hasPrefix("treat."))
        }
        XCTAssertEqual(Set(CharacterType.allCases.map(\.treatEmoji)).count, 6)
        XCTAssertTrue(Shop.starItems.allSatisfy { $0.currency == .stars && $0.trailLook == nil })
    }

    func testBuyingSpendsTheRightCurrencyOnce() {
        var progress = PlayerProgress.defaultProgress
        let carrotTrail = Shop.treatItems(for: .bunny)[0]
        let morning = Shop.starItems[0]
        progress.earnStars(50)
        XCTAssertFalse(progress.buy(carrotTrail), "stars can't pay for a treat item")
        progress.earnTreats(carrotTrail.price, for: .turtle)
        XCTAssertFalse(progress.buy(carrotTrail), "another character's treats don't count")
        progress.earnTreats(carrotTrail.price + 2, for: .bunny)
        XCTAssertTrue(progress.buy(carrotTrail))
        XCTAssertEqual(progress.treatBalance(.bunny), 2)
        XCTAssertEqual(progress.starBalance, 50)
        XCTAssertFalse(progress.buy(carrotTrail), "already owned")
        XCTAssertTrue(progress.buy(morning))
        XCTAssertEqual(progress.starBalance, 50 - morning.price)
    }

    func testEquippingNeedsOwnershipAndTheRightCharacter() {
        var progress = PlayerProgress.defaultProgress
        let trail = Shop.treatItems(for: .cat)[1]
        progress.equipFlair(trail, for: .cat)
        XCTAssertNil(progress.equippedFlair(for: .cat))
        progress.earnTreats(trail.price, for: .cat)
        progress.buy(trail)
        progress.equipFlair(trail, for: .frog)
        XCTAssertNil(progress.equippedFlair(for: .frog))
        progress.equipFlair(trail, for: .cat)
        XCTAssertEqual(progress.equippedFlair(for: .cat), trail)
        progress.equipFlair(nil, for: .cat)
        XCTAssertNil(progress.equippedFlair(for: .cat))

        XCTAssertNil(progress.pinnedSky)
        progress.pinSky(.night)
        XCTAssertNil(progress.pinnedSky, "not owned")
        progress.earnStars(20)
        progress.buy(Shop.starItems[2])
        progress.pinSky(.night)
        XCTAssertEqual(progress.pinnedSky, .night)
    }

    func testSpendingStarsKeepsEarnedTrailTiers() {
        var progress = PlayerProgress.defaultProgress
        progress.bonusStars = 60
        progress.earnStars(60)
        progress.buy(Shop.starItems[2])
        XCTAssertEqual(progress.effectiveStars, 60)
        XCTAssertEqual(progress.starBalance, 40)
    }

    func testOldSaveStartsTheWalletWithItsStars() throws {
        var old = PlayerProgress.defaultProgress
        old.updateStageResult(cleared(0, stars: 3))
        old.bonusStars = 4
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        for key in ["kidsMode", "starsBanked", "starsSpent", "treats", "ownedItems", "equippedFlair",
                    "preferredSky", "openedCourses", "unlockedRoutes", "redeemedCodes"] {
            json.removeValue(forKey: key)
        }
        let decoded = try JSONDecoder().decode(PlayerProgress.self,
                                               from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.starBalance, 7)
        XCTAssertFalse(decoded.kidsMode)
        XCTAssertTrue(decoded.redeemedCodes.isEmpty)
    }

    func testNewFieldsSurviveARoundTrip() throws {
        var progress = PlayerProgress.defaultProgress
        progress.kidsMode = true
        progress.earnStars(9)
        progress.earnTreats(4, for: .frog)
        progress.openedCourses = [11]
        progress.unlockedRoutes = [RouteID.starRoad.rawValue]
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertTrue(decoded.kidsMode)
        XCTAssertEqual(decoded.starBalance, 9)
        XCTAssertEqual(decoded.treatBalance(.frog), 4)
        XCTAssertTrue(decoded.isCourseUnlocked(11))
        XCTAssertTrue(decoded.isRouteUnlocked(.starRoad))
    }

    func testRewardRules() {
        var result = cleared(0, stars: 2)
        result.bullseyes = 20
        XCTAssertEqual(RewardRules.treats(forCourse: result), 1 + 2 + 3)
        XCTAssertEqual(RewardRules.treats(forEndlessRings: 23), 4)
        XCTAssertEqual(RewardRules.treats(forEndlessRings: 500), 8)
        XCTAssertEqual(RewardRules.treats(forFreeFlightStars: 2), 0)
        XCTAssertEqual(RewardRules.treats(forFreeFlightStars: 100), 6)
    }

    // MARK: - Secret codes

    func testCodesIgnoreCaseSpacesAndSymbols() {
        XCTAssertEqual(SecretCodes.normalise(" sky-friend 7! "), "SKYFRIEND7")
        XCTAssertEqual(SecretCodes.hash("Sky Friend 7"), SecretCodes.hash("SKYFRIEND7"))
        XCTAssertEqual(SecretCodes.hash("x").count, 64)
    }

    func testACodeWorksOnceAndPaysItsReward() {
        // The shipped codes are not in this (public) repository, so the
        // machinery is exercised with a stand-in catalogue.
        let catalogue = [
            SecretCodes.Entry(hash: SecretCodes.hash("TESTROUTE"), reward: .unlockRoute(.starRoad)),
            SecretCodes.Entry(hash: SecretCodes.hash("TESTPACK"), reward: .starterPack(stars: 10, treats: 5)),
            SecretCodes.Entry(hash: SecretCodes.hash("TESTTRAIL"), reward: .item(Shop.cometID))
        ]
        var progress = PlayerProgress.defaultProgress
        XCTAssertEqual(SecretCodes.redeem("nope", into: &progress, entries: catalogue), .unknown)
        XCTAssertEqual(SecretCodes.redeem("", into: &progress, entries: catalogue), .unknown)
        XCTAssertEqual(SecretCodes.redeem("test route", into: &progress, entries: catalogue),
                       .accepted(.unlockRoute(.starRoad)))
        XCTAssertTrue(progress.isCourseUnlocked(40))
        XCTAssertEqual(SecretCodes.redeem("TESTROUTE", into: &progress, entries: catalogue), .alreadyUsed)

        XCTAssertEqual(SecretCodes.redeem("TestPack", into: &progress, entries: catalogue),
                       .accepted(.starterPack(stars: 10, treats: 5)))
        XCTAssertEqual(progress.starBalance, 10)
        XCTAssertTrue(CharacterType.allCases.allSatisfy { progress.treatBalance($0) == 5 })

        _ = SecretCodes.redeem("TESTTRAIL", into: &progress, entries: catalogue)
        progress.equipFlair(Shop.comet, for: .penguin)
        XCTAssertEqual(progress.equippedFlair(for: .penguin), Shop.comet, "comet fits everyone")
    }

    func testShippedCodesAreFiveDistinctHashesWithOneRouteKey() {
        let entries = SecretCodes.entries
        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(Set(entries.map(\.hash)).count, 5)
        XCTAssertTrue(entries.allSatisfy { $0.hash.count == 64 })
        XCTAssertEqual(entries.filter { $0.reward == .unlockRoute(.starRoad) }.count, 1)
        for entry in entries {
            XCTAssertFalse(SecretCodes.message(for: entry.reward).contains("code."))
        }
        var progress = PlayerProgress.defaultProgress
        XCTAssertEqual(SecretCodes.redeem("definitely not a code", into: &progress), .unknown)
    }
}
