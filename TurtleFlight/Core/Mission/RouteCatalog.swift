import Foundation

/// A chain of courses the player clears in order.
///
/// The campaign is not one long line: there are five routes side by
/// side. Four start with their first course open, so there is always
/// more than one thing to try next. The fifth — Star Road — opens when
/// the other four are finished (or with a secret code).
enum RouteID: String, CaseIterable {
    case skySchool, sunRoad, eastTrail, deepBlue, starRoad

    var displayName: String { L10n.t("route.\(rawValue).name") }
    var emoji: String {
        switch self {
        case .skySchool: return "☁️"
        case .sunRoad:   return "☀️"
        case .eastTrail: return "⛰️"
        case .deepBlue:  return "🌊"
        case .starRoad:  return "🚀"
        }
    }

    /// Stage index of the route's first course. The original five
    /// campaign stages keep 0…4 so saved results and ghosts still match.
    var firstIndex: Int {
        switch self {
        case .skySchool: return 0
        case .sunRoad:   return 10
        case .eastTrail: return 20
        case .deepBlue:  return 30
        case .starRoad:  return 40
        }
    }

    /// The route that only opens at the end.
    var isFinale: Bool { self == .starRoad }
}

enum RouteCatalog {

    /// Stars it costs to open the next locked course early.
    static let earlyOpenPrice = 8

    /// One row of the difficulty table: where, how many rings, how big.
    private struct Step {
        let world: MapTheme
        let rings: Int
        let radius: Float
        let pattern: CourseSpec.Pattern
        let recipe: GateRecipe
        var comboShrink = false
    }

    private static let steps: [RouteID: [Step]] = [
        .sunRoad: [
            Step(world: .desert, rings: 8,  radius: 45, pattern: .weave,  recipe: .standard),
            Step(world: .desert, rings: 10, radius: 38, pattern: .sCurve, recipe: .shrinkingEveryThird),
            Step(world: .city,   rings: 10, radius: 32, pattern: .zigzag, recipe: .tiltAlternate),
            Step(world: .city,   rings: 14, radius: 26, pattern: .race,   recipe: .mixedAfterWarmup)
        ],
        .eastTrail: [
            Step(world: .seoul, rings: 8,  radius: 42, pattern: .weave,  recipe: .standard),
            Step(world: .seoul, rings: 10, radius: 36, pattern: .peaks,  recipe: .shrinkingEveryThird),
            Step(world: .wild,  rings: 12, radius: 30, pattern: .sCurve, recipe: .tiltAlternate),
            Step(world: .wild,  rings: 14, radius: 24, pattern: .peaks,  recipe: .mixedAfterWarmup)
        ],
        .deepBlue: [
            Step(world: .ocean, rings: 9,  radius: 40, pattern: .weave,  recipe: .standard),
            Step(world: .ocean, rings: 11, radius: 34, pattern: .sCurve, recipe: .shrinkingEveryThird),
            Step(world: .ocean, rings: 12, radius: 28, pattern: .zigzag, recipe: .tiltAlternate),
            Step(world: .ocean, rings: 16, radius: 22, pattern: .race,   recipe: .mixedAfterWarmup)
        ],
        .starRoad: [
            Step(world: .space, rings: 12, radius: 30, pattern: .sCurve, recipe: .mixedAfterWarmup),
            Step(world: .space, rings: 14, radius: 26, pattern: .peaks,  recipe: .mixedAfterWarmup),
            Step(world: .space, rings: 16, radius: 22, pattern: .race,   recipe: .mixed),
            Step(world: .space, rings: 20, radius: 18, pattern: .race,   recipe: .mixed, comboShrink: true)
        ]
    ]

    /// Courses of a route, in clearing order.
    static func courses(in route: RouteID) -> [StageDefinition] {
        byRoute[route] ?? []
    }

    /// Every campaign course across all routes.
    static let allCourses: [StageDefinition] = RouteID.allCases.flatMap { courses(in: $0) }

    static func course(index: Int) -> StageDefinition? {
        allCourses.first { $0.index == index }
    }

    /// Which route a stage index belongs to, and its 0-based step.
    static func location(of index: Int) -> (route: RouteID, step: Int)? {
        for route in RouteID.allCases {
            let offset = index - route.firstIndex
            if offset >= 0 && offset < courses(in: route).count { return (route, offset) }
        }
        return nil
    }

    /// The course after `index` on the same route, if any.
    static func next(after index: Int) -> StageDefinition? {
        guard let here = location(of: index) else { return nil }
        let list = courses(in: here.route)
        return here.step + 1 < list.count ? list[here.step + 1] : nil
    }

    private static let byRoute: [RouteID: [StageDefinition]] = {
        var out: [RouteID: [StageDefinition]] = [.skySchool: StageDefinition.allStages]
        for (route, list) in steps {
            out[route] = list.enumerated().map { offset, step in
                make(route: route, offset: offset, step: step)
            }
        }
        return out
    }()

    private static func make(route: RouteID, offset: Int, step: Step) -> StageDefinition {
        let count = step.rings
        // Tighter rings come with shorter hops and wider swings.
        let hard = Float(offset) / 3
        return StageDefinition(
            index: route.firstIndex + offset,
            name: "\(route.rawValue) \(offset + 1)",
            koreanName: "\(route.rawValue) \(offset + 1)",
            difficulty: min(5, offset + (route.isFinale ? 3 : 2)),
            description: "",
            ringRadius: step.radius,
            timeLimit: TimeInterval(count * 12),
            star3Time: TimeInterval(count * 5 + 10),
            starCountForPerfect: nil,
            star3Condition: "",
            star2Condition: "",
            learningGoal: "",
            course: CourseSpec(
                pattern: step.pattern, count: count,
                spacing: 170 - 30 * hard, startZ: -180,
                lateralAmplitude: 70 + 40 * hard, angleStep: 0.45 + 0.3 * hard,
                baseAltitude: 450, altitudeAmplitude: step.pattern == .weave ? 10 : 50 + 50 * hard,
                gateRecipe: step.recipe, comboShrink: step.comboShrink
            ),
            world: step.world
        )
    }
}

// MARK: - Kids courses

extension StageDefinition {

    /// The gentlest version of this course: fewer, bigger, plain rings,
    /// no clock. `MissionEngine` also stops counting misses and bumps
    /// against the player when `isKids` is set, so it cannot be failed.
    func kidsVariant() -> StageDefinition {
        guard !isKids, !isSpecial else { return self }
        var easy = self
        easy.isKids = true
        easy.ringRadius = max(45, (ringRadius * 1.6).rounded())
        easy.timeLimit = nil
        easy.star3Time = nil
        easy.starCountForPerfect = nil
        easy.course.count = max(4, Int((Double(course.count) * 0.6).rounded()))
        easy.course.gateRecipe = .standard
        easy.course.comboShrink = false
        easy.course.lateralAmplitude = course.lateralAmplitude * 0.6
        easy.course.altitudeAmplitude = course.altitudeAmplitude * 0.5
        return easy
    }
}
