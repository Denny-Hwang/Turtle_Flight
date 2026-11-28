import Foundation
import SceneKit

/// Set pieces along the route ("길목 볼거리", docs/FLIGHT_FUN_PLAN.md §4).
///
/// Instead of detailing the whole map, Free Flight puts one distinctive
/// sculpture or item in the player's path every 25–35 seconds, at the
/// player's own height so it is seen head-on rather than from above. Two
/// per world are for flying through (an arch, a tunnel, a gate); one does
/// something when touched (an updraft, a boost refill, a bundle of stars).
///
/// All original designs built from SceneKit primitives (`SetPieceFactory`)
/// — no real-world landmark is reproduced. Free Flight only: missions keep
/// their focus on the rings. Raw values are persisted in `SetPieceLog` —
/// never rename a case.
enum SetPiece: String, CaseIterable, Codable, Sendable {
    // sky
    case rainbowArch, cloudTunnel, thermal
    // desert
    case sandWindRing, cactusGate, mirageOasis
    // city
    case flagLine, laundryBridge, bubbleFountain
    // seoul
    case lanternTunnel, roofGate, kiteWind
    // wild
    case waterfallArch, logBridge, fireflies
    // space
    case ringedPlanet, constellationGate, cometTail
    // ocean
    case kelpArch, coralGate, bubbleColumn

    /// What touching it does.
    enum Effect: Equatable, Sendable {
        /// Fly through the opening: +1 star.
        case passThrough
        /// Rise while inside the column.
        case lift
        /// Refill part of the boost gauge.
        case boost
        /// A bundle of stars.
        case stars
    }

    var world: MapTheme {
        switch self {
        case .rainbowArch, .cloudTunnel, .thermal:               return .sky
        case .sandWindRing, .cactusGate, .mirageOasis:           return .desert
        case .flagLine, .laundryBridge, .bubbleFountain:         return .city
        case .lanternTunnel, .roofGate, .kiteWind:               return .seoul
        case .waterfallArch, .logBridge, .fireflies:             return .wild
        case .ringedPlanet, .constellationGate, .cometTail:      return .space
        case .kelpArch, .coralGate, .bubbleColumn:               return .ocean
        }
    }

    var effect: Effect {
        switch self {
        case .thermal, .bubbleColumn:               return .lift
        case .bubbleFountain, .kiteWind, .cometTail: return .boost
        case .mirageOasis, .fireflies:              return .stars
        default:                                    return .passThrough
        }
    }

    var displayName: String { L10n.t("setpiece.\(rawValue).name") }

    static func pieces(for world: MapTheme) -> [SetPiece] {
        allCases.filter { $0.world == world }
    }

    // MARK: - Geometry (local frame: built facing -Z, origin = opening /
    // effect centre)

    /// Radius of the fly-through opening, or of the touch zone.
    var zoneRadius: Float {
        switch effect {
        case .passThrough: return 48
        case .lift:        return 45
        case .boost:       return 60
        case .stars:       return 70
        }
    }

    /// Half the vertical extent of a lift column.
    static let liftHalfHeight: Float = 220
    /// Climb rate inside a lift column (m/s), on top of the player's own.
    static let liftRate: Float = 30
    /// Boost gauge refill.
    static let boostRefill: Float = 0.5
    /// Stars from a `.stars` piece, and from flying through an opening.
    static let bundleStars = 3
    static let passStars = 1

    /// How far below the centre the piece reaches (keeps it off the ground).
    var depthBelowCentre: Float {
        effect == .lift ? Self.liftHalfHeight : 90
    }
}

/// When the next set piece is due and which one. Pure (seeded), so tests
/// can pin the rhythm.
struct SetPieceScheduler {
    static let interval: ClosedRange<Float> = 25...35
    static let firstDelay: ClosedRange<Float> = 12...18
    static let spawnDistance: ClosedRange<Float> = 420...560
    /// Sideways offset of a fly-through opening from the current path.
    static let lateralJitter: Float = 45
    /// Postpone when the spawn point is this close to a landmark.
    static let landmarkClearance: Float = 350
    static let retryDelay: Float = 4
    /// Never more than this many in the sky at once.
    static let maxActive = 2

    let world: MapTheme
    private var rng: SeededRandom
    private var queue: [SetPiece] = []
    private var last: SetPiece?
    private(set) var nextTime: Float
    /// QA (`-TFSetPiece`): this one first, three seconds in.
    private var forced: SetPiece?

