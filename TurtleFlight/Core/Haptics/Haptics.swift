import UIKit

/// Every moment the game answers with a vibration.
///
/// One table (`pattern`) decides what each moment feels like, so a brush
/// against a ring's rim, a clean bullseye and a bump on the ground are
/// told apart by touch alone — and so the Settings toggle silences all
/// of them at once.
enum HapticEvent: String, CaseIterable {
    case ringBullseye, ringGreat, ringOk
    /// Crossed the ring's plane just outside the rim: "you hit the ring".
    case ringRim
    /// Crossed well outside the ring.
    case ringMiss
    case groundHit
    case boostStart, boostDenied
    /// Star / treat picked up, a friend greeted.
    case pickup
    /// Landmark discovered, postcard earned.
    case discovery
    case stageClear, stageFail
    case purchase, codeAccepted, codeRejected
    case tap
}

/// One beat of a haptic pattern.
struct HapticPulse: Equatable {
    enum Kind: Equatable {
        case light, medium, heavy, rigid, soft
        case success, warning, error
    }
    let kind: Kind
    /// 0…1. Ignored by the notification kinds.
    var intensity: CGFloat = 1
    /// Seconds after the event.
    var delay: TimeInterval = 0
}

final class Haptics {

    static let shared = Haptics()

    static let enabledKey = "haptics.enabled"

    /// Player toggle (Settings → Controls). On unless switched off.
    var isEnabled: Bool {
        get { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    private let defaults: UserDefaults
    private var impacts: [HapticPulse.Kind: UIImpactFeedbackGenerator] = [:]
    private lazy var notifier = UINotificationFeedbackGenerator()
    /// Pulses actually fired — tests read this instead of feeling the phone.
    private(set) var playedCount = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Ring crossings within this many radii of the rim count as hitting
    /// the ring itself rather than missing it.
    static let rimBand: Float = 1.25

    /// What a ring crossing feels like.
    static func event(forCrossingAccuracy accuracy: Float, judgement: GateJudgement) -> HapticEvent {
        if accuracy > 1 { return accuracy <= rimBand ? .ringRim : .ringMiss }
        switch judgement {
        case .bullseye: return .ringBullseye
        case .great:    return .ringGreat
        default:        return .ringOk
        }
    }

    static func pattern(for event: HapticEvent) -> [HapticPulse] {
        switch event {
        case .ringBullseye:
            return [HapticPulse(kind: .rigid, intensity: 1),
                    HapticPulse(kind: .light, intensity: 0.6, delay: 0.08)]
        case .ringGreat:
            return [HapticPulse(kind: .medium, intensity: 0.8)]
        case .ringOk:
            return [HapticPulse(kind: .light, intensity: 0.6)]
        case .ringRim:
            return [HapticPulse(kind: .heavy, intensity: 0.9),
                    HapticPulse(kind: .rigid, intensity: 0.7, delay: 0.10)]
        case .ringMiss:
            return [HapticPulse(kind: .warning)]
        case .groundHit:
            return [HapticPulse(kind: .heavy, intensity: 1),
                    HapticPulse(kind: .soft, intensity: 0.8, delay: 0.09),
                    HapticPulse(kind: .soft, intensity: 0.5, delay: 0.20)]
        case .boostStart:
            return [HapticPulse(kind: .medium, intensity: 0.7),
                    HapticPulse(kind: .soft, intensity: 1, delay: 0.07)]
        case .boostDenied:
            return [HapticPulse(kind: .light, intensity: 0.5)]
        case .pickup:
            return [HapticPulse(kind: .soft, intensity: 0.7)]
        case .discovery, .stageClear, .purchase, .codeAccepted:
            return [HapticPulse(kind: .success)]
        case .stageFail, .codeRejected:
            return [HapticPulse(kind: .error)]
        case .tap:
            return [HapticPulse(kind: .light, intensity: 0.7)]
        }
    }

    /// Fire the pattern for `event`. Safe from any thread.
    func play(_ event: HapticEvent) {
        guard isEnabled else { return }
        let pulses = Self.pattern(for: event)
        let run = { [weak self] in
            guard let self else { return }
            for pulse in pulses {
                if pulse.delay <= 0 {
                    self.fire(pulse)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + pulse.delay) { [weak self] in
                        self?.fire(pulse)
                    }
                }
            }
        }
        if Thread.isMainThread { run() } else { DispatchQueue.main.async(execute: run) }
    }

    /// Warm the engine up before a flight so the first bump isn't late.
    func prepare() {
        guard isEnabled else { return }
        for kind in [HapticPulse.Kind.light, .medium, .heavy, .rigid, .soft] {
            generator(for: kind)?.prepare()
        }
    }

    private func fire(_ pulse: HapticPulse) {
        guard isEnabled else { return }
        playedCount += 1
        switch pulse.kind {
        case .success: notifier.notificationOccurred(.success)
        case .warning: notifier.notificationOccurred(.warning)
        case .error:   notifier.notificationOccurred(.error)
        default:       generator(for: pulse.kind)?.impactOccurred(intensity: pulse.intensity)
        }
    }

    private func generator(for kind: HapticPulse.Kind) -> UIImpactFeedbackGenerator? {
        if let existing = impacts[kind] { return existing }
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch kind {
        case .light:  style = .light
        case .medium: style = .medium
        case .heavy:  style = .heavy
        case .rigid:  style = .rigid
        case .soft:   style = .soft
        default:      return nil
        }
        let made = UIImpactFeedbackGenerator(style: style)
        impacts[kind] = made
        return made
    }
}
