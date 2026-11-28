#if DEBUG
import Foundation

/// App Store screenshot mode — Debug builds only, compiled out of
/// Release/Archive. Driven by `scripts/screenshots/capture.sh`, which
/// launches the simulator app with `-TFScreenshot <scene>` (plus the
/// stock `-selectedCharacter` / `-selectedMapTheme` UserDefaults
/// arguments to pick who flies where).
///
/// Nothing is faked: in flight scenes an autopilot steers the real
/// flight engine through each ring's centre, so the BULLSEYE callouts,
/// score, combo, result screen, quest progress and mastery that end up
/// on screen are the game's own output. The only changes to normal
/// behaviour are: onboarding and the "no gyroscope" alert are skipped
/// (Simulator has no gyro), callouts stay up until the next one, and a
/// flight scene freezes right after the bullseye that reaches
/// `freezeCombo` so the capture lands on that frame.
enum ScreenshotScene: String {
    case home
    case characters
    case stages
    case daily
    case dailyResult = "daily-result"
    case skyrun
    // QA-only scenes (scripts/screenshots/qa_matrix.sh) — every other
    // screen, so layout can be checked per device and per language.
    case settings
    case album
    case shop
    /// Character select for a route course (shows the course briefing).
    case briefing
    case onboarding
    case pause
    case freeflight
    /// Free Flight flown by the autopilot to the nearest landmark,
    /// frozen `tourFreezeDistance` short of it.
    case tour
    case stage
    /// Flies the course to its result screen. `-TFStageIndex <n>` picks
    /// the campaign stage (default 0; stage 3 has the tallest card).
    case stageResult = "stage-result"
    /// Free Flight summary: flies a few seconds, then taps Exit.
    case freeflightResult = "freeflight-result"
    /// Device soak test (scripts/device/verify.sh): Sky Run flown by the
    /// autopilot with no freeze, so it keeps flying for as long as the
    /// perf probe records.
    case soak
    /// Device soak in Free Flight (`verify.sh --free`): flies straight
    /// with set pieces and companions on their normal rhythm, so the
    /// perf probe measures them (plan W6).
    case soakFree = "soak-free"
}

enum ScreenshotDirector {
    static let scene: ScreenshotScene? =
        UserDefaults.standard.string(forKey: "TFScreenshot").flatMap(ScreenshotScene.init(rawValue:))

    static var isActive: Bool { scene != nil }

    /// Screenshot runs keep Free Flight deterministic (no set pieces or
    /// companions) — except the Free Flight soak, which is there to
    /// measure them.
    static var allowsFreeFlightExtras: Bool { scene == nil || scene == .soakFree }

    /// `stage-result`: which campaign stage to fly.
    static var stageIndex: Int { UserDefaults.standard.integer(forKey: "TFStageIndex") }

    /// Flight scenes fly themselves.
    static var autopilot: Bool {
        switch scene {
        case .daily, .dailyResult, .skyrun, .pause, .stage, .stageResult, .tour, .soak: return true
        default: return false
        }
    }

    /// Freeze the simulation shortly after a bullseye that brings the
    /// combo to at least this value. Nil = never freeze (the result
    /// scene flies the whole course).
    static var freezeCombo: Int? {
        switch scene {
        case .daily:  return 5
        case .stage:  return 3
        case .skyrun: return 9
        default:      return nil
        }
    }

    /// Seconds to keep flying after the freeze-trigger bullseye, so the
    /// character has cleared the ring and the next gates are in view.
    static let freezeDelay: Double = 0.18

    /// `tour` with `-TFTourKind <rawValue>`: only that landmark appears
    /// (it must belong to the selected world), for before/after captures.
    static var tourKind: LandmarkKind? {
        guard scene == .tour else { return nil }
        return UserDefaults.standard.string(forKey: "TFTourKind").flatMap(LandmarkKind.init(rawValue:))
    }

    /// `tour`: stop this far from the landmark so it fills the frame.
    static var tourFreezeDistance: Float {
        let v = UserDefaults.standard.float(forKey: "TFTourDistance")
        return v > 0 ? v : 420
    }
}
#endif
