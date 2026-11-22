import XCTest
import SwiftUI
@testable import TurtleFlight

/// Sprint 3 — accessibility / portability pass.
///
/// Pins:
///   1. GyroController fallback path: when the gyro is unavailable, the
///      `injectFallback(...)` API moves the published roll/pitch values
///      and the auto-level timer reflects activity.
///   2. DeviceCanvas leaves iPhones at 1x and scales iPads up.
///   3. Theme.Typography Dynamic Type variants exist as `Font` values
///      (compile-time check only — visual assertions belong in UI tests).
final class Sprint3AccessibilityTests: XCTestCase {

    // MARK: - Gyro fallback

    func testInjectFallbackMovesPublishedInputs() {
        let controller = GyroController(sensitivity: .easy)
        // Simulate "no real gyro available" — that's the default in the
        // unit-test target since CMMotionManager.isDeviceMotionAvailable
        // is false on a Mac host runner.
        XCTAssertFalse(controller.isAvailable,
                       "Test runner has no gyro; precondition for this test")

        // Drag right-and-up.
        controller.injectFallback(rollNormalized: 1.0, pitchNormalized: 1.0)
        // After one sample the smoothing has only applied alpha (0.08)
        // of the curved input, so we expect SOMETHING > 0 but not the
        // full rail. The exact value depends on the curve; just sanity-
        // check sign + non-zero.
        XCTAssertGreaterThan(controller.rollInput, 0,
                             "Right drag should produce positive roll")
        XCTAssertGreaterThan(controller.pitchInput, 0,
                             "Up drag should produce positive pitch")

        // Sustained input drives values closer to 1.0 over time.
        for _ in 0..<200 {
            controller.injectFallback(rollNormalized: 1.0, pitchNormalized: 0)
        }
        XCTAssertGreaterThan(controller.rollInput, 0.5,
                             "Sustained right drag should accumulate toward 1.0")
    }

    func testInjectFallbackClampsOutOfRangeInputs() {
        let controller = GyroController(sensitivity: .normal)
        controller.injectFallback(rollNormalized: 5.0, pitchNormalized: -5.0)
        XCTAssertLessThanOrEqual(controller.rollInput, 1.0)
        XCTAssertGreaterThanOrEqual(controller.pitchInput, -1.0)
    }

    func testReleaseFallbackDecaysSmoothing() {
        let controller = GyroController(sensitivity: .easy)
        // Drive input up.
        for _ in 0..<200 {
            controller.injectFallback(rollNormalized: 1.0, pitchNormalized: 0)
        }
        let before = controller.rollInput
        XCTAssertGreaterThan(before, 0.3)

        // Release for a bunch of frames.
        for _ in 0..<200 {
            controller.releaseFallback()
        }
        XCTAssertLessThan(controller.rollInput, before * 0.1,
                          "After many release frames the smoothing should decay near zero")
    }

    func testInjectFallbackIsNoOpWhenGyroIsAvailable() {
        // We can't easily fake `isAvailable=true` without intercepting
        // CMMotionManager, but we can flip the published flag directly
        // in tests since it's `@Published var`. That covers the public
        // contract: "ignored when a real gyro is feeding samples".
        let controller = GyroController(sensitivity: .easy)
        controller.isAvailable = true
        controller.injectFallback(rollNormalized: 1.0, pitchNormalized: 1.0)
        XCTAssertEqual(controller.rollInput, 0)
        XCTAssertEqual(controller.pitchInput, 0)
    }

    // MARK: - Device canvas (iPad scale-up)

    /// Landscape safe-area sizes in points.
    private let iPhone17e       = CGSize(width: 750, height: 369)
    private let iPhoneProMax    = CGSize(width: 832, height: 419)
    private let iPadMini        = CGSize(width: 1133, height: 700)
    private let iPadPro11       = CGSize(width: 1210, height: 790)
    private let iPadPro13       = CGSize(width: 1376, height: 988)

    func testIPhonesAreNotScaled() {
        XCTAssertEqual(DeviceCanvas.scale(for: iPhone17e), 1)
        XCTAssertEqual(DeviceCanvas.scale(for: iPhoneProMax), 1)
    }