    init(world: MapTheme, seed: Int, forced: SetPiece? = nil) {
        self.world = world
        self.rng = SeededRandom(seed: seed)
        self.forced = forced
        self.nextTime = forced != nil ? 3 : 0
        if forced == nil { nextTime = rng.nextFloat(in: Self.firstDelay) }
    }

    func isDue(at clock: Float) -> Bool { clock >= nextTime }

    /// Something blocked the spawn (a landmark, a wonder): try again soon.
    mutating func postpone(from clock: Float) {
        nextTime = clock + Self.retryDelay
    }

    /// Take the next piece and schedule the one after. Cycles the world's
    /// pieces in a shuffled order, never the same one twice in a row.
    mutating func take(at clock: Float) -> (piece: SetPiece, distance: Float, lateral: Float) {
        nextTime = clock + rng.nextFloat(in: Self.interval)
        let distance = rng.nextFloat(in: Self.spawnDistance)
        let lateral = rng.nextFloat(in: -Self.lateralJitter...Self.lateralJitter)
        if let forced {
            self.forced = nil
            return (forced, distance, 0)
        }
        if queue.isEmpty {
            var fresh = SetPiece.pieces(for: world)
            for i in stride(from: fresh.count - 1, to: 0, by: -1) {
                fresh.swapAt(i, rng.nextInt(in: 0...i))
            }
            // No repeat across the shuffle boundary.
            if fresh.count > 1, fresh.first == last { fresh.swapAt(0, fresh.count - 1) }
            queue = fresh
        }
        let piece = queue.removeFirst()
        last = piece
        return (piece, distance, lateral)
    }
}

/// A set piece in the sky right now.
struct ActiveSetPiece {
    let piece: SetPiece
    let node: SCNNode
    let center: SCNVector3
    /// Unit vector the player was flying along when it spawned; the
    /// opening faces it.
    let forward: SIMD2<Float>
    var used = false
    var inLift = false

    /// Signed distance past the opening's plane along `forward`.
    func distancePast(_ p: SCNVector3) -> Float {
        (p.x - center.x) * forward.x + (p.z - center.z) * forward.y
    }

    /// True when the segment `from → to` goes through the opening.
    func passes(from: SCNVector3, to: SCNVector3) -> Bool {
        let d0 = distancePast(from), d1 = distancePast(to)
        guard d0 < 0, d1 >= 0 else { return false }
        let t = d1 - d0 > 0 ? -d0 / (d1 - d0) : 0
        let hit = SCNVector3(from.x + (to.x - from.x) * t,
                             from.y + (to.y - from.y) * t,
                             from.z + (to.z - from.z) * t)
        let dx = hit.x - center.x, dy = hit.y - center.y, dz = hit.z - center.z
        return (dx * dx + dy * dy + dz * dz).squareRoot() <= piece.zoneRadius
    }

    /// Inside the touch zone (a vertical column for lifts, a ball otherwise).
    func contains(_ p: SCNVector3) -> Bool {
        let dx = p.x - center.x, dy = p.y - center.y, dz = p.z - center.z
        let r = piece.zoneRadius
        if piece.effect == .lift {
            return dx * dx + dz * dz <= r * r && abs(dy) <= SetPiece.liftHalfHeight
        }
        return dx * dx + dy * dy + dz * dz <= r * r
    }
}

/// Which set pieces the player has been through / used. On-device only
/// (`setpieces.v1`); the album page (W5) reads it.
/// `@unchecked Sendable`: `seen` is only touched under `lock`.
final class SetPieceLog: @unchecked Sendable {
    static let shared = SetPieceLog()

    private let defaults: UserDefaults
    private let key = "setpieces.v1"
    private let lock = NSLock()
    private var seen: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.seen = Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// True the first time.
    @discardableResult
    func record(_ piece: SetPiece) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard seen.insert(piece.rawValue).inserted else { return false }
        defaults.set(seen.sorted(), forKey: key)
        return true
    }

    func hasSeen(_ piece: SetPiece) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return seen.contains(piece.rawValue)
    }

    var seenCount: Int {
        lock.lock(); defer { lock.unlock() }
        return SetPiece.allCases.filter { seen.contains($0.rawValue) }.count
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        seen = []
        defaults.removeObject(forKey: key)
    }
}
