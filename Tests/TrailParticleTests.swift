import XCTest
import SceneKit
@testable import TurtleFlight

final class TrailParticleTests: XCTestCase {

    // MARK: - Per-vehicle parameter table

    func testEveryVehicleHasNonZeroTrailParameters() {
        for v in VehicleType.allCases {
            let p = CharacterRegistry.trailParameters(for: v)
            XCTAssertGreaterThan(p.baseBirthRate, 0, "no birth rate for \(v)")
            XCTAssertGreaterThan(p.lifeSpan, 0,      "no life span for \(v)")
            XCTAssertGreaterThan(p.particleSize, 0,  "no particle size for \(v)")
            XCTAssertGreaterThanOrEqual(p.spreadingAngle, 0)
        }
    }

    func testTurboTrailIsLargestAndBrightest() {
        // Spec: rocket flame is the most prominent of the seven trails.
        let turbo = CharacterRegistry.trailParameters(for: .shellJet)
        let pip   = CharacterRegistry.trailParameters(for: .bellyGlider)
        let mochi = CharacterRegistry.trailParameters(for: .cushionBalloon)
        XCTAssertGreaterThan(turbo.baseBirthRate, pip.baseBirthRate)
        XCTAssertGreaterThan(turbo.baseBirthRate, mochi.baseBirthRate)
        XCTAssertGreaterThan(turbo.particleSize, mochi.particleSize)
        XCTAssertEqual(turbo.blendMode, .additive,
                       "rocket flame should glow additively over the sky")
    }

    func testCloudSurfTrailIsTheLongestLived() {
        // Spec: cloud surf leaves drifting puffs that linger.
        let cloud = CharacterRegistry.trailParameters(for: .cloudSurf)
        for v in VehicleType.allCases where v != .cloudSurf {
            let p = CharacterRegistry.trailParameters(for: v)
            XCTAssertGreaterThanOrEqual(cloud.lifeSpan, p.lifeSpan,
                                        "\(v) trail outlives the cloud puff")
        }
    }

    // MARK: - Build a real SCNParticleSystem

    func testBuildTrailParticleSystemAppliesParameters() {
        let registry = CharacterRegistry.shared
        for v in VehicleType.allCases {
            let p = CharacterRegistry.trailParameters(for: v)
            let sys = registry.buildTrailParticleSystem(for: v)
            XCTAssertEqual(sys.birthRate, p.baseBirthRate, accuracy: 1e-6,
                           "\(v) birthRate mismatch")
            XCTAssertEqual(sys.particleLifeSpan, p.lifeSpan, accuracy: 1e-6)
            XCTAssertEqual(sys.particleSize, p.particleSize, accuracy: 1e-6)
            XCTAssertEqual(sys.particleVelocity, p.velocity, accuracy: 1e-6)
            XCTAssertEqual(sys.blendMode, p.blendMode)
            XCTAssertEqual((sys.particleColor as? UIColor), p.color,
                           "\(v) should tint particles to its palette")
            XCTAssertTrue(sys.loops, "trail must loop forever during flight")
            XCTAssertFalse(sys.isLightingEnabled,
                           "particles ignore scene lighting (2D vibe)")
        }
    }

    // MARK: - Boost modulator

    func testBoostModulatorMultipliesBirthRate() {
        let registry = CharacterRegistry.shared
        let animator = CharacterAnimator()
        let sys = registry.buildTrailParticleSystem(for: .shellJet)
        let base = CharacterRegistry.trailParameters(for: .shellJet).baseBirthRate

        animator.setTrailBoosting(sys, boosting: true, baseBirthRate: base)
        XCTAssertEqual(
            sys.birthRate,
            base * CharacterAnimator.trailBoostBirthRateMultiplier,
            accuracy: 1e-6,
            "boost should multiply birth rate"
        )

        animator.setTrailBoosting(sys, boosting: false, baseBirthRate: base)
        XCTAssertEqual(sys.birthRate, base, accuracy: 1e-6,
                       "releasing boost should restore base rate")
    }

    func testBoostModulatorIsIdempotent() {
        // Calling repeatedly with the same state should not produce visible
        // churn. Easy to assert: the property doesn't change after the
        // first call.
        let registry = CharacterRegistry.shared
        let animator = CharacterAnimator()
        let sys = registry.buildTrailParticleSystem(for: .carrotJet)
        let base = CharacterRegistry.trailParameters(for: .carrotJet).baseBirthRate

        animator.setTrailBoosting(sys, boosting: true, baseBirthRate: base)
        let after1 = sys.birthRate
        animator.setTrailBoosting(sys, boosting: true, baseBirthRate: base)
        XCTAssertEqual(sys.birthRate, after1, accuracy: 1e-9)
    }
}
