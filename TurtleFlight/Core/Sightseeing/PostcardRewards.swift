import Foundation
import SceneKit
import UIKit

/// What collecting a world's postcards pays: half of them → a few stars,
/// all of them → more stars and that world's **Festival** (lanterns and
/// fireworks in Free Flight, switchable in the album). Earned only by
/// flying; nothing to buy.
enum PostcardMilestone: String, CaseIterable, Codable {
    case half
    case complete

    /// Postcards needed in a world with `total` landmarks.
    func required(of total: Int) -> Int {
        switch self {
        case .half:     return max(1, (total + 1) / 2)
        case .complete: return total
        }
    }

    var stars: Int {
        switch self {
        case .half:     return 5
        case .complete: return 10
        }
    }
}

struct PostcardReward: Equatable, Hashable {
    let world: MapTheme
    let milestone: PostcardMilestone

    /// Stored in `PlayerProgress.claimedPostcardRewards`.
    var id: String { "\(world.rawValue).\(milestone.rawValue)" }
    var stars: Int { milestone.stars }
}

enum PostcardRewards {

    /// Milestones `world` has reached with `found` postcards.
    static func reached(world: MapTheme, found: Int) -> [PostcardReward] {
        let total = LandmarkKind.kinds(in: world).count
        guard total > 0 else { return [] }
        return PostcardMilestone.allCases
            .filter { found >= $0.required(of: total) }
            .map { PostcardReward(world: world, milestone: $0) }
    }

    /// Milestones reached but not yet paid, across every world.
    static func due(album: PostcardAlbum, claimed: Set<String>) -> [PostcardReward] {
        MapTheme.allCases.flatMap { world in
            reached(world: world, found: album.postcardCount(in: world))
        }.filter { !claimed.contains($0.id) }
    }

    /// The milestone this exact postcard count crosses, if any (for the
    /// in-flight banner the moment it happens).
    static func crossed(world: MapTheme, found: Int) -> PostcardMilestone? {
        let total = LandmarkKind.kinds(in: world).count
        guard total > 0 else { return nil }
        // Check the bigger one first: a two-landmark world reaches half
        // and all on different postcards, but a one-landmark world would
        // reach both at once.
        for milestone in PostcardMilestone.allCases.reversed() where found == milestone.required(of: total) {
            return milestone
        }
        return nil
    }

    static func isFestivalUnlocked(_ world: MapTheme, album: PostcardAlbum = .shared) -> Bool {
        let total = LandmarkKind.kinds(in: world).count
        return total > 0 && album.postcardCount(in: world) >= total
    }
}

extension PlayerProgress {
    /// Festival shows in Free Flight in `world`: unlocked by the album
    /// and not switched off.
    func festivalEnabled(in world: MapTheme, album: PostcardAlbum = .shared) -> Bool {
        PostcardRewards.isFestivalUnlocked(world, album: album) && !festivalOff.contains(world.rawValue)
    }
}

/// Festival decorations around the player: paper lanterns drifting up
/// (glowing pearls under the sea, star lanterns in space) and a firework
/// now and then. Lanterns are recycled around the player rather than
/// placed in the world, so the cost is fixed: `lanternCount` nodes and
/// one burst system at a time.
final class FestivalLayer {
    static let lanternCount = 26
    /// Lanterns live in a box this wide around the player.
    static let span: Float = 900
    static let fireworkInterval: Float = 4.5

    private let root = SCNNode()
    private var lanterns: [SCNNode] = []
    /// Starts most of the way to the first burst so one goes off soon.
    private var fireworkClock: Float = FestivalLayer.fireworkInterval - 1.5
    private var rng = SeededRandom(seed: 1122)
    private let world: MapTheme

    init(parentNode: SCNNode, world: MapTheme, around position: SCNVector3) {
        self.world = world
        root.name = "festival"
        parentNode.addChildNode(root)
        for i in 0..<Self.lanternCount {
            let lantern = Self.makeLantern(world: world, variant: i)
            lantern.position = SCNVector3(position.x + rng.nextFloat(in: -1...1) * Self.span / 2,
                                          position.y + rng.nextFloat(in: -120...220),
                                          position.z + rng.nextFloat(in: -1...1) * Self.span / 2)
            let rise = TimeInterval(rng.nextFloat(in: 5...8))
            lantern.runAction(.repeatForever(.sequence([
                .moveBy(x: 0, y: 16, z: 0, duration: rise),
                .moveBy(x: 0, y: -16, z: 0, duration: rise)
            ])))
            root.addChildNode(lantern)
            lanterns.append(lantern)
        }
    }

