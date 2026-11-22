import Foundation
import SceneKit
import UIKit

/// A rare surprise that can turn up during a Free Flight: a meteor
/// shower, a full-circle rainbow, a whale made of cloud, a tide of
/// glowing jellyfish. At most one per flight, never in a mission, and
/// purely a treat — fly up to it for a small star bonus, and it goes in
/// the album's "Sky Wonders" page the first time it is seen.
///
/// Raw values are persisted in `WonderLog` — never rename a case.
enum SkyWonder: String, CaseIterable, Codable {
    case meteorShower
    case roundRainbow
    case cloudWhale
    case glowTide

    var displayName: String { L10n.t("wonder.\(rawValue).name") }

    var symbol: String {
        switch self {
        case .meteorShower: return "sparkles"
        case .roundRainbow: return "rainbow"
        case .cloudWhale:   return "cloud.fill"
        case .glowTide:     return "drop.circle.fill"
        }
    }

    /// Where and when it can happen.
    func isPossible(in world: MapTheme, mood: SkyMood) -> Bool {
        switch self {
        case .meteorShower: return world == .space || (world.hasOpenSky && mood == .night)
        case .roundRainbow: return world.hasOpenSky && (mood == .day || mood == .morning)
        case .cloudWhale:   return world.hasOpenSky && mood != .night
        case .glowTide:     return world == .ocean
        }
    }

    /// The wonder planned for one flight, if any.
    struct Plan: Equatable {
        let wonder: SkyWonder
        /// Seconds of flight before it appears.
        let startTime: Float
    }

    /// Out of 100: how often a flight gets one. Rare enough to be a
    /// surprise, common enough that most players meet one in a session.
    static let chancePercent = 35
    /// How long it stays in the sky.
    static let duration: Float = 32
    /// Stars for flying up to it.
    static let bonusStars = 3
    /// "Up to it" means within this distance of its centre.
    static let bonusRadius: Float = 160
    /// It appears this far ahead of the player.
    static let spawnDistance: Float = 650

    /// Pure, so tests can pin it: roll for a wonder and pick its moment.
    static func plan(world: MapTheme, mood: SkyMood, seed: Int) -> Plan? {
        var rng = SeededRandom(seed: seed)
        guard rng.nextInt(in: 0...99) < chancePercent else { return nil }
        let options = allCases.filter { $0.isPossible(in: world, mood: mood) }
        guard !options.isEmpty else { return nil }
        let wonder = options[rng.nextInt(in: 0...(options.count - 1))]
        return Plan(wonder: wonder, startTime: rng.nextFloat(in: 35...110))
    }
}

/// Which wonders the player has seen. On-device only (`wonders.v1`),
/// thread-safe like `PostcardAlbum`.
/// `@unchecked Sendable`: `seen` is only touched under `lock`.
final class WonderLog: @unchecked Sendable {
    static let shared = WonderLog()

    private let defaults: UserDefaults
    private let key = "wonders.v1"
    private let lock = NSLock()
    private var seen: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.seen = Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Mark `wonder` seen. True the first time.
    @discardableResult
    func record(_ wonder: SkyWonder) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard seen.insert(wonder.rawValue).inserted else { return false }
        defaults.set(seen.sorted(), forKey: key)
        return true
    }

    func hasSeen(_ wonder: SkyWonder) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return seen.contains(wonder.rawValue)
    }

    var seenCount: Int {
        lock.lock(); defer { lock.unlock() }
        return SkyWonder.allCases.filter { seen.contains($0.rawValue) }.count
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        seen = []
        defaults.removeObject(forKey: key)
    }
}

/// Builds the wonders from SceneKit primitives and particles. Each node
/// is centred on the point the player flies to for the bonus, and is
/// built facing -Z (the caller turns it toward the player's heading).
enum WonderFactory {

    static func build(_ wonder: SkyWonder) -> SCNNode {
        let root = SCNNode()
        root.name = "wonder_\(wonder.rawValue)"
        switch wonder {
        case .meteorShower: meteorShower(root)
        case .roundRainbow: roundRainbow(root)
        case .cloudWhale:   cloudWhale(root)
        case .glowTide:     glowTide(root)
        }
        root.opacity = 0
        root.runAction(.fadeIn(duration: 1.5))
        return root
    }

