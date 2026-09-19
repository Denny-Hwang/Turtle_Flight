import Foundation

/// Behaviour of a single gate beyond "a ring hanging in the air".
///
/// Each kind changes what precise control the player has to demonstrate:
///   • `standard`  — the classic torus.
///   • `shrinking` — starts at full size the moment it becomes the target
///     and shrinks toward `minScale` over `duration` seconds. Dawdling is
///     punished; committing early is rewarded.
///   • `tilt`      — an elliptical slit (minor axis `slitRatio` × radius)
///     rotated `angleDegrees` about the course direction. Threading it
///     needs both lateral and vertical precision at once.
///   • `moving`    — the centre oscillates sideways (`.lateral`) or
///     vertically (`.vertical`) by `amplitude` metres with `period`
///     seconds per cycle. Timing joins precision.
enum GateKind: Codable, Equatable {
    case standard
    case shrinking(minScale: Float, duration: Float)
    case tilt(angleDegrees: Float, slitRatio: Float)
    case moving(axis: MoveAxis, amplitude: Float, period: Float)

    enum MoveAxis: String, Codable, Equatable {
        case lateral
        case vertical
    }

    /// Stable identifier for analytics / tests.
    var name: String {
        switch self {
        case .standard:  return "standard"
        case .shrinking: return "shrinking"
        case .tilt:      return "tilt"
        case .moving:    return "moving"
        }
    }

    // MARK: - Presets used by the campaign recipes

    static let defaultShrinking = GateKind.shrinking(minScale: 0.5, duration: 6)
    static let defaultTilt      = GateKind.tilt(angleDegrees: 45, slitRatio: 0.45)
    static let defaultMoving    = GateKind.moving(axis: .lateral, amplitude: 40, period: 4)
}

/// How a course assigns gate kinds to its rings. Kept as data on
/// `CourseSpec` so a Daily Run can pick a recipe by seed and a stage can
/// pin one by hand.
enum GateRecipe: String, Codable, CaseIterable, Equatable {
    /// Every ring is a standard torus.
    case standard
    /// Every third ring (starting with the 3rd) shrinks.
    case shrinkingEveryThird
    /// Every other ring from the 2nd is a tilted slit.
    case tiltAlternate
    /// Rotates standard → shrinking → tilt → moving.
    case mixed
    /// Standard for the first three, then the mixed rotation.
    case mixedAfterWarmup

    /// Gate kinds for a course of `count` rings.
    func kinds(count: Int) -> [GateKind] {
        guard count > 0 else { return [] }
        return (0..<count).map { kind(at: $0) }
    }

    func kind(at index: Int) -> GateKind {
        switch self {
        case .standard:
            return .standard
        case .shrinkingEveryThird:
            return (index + 1) % 3 == 0 ? .defaultShrinking : .standard
        case .tiltAlternate:
            return index % 2 == 1 ? .defaultTilt : .standard
        case .mixed:
            return Self.rotation[index % Self.rotation.count]
        case .mixedAfterWarmup:
            return index < 3 ? .standard : Self.rotation[(index - 3) % Self.rotation.count]
        }
    }

    private static let rotation: [GateKind] = [
        .standard, .defaultShrinking, .defaultTilt, .defaultMoving
    ]
}
