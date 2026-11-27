import Foundation
import SceneKit
import UIKit

/// Free Flight ring trails (R2, docs/FLIGHT_FUN_PLAN.md §3.2; owner
/// 2026-11-27 "넣어줘"). Free Flight had no rings at all; now every
/// 30–40 s a short trail of five rings appears ahead, bending toward the
/// nearest landmark not yet stamped. Fly them all for stars and a boost
/// refill. Optional: nothing happens if the player ignores it.
struct RingTrail {
    static let count = 5
    static let firstOffset: Float = 300
    static let spacing: Float = 110
    /// Largest turn between consecutive rings (degrees).
    static let maxTurn: Float = 15
    /// Gentle height changes only (well under the course slope limit).
    static let maxSlope: Float = 0.25
    static let radius: Float = 30
    static let groundClearance: Float = 60
    /// Reward for flying all five.
    static let completeStars = 3
    static let boostRefill: Float = 0.5
    /// The trail fades once the player is this far past its last ring,
    /// or after `lifetime` seconds.
    static let leaveDistance: Float = 350
    static let lifetime: Float = 45

    struct Gate {
        let center: SIMD3<Float>
        /// Horizontal unit vector the player flies through it along.
        let forward: SIMD2<Float>
        var passed = false
    }

    private(set) var gates: [Gate]
    private(set) var age: Float = 0
    /// Index of the next ring to fly (rings must be taken in order).
    private(set) var next = 0

    var isComplete: Bool { next >= gates.count }

    /// Lay out the trail ahead of `position` (heading in degrees, 0 =
    /// north / -Z), turning toward `targetBearing` (degrees relative to
    /// the heading, nil = straight on). `ground(x, z)` keeps rings clear.
    init(position p: SIMD3<Float>, heading: Float, targetBearing: Float?,
         seed: Int, ground: (Float, Float) -> Float) {
        var rng = SeededRandom(seed: seed)
        var h = heading
        var remaining = targetBearing ?? 0
        var point = p
        var y = p.y
        var gates: [Gate] = []
        for i in 0..<Self.count {
            if i > 0 {
                let turn = max(-Self.maxTurn, min(Self.maxTurn, remaining))
                h += turn
                remaining -= turn
            }
            let rad = h * .pi / 180
            let f = SIMD2<Float>(sin(rad), -cos(rad))
            let step = i == 0 ? Self.firstOffset : Self.spacing
            point += SIMD3(f.x, 0, f.y) * step
            let wave = rng.nextFloat(in: -1...1) * step * Self.maxSlope * 0.8
            let floor = ground(point.x, point.z) + Self.groundClearance + Self.radius
            y = max(floor, min(y + step * Self.maxSlope, max(y - step * Self.maxSlope, y + wave)))
            gates.append(Gate(center: SIMD3(point.x, y, point.z), forward: f))
        }
        self.gates = gates
    }

    /// Advance by one sightseeing tick. Returns the index of the ring
    /// just flown through, if any.
    mutating func step(deltaTime: Float, from a: SIMD3<Float>, to b: SIMD3<Float>) -> Int? {
        age += deltaTime
        guard next < gates.count else { return nil }
        let gate = gates[next]
        let d0 = simd_dot(SIMD2(a.x - gate.center.x, a.z - gate.center.z), gate.forward)
        let d1 = simd_dot(SIMD2(b.x - gate.center.x, b.z - gate.center.z), gate.forward)
        guard d0 < 0, d1 >= 0 else {
            // Flew past this one without going through: skip it, so the
            // rest of the trail is still worth chasing.
            if d1 > Self.spacing * 0.6 { next += 1 }
            return nil
        }
        let t = d1 - d0 > 0 ? -d0 / (d1 - d0) : 0
        let hit = a + (b - a) * t
        guard simd_distance(hit, gate.center) <= Self.radius else {
            next += 1
            return nil
        }
        gates[next].passed = true
        next += 1
        return next - 1
    }

