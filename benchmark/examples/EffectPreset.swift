// Benchmark example (benchmark/PLAN.md B2) — NOT part of the app target.
//
// Effekseer's useful idea for us is not its runtime but its split:
// an effect is *data* (emitters + curves over life) authored apart from
// the code that plays it. Today each `SCNParticleSystem()` in the app is
// configured inline (SkyWonder, SetPieceFactory, PostcardRewards,
// CharacterRegistry trails). A small value type lets those share one
// builder, gain size/opacity curves, and be listed in a debug gallery.

import SceneKit
import UIKit

struct EffectPreset: Sendable, Equatable {
    struct Curve: Sendable, Equatable {
        /// (time 0…1 over the particle's life, value) pairs.
        var keys: [(t: Float, v: Float)]
        static func == (a: Curve, b: Curve) -> Bool {
            a.keys.map(\.t) == b.keys.map(\.t) && a.keys.map(\.v) == b.keys.map(\.v)
        }
    }

    var name: String
    var birthRate: CGFloat
    /// 0 = loop forever; otherwise a one-shot burst of this length.
    var burst: CGFloat
    var life: CGFloat
    var lifeVariation: CGFloat = 0
    var speed: CGFloat
    var speedVariation: CGFloat = 0
    var spreadDegrees: CGFloat = 180
    var size: CGFloat
    var sizeVariation: CGFloat = 0
    var color: SIMD4<Float>
    var additive = true
    var gravity: SIMD3<Float> = .zero
    var sizeOverLife: Curve? = nil
    var opacityOverLife: Curve? = nil

    @MainActor
    func makeSystem(image: UIImage) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = image
        ps.birthRate = birthRate
        ps.loops = burst == 0
        if burst > 0 { ps.emissionDuration = burst }
        ps.particleLifeSpan = life
        ps.particleLifeSpanVariation = lifeVariation
        ps.particleVelocity = speed
        ps.particleVelocityVariation = speedVariation
        ps.spreadingAngle = spreadDegrees
        ps.particleSize = size
        ps.particleSizeVariation = sizeVariation
        ps.particleColor = UIColor(red: CGFloat(color.x), green: CGFloat(color.y),
                                   blue: CGFloat(color.z), alpha: CGFloat(color.w))
        ps.blendMode = additive ? .additive : .alpha
        ps.isLightingEnabled = false
        if gravity != .zero {
            ps.isAffectedByGravity = false
            ps.acceleration = SCNVector3(gravity.x, gravity.y, gravity.z)
        }
        var controllers: [SCNParticleSystem.ParticleProperty: SCNParticlePropertyController] = [:]
        if let c = sizeOverLife { controllers[.size] = Self.controller(c) }
        if let c = opacityOverLife { controllers[.opacity] = Self.controller(c) }
        if !controllers.isEmpty { ps.propertyControllers = controllers }
        return ps
    }

    private static func controller(_ curve: Curve) -> SCNParticlePropertyController {
        let anim = CAKeyframeAnimation()
        anim.values = curve.keys.map { NSNumber(value: $0.v) }
        anim.keyTimes = curve.keys.map { NSNumber(value: $0.t) }
        // Input defaults to the particle's normalised life (0…1).
        return SCNParticlePropertyController(animation: anim)
    }
}

extension EffectPreset {
    /// BULLSEYE ring pass: a quick gold pop that grows then fades.
    static let bullseyeBurst = EffectPreset(
        name: "bullseye", birthRate: 600, burst: 0.06, life: 0.7, lifeVariation: 0.2,
        speed: 40, speedVariation: 15, size: 1.6, sizeVariation: 0.6,
        color: SIMD4(1.0, 0.85, 0.3, 1),
        sizeOverLife: Curve(keys: [(0, 0.4), (0.2, 1.2), (1, 0.2)]),
        opacityOverLife: Curve(keys: [(0, 1), (0.6, 0.8), (1, 0)]))

    /// Star pickup: small upward sparkle with a little gravity.
    static let starPickup = EffectPreset(
        name: "star", birthRate: 250, burst: 0.05, life: 0.9,
        speed: 18, speedVariation: 8, spreadDegrees: 60, size: 0.8,
        color: SIMD4(1.0, 0.95, 0.6, 1), gravity: SIMD3(0, -12, 0),
        opacityOverLife: Curve(keys: [(0, 1), (1, 0)]))

    /// Updraft column (set piece): looping, slow, rising mist.
    static let updraftMist = EffectPreset(
        name: "updraft", birthRate: 30, burst: 0, life: 3, lifeVariation: 0.5,
        speed: 12, spreadDegrees: 10, size: 4, sizeVariation: 1.5,
        color: SIMD4(0.85, 0.95, 1.0, 0.35), additive: false,
        sizeOverLife: Curve(keys: [(0, 0.5), (1, 1.6)]),
        opacityOverLife: Curve(keys: [(0, 0), (0.2, 1), (1, 0)]))

    static let all: [EffectPreset] = [.bullseyeBurst, .starPickup, .updraftMist]
}
