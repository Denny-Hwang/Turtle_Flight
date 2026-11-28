import XCTest
import SwiftUI
@testable import TurtleFlight

/// Sprint 3 — accessibility / portability pass.
///
/// Pins:
///   1. No gyro → the on-screen stick drives the flight.
///   2. DeviceCanvas leaves iPhones at 1x and scales iPads up.
///   3. Theme.Typography Dynamic Type variants exist as `Font` values
///      (compile-time check only — visual assertions belong in UI tests).
final class Sprint3AccessibilityTests: XCTestCase {

    // MARK: - No-gyro fallback
    // The drag fallback moved to the on-screen stick (`StickInput`,
    // 2026-11-26); `JoystickTests` covers the filter. Here: a device
    // without a gyro always flies with the stick.

    func testNoGyroMeansJoystick() {
        let vm = FlightViewModel()
        XCTAssertFalse(vm.gyroController.isAvailable, "test host has no gyro")
        vm.refreshControlMode()
        XCTAssertEqual(vm.controlMode, .joystick)
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

    func testGatePulseOnlyRewardsCleanPasses() {
        XCTAssertEqual(FlightViewModel.gatePulseStrength(for: .bullseye), 1.0)
        XCTAssertGreaterThan(FlightViewModel.gatePulseStrength(for: .great), 0)
        XCTAssertEqual(FlightViewModel.gatePulseStrength(for: .ok), 0)
        XCTAssertEqual(FlightViewModel.gatePulseStrength(for: .miss), 0)
    }
}
