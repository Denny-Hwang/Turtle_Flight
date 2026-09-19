import Foundation

/// Three small goals a day, drawn from a pool by the date's seed. Each
/// completed quest pays bonus stars into `PlayerProgress.bonusStars`,
/// which count toward the trail-colour tiers — closing the gap between
/// the 15★ campaign cap and the 50★ / 150★ / 300★ cosmetics that were
/// previously unreachable.
///
/// Pure model + a small persisted store. Progress events come from the
/// game loop through `QuestTracker.record(_:)`.
enum QuestKind: String, Codable, CaseIterable {
    case collectStars        // collect N stars in flights today
    case passGates           // pass N gates (any judgement but miss)
    case bullseyes           // N bullseye judgements
    case cleanClear          // clear any course with zero collisions (N = 1)
    case flyMinutes          // accumulate N minutes of flight time
    case completeDaily       // finish today's Daily Run (N = 1)
    case comboReach          // reach a combo of N in one run
    case flyCharacter        // start N flights with a specific character

    var l10nKey: String { "quest.\(rawValue)" }
}

struct Quest: Codable, Equatable, Identifiable {
    let id: String
    let kind: QuestKind
    let target: Int
    /// Only for `.flyCharacter`.
    let character: CharacterType?
    let rewardStars: Int
    var progress: Int = 0
    var claimed: Bool = false

    var isComplete: Bool { progress >= target }
    var fraction: Double { target > 0 ? min(1, Double(progress) / Double(target)) : 0 }
}

struct DailyQuestSet: Codable, Equatable {
    let day: String
    var quests: [Quest]

    var allClaimed: Bool { quests.allSatisfy(\.claimed) }
}

/// Things the game reports; the tracker maps them to quest progress.
enum QuestEvent: Equatable {
    case starsCollected(Int)
    case gatePassed
    case bullseye
    case courseCleared(collisions: Int, isDaily: Bool)
    case flightTime(seconds: Double)
    case comboReached(Int)
    case flightStarted(character: CharacterType)
}

enum QuestGenerator {

    /// Deterministic three-quest set for `day` ("yyyy-MM-dd").
    static func quests(for day: String) -> [Quest] {
        var rng = SeededRandom(seed: SeededRandom.stableHash("quests:" + day))
        var pool: [QuestKind] = QuestKind.allCases
        var out: [Quest] = []
        for slot in 0..<3 {
            guard !pool.isEmpty else { break }
            let pick = rng.nextInt(in: 0...(pool.count - 1))
            let kind = pool.remove(at: pick)
            out.append(make(kind, slot: slot, day: day, rng: &rng))
        }
        return out
    }

    private static func make(_ kind: QuestKind, slot: Int, day: String,
                             rng: inout SeededRandom) -> Quest {
        let id = "\(day)-\(slot)-\(kind.rawValue)"
        switch kind {
        case .collectStars:
            let n = [20, 30, 40][rng.nextInt(in: 0...2)]
            return Quest(id: id, kind: kind, target: n, character: nil, rewardStars: 3)
        case .passGates:
            let n = [15, 25, 40][rng.nextInt(in: 0...2)]
            return Quest(id: id, kind: kind, target: n, character: nil, rewardStars: 3)
        case .bullseyes:
            let n = [3, 5, 8][rng.nextInt(in: 0...2)]
            return Quest(id: id, kind: kind, target: n, character: nil, rewardStars: 5)
        case .cleanClear:
            return Quest(id: id, kind: kind, target: 1, character: nil, rewardStars: 5)
        case .flyMinutes:
            let n = [3, 5, 8][rng.nextInt(in: 0...2)]
            return Quest(id: id, kind: kind, target: n, character: nil, rewardStars: 2)
        case .completeDaily:
            return Quest(id: id, kind: kind, target: 1, character: nil, rewardStars: 5)
        case .comboReach:
            let n = [5, 8, 12][rng.nextInt(in: 0...2)]
            return Quest(id: id, kind: kind, target: n, character: nil, rewardStars: 5)
        case .flyCharacter:
            let all = CharacterType.allCases
            let character = all[rng.nextInt(in: 0...(all.count - 1))]
            return Quest(id: id, kind: kind, target: 2, character: character, rewardStars: 3)
        }
    }
}