    /// Soft round dot, shared by every particle system here.
    static let dotImage: UIImage = {
        let size = CGSize(width: 32, height: 32)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                             endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
        }
    }()

    private static func material(_ color: UIColor, glow: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        if glow { m.emission.contents = color; m.lightingModel = .constant }
        if color.cgColor.alpha < 1 { m.isDoubleSided = true }
        return m
    }

    private static func add(_ geometry: SCNGeometry, _ color: UIColor, to parent: SCNNode,
                            at p: SCNVector3 = SCNVector3Zero, glow: Bool = false) -> SCNNode {
        geometry.materials = [material(color, glow: glow)]
        let node = SCNNode(geometry: geometry)
        node.position = p
        parent.addChildNode(node)
        return node
    }

    // MARK: Meteor shower — streaks across the sky and one big wishing
    // star drifting down that the player can catch.

    private static func meteorShower(_ r: SCNNode) {
        let streaks = SCNParticleSystem()
        streaks.particleImage = dotImage
        streaks.birthRate = 14
        streaks.particleLifeSpan = 2.2
        streaks.particleLifeSpanVariation = 0.6
        streaks.emitterShape = SCNBox(width: 1600, height: 20, length: 900, chamferRadius: 0)
        streaks.birthLocation = .volume
        streaks.emittingDirection = SCNVector3(-0.6, -0.55, 0.2)
        streaks.spreadingAngle = 6
        streaks.particleVelocity = 420
        streaks.particleVelocityVariation = 120
        streaks.particleSize = 5
        streaks.stretchFactor = 0.12
        streaks.particleColor = UIColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1)
        streaks.particleColorVariation = SCNVector4(0.08, 0.2, 0, 0)
        streaks.blendMode = .additive
        streaks.isLightingEnabled = false
        let emitter = SCNNode()
        emitter.position = SCNVector3(0, 360, 0)
        emitter.addParticleSystem(streaks)
        r.addChildNode(emitter)

        let star = SCNNode()
        star.name = "wishingStar"
        _ = add(SCNSphere(radius: 12), UIColor(red: 1.0, green: 0.95, blue: 0.70, alpha: 1), to: star, glow: true)
        // Star points, so it reads as a star and not a moon.
        for angle: Float in [0, .pi / 4, .pi / 2, 3 * .pi / 4] {
            let ray = add(SCNBox(width: 46, height: 3, length: 3, chamferRadius: 1.5),
                          UIColor(red: 1.0, green: 0.90, blue: 0.45, alpha: 1), to: star, glow: true)
            ray.eulerAngles.z = angle
        }
        let sparkle = SCNParticleSystem()
        sparkle.particleImage = dotImage
        sparkle.birthRate = 60
        sparkle.particleLifeSpan = 1.4
        sparkle.particleSize = 4
        sparkle.particleVelocity = 14
        sparkle.spreadingAngle = 180
        sparkle.particleColor = UIColor(red: 1.0, green: 0.88, blue: 0.45, alpha: 1)
        sparkle.blendMode = .additive
        sparkle.isLightingEnabled = false
        star.addParticleSystem(sparkle)
        star.position = SCNVector3(0, 140, 0)
        star.constraints = [SCNBillboardConstraint()]
        // Drift down to the player's height and bob there.
        star.runAction(.sequence([
            .moveBy(x: 0, y: -140, z: 0, duration: 6),
            .repeatForever(.sequence([.moveBy(x: 0, y: 12, z: 0, duration: 1.6),
                                      .moveBy(x: 0, y: -12, z: 0, duration: 1.6)]))
        ]))
        r.addChildNode(star)
    }

    // MARK: Round rainbow — seen from the air a rainbow is a full
    // circle; fly through the middle.

    private static func roundRainbow(_ r: SCNNode) {
        let colours: [UIColor] = [
            UIColor(red: 0.95, green: 0.30, blue: 0.30, alpha: 0.55),
            UIColor(red: 1.0, green: 0.62, blue: 0.20, alpha: 0.55),
            UIColor(red: 1.0, green: 0.88, blue: 0.25, alpha: 0.55),
            UIColor(red: 0.35, green: 0.80, blue: 0.40, alpha: 0.55),
            UIColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 0.55),
            UIColor(red: 0.60, green: 0.40, blue: 0.90, alpha: 0.55)
        ]
        let ring = SCNNode()
        ring.eulerAngles.x = .pi / 2   // stand the torus up, facing the player
        for (i, colour) in colours.enumerated() {
            _ = add(SCNTorus(ringRadius: CGFloat(150 - i * 7), pipeRadius: 3.6), colour, to: ring, glow: true)
        }
        r.addChildNode(ring)
        ring.runAction(.repeatForever(.sequence([.scale(to: 1.03, duration: 2.5), .scale(to: 1.0, duration: 2.5)])))
        let mist = SCNParticleSystem()
        mist.particleImage = dotImage
        mist.birthRate = 30
        mist.particleLifeSpan = 3
        mist.emitterShape = SCNTorus(ringRadius: 130, pipeRadius: 10)
        mist.birthLocation = .surface
        mist.particleVelocity = 4
        mist.particleSize = 6
        mist.particleColor = UIColor(white: 1, alpha: 0.5)
        mist.blendMode = .additive
        mist.isLightingEnabled = false
        ring.addParticleSystem(mist)
    }

    // MARK: Cloud whale — a big friendly whale made of cloud puffs,
    // swimming slowly across the sky.

    private static func cloudWhale(_ r: SCNNode) {
        let white = UIColor(white: 1, alpha: 0.95)
        let whale = SCNNode()
        whale.name = "cloudWhale"
        // Body: a row of puffs, fattest at the head.
        let body: [(Float, Float)] = [(-60, 26), (-30, 34), (0, 38), (32, 34), (62, 26), (88, 18), (108, 12)]
        for (z, radius) in body {
            _ = add(SCNSphere(radius: CGFloat(radius)), white, to: whale, at: SCNVector3(0, 0, z))
            _ = add(SCNSphere(radius: CGFloat(radius * 0.6)), white, to: whale, at: SCNVector3(0, radius * 0.6, z + 6))
        }
        // Tail flukes and side fins.
        for sx: Float in [-1, 1] {
            _ = add(SCNSphere(radius: 16), white, to: whale, at: SCNVector3(sx * 22, 6, 124))
            let fin = add(SCNSphere(radius: 14), white, to: whale, at: SCNVector3(sx * 40, -14, -10))
            fin.scale = SCNVector3(1.4, 0.5, 1)
            // Eyes: so it is unmistakably a creature.
            _ = add(SCNSphere(radius: 3.5), UIColor(red: 0.20, green: 0.30, blue: 0.45, alpha: 1), to: whale,
                    at: SCNVector3(sx * 27, 8, -64))
        }
        // Spout.
        let spout = SCNParticleSystem()
        spout.particleImage = dotImage
        spout.birthRate = 25
        spout.particleLifeSpan = 1.4
        spout.emittingDirection = SCNVector3(0, 1, 0)
        spout.spreadingAngle = 18
        spout.particleVelocity = 40
        spout.acceleration = SCNVector3(0, -18, 0)
        spout.particleSize = 6
        spout.particleColor = UIColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 0.9)
        spout.isLightingEnabled = false
        let spoutNode = SCNNode()
        spoutNode.position = SCNVector3(0, 40, -40)
        spoutNode.addParticleSystem(spout)
        whale.addChildNode(spoutNode)
        // Swim across (local X), with a lazy rise and fall. The body is
        // modelled along +Z, so turn it to face the way it swims.
        whale.eulerAngles.y = -.pi / 2
        whale.scale = SCNVector3(1.5, 1.5, 1.5)
        whale.position = SCNVector3(-260, 0, 0)
        whale.runAction(.group([
            .moveBy(x: 520, y: 0, z: 0, duration: TimeInterval(SkyWonder.duration)),
            .repeatForever(.sequence([.moveBy(x: 0, y: 18, z: 0, duration: 3), .moveBy(x: 0, y: -18, z: 0, duration: 3)]))
        ]))
        r.addChildNode(whale)
    }

    // MARK: Glow tide — a swarm of little glowing jellyfish rising
    // through the deep.

    private static func glowTide(_ r: SCNNode) {
        var rng = SeededRandom(seed: 2026)
        let hues: [CGFloat] = [0.50, 0.55, 0.78, 0.86]
        for i in 0..<36 {
            let jelly = SCNNode()
            let colour = UIColor(hue: hues[i % hues.count], saturation: 0.55, brightness: 1, alpha: 0.85)
            let bell = add(SCNSphere(radius: CGFloat(rng.nextFloat(in: 5...10))), colour, to: jelly, glow: true)
            bell.scale = SCNVector3(1, 0.7, 1)
            for t in 0..<3 {
                _ = add(SCNCylinder(radius: 0.6, height: 10), colour.withAlphaComponent(0.6), to: jelly,
                        at: SCNVector3(Float(t - 1) * 2.5, -8, 0), glow: true)
            }
            let angle = rng.nextFloat(in: 0...(2 * .pi))
            let radius = rng.nextFloat(in: 0...170)
            jelly.position = SCNVector3(cos(angle) * radius, rng.nextFloat(in: -90...90), sin(angle) * radius)
            let rise = TimeInterval(rng.nextFloat(in: 2.5...4))
            jelly.runAction(.repeatForever(.sequence([
                .moveBy(x: 0, y: 14, z: 0, duration: rise),
                .moveBy(x: 0, y: -14, z: 0, duration: rise)
            ])))
            r.addChildNode(jelly)
        }
    }

    /// World position the player has to reach for the bonus.
    static func anchor(of node: SCNNode) -> SCNVector3 {
        if let star = node.childNode(withName: "wishingStar", recursively: false) {
            return star.presentation.worldPosition
        }
        if let whale = node.childNode(withName: "cloudWhale", recursively: false) {
            return whale.presentation.worldPosition
        }
        return node.worldPosition
    }
}
