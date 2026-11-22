import Foundation
import SceneKit
import UIKit

/// V3 (docs/VISUAL_AUDIO_PLAN.md): a real water surface for the worlds
/// with rivers and seas. Before this, "water" was only terrain below 0 m
/// painted blue. One large plane follows the player; its ripple texture
/// is anchored to world coordinates (so it doesn't slide with the plane)
/// and drifts slowly, and a Blinn highlight gives the sun a glint.
/// One draw call, no per-vertex work.
final class WaterSurface {
    /// Plane side; matches the far-terrain span so the edge is lost in fog.
    static let size: Float = 5000
    /// World units per ripple tile.
    static let tile: Float = 240
    /// Sits just above sea level so the shoreline terrain doesn't flicker.
    static let level: Float = 0.6

    let node: SCNNode
    private let material: SCNMaterial

    /// Worlds that have water at sea level. The desert has none, space has
    /// none, and the ocean world is already under water.
    static func hasWater(_ world: MapTheme) -> Bool {
        switch world {
        // Matches `WorldProfile.seaOffset`: only these dip below 0 m.
        case .seoul, .city, .wild:            return true
        case .sky, .desert, .space, .ocean:   return false
        }
    }

    init(world: MapTheme, profile: WorldProfile) {
        let plane = SCNPlane(width: CGFloat(Self.size), height: CGFloat(Self.size))
        let m = SCNMaterial()
        let deep = profile.ramp.first?.color ?? SCNVector3(0.3, 0.55, 0.85)
        m.diffuse.contents = Self.rippleImage(base: deep)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.mipFilter = .linear
        m.lightingModel = .blinn
        m.specular.contents = UIColor(white: 1, alpha: 1)
        m.shininess = 0.55
        m.transparency = 0.86
        m.isDoubleSided = false
        plane.materials = [m]
        material = m
        node = SCNNode(geometry: plane)
        node.name = "water"
        node.eulerAngles.x = -.pi / 2
        node.castsShadow = false
    }

    /// Keep the plane under the player and the ripples fixed to the world
    /// (plus a slow drift). `time` in seconds.
    func update(playerPosition p: SCNVector3, time: Float) {
        node.position = SCNVector3(p.x, Self.level, p.z)
        let scale = Self.size / Self.tile
        let drift = time * 0.015
        var t = SCNMatrix4Identity
        t.m11 = scale
        t.m22 = scale
        // Plane u runs along +x, v along +z once laid flat (see tests).
        t.m41 = (p.x - Self.size / 2) / Self.tile + drift
        t.m42 = (p.z - Self.size / 2) / Self.tile + drift * 0.6
        material.diffuse.contentsTransform = t
    }

    /// Tileable ripple pattern over the water colour: sums of sines with
    /// whole-number frequencies, so the edges wrap.
    static func rippleImage(base: SCNVector3, size: Int = 256) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { ctx in
            let c = ctx.cgContext
            for y in 0..<size {
                for x in 0..<size {
                    let u = Float(x) / Float(size) * 2 * .pi
                    let v = Float(y) / Float(size) * 2 * .pi
                    var w = sin(u * 2 + sin(v * 3) * 0.8) + sin(v * 4 + u) * 0.6 + sin((u - v) * 5) * 0.35
                    w = (w + 1.95) / 3.9                         // ~0…1
                    let crest = max(0, w - 0.78) / 0.22          // bright crests only
                    let shade = 0.96 + w * 0.08
                    let r = min(1, base.x * shade + crest * 0.14)
                    let g = min(1, base.y * shade + crest * 0.16)
                    let b = min(1, base.z * shade + crest * 0.14)
                    c.setFillColor(UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }
}
