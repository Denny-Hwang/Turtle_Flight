import Foundation
import SceneKit

/// In-flight animation surface for the character billboard.
///
/// Two responsibilities:
///   • Drive the 2×2 atlas UV offset to switch facial expressions
///     (default / joy / scared / speed) — see `setExpression(_:on:)`.
///   • Modulate the per-vehicle trail particle system's birth rate when
///     the player boosts — see `setTrailBoosting(_:boosting:baseBirthRate:)`.
///
/// History: a previous incarnation drove per-vehicle 3D rigs (propeller
/// spin, ear sway, balloon scale, etc.) via `applyFlightPose(...)`. After
/// the migration to 2D atlas-textured billboards (PR #36), those rigs no
/// longer exist in the live render path — the entire `applyFlightPose`
/// surface and its 7 vehicle-specific helpers became dead code. They were
/// removed to keep the binary lean and to stop the documentation
/// implying motion that the player actually sees. Per-vehicle motion can
/// return as billboard-level animations (subtle scale pulse, rotation
/// jitter) in a follow-up PR; the trail particles already differentiate
/// vehicles visually for v1.
final class CharacterAnimator {

    // MARK: - Atlas billboard expression switching

    /// Animate the billboard's UV offset to switch which expression cell of
    /// the 2×2 atlas is shown. The transition is short (~0.18s) so it reads
    /// as a snap rather than a fade — matches a chibi-style art beat.
    ///
    /// Caller is responsible for tracking the *current* expression to avoid
    /// re-issuing the same transition every frame; SCNTransaction itself
    /// will collapse identical animations but the per-frame churn is wasteful.
    func setExpression(_ expression: CharacterExpression,
                       on billboardNode: SCNNode,
                       duration: TimeInterval = 0.18) {
        guard let mat = billboardNode.geometry?.firstMaterial else { return }
        let target = CharacterRegistry.uvTransform(forCell: expression.atlasCell)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        mat.diffuse.contentsTransform = target
        SCNTransaction.commit()
    }

    // MARK: - Trail boost modulation

    /// Multiplier applied to a trail's birth rate while the player is
    /// boosting. Tuned so the trail visibly thickens without overwhelming
    /// the screen on long boosts.
    static let trailBoostBirthRateMultiplier: CGFloat = 2.5

    /// Modulate a trail particle system's emission rate based on boost
    /// state. The base birth rate is per-vehicle (see
    /// `CharacterRegistry.trailParameters`); this method just multiplies it.
    func setTrailBoosting(_ system: SCNParticleSystem,
                          boosting: Bool,
                          baseBirthRate: CGFloat) {
        let target = boosting
            ? baseBirthRate * Self.trailBoostBirthRateMultiplier
            : baseBirthRate
        guard system.birthRate != target else { return }
        system.birthRate = target
    }
}
