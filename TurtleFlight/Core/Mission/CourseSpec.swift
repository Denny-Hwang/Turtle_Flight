import Foundation
import SceneKit

/// Declarative description of a ring course.
///
/// Until Phase 1 every stage's ring layout was a hand-written `sin`
/// formula inside `StageDefinition`. That made three things impossible:
/// tuning a course without a code change, generating a *new* course
/// (Daily Run, Endless), and reproducing a course from a seed. A
/// `CourseSpec` is plain `Codable` data — it can live in Swift, in a JSON
/// resource, or be synthesised at runtime from a date — and
/// `CourseGenerator` turns it into world-space ring positions
/// deterministically.
///
/// Coordinates: the player starts at (0, 500, 0) facing -Z. Rings are
/// laid out along -Z starting `startZ` ahead of the player and stepping
/// `spacing` metres per ring.
struct CourseSpec: Codable, Equatable {

    /// Shape family for the lateral / vertical envelope.
    enum Pattern: String, Codable, CaseIterable {
        /// Gentle sine weave with a slow steady climb. Tutorial feel.
        case weave
        /// Hard left/right alternation at a fixed altitude.
        case zigzag
        /// Sine weave with a slower sine in altitude — continuous S-turns.
        case sCurve
        /// Sine weave with altitude stepping through three tiers.
        case peaks
        /// Two overlapped sines laterally + fast altitude sine. Race course.
        case race
    }

    var pattern: Pattern
    /// Number of rings. Must be > 0.
    var count: Int
    /// Distance along -Z between consecutive rings.
    var spacing: Float
    /// Z of the first ring (negative = ahead of the spawn point).
    var startZ: Float
    /// Peak lateral (X) displacement of the envelope.
    var lateralAmplitude: Float
    /// Radians advanced per ring for the sine envelopes.
    var angleStep: Float
    /// Altitude the envelope is centred on.
    var baseAltitude: Float
    /// Vertical envelope amplitude. For `.weave` this is the per-ring
    /// climb; for `.peaks` the tier height.
    var altitudeAmplitude: Float
    /// Extra per-ring random offset (metres, both axes). Zero = the
    /// classic hand-tuned layouts. Only meaningful with a non-zero seed.
    var jitter: Float
    /// Seed for the jitter RNG. Zero disables jitter entirely so the
    /// campaign stages stay byte-identical to their formula.
    var seed: UInt64
    /// Which gate kinds appear, and where. See `GateRecipe`.
    var gateRecipe: GateRecipe
    /// When true the effective ring radius shrinks as the player's combo
    /// grows (see `MissionEngine.comboRadiusFactor`), so a hot streak
    /// keeps raising the bar on its own.
    var comboShrink: Bool

    init(pattern: Pattern,
         count: Int,
         spacing: Float,
         startZ: Float,
         lateralAmplitude: Float,
         angleStep: Float,
         baseAltitude: Float,
         altitudeAmplitude: Float,
         jitter: Float = 0,
         seed: UInt64 = 0,
         gateRecipe: GateRecipe = .standard,
         comboShrink: Bool = false) {
        self.pattern = pattern
        self.count = count
        self.spacing = spacing
        self.startZ = startZ
        self.lateralAmplitude = lateralAmplitude
        self.angleStep = angleStep
        self.baseAltitude = baseAltitude
        self.altitudeAmplitude = altitudeAmplitude
        self.jitter = jitter
        self.seed = seed
        self.gateRecipe = gateRecipe
        self.comboShrink = comboShrink
    }

    /// Gate kind per ring, from the recipe.
    var gateKinds: [GateKind] { gateRecipe.kinds(count: count) }
}

enum CourseGenerator {

    /// Lowest altitude any generated ring is allowed at. Terrain peaks
    /// reach 300m; `MissionEngine.startStage` additionally clamps rings
    /// above the actual terrain sample, so this is only a sanity floor.
    static let minimumAltitude: Float = 80

    /// World-space ring centres for `spec`. Pure function of its input.
    static func generate(_ spec: CourseSpec) -> [SCNVector3] {
        guard spec.count > 0 else { return [] }
        var rng = SeededRandom(seed: spec.seed)
        var rings: [SCNVector3] = []
        rings.reserveCapacity(spec.count)

        for i in 0..<spec.count {
            let fi = Float(i)
            let angle = fi * spec.angleStep
            var x: Float
            var y: Float

            switch spec.pattern {
            case .weave:
                x = sin(angle) * spec.lateralAmplitude
                y = spec.baseAltitude + fi * spec.altitudeAmplitude
            case .zigzag:
                x = (i % 2 == 0) ? -spec.lateralAmplitude : spec.lateralAmplitude
                y = spec.baseAltitude
            case .sCurve:
                x = sin(angle) * spec.lateralAmplitude
                y = spec.baseAltitude + sin(angle * 0.5) * spec.altitudeAmplitude
            case .peaks:
                x = sin(angle) * spec.lateralAmplitude
                y = spec.baseAltitude + Float(i % 3) * spec.altitudeAmplitude
            case .race:
                x = sin(angle) * spec.lateralAmplitude
                    + cos(angle * 0.7) * spec.lateralAmplitude * (2.0 / 3.0)
                y = spec.baseAltitude + sin(angle * 1.5) * spec.altitudeAmplitude
            }

            if spec.seed != 0 && spec.jitter > 0 {
                x += rng.nextFloat(in: -spec.jitter...spec.jitter)
                y += rng.nextFloat(in: -spec.jitter...spec.jitter)
            }

            y = max(y, minimumAltitude)
            let z = spec.startZ - fi * spec.spacing
            rings.append(SCNVector3(x, y, z))
        }
        return rings
    }

    /// Unit horizontal travel direction through each ring, derived from
    /// its neighbours (central difference; one-sided at the ends). Rings
    /// face the direction the player is expected to fly through them, so
    /// `MissionEngine` can do a proper plane-crossing test instead of a
    /// sphere-distance check.
    static func normals(for positions: [SCNVector3]) -> [SCNVector3] {
        guard !positions.isEmpty else { return [] }
        if positions.count == 1 { return [SCNVector3(0, 0, -1)] }
        var out: [SCNVector3] = []
        out.reserveCapacity(positions.count)
        for i in 0..<positions.count {
            let prev = positions[max(i - 1, 0)]
            let next = positions[min(i + 1, positions.count - 1)]
            var d = SCNVector3(next.x - prev.x, 0, next.z - prev.z)
            if d.length < 0.001 { d = SCNVector3(0, 0, -1) }
            out.append(d.normalized)
        }
        return out
    }
}