    var passedCount: Int { gates.filter(\.passed).count }
    var allPassed: Bool { passedCount == gates.count }

    /// Done with: flown, left well behind, or timed out.
    func isFinished(playerPosition p: SIMD3<Float>) -> Bool {
        guard let last = gates.last else { return true }
        let past = simd_dot(SIMD2(p.x - last.center.x, p.z - last.center.z), last.forward)
        return isComplete && past > 40 || past > Self.leaveDistance || age > Self.lifetime
    }
}

/// When the next trail comes. Seeded.
struct RingTrailScheduler {
    static let firstDelay: ClosedRange<Float> = 28...38
    static let interval: ClosedRange<Float> = 30...40
    private var rng: SeededRandom
    private(set) var nextTime: Float

    init(seed: Int, forcedSoon: Bool = false) {
        rng = SeededRandom(seed: seed)
        nextTime = forcedSoon ? 2 : rng.nextFloat(in: Self.firstDelay)
    }

    func isDue(at clock: Float) -> Bool { clock >= nextTime }

    /// A trail was laid; the next one counts from when this one ends.
    mutating func taken() { nextTime = .greatestFiniteMagnitude }
    mutating func finished(at clock: Float) { nextTime = clock + rng.nextFloat(in: Self.interval) }
    mutating func postpone(from clock: Float) { nextTime = clock + 5 }
    mutating func nextSeed() -> Int { Int(rng.next() >> 33) }
}

/// Mint rings, so a trail never reads as a mission course (gold target,
/// blue idle).
enum RingTrailFactory {
    static let idle = UIColor(red: 0.45, green: 0.95, blue: 0.80, alpha: 0.55)
    static let next = UIColor(red: 0.55, green: 1.0, blue: 0.85, alpha: 1)

    static func build(_ trail: RingTrail) -> SCNNode {
        let root = SCNNode()
        root.name = "ring_trail"
        for (i, gate) in trail.gates.enumerated() {
            let ring = SCNNode()
            ring.name = "trail_\(i)"
            let torus = SCNTorus(ringRadius: CGFloat(RingTrail.radius), pipeRadius: 2.2)
            let m = SCNMaterial()
            m.diffuse.contents = idle
            m.emission.contents = idle
            m.lightingModel = .constant
            torus.materials = [m]
            let shape = SCNNode(geometry: torus)
            shape.eulerAngles.x = .pi / 2
            ring.addChildNode(shape)
            ring.position = SCNVector3(gate.center.x, gate.center.y, gate.center.z)
            // Same convention as mission rings: yaw from the travel direction.
            ring.eulerAngles.y = atan2(gate.forward.x, gate.forward.y)
            ring.opacity = 0
            ring.runAction(.sequence([.wait(duration: 0.15 * Double(i)), .fadeIn(duration: 0.6)]))
            root.addChildNode(ring)
        }
        highlight(root, next: 0)
        return root
    }

    /// Brighten the ring to fly next, and pop the one just flown.
    static func highlight(_ root: SCNNode, next: Int, popped: Int? = nil) {
        if let popped, let ring = root.childNode(withName: "trail_\(popped)", recursively: false) {
            // Shrink away rather than swell: the ring is right by the
            // camera when it is flown, and growing it covered the screen.
            ring.removeAction(forKey: "pulse")
            ring.runAction(.sequence([.group([.scale(to: 0.4, duration: 0.25), .fadeOut(duration: 0.2)]),
                                      .removeFromParentNode()]))
        }
        guard let ring = root.childNode(withName: "trail_\(next)", recursively: false) else { return }
        ring.enumerateChildNodes { node, _ in
            node.geometry?.firstMaterial?.diffuse.contents = Self.next
            node.geometry?.firstMaterial?.emission.contents = Self.next
        }
        ring.runAction(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.5), .scale(to: 1.0, duration: 0.5)])),
                       forKey: "pulse")
    }
}