/// Persists today's quest set and applies events to it.
final class QuestTracker {

    static let storageKey = "quests.v1"
    static let shared = QuestTracker(defaults: .standard)

    private let defaults: UserDefaults
    private(set) var current: DailyQuestSet
    /// Injected clock for tests.
    var now: () -> Date = { Date() }

    /// Called with the stars just earned when a quest is claimed.
    var onReward: ((Int) -> Void)?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let set = try? JSONDecoder().decode(DailyQuestSet.self, from: data) {
            current = set
        } else {
            current = DailyQuestSet(day: "", quests: [])
        }
        rollOverIfNeeded()
    }

    /// Today's quests, generating a fresh set when the day changed.
    func todaysQuests() -> [Quest] {
        rollOverIfNeeded()
        return current.quests
    }

    /// Bring the stored set up to today. Yesterday's unclaimed progress
    /// is discarded — a daily quest is for that day.
    func rollOverIfNeeded() {
        let today = Analytics.dayString(now())
        guard current.day != today else { return }
        current = DailyQuestSet(day: today, quests: QuestGenerator.quests(for: today))
        persist()
    }

    /// Apply a game event to every matching quest. Returns the ids of
    /// quests that just became complete (for a HUD toast).
    @discardableResult
    func record(_ event: QuestEvent) -> [String] {
        rollOverIfNeeded()
        var newlyComplete: [String] = []
        for i in current.quests.indices {
            var q = current.quests[i]
            guard !q.isComplete else { continue }
            switch (q.kind, event) {
            case (.collectStars, .starsCollected(let n)):
                q.progress += n
            case (.passGates, .gatePassed):
                q.progress += 1
            case (.bullseyes, .bullseye):
                q.progress += 1
            case (.cleanClear, .courseCleared(let collisions, _)) where collisions == 0:
                q.progress = q.target
            case (.completeDaily, .courseCleared(_, let isDaily)) where isDaily:
                q.progress = q.target
            case (.flyMinutes, .flightTime(let seconds)):
                // Track in whole minutes via an accumulated seconds field
                // encoded in progress × 60? Keep it simple: progress is
                // minutes, so bump when a whole minute has accrued.
                secondsAccrued += seconds
                let minutes = Int(secondsAccrued / 60)
                if minutes > q.progress { q.progress = minutes }
            case (.comboReach, .comboReached(let combo)):
                q.progress = max(q.progress, combo)
            case (.flyCharacter, .flightStarted(let character)) where character == q.character:
                q.progress += 1
            default:
                continue
            }
            q.progress = min(q.progress, q.target)
            current.quests[i] = q
            if q.isComplete { newlyComplete.append(q.id) }
        }
        persist()
        return newlyComplete
    }

    /// Claim the reward for a completed quest. Returns the stars paid.
    @discardableResult
    func claim(_ id: String) -> Int {
        guard let i = current.quests.firstIndex(where: { $0.id == id }),
              current.quests[i].isComplete, !current.quests[i].claimed
        else { return 0 }
        current.quests[i].claimed = true
        persist()
        let reward = current.quests[i].rewardStars
        onReward?(reward)
        return reward
    }

    /// Claim every completed, unclaimed quest. Returns total stars paid.
    @discardableResult
    func claimAllCompleted() -> Int {
        current.quests.filter { $0.isComplete && !$0.claimed }
            .map { claim($0.id) }
            .reduce(0, +)
    }

    func reset() {
        current = DailyQuestSet(day: "", quests: [])
        secondsAccrued = 0
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.storageKey + ".seconds")
        rollOverIfNeeded()
    }

    // MARK: - Private

    /// Flight seconds accrued today for the `.flyMinutes` quest.
    private var secondsAccrued: Double {
        get { defaults.double(forKey: Self.storageKey + ".seconds." + current.day) }
        set { defaults.set(newValue, forKey: Self.storageKey + ".seconds." + current.day) }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
