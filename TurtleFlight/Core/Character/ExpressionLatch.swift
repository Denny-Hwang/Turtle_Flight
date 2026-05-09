import Foundation

/// Resolves which `CharacterExpression` the in-flight billboard should show
/// at any given frame, given:
///   • the current MissionEngine state (transitions latch joy / scared)
///   • whether the player is currently boosting
///   • a monotonic wall-clock time (caller supplies — usually
///     `CACurrentMediaTime()`)
///
/// Priority (highest wins): latched(joy|scared) > speed > default.
/// Latched expressions hold for a fixed duration so the player has time to
/// register the emotional beat before the face returns to the boost/idle
/// toggle. State transitions are *edge-detected* via a stable state key so
/// repeated frames in the same state don't keep re-arming the latch.
///
/// This type is deliberately pure: no SceneKit, no AVFoundation, no UIKit
/// — just three primitive inputs in, one expression out. That makes it
/// straightforward to unit-test the priority and timing logic.
struct ExpressionLatch {

    /// What the billboard *should* be displaying right now (driven by the
    /// most recent `update(...)` call).
    private(set) var current: CharacterExpression = .default

    /// Active latched expression, or nil when no latch is in effect.
    private var latched: CharacterExpression?

    /// Wall-clock instant at which the active latch expires.
    private var latchUntil: TimeInterval = 0

    /// Last observed mission-state key; we only act on transitions, not
    /// on every frame in the same state.
    private var lastMissionStateKey: String = ""

    /// How long `joy` is held after a stage clears.
    let joyLatchDuration: TimeInterval

    /// How long `scared` is held after a stage fails.
    let scaredLatchDuration: TimeInterval

    init(joyLatchDuration: TimeInterval = 2.0,
         scaredLatchDuration: TimeInterval = 1.5) {
        self.joyLatchDuration = joyLatchDuration
        self.scaredLatchDuration = scaredLatchDuration
    }

    /// Reset to the just-spawned state. Call when a new flight begins.
    mutating func reset() {
        current = .default
        latched = nil
        latchUntil = 0
        lastMissionStateKey = ""
    }

    /// Resolve the expression for this frame and return it. Side effect:
    /// stores the result in `current`.
    ///
    /// `missionStateKey` is a stable identifier ("notStarted" / "inProgress"
    /// / "completed" / "failed"). The caller derives it from
    /// `MissionEngine.MissionState` to avoid leaking the SceneKit-tinged
    /// MissionEngine enum into this pure type.
    @discardableResult
    mutating func update(missionStateKey: String,
                         isBoosting: Bool,
                         now: TimeInterval) -> CharacterExpression {
        // Edge-detect mission transitions and arm the latch.
        if missionStateKey != lastMissionStateKey {
            lastMissionStateKey = missionStateKey
            switch missionStateKey {
            case "completed":
                latched = .joy
                latchUntil = now + joyLatchDuration
            case "failed":
                latched = .scared
                latchUntil = now + scaredLatchDuration
            default:
                break
            }
        }

        // Resolve priority.
        if let l = latched, now < latchUntil {
            current = l
            return l
        }
        latched = nil
        current = isBoosting ? .speed : .default
        return current
    }
}
