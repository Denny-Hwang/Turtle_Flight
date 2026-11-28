import Foundation
import SceneKit
import UIKit

/// Companions (W4, docs/FLIGHT_FUN_PLAN.md §4): now and then in Free
/// Flight a small flock from the world comes in from ahead, falls in
/// beside the character for a few seconds, then peels away. Flying in
/// close to them pays a star. Original, primitive-built animals; Free
/// Flight only.
enum Companion: String, CaseIterable, Sendable {
    case geese, sandpipers, pigeons, magpies, eagles, satellites, dolphins

    static func of(_ world: MapTheme) -> Companion {
        switch world {
        case .sky:    return .geese
        case .desert: return .sandpipers
        case .city:   return .pigeons
        case .seoul:  return .magpies
        case .wild:   return .eagles
        case .space:  return .satellites
        case .ocean:  return .dolphins
        }
    }

    var displayName: String { L10n.t("companion.\(rawValue).name") }

    /// Where each member sits in the flock (metres; x right, y up,
    /// z back — the flock flies toward -Z).
    var formation: [SIMD3<Float>] {
        switch self {
        case .geese:      return [SIMD3(0, 0, 0), SIMD3(-7, 0, 7), SIMD3(7, 0, 7), SIMD3(-14, 0, 14), SIMD3(14, 0, 14)]
        case .sandpipers: return [SIMD3(0, 0, 0), SIMD3(6, 1, 4), SIMD3(-5, -1, 6), SIMD3(2, 2, 10)]
        case .pigeons:    return [SIMD3(0, 0, 0), SIMD3(-6, 2, 3), SIMD3(5, -1, 5), SIMD3(-2, 1, 9)]
        case .magpies:    return [SIMD3(0, 0, 0), SIMD3(8, 1, 5)]
        case .eagles:     return [SIMD3(0, 0, 0), SIMD3(-12, 3, 8)]
        case .satellites: return [SIMD3(0, 0, 0), SIMD3(10, 4, 6), SIMD3(-10, -3, 8)]
        case .dolphins:   return [SIMD3(0, 0, 0), SIMD3(-8, -2, 5), SIMD3(8, 1, 7)]
        }
    }

    // MARK: Timing (seconds) and placement (metres)

    static let firstDelay: ClosedRange<Float> = 40...70
    static let interval: ClosedRange<Float> = 70...110
    static let approachTime: Float = 3.5
    static let cruiseTime: Float = 12
    static let leaveTime: Float = 3
    /// Spawn point ahead of the character, and the slot beside it.
    static let spawnAhead: Float = 170
    static let slotSide: Float = 26
    static let slotAhead: Float = 6
    static let slotUp: Float = 5
    /// Fly within this of the flock's lead during the cruise for the star.
    static let greetRadius: Float = 20
    static let greetStars = 1
}

/// One flock's flight with the character. Pure state machine over time
/// and the character's pose, so tests can drive it without SceneKit.
struct CompanionFlight {
    enum Phase: Equatable { case approach, cruise, leave, done }

    let companion: Companion
    /// +1 = flock flies on the character's right, -1 = left.
    let side: Float
    private(set) var age: Float = 0
    private(set) var position: SIMD3<Float>
    private(set) var heading: Float
    private(set) var greeted = false

    init(companion: Companion, side: Float, characterPosition p: SIMD3<Float>, heading: Float) {
        self.companion = companion
        self.side = side
        self.heading = heading
        let f = Self.forward(heading)
        let r = SIMD3<Float>(-f.z, 0, f.x)
        position = p + f * Companion.spawnAhead + r * side * Companion.slotSide * 2.5 + SIMD3(0, 18, 0)
    }

    var phase: Phase {
        if age < Companion.approachTime { return .approach }
        if age < Companion.approachTime + Companion.cruiseTime { return .cruise }
        if age < Companion.approachTime + Companion.cruiseTime + Companion.leaveTime { return .leave }
        return .done
    }

