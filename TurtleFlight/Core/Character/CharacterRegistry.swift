import Foundation
import SceneKit
#if canImport(UIKit)
import UIKit
#endif

final class CharacterRegistry {
    static let shared = CharacterRegistry()

    private init() {}

    /// Get all available characters
    var allCharacters: [CharacterConfig] {
        CharacterType.allCases.map { $0.config }
    }

    // The low-poly SCNSphere/SCNCapsule character + vehicle builders that
    // used to live here (~600 LOC) were removed in the App Store readiness
    // pass: the in-flight path has rendered the atlas billboard exclusively
    // since PR #36 and the selection screen uses 2D imagesets, so no code
    // path could reach them. History: git log -- this file.
}

// MARK: - In-flight Billboard (atlas-textured SCNPlane)
//
// Per docs/CHARACTER_DESIGN_PROMPT.md §Technical Notes / 2:
//   The in-flight character + vehicle is rendered as a billboarded textured
//   plane (SCNBillboardConstraint on a SCNPlane), not a 3D mesh. This keeps
//   the chibi 2D art style intact and matches the 80MB app size budget.
//
// The atlas (`{name}_atlas` imageset, 2048×2048) is laid out in a 2×2 grid:
//   ┌──────────────┬──────────────┐
//   │  default     │  joy         │  ← row 1 (top)
//   ├──────────────┼──────────────┤
//   │  scared      │  speed       │  ← row 0 (bottom)
//   └──────────────┴──────────────┘
//   col 0 (left)     col 1 (right)
//
// Switching expression = animating diffuse.contentsTransform's UV offset
// between cells. See `CharacterAnimator.setExpression(_:on:)`.

/// One of the four expression frames packed into a character's atlas image.
enum CharacterExpression: String, CaseIterable {
    case `default`
    case joy
    case scared
    case speed

    /// Cell coordinates in the 2×2 atlas. col 0 = left half, col 1 = right;
    /// row 0 = bottom half (scared/speed), row 1 = top half (default/joy).
    var atlasCell: (col: Int, row: Int) {
        switch self {
        case .default: return (0, 1)
        case .joy:     return (1, 1)
        case .scared:  return (0, 0)
        case .speed:   return (1, 0)
        }
    }
}

extension CharacterRegistry {

    /// Build the in-flight character node — a billboarded SCNPlane textured
    /// with the character's expression atlas. The flying-pose art already
    /// integrates the vehicle, so this single node replaces the previous
    /// (charNode + vehNode) primitive pair for in-flight rendering.
    ///
    /// `size` is the world-space side length of the square plane.
    func buildInflightBillboard(for character: CharacterType,
                                size: CGFloat = 2.0) -> SCNNode {
        let plane = SCNPlane(width: size, height: size)
        let mat = plane.firstMaterial ?? SCNMaterial()

        let atlasName = "\(character.assetPrefix)_atlas"
        #if canImport(UIKit)
        if let img = UIImage(named: atlasName) {
            mat.diffuse.contents = img
        } else {
            // Asset missing — surface visually so it's caught in QA, not
            // silently invisible.
            mat.diffuse.contents = UIColor.magenta
        }
        #endif

        // Crop to the default expression cell on first display.
        mat.diffuse.contentsTransform = Self.uvTransform(forCell: CharacterExpression.default.atlasCell)
        // Clamp prevents bleeding between adjacent atlas cells (per spec).
        mat.diffuse.wrapS = .clamp
        mat.diffuse.wrapT = .clamp
        mat.diffuse.magnificationFilter = .linear
        mat.diffuse.minificationFilter = .linear
        mat.diffuse.mipFilter = .linear
        // 2D chibi art — ignore scene lighting so it reads as flat illustration.
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        plane.firstMaterial = mat

        let node = SCNNode(geometry: plane)
        node.name = character.rawValue
        // Always face the active camera. Position/heading on a parent node
        // still drives where the character appears in the world; the plane
        // itself just keeps facing us.
        node.constraints = [SCNBillboardConstraint()]
        node.castsShadow = false
        return node
    }

    /// UV transform that crops the texture to one cell of a 2×2 atlas.
    /// Applied to `material.diffuse.contentsTransform`.
    ///
    /// Direct matrix construction (rather than `SCNMatrix4Translate(scale,…)`)
    /// avoids the post-scale ordering footgun where the translate value
    /// gets divided by the scale factor.
    static func uvTransform(forCell cell: (col: Int, row: Int)) -> SCNMatrix4 {
        let s: Float = 0.5
        var t = SCNMatrix4Identity
        t.m11 = s
        t.m22 = s
        t.m41 = Float(cell.col) * s
        t.m42 = Float(cell.row) * s
        return t
    }
}

// MARK: - Per-vehicle trail particle systems
//
// Per docs/CHARACTER_DESIGN_PROMPT.md each character has a uniquely styled
// trail (rocket flame, blue exhaust sparkles, golden seeds, lavender stars,
// water droplets, heart puffs, cloud puffs). The spec calls for separate
// PNG textures emitted via SCNParticleSystem; this initial pass uses
// SceneKit's built-in spark texture tinted per-vehicle, which gives clear
// color/size differentiation today and accepts custom particleImage PNGs
// in a follow-up PR without rewriting any of the wiring below.