    func testIPadsScaleUpWithScreenSize() {
        let mini = DeviceCanvas.scale(for: iPadMini)
        let pro11 = DeviceCanvas.scale(for: iPadPro11)
        let pro13 = DeviceCanvas.scale(for: iPadPro13)
        XCTAssertGreaterThan(mini, 1.1)
        XCTAssertGreaterThan(pro11, mini)
        XCTAssertGreaterThan(pro13, pro11)
        XCTAssertLessThan(pro13, 2, "the 13-inch shouldn't look blown up")
    }

    func testScaledCanvasFitsTheScreen() {
        // The virtual canvas never comes out smaller than the reference
        // in both directions, and the scaled canvas is the screen size.
        for size in [iPadMini, iPadPro11, iPadPro13] {
            let s = DeviceCanvas.scale(for: size)
            let virtual = CGSize(width: size.width / s, height: size.height / s)
            XCTAssertGreaterThanOrEqual(virtual.width + 0.5, DeviceCanvas.reference.width)
            XCTAssertGreaterThanOrEqual(virtual.height + 0.5, DeviceCanvas.reference.height)
        }
    }

    func testDegenerateSizeIsNotScaled() {
        XCTAssertEqual(DeviceCanvas.scale(for: .zero), 1)
    }

    // MARK: - Dynamic Type tokens

    func testDynamicTypeTokensAreAccessible() {
        // The variants below feed into SwiftUI Font; we can't introspect
        // their resolved size in a unit test (that's view-tree work),
        // but we can confirm the symbols exist + are distinct.
        let body  = Theme.Typography.bodyDynamic
        let title = Theme.Typography.titleDynamic
        let sub   = Theme.Typography.subtitleDynamic
        let cap   = Theme.Typography.captionDynamic
        let bold  = Theme.Typography.bodyDynamicBold
        // Distinct values — different tokens shouldn't collapse to one.
        // (`Font` is Hashable; `String(describing:)` collapses on newer
        // SwiftUI runtimes, which is why the previous version failed.)
        let set: Set<Font> = [body, title, sub, cap, bold]
        XCTAssertEqual(set.count, 5,
                       "Dynamic Type tokens must be distinct so they map to different text styles")
    }

    // MARK: - i18n docs

    func testI18NDocExists() {
        // Sprint 3-D ships a process doc instead of half-translated
        // bundles. The doc is the contract for how future locales come
        // online; a missing doc would mean the i18n debt is silent.
        let bundle = Bundle(for: type(of: self))
        let url = bundle.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/I18N.md")
        if FileManager.default.fileExists(atPath: url.path) {
            // Found it. (The above path is best-effort — depends on
            // where xctest puts the Tests bundle. If we don't find it
            // here, skip rather than fail.)
            return
        }
        // Fallback: scan the workspace root directly via a relative path
        // under #file. This always works in the source-checkout layout.
        let here = URL(fileURLWithPath: #file)
        let repoRoot = here
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let docPath = repoRoot.appendingPathComponent("docs/I18N.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: docPath.path),
                      "docs/I18N.md should ship with Sprint 3 — it's the i18n contract")
    }

    // MARK: - Touch controls preference

    func testTouchControlPreferencePersistsAndDefaultsOff() {
        let key = GyroController.touchControlKey
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertFalse(GyroController.touchControlEnabled, "tilt stays the default")
        GyroController.touchControlEnabled = true
        XCTAssertTrue(GyroController.touchControlEnabled)
        XCTAssertTrue(GyroController().usesTouchInput)
    }

    func testGatePulseOnlyRewardsCleanPasses() {
        XCTAssertEqual(FlightViewModel.gatePulseStrength(for: .bullseye), 1.0)
        XCTAssertGreaterThan(FlightViewModel.gatePulseStrength(for: .great), 0)
        XCTAssertEqual(FlightViewModel.gatePulseStrength(for: .ok), 0)
        XCTAssertEqual(FlightViewModel.gatePulseStrength(for: .miss), 0)
    }
}
