import Foundation
import SceneKit

/// "Sky Run": an infinite gate course whose rings tighten, crowd and
/// wobble the further you get. Three misses end the run; the score is
/// gates passed + precision points. This is the "one more try" loop —
/// every run is short, every run ends in a number you want to beat.
///
/// Rings are generated in *chunks* so the scene never holds more than a
/// few dozen at once: `MissionEngine` calls back for more when the
/// player is within `refillThreshold` rings of the end of what it has.
enum EndlessCourse {

    static let stageIndex = 200
    /// Misses before the run ends.
    static let maxMisses = 3
    /// Rings generated per chunk.
    static let chunkSize = 24
    /// Ask for another chunk when fewer than this many rings remain ahead.
    static let refillThreshold = 10

    /// Ring radius at ring `index` (0-based, across the whole run).
    /// Starts generous, tightens 0.25 m per ring, floors at 12 m.
    static func radius(at index: Int) -> Float {
        max(12, 44 - Float(index) * 0.25)
    }

    /// Spacing along -Z at ring `index`: tightens from 170 m toward 95 m.
    static func spacing(at index: Int) -> Float {
        max(95, 170 - Float(index) * 0.6)
    }

    /// Lateral / vertical wobble grows with distance so late rings need
    /// bigger corrections between gates.
    static func lateralAmplitude(at index: Int) -> Float {
        min(140, 50 + Float(index) * 0.7)
    }

    static func altitudeAmplitude(at index: Int) -> Float {
        min(120, 30 + Float(index) * 0.5)
    }

    /// Gate kind schedule: plain for the first 8, then a rotation whose
    /// "hard" kinds appear more often deeper in.
    static func gateKind(at index: Int, rng: inout SeededRandom) -> GateKind {
        guard index >= 8 else { return .standard }
        let roll = rng.nextUnit()
        let hardBias = min(0.6, Float(index) / 100)     // up to 60 % non-standard
        guard roll < 0.3 + hardBias else { return .standard }
        switch rng.nextInt(in: 0...2) {
        case 0:  return .shrinking(minScale: 0.5, duration: max(3, 6 - Float(index) / 40))
        case 1:  return .tilt(angleDegrees: rng.nextFloat(in: -60...60), slitRatio: 0.45)
        default: return .moving(axis: rng.nextUnit() < 0.5 ? .lateral : .vertical,
                                amplitude: rng.nextFloat(in: 25...45),
                                period: rng.nextFloat(in: 3...5))
        }
    }

    /// One generated ring.
    struct RingSpec: Equatable {
        let position: SCNVector3
        let radius: Float
        let kind: GateKind

        static func == (lhs: RingSpec, rhs: RingSpec) -> Bool {
            lhs.radius == rhs.radius && lhs.kind == rhs.kind
                && lhs.position.x == rhs.position.x
                && lhs.position.y == rhs.position.y
                && lhs.position.z == rhs.position.z
        }
    }

    /// Generate rings `startIndex ..< startIndex + count`, continuing
    /// from `previousEnd` (the last ring of the previous chunk, or nil
    /// for the first chunk). Deterministic for a given seed + index.
    static func chunk(seed: UInt64, startIndex: Int, count: Int = chunkSize,
                      previousEnd: SCNVector3?) -> [RingSpec] {
        var rng = SeededRandom(seed: seed ^ UInt64(startIndex &* 7919))
        var out: [RingSpec] = []
        out.reserveCapacity(count)
        var z = previousEnd?.z ?? -160
        var baseY = previousEnd?.y ?? 450
        for i in 0..<count {
            let index = startIndex + i
            if i > 0 || previousEnd != nil { z -= spacing(at: index) }
            let angle = Float(index) * 0.55
            let x = sin(angle) * lateralAmplitude(at: index)
                + rng.nextFloat(in: -20...20)
            // Random-walk the base altitude gently so the course drifts
            // up and down instead of oscillating around one line.
            baseY += rng.nextFloat(in: -25...25)
            baseY = min(700, max(180, baseY))
            let y = max(CourseGenerator.minimumAltitude,
                        baseY + sin(angle * 1.3) * altitudeAmplitude(at: index))
            let kind = gateKind(at: index, rng: &rng)
            out.append(RingSpec(position: SCNVector3(x, y, z), radius: radius(at: index), kind: kind))
        }
        return out
    }

    /// Stage shell for the run. The `course` field is a placeholder —
    /// the engine ignores it for endless stages and pulls chunks instead.
    static func stage(seed: UInt64 = UInt64(Date().timeIntervalSince1970)) -> StageDefinition {
        StageDefinition(
            index: stageIndex,
            name: "Sky Run",
            koreanName: "스카이런",
            difficulty: 4,
            description: "끝없는 게이트, 3번 놓치면 끝",
            ringRadius: radius(at: 0),
            timeLimit: nil,
            star3Time: nil,
            starCountForPerfect: nil,
            star3Condition: "",
            star2Condition: "",
            learningGoal: "지구력 + 정밀도",
            course: CourseSpec(pattern: .weave, count: chunkSize, spacing: spacing(at: 0),
                               startZ: -160, lateralAmplitude: 50, angleStep: 0.55,
                               baseAltitude: 450, altitudeAmplitude: 30,
                               jitter: 0, seed: seed, gateRecipe: .standard, comboShrink: true)
        )
    }
}
