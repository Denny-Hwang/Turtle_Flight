import Foundation

/// Short spoken callouts ("Bullseye!", "Boost!") layered over the
/// synthesised SFX. The audio is pre-recorded with Google Cloud
/// Text-to-Speech (Neural2, a non-generative voice) by
/// `scripts/audio/generate_voice.sh` and bundled as
/// `TurtleFlight/Resources/Audio/voice_<rawValue>.m4a`. Nothing is
/// synthesised or fetched at runtime: a line whose file is missing is
/// simply silent, so the game ships fine before the clips exist.
///
/// The text of every line lives in `scripts/audio/voice-lines.json`;
/// `VoiceLineTests` keeps that manifest and this enum in step.
enum VoiceLine: String, CaseIterable {
    case go
    case bullseye
    case great
    case combo5 = "combo_5"
    case combo10 = "combo_10"
    case combo20 = "combo_20"
    case boost
    case stageClear = "stage_clear"
    case stageFail = "stage_fail"

    /// Bundle resource name (extension resolved by `AudioManager.assetURL`).
    var assetName: String { "voice_\(rawValue)" }

    /// Higher wins. A line only cuts off the one playing when it is
    /// strictly more important, so a bullseye never talks over
    /// "Stage clear!" and a burst of gates doesn't stutter.
    var priority: Int {
        switch self {
        case .stageClear, .stageFail: return 5
        case .combo20:                return 4
        case .combo10:                return 3
        case .combo5:                 return 2
        case .bullseye:               return 1
        case .go, .great, .boost:     return 0
        }
    }

    /// Combo counts that earn a milestone line, keyed to the combo
    /// value *after* the pass (`RunScore.combo`).
    static let comboMilestones: [Int: VoiceLine] = [5: .combo5, 10: .combo10, 20: .combo20]

    /// Callout for a gate pass, or nil for an unremarkable one. A combo
    /// milestone beats the judgement so the bigger moment is the one
    /// the player hears; OK passes stay silent (the ring chime covers
    /// them) so the voice stays special.
    static func forGatePass(judgement: GateJudgement, comboAfterPass: Int) -> VoiceLine? {
        if let milestone = comboMilestones[comboAfterPass] { return milestone }
        switch judgement {
        case .bullseye: return .bullseye
        case .great:    return .great
        case .ok, .miss: return nil
        }
    }

    /// Whether `next` may start while `current` is still playing.
    static func shouldInterrupt(current: VoiceLine?, with next: VoiceLine) -> Bool {
        guard let current else { return true }
        return next.priority > current.priority
    }
}