    /// 0…1 visibility (fades in on approach, out on leave).
    var opacity: Float {
        switch phase {
        case .approach: return min(1, age / 1.2)
        case .cruise: return 1
        case .leave: return max(0, 1 - (age - Companion.approachTime - Companion.cruiseTime) / Companion.leaveTime)
        case .done: return 0
        }
    }

    static func forward(_ headingDegrees: Float) -> SIMD3<Float> {
        let h = headingDegrees * .pi / 180
        return SIMD3(sin(h), 0, -cos(h))
    }

    /// The slot beside the character the flock settles into.
    func slot(characterPosition p: SIMD3<Float>, heading h: Float) -> SIMD3<Float> {
        let f = Self.forward(h)
        let r = SIMD3<Float>(-f.z, 0, f.x)
        return p + f * Companion.slotAhead + r * side * Companion.slotSide + SIMD3(0, Companion.slotUp, 0)
    }

    /// Advance one frame. Returns true the moment the character earns the
    /// greeting star.
    mutating func step(deltaTime dt: Float, characterPosition p: SIMD3<Float>,
                       heading h: Float, speedMetresPerSecond v: Float) -> Bool {
        age += dt
        let f = Self.forward(h)
        switch phase {
        case .approach, .cruise:
            // Fly at the character's speed, then ease toward the slot
            // (without the speed term the flock trails ~v/rate behind).
            position += f * v * dt
            let target = slot(characterPosition: p, heading: h)
            let k: Float = phase == .approach ? 1 - exp(-dt * 1.6) : 1 - exp(-dt * 4)
            position += (target - position) * k
            heading = Self.blendHeading(heading, toward: h, k: k)
        case .leave:
            // Peel off: keep going forward, drift outward and up.
            let r = SIMD3<Float>(-f.z, 0, f.x)
            position += (f * v + r * side * 14 + SIMD3(0, 9, 0)) * dt
            heading = Self.blendHeading(heading, toward: h + side * 25, k: 1 - exp(-dt))
        case .done:
            break
        }
        guard phase == .cruise, !greeted, simd_distance(position, p) < Companion.greetRadius else { return false }
        greeted = true
        return true
    }

    static func blendHeading(_ a: Float, toward b: Float, k: Float) -> Float {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return a + d * k
    }
}

/// When the next flock comes. Seeded.
struct CompanionScheduler {
    private var rng: SeededRandom
    private(set) var nextTime: Float

    init(seed: Int, forcedSoon: Bool = false) {
        rng = SeededRandom(seed: seed)
        nextTime = forcedSoon ? 2 : rng.nextFloat(in: Companion.firstDelay)
    }

    func isDue(at clock: Float) -> Bool { clock >= nextTime }

    /// Schedule the next one; returns the side the new flock takes.
    mutating func take(at clock: Float) -> Float {
        nextTime = clock + rng.nextFloat(in: Companion.interval)
        return rng.nextUnit() < 0.5 ? -1 : 1
    }

    mutating func postpone(from clock: Float) { nextTime = clock + 6 }
}

/// Builds the flocks from primitives. Members flap / bob on their own
/// actions; the root is moved by `CompanionFlight`.
enum CompanionFactory {

