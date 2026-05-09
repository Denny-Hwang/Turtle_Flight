import Foundation

/// Persistent record of whether the user has finished the first-run
/// onboarding flow. Backed by UserDefaults so we survive process restarts
/// and TestFlight reinstalls (within the same App Store bundle ID).
///
/// Keep this type *intentionally minimal* — it's the smallest persistence
/// surface in the app and the unit tests for it should run in microseconds.
struct OnboardingState: Codable, Equatable {

    /// True after the user has either tapped "Get Started" on the last
    /// onboarding card OR explicitly skipped via the top-right Skip button.
    var completed: Bool

    /// Default for a fresh install — the first launch should show the
    /// onboarding flow.
    static let pristine = OnboardingState(completed: false)

    // MARK: - UserDefaults bridge

    /// Storage key. Single string so the next migration can rename
    /// without grepping.
    static let storageKey = "onboarding.state.v1"

    /// Load from a backing store (UserDefaults by default). Falls back to
    /// `.pristine` if no record exists or the payload is corrupt — never
    /// throws, because onboarding-state corruption shouldn't block launch.
    static func load(from defaults: UserDefaults = .standard) -> OnboardingState {
        guard let data = defaults.data(forKey: storageKey) else { return .pristine }
        return (try? JSONDecoder().decode(OnboardingState.self, from: data)) ?? .pristine
    }

    /// Persist to a backing store. Returns success — callers may want to
    /// surface a non-blocking error if the write fails (rare on iOS).
    @discardableResult
    func save(to defaults: UserDefaults = .standard) -> Bool {
        guard let data = try? JSONEncoder().encode(self) else { return false }
        defaults.set(data, forKey: Self.storageKey)
        return true
    }
}
