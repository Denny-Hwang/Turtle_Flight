import Foundation
import os

private let log = Logger(subsystem: "com.turtleflight.app", category: "Analytics")

/// Product-funnel events. Everything here stays on the device: the only
/// sinks are OSLog (visible in Console.app during development) and a
/// small set of aggregate counters in `UserDefaults` that the Settings
/// screen can show back to the player ("you played 12 days, cleared 4
/// stages…"). Nothing is uploaded — see PRIVACY.md.
///
/// Why bother if it never leaves the device? Because the numbers still
/// tell the team what to build next during TestFlight: a tester can
/// read their funnel out of Settings, and a sysdiagnose carries the
/// OSLog stream. It also gives the retention features (streaks, daily
/// quests) a single source of truth for "days played".
enum AnalyticsEvent: String, CaseIterable {
    case sessionStarted
    case onboardingCompleted
    case flightStarted
    case ringPassed
    case ringMissed
    case stageCompleted
    case stageFailed
    case freeFlightEnded
    case settingsOpened
}

/// Point-in-time read of the counters, for UI / tests.
struct AnalyticsSnapshot: Codable, Equatable {
    var counts: [String: Int]
    var playDays: [String]
    var firstLaunch: Date?

    func count(_ event: AnalyticsEvent) -> Int {
        counts[event.rawValue] ?? 0
    }
}

final class Analytics {

    static let shared = Analytics(defaults: .standard)

    // Storage keys. Listed in PRIVACY.md — keep in sync.
    enum Keys {
        static let counters   = "analytics.counters.v1"
        static let playDays   = "analytics.playDays.v1"
        static let firstLaunch = "analytics.firstLaunch.v1"
    }

    /// Upper bound on the stored play-day list. 400 days is plenty for
    /// any streak / retention arithmetic and keeps the blob tiny.
    static let maxStoredPlayDays = 400

    private let defaults: UserDefaults
    /// Serial queue so `track` is safe from the render thread.
    private let queue = DispatchQueue(label: "com.turtleflight.analytics")
    private var counters: [String: Int]
    private var playDays: [String]
    private var firstLaunch: Date?

    /// Injected clock so tests can pin "today".
    var now: () -> Date = { Date() }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(defaults: UserDefaults) {
        self.defaults = defaults
        counters = defaults.dictionary(forKey: Keys.counters) as? [String: Int] ?? [:]
        playDays = defaults.stringArray(forKey: Keys.playDays) ?? []
        firstLaunch = defaults.object(forKey: Keys.firstLaunch) as? Date
    }

    // MARK: - Recording

    /// Increment the event counter and log the event with its params.
    /// Safe to call from any thread.
    func track(_ event: AnalyticsEvent, _ params: [String: Any] = [:]) {
        queue.async { [self] in
            counters[event.rawValue, default: 0] += 1
            let paramText = params.isEmpty ? "" : " \(params)"
            log.info("\(event.rawValue, privacy: .public)\(paramText, privacy: .public)")
            persist()
        }
    }

    /// Call once per app launch. Records the install date on first run
    /// and adds today to the play-day set.
    func markSessionStart() {
        // Read the clock on the caller's thread: a test that advances
        // `now` right after this call must not affect the queued write.
        let stamp = now()
        queue.async { [self] in
            let today = Self.dayString(stamp)
            if firstLaunch == nil { firstLaunch = stamp }
            if playDays.last != today, !playDays.contains(today) {
                playDays.append(today)
                if playDays.count > Self.maxStoredPlayDays {
                    playDays.removeFirst(playDays.count - Self.maxStoredPlayDays)
                }
            }
            counters[AnalyticsEvent.sessionStarted.rawValue, default: 0] += 1
            persist()
        }
    }

    /// Wipe every counter. Wired to Settings → Reset Progress so the
    /// destructive action really does remove everything the app stores.
    func reset() {
        queue.async { [self] in
            counters = [:]
            playDays = []
            firstLaunch = nil
            defaults.removeObject(forKey: Keys.counters)
            defaults.removeObject(forKey: Keys.playDays)
            defaults.removeObject(forKey: Keys.firstLaunch)
        }
    }

    // MARK: - Reading

    /// Synchronous snapshot. Waits for any queued writes so a test that
    /// tracks then reads sees its own event.
    func snapshot() -> AnalyticsSnapshot {
        queue.sync {
            AnalyticsSnapshot(counts: counters, playDays: playDays, firstLaunch: firstLaunch)
        }
    }

    /// Number of distinct calendar days the app has been opened.
    var distinctPlayDays: Int { snapshot().playDays.count }

    /// Consecutive days played ending today (or yesterday, so an evening
    /// player who hasn't opened the app yet today still sees the streak).
    func currentStreak(asOf date: Date? = nil) -> Int {
        let days = Set(snapshot().playDays)
        guard !days.isEmpty else { return 0 }
        let calendar = Calendar(identifier: .gregorian)
        var cursor = calendar.startOfDay(for: date ?? now())
        if !days.contains(Self.dayString(cursor)) {
            // Allow a grace day: streak counted up to yesterday.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(Self.dayString(yesterday)) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(Self.dayString(cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: - Helpers

    static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private func persist() {
        defaults.set(counters, forKey: Keys.counters)
        defaults.set(playDays, forKey: Keys.playDays)
        if let firstLaunch {
            defaults.set(firstLaunch, forKey: Keys.firstLaunch)
        }
    }
}