    static func build(_ companion: Companion) -> SCNNode {
        let root = SCNNode()
        root.name = "companion_\(companion.rawValue)"
        for (i, offset) in companion.formation.enumerated() {
            let member = member(companion, index: i)
            member.position = SCNVector3(offset.x, offset.y, offset.z)
            root.addChildNode(member)
        }
        root.opacity = 0
        return root
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    @discardableResult
    private static func put(_ g: SCNGeometry, _ c: UIColor, in parent: SCNNode, at p: SCNVector3 = SCNVector3Zero,
                            scale: SCNVector3 = SCNVector3(1, 1, 1)) -> SCNNode {
        let m = SCNMaterial()
        m.diffuse.contents = c
        g.materials = [m]
        let n = SCNNode(geometry: g)
        n.position = p
        n.scale = scale
        parent.addChildNode(n)
        return n
    }

    private static func member(_ c: Companion, index i: Int) -> SCNNode {
        switch c {
        case .geese:      return bird(body: rgb(0.66, 0.60, 0.52), wing: rgb(0.52, 0.47, 0.41), head: rgb(0.15, 0.15, 0.17),
                                      size: 1.5, flap: 0.55, period: 0.9, phase: i, neck: true)
        case .sandpipers: return bird(body: rgb(0.86, 0.72, 0.52), wing: rgb(0.66, 0.52, 0.36), head: rgb(0.86, 0.72, 0.52),
                                      size: 0.9, flap: 0.7, period: 0.35, phase: i)
        case .pigeons:    return bird(body: rgb(0.62, 0.66, 0.74), wing: rgb(0.52, 0.56, 0.66), head: rgb(0.40, 0.55, 0.55),
                                      size: 1.0, flap: 0.65, period: 0.45, phase: i)
        case .magpies:
            let b = bird(body: rgb(0.12, 0.12, 0.16), wing: rgb(0.95, 0.95, 0.97), head: rgb(0.10, 0.10, 0.14),
                         size: 1.1, flap: 0.6, period: 0.5, phase: i)
            put(SCNBox(width: 0.8, height: 0.25, length: 4.5, chamferRadius: 0.2), rgb(0.15, 0.20, 0.35), in: b,
                at: SCNVector3(0, 0.3, 3.6))
            return b
        case .eagles:     return bird(body: rgb(0.45, 0.32, 0.20), wing: rgb(0.38, 0.27, 0.17), head: rgb(0.95, 0.95, 0.92),
                                      size: 2.2, flap: 0.25, period: 2.2, phase: i)
        case .satellites: return satellite(phase: i)
        case .dolphins:   return dolphin(phase: i)
        }
    }

    /// Body, head, beak, tail fan and two tapered flapping wings (inner
    /// and outer feathers, so it reads as a bird, never a plane).
    /// `size` ~ metres of body; `neck` lifts the head on a neck (geese).
    private static func bird(body: UIColor, wing: UIColor, head: UIColor, size s: Float,
                             flap: Float, period: TimeInterval, phase: Int, neck: Bool = false) -> SCNNode {
        let n = SCNNode()
        put(SCNSphere(radius: CGFloat(s)), body, in: n, scale: SCNVector3(0.75, 0.7, 1.35))
        let headAt = neck ? SCNVector3(0, s * 0.75, -s * 2.4) : SCNVector3(0, s * 0.3, -s * 1.5)
        if neck {
            let neckNode = put(SCNCylinder(radius: CGFloat(s * 0.22), height: CGFloat(s * 1.4)), head, in: n,
                               at: SCNVector3(0, s * 0.45, -s * 1.75))
            neckNode.eulerAngles.x = -0.95
        }
        put(SCNSphere(radius: CGFloat(s * (neck ? 0.38 : 0.5))), head, in: n, at: headAt)
        let beak = put(SCNCone(topRadius: 0, bottomRadius: CGFloat(s * 0.16), height: CGFloat(s * 0.6)),
                       rgb(1.0, 0.62, 0.2), in: n, at: SCNVector3(headAt.x, headAt.y - s * 0.05, headAt.z - s * 0.55))
        beak.eulerAngles.x = -.pi / 2
        // Tail fan.
        let tail = put(SCNPyramid(width: CGFloat(s * 1.1), height: CGFloat(s * 1.2), length: CGFloat(s * 0.1)), wing, in: n,
                       at: SCNVector3(0, 0, s * 1.2))
        tail.eulerAngles.x = .pi / 2
        for side: Float in [-1, 1] {
            let shoulder = SCNNode()
            shoulder.position = SCNVector3(side * s * 0.55, s * 0.2, -s * 0.15)
            // Inner wing: broad at the body.
            put(SCNBox(width: CGFloat(s * 1.4), height: CGFloat(s * 0.1), length: CGFloat(s * 0.95), chamferRadius: CGFloat(s * 0.05)),
                wing, in: shoulder, at: SCNVector3(side * s * 0.7, 0, 0))
            // Outer feathers: narrower and swept back, flexing with the beat.
            let elbow = SCNNode()
            elbow.position = SCNVector3(side * s * 1.4, 0, 0)
            let outer = put(SCNBox(width: CGFloat(s * 1.3), height: CGFloat(s * 0.08), length: CGFloat(s * 0.55),
                                   chamferRadius: CGFloat(s * 0.04)),
                            wing, in: elbow, at: SCNVector3(side * s * 0.6, 0, s * 0.18))
            outer.eulerAngles.y = side * 0.35
            shoulder.addChildNode(elbow)
            n.addChildNode(shoulder)
            let up = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(side * flap), duration: period / 2, usesShortestUnitArc: true)
            let down = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(-side * flap * 0.6), duration: period / 2, usesShortestUnitArc: true)
            up.timingMode = .easeInEaseOut
            down.timingMode = .easeInEaseOut
            shoulder.runAction(.sequence([.wait(duration: Double(phase) * 0.13), .repeatForever(.sequence([up, down]))]))
            let flexUp = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(side * flap * 0.5), duration: period / 2, usesShortestUnitArc: true)
            let flexDown = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(-side * flap * 0.4), duration: period / 2, usesShortestUnitArc: true)
            elbow.runAction(.sequence([.wait(duration: Double(phase) * 0.13 + period * 0.1),
                                       .repeatForever(.sequence([flexUp, flexDown]))]))
        }
        return n
    }

    private static func satellite(phase: Int) -> SCNNode {
        let n = SCNNode()
        put(SCNBox(width: 2.4, height: 2.4, length: 3.2, chamferRadius: 0.4), rgb(0.85, 0.80, 0.55), in: n)
        for side: Float in [-1, 1] {
            put(SCNBox(width: 6, height: 0.2, length: 2.4, chamferRadius: 0.1), rgb(0.25, 0.40, 0.85), in: n,
                at: SCNVector3(side * 4.4, 0, 0))
        }
        let dish = put(SCNCone(topRadius: 1.4, bottomRadius: 0.2, height: 0.8), UIColor(white: 0.92, alpha: 1), in: n,
                       at: SCNVector3(0, 1.7, 0))
        dish.eulerAngles.x = 0.4
        let light = put(SCNSphere(radius: 0.35), rgb(1, 0.3, 0.3), in: n, at: SCNVector3(0, -1.4, 0))
        light.geometry?.firstMaterial?.emission.contents = UIColor.red
        light.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.2, duration: 0.5), .fadeOpacity(to: 1, duration: 0.5)])))
        n.runAction(.sequence([.wait(duration: Double(phase) * 0.4),
                               .repeatForever(.rotateBy(x: 0, y: 0, z: .pi * 2, duration: 14))]))
        return n
    }

    private static func dolphin(phase: Int) -> SCNNode {
        let n = SCNNode()
        let body = rgb(0.45, 0.58, 0.72)
        put(SCNSphere(radius: 1.6), body, in: n, scale: SCNVector3(0.7, 0.65, 2.3))
        put(SCNSphere(radius: 0.9), rgb(0.85, 0.90, 0.95), in: n, at: SCNVector3(0, -0.5, -1.2), scale: SCNVector3(0.8, 0.5, 1.6))
        put(SCNCone(topRadius: 0, bottomRadius: 0.5, height: 1.6), body, in: n, at: SCNVector3(0, 0.1, -4.1))
            .eulerAngles.x = -.pi / 2
        put(SCNPyramid(width: 0.3, height: 1.4, length: 1.4), body, in: n, at: SCNVector3(0, 0.8, 0.3))
        let tail = put(SCNBox(width: 2.6, height: 0.2, length: 0.9, chamferRadius: 0.1), body, in: n, at: SCNVector3(0, 0, 3.9))
        tail.runAction(.repeatForever(.sequence([.rotateTo(x: 0.35, y: 0, z: 0, duration: 0.45),
                                                 .rotateTo(x: -0.35, y: 0, z: 0, duration: 0.45)])))
        n.runAction(.sequence([.wait(duration: Double(phase) * 0.3),
                               .repeatForever(.sequence([.moveBy(x: 0, y: 2.5, z: 0, duration: 1.1),
                                                         .moveBy(x: 0, y: -2.5, z: 0, duration: 1.1)]))]))
        return n
    }
}