    /// Wrap lanterns that fell behind to the far side, and pop a
    /// firework ahead every few seconds. Call at the sightseeing rate.
    func update(deltaTime: Float, playerPosition p: SCNVector3, heading: Float) {
        let half = Self.span / 2
        for lantern in lanterns {
            var q = lantern.position
            if q.x - p.x > half { q.x -= Self.span } else if p.x - q.x > half { q.x += Self.span }
            if q.z - p.z > half { q.z -= Self.span } else if p.z - q.z > half { q.z += Self.span }
            if abs(q.y - p.y) > 300 { q.y = p.y + rng.nextFloat(in: -100...200) }
            if q.x != lantern.position.x || q.y != lantern.position.y || q.z != lantern.position.z {
                lantern.position = q
            }
        }
        fireworkClock += deltaTime
        guard fireworkClock >= Self.fireworkInterval else { return }
        fireworkClock = 0
        let h = heading * .pi / 180
        let ahead = rng.nextFloat(in: 450...700)
        let side = rng.nextFloat(in: -260...260)
        let at = SCNVector3(p.x + sin(h) * ahead + cos(h) * side,
                            p.y + rng.nextFloat(in: 120...260),
                            p.z - cos(h) * ahead + sin(h) * side)
        burst(at: at)
    }

    func remove() {
        root.removeAllActions()
        root.removeFromParentNode()
        lanterns.removeAll()
    }

    private func burst(at position: SCNVector3) {
        let hue = CGFloat(rng.nextUnit())
        let system = SCNParticleSystem()
        system.particleImage = WonderFactory.dotImage
        system.birthRate = 900
        system.emissionDuration = 0.08
        system.loops = false
        system.particleLifeSpan = 1.6
        system.particleLifeSpanVariation = 0.4
        system.spreadingAngle = 180
        system.particleVelocity = 110
        system.particleVelocityVariation = 30
        system.acceleration = SCNVector3(0, -30, 0)
        system.dampingFactor = 1.2
        system.particleSize = 4
        system.particleColor = UIColor(hue: hue, saturation: 0.7, brightness: 1, alpha: 1)
        system.particleColorVariation = SCNVector4(0.06, 0.2, 0, 0)
        system.blendMode = .additive
        system.isLightingEnabled = false
        let opacity = CAKeyframeAnimation()
        opacity.values = [1, 1, 0]
        opacity.keyTimes = [0, 0.6, 1]
        system.propertyControllers = [.opacity: SCNParticlePropertyController(animation: opacity)]
        let node = SCNNode()
        node.position = position
        node.addParticleSystem(system)
        root.addChildNode(node)
        node.runAction(.sequence([.wait(duration: 2.5), .removeFromParentNode()]))
    }

    static func makeLantern(world: MapTheme, variant: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "lantern"
        let colour: UIColor
        switch world {
        case .ocean:
            // Glowing pearls.
            colour = UIColor(hue: [0.50, 0.58, 0.86][variant % 3], saturation: 0.30, brightness: 1, alpha: 1)
        case .space:
            // Star lanterns.
            colour = UIColor(hue: [0.13, 0.55, 0.80][variant % 3], saturation: 0.45, brightness: 1, alpha: 1)
        default:
            // Paper lanterns in warm festival colours.
            colour = UIColor(hue: [0.01, 0.07, 0.12, 0.95][variant % 4], saturation: 0.72, brightness: 1, alpha: 1)
        }
        // Lit from inside: mostly emissive, with a little Lambert shading
        // left so it reads as round rather than a flat sticker.
        let glow = SCNMaterial()
        glow.diffuse.contents = colour
        glow.emission.contents = colour.withAlphaComponent(1).blended(toward: .black, amount: 0.25)
        glow.lightingModel = .lambert
        let body = SCNSphere(radius: world == .ocean ? 5 : 6)
        body.segmentCount = 16
        body.materials = [glow]
        let bodyNode = SCNNode(geometry: body)
        if world != .ocean { bodyNode.scale = SCNVector3(1, world == .space ? 1 : 1.3, 1) }
        node.addChildNode(bodyNode)
        if world != .ocean && world != .space {
            // Dark rims top and bottom, like a real paper lantern.
            let rim = SCNMaterial()
            rim.diffuse.contents = UIColor(red: 0.35, green: 0.12, blue: 0.10, alpha: 1)
            for y: Float in [-7.6, 7.6] {
                let cap = SCNCylinder(radius: 3.2, height: 1.6)
                cap.materials = [rim]
                let capNode = SCNNode(geometry: cap)
                capNode.position = SCNVector3(0, y, 0)
                node.addChildNode(capNode)
            }
        }
        if world == .space {
            node.constraints = [SCNBillboardConstraint()]
            // A little four-point twinkle.
            for angle: Float in [0, .pi / 2] {
                let ray = SCNBox(width: 18, height: 1.6, length: 1.6, chamferRadius: 0.8)
                let m = SCNMaterial()
                m.diffuse.contents = colour
                m.emission.contents = colour
                m.lightingModel = .constant
                ray.materials = [m]
                let rayNode = SCNNode(geometry: ray)
                rayNode.eulerAngles.z = angle
                node.addChildNode(rayNode)
            }
        }
        return node
    }
}

private extension UIColor {
    func blended(toward other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount, alpha: a1)
    }
}