/// Tunable parameters for a single trail emitter. Stored separately so the
/// resolver can consult `boostMultiplier` without inspecting SCN state.
struct TrailParameters {
    let color: UIColor
    let particleSize: CGFloat
    let particleSizeVariation: CGFloat
    let baseBirthRate: CGFloat       // particles per second at idle speed
    let lifeSpan: CGFloat            // seconds
    let velocity: CGFloat            // emit speed (scene units / sec)
    let velocityVariation: CGFloat
    let spreadingAngle: CGFloat      // degrees
    let blendMode: SCNParticleBlendMode
}

extension CharacterRegistry {

    /// Build a per-vehicle trail emitter. The system is fully configured
    /// (color, size, life, velocity, spread, blend) — caller just attaches
    /// it to a positioned node behind the character each frame.
    func buildTrailParticleSystem(for vehicle: VehicleType) -> SCNParticleSystem {
        let params = Self.trailParameters(for: vehicle)
        let p = SCNParticleSystem()
        p.loops = true
        p.emissionDuration = 1
        // Emit "back along local +Z"; FlightViewModel orients the emitter
        // node so its +Z points away from the character's heading.
        p.emittingDirection = SCNVector3(0, 0, 1)
        p.spreadingAngle = params.spreadingAngle
        p.particleAngularVelocity = 60
        p.particleAngularVelocityVariation = 30
        p.blendMode = params.blendMode
        p.isLightingEnabled = false
        p.particleColor = params.color
        p.particleSize = params.particleSize
        p.particleSizeVariation = params.particleSizeVariation
        p.birthRate = params.baseBirthRate
        p.particleLifeSpan = params.lifeSpan
        p.particleVelocity = params.velocity
        p.particleVelocityVariation = params.velocityVariation
        return p
    }

    /// Per-vehicle parameter table — public for tests and so the boost
    /// modulator (CharacterAnimator.setTrailBoosting) can read the base
    /// birth rate without retaining a reference to the SCNParticleSystem.
    static func trailParameters(for vehicle: VehicleType) -> TrailParameters {
        switch vehicle {
        case .shellJet:        // 🐢 Turbo — bright rocket flame
            return TrailParameters(
                color:                 UIColor(hex: 0xEF9F27),
                particleSize:          0.45,
                particleSizeVariation: 0.15,
                baseBirthRate:         60,
                lifeSpan:              0.45,
                velocity:              6,
                velocityVariation:     1.5,
                spreadingAngle:        14,
                blendMode:             .additive
            )
        case .bellyGlider:     // 🐧 Pip — sky-blue exhaust sparkles
            return TrailParameters(
                color:                 UIColor(hex: 0x85B7EB),
                particleSize:          0.18,
                particleSizeVariation: 0.06,
                baseBirthRate:         18,
                lifeSpan:              0.6,
                velocity:              3,
                velocityVariation:     0.6,
                spreadingAngle:        18,
                blendMode:             .additive
            )
        case .hamsterCopter:   // 🐹 Nutty — golden sparkles + seed feel
            return TrailParameters(
                color:                 UIColor(hex: 0xFAC775),
                particleSize:          0.22,
                particleSizeVariation: 0.08,
                baseBirthRate:         22,
                lifeSpan:              0.8,
                velocity:              2,
                velocityVariation:     0.7,
                spreadingAngle:        22,
                blendMode:             .additive
            )
        case .cushionBalloon:  // 🐱 Mochi — lavender sparkle stars
            return TrailParameters(
                color:                 UIColor(hex: 0xAFA9EC),
                particleSize:          0.18,
                particleSizeVariation: 0.06,
                baseBirthRate:         12,
                lifeSpan:              1.0,
                velocity:              1.5,
                velocityVariation:     0.4,
                spreadingAngle:        24,
                blendMode:             .additive
            )
        case .balloonBody:     // 🐸 Bounce — water droplets (the lily pad's
                               //              wake — the design reference)
            return TrailParameters(
                color:                 UIColor(hex: 0x85B7EB),
                particleSize:          0.20,
                particleSizeVariation: 0.06,
                baseBirthRate:         16,
                lifeSpan:              0.7,
                velocity:              2.2,
                velocityVariation:     0.6,
                spreadingAngle:        20,
                blendMode:             .alpha
            )
        case .carrotJet:       // 🐰 Hoppy — peach heart-puff trail
            return TrailParameters(
                color:                 UIColor(hex: 0xF5C4B3),
                particleSize:          0.30,
                particleSizeVariation: 0.10,
                baseBirthRate:         14,
                lifeSpan:              0.7,
                velocity:              4,
                velocityVariation:     0.8,
                spreadingAngle:        16,
                blendMode:             .alpha
            )
        case .cloudSurf:       // ☁️ shared — soft white cloud puffs
            return TrailParameters(
                color:                 UIColor.white,
                particleSize:          0.70,
                particleSizeVariation: 0.20,
                baseBirthRate:         9,
                lifeSpan:              1.5,
                velocity:              1.0,
                velocityVariation:     0.4,
                spreadingAngle:        26,
                blendMode:             .alpha
            )
        }
    }
}
