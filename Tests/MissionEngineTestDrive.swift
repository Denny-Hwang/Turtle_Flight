import Foundation
import SceneKit
@testable import TurtleFlight

/// Test-only helpers for driving `MissionEngine` through rings now that
/// passage is a plane-crossing test (Phase 1). A single `update` at the
/// ring centre no longer counts — the player's path has to pierce the
/// ring's disc — so tests fly a two-frame segment straight through it.
extension MissionEngine {

    /// Fly through ring `index` dead-centre along its normal, with an
    /// optional lateral offset (in metres) to exercise accuracy scoring.
    /// Uses the ring's *live* centre so moving gates (Phase 2) are hit
    /// where they currently are.
    func testPass(ringIndex index: Int,
                  lateralOffset: Float = 0,
                  verticalOffset: Float = 0,
                  deltaTime: Float = 0.016) {
        let ring = rings[index]
        let n = ring.normal
        // Any horizontal vector perpendicular to the normal.
        let side = ring.sideAxis
        let live = ring.center(at: elapsedTime + Double(deltaTime))
        let centre = SCNVector3(live.x + side.x * lateralOffset,
                                live.y + verticalOffset,
                                live.z + side.z * lateralOffset)
        let before = centre - n * 20
        let after  = centre + n * 20
        update(deltaTime: deltaTime, playerPosition: before)
        update(deltaTime: deltaTime, playerPosition: after)
    }

    /// Fly through every remaining ring in order. Bounded so a ring that
    /// can't be passed fails the test instead of hanging it.
    func testPassAllRings(deltaTime: Float = 0.016) {
        var attempts = 0
        while currentRingIndex < rings.count, attempts < rings.count * 4 {
            attempts += 1
            if case .inProgress = state {
                testPass(ringIndex: currentRingIndex, deltaTime: deltaTime)
            } else {
                break
            }
        }
    }
}
