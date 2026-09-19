import Foundation

/// "Today's course": a 12-gate course every player in the world sees
/// identically on a given calendar day, generated from the date alone.
///
/// No server, no download — the seed is a stable hash of `yyyy-MM-dd`
/// (see `SeededRandom.stableHash`), and every parameter of the course is
/// drawn from that seed. Tomorrow's course is different, yesterday's is
/// gone. That is the whole retention hook: a reason to open the app
/// today that didn't exist yesterday and won't exist tomorrow.
enum DailyRun {

    /// Stage index reserved for the daily course. Campaign stages are
    /// 0…4; anything ≥ 100 is a special course and is *not* stored in
    /// `PlayerProgress.stageResults`.
    static let stageIndex = 100
    static let ringCount = 12
    static let timeLimit: TimeInterval = 120
    static let star3Time: TimeInterval = 75

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Stable key for a date ("2026-09-19"). Used as the seed source and
    /// as the dictionary key for the day's best result.
    static func key(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func seed(for date: Date) -> UInt64 {
        SeededRandom.stableHash("daily:" + key(for: date))
    }

    /// The course for `date`. Pure: same date → same spec.
    static func courseSpec(for date: Date) -> CourseSpec {
        var rng = SeededRandom(seed: seed(for: date))
        let patterns: [CourseSpec.Pattern] = [.weave, .sCurve, .peaks, .race]
        let recipes: [GateRecipe] = [.shrinkingEveryThird, .tiltAlternate, .mixed, .mixedAfterWarmup]
        let pattern = patterns[rng.nextInt(in: 0...(patterns.count - 1))]
        let recipe = recipes[rng.nextInt(in: 0...(recipes.count - 1))]
        return CourseSpec(
            pattern: pattern,
            count: ringCount,
            spacing: rng.nextFloat(in: 120...170),
            startZ: -160,
            lateralAmplitude: rng.nextFloat(in: 60...120),
            angleStep: rng.nextFloat(in: 0.4...0.9),
            baseAltitude: rng.nextFloat(in: 350...550),
            altitudeAmplitude: rng.nextFloat(in: 40...120),
            jitter: rng.nextFloat(in: 10...30),
            seed: seed(for: date),
            gateRecipe: recipe,
            comboShrink: rng.nextUnit() < 0.5
        )
    }

    /// Ring radius for the day: tight-ish, drawn from the same seed.
    static func ringRadius(for date: Date) -> Float {
        var rng = SeededRandom(seed: seed(for: date) ^ 0x5EED)
        return rng.nextFloat(in: 22...34).rounded()
    }

    /// Full stage definition for `date`, ready for `MissionEngine`.
    static func stage(for date: Date = Date()) -> StageDefinition {
        StageDefinition(
            index: stageIndex,
            name: "Daily Run",
            koreanName: "오늘의 코스",
            difficulty: 3,
            description: "오늘의 코스 \(key(for: date))",
            ringRadius: ringRadius(for: date),
            timeLimit: timeLimit,
            star3Time: star3Time,
            starCountForPerfect: nil,
            star3Condition: "75초 이내 + 접촉 0회",
            star2Condition: "완료",
            learningGoal: "매일 새로운 코스",
            course: courseSpec(for: date)
        )
    }
}

extension StageDefinition {
    /// True for courses outside the 5-stage campaign (daily, endless).
    var isSpecial: Bool { index >= DailyRun.stageIndex }
    var isDailyRun: Bool { index == DailyRun.stageIndex }
    var isEndless: Bool { index == EndlessCourse.stageIndex }
}
