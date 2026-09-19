import XCTest
@testable import TurtleFlight

final class AnalyticsTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "AnalyticsTests.suite"

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

    func testTrackIncrementsCounter() {
        let analytics = Analytics(defaults: defaults)
        analytics.track(.ringPassed, ["accuracy": 0.2])
        analytics.track(.ringPassed)
        analytics.track(.stageCompleted)
        let snap = analytics.snapshot()
        XCTAssertEqual(snap.count(.ringPassed), 2)
        XCTAssertEqual(snap.count(.stageCompleted), 1)
        XCTAssertEqual(snap.count(.stageFailed), 0)
    }

    func testCountersPersistAcrossInstances() {
        let first = Analytics(defaults: defaults)
        first.track(.flightStarted)
        _ = first.snapshot()   // flush the serial queue
        let second = Analytics(defaults: defaults)
        XCTAssertEqual(second.snapshot().count(.flightStarted), 1)
    }

    func testSessionStartRecordsDistinctPlayDays() {
        let analytics = Analytics(defaults: defaults)
        analytics.now = { self.date("2026-09-19") }
        analytics.markSessionStart()
        analytics.markSessionStart()          // same day twice
        analytics.now = { self.date("2026-09-20") }
        analytics.markSessionStart()
        let snap = analytics.snapshot()
        XCTAssertEqual(snap.playDays, ["2026-09-19", "2026-09-20"])
        XCTAssertEqual(snap.count(.sessionStarted), 3)
        XCTAssertNotNil(snap.firstLaunch)
    }

    func testStreakCountsConsecutiveDays() {
        let analytics = Analytics(defaults: defaults)
        for day in ["2026-09-17", "2026-09-18", "2026-09-19"] {
            analytics.now = { self.date(day) }
            analytics.markSessionStart()
        }
        XCTAssertEqual(analytics.currentStreak(asOf: date("2026-09-19")), 3)
    }

    func testStreakAllowsGraceDay() {
        let analytics = Analytics(defaults: defaults)
        for day in ["2026-09-18", "2026-09-19"] {
            analytics.now = { self.date(day) }
            analytics.markSessionStart()
        }
        // Not yet played today: streak still counts up to yesterday.
        XCTAssertEqual(analytics.currentStreak(asOf: date("2026-09-20")), 2)
        // Two days later the streak is gone.
        XCTAssertEqual(analytics.currentStreak(asOf: date("2026-09-21")), 0)
    }

    func testStreakBreaksOnGap() {
        let analytics = Analytics(defaults: defaults)
        for day in ["2026-09-15", "2026-09-16", "2026-09-19"] {
            analytics.now = { self.date(day) }
            analytics.markSessionStart()
        }
        XCTAssertEqual(analytics.currentStreak(asOf: date("2026-09-19")), 1)
    }

    func testResetClearsEverything() {
        let analytics = Analytics(defaults: defaults)
        analytics.now = { self.date("2026-09-19") }
        analytics.markSessionStart()
        analytics.track(.ringPassed)
        analytics.reset()
        let snap = analytics.snapshot()
        XCTAssertTrue(snap.counts.isEmpty)
        XCTAssertTrue(snap.playDays.isEmpty)
        XCTAssertNil(snap.firstLaunch)
        XCTAssertNil(defaults.object(forKey: Analytics.Keys.counters))
    }

    func testTrackIsSafeFromBackgroundThreads() {
        let analytics = Analytics(defaults: defaults)
        let group = DispatchGroup()
        for _ in 0..<50 {
            group.enter()
            DispatchQueue.global().async {
                analytics.track(.ringPassed)
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(analytics.snapshot().count(.ringPassed), 50)
    }
}
