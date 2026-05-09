import XCTest
@testable import TurtleFlight

/// Tiny smoke tests for the persistence surface that gates first-run
/// onboarding. Drives an isolated `UserDefaults` suite so the
/// production `.standard` defaults are never touched by the test run.
final class OnboardingStateTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "OnboardingStateTests.suite"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testFreshInstallReturnsPristineState() {
        let state = OnboardingState.load(from: defaults)
        XCTAssertFalse(state.completed,
                       "fresh installs MUST see the onboarding flow")
    }

    func testRoundTripPreservesCompletedFlag() {
        var state = OnboardingState(completed: true)
        XCTAssertTrue(state.save(to: defaults))

        let restored = OnboardingState.load(from: defaults)
        XCTAssertTrue(restored.completed,
                      "completed flag must survive a save→load round trip")

        // Mutating an in-memory copy should not retroactively rewrite
        // disk state.
        state.completed = false
        let stillRestored = OnboardingState.load(from: defaults)
        XCTAssertTrue(stillRestored.completed)
    }

    func testCorruptPayloadFallsBackToPristine() {
        // Write garbage into the defaults slot — load should NOT throw,
        // and must default to "show the onboarding".
        defaults.set("not json".data(using: .utf8), forKey: OnboardingState.storageKey)

        let state = OnboardingState.load(from: defaults)
        XCTAssertFalse(state.completed)
    }

    func testPristineHasCorrectInitialValue() {
        XCTAssertFalse(OnboardingState.pristine.completed)
    }
}
