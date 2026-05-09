import XCTest
import SwiftUI
@testable import TurtleFlight

/// Sanity tests for the design-token foundation.
///
/// These tests intentionally don't try to assert on rendered SwiftUI
/// output (that's an integration concern). They pin three things:
///   1. Token tables don't drift from their underlying palette.
///   2. The scale relationships hold (xs < s < m < l … so layouts that
///      depend on relative size won't silently flip if a number changes).
///   3. The elevation modifier is applied without crashing.
final class ThemeTests: XCTestCase {

    // MARK: - Spacing scale monotonicity

    func testSpacingScaleIsMonotonic() {
        XCTAssertLessThan(Theme.Spacing.xxs, Theme.Spacing.xs)
        XCTAssertLessThan(Theme.Spacing.xs,  Theme.Spacing.s)
        XCTAssertLessThan(Theme.Spacing.s,   Theme.Spacing.m)
        XCTAssertLessThan(Theme.Spacing.m,   Theme.Spacing.l)
        XCTAssertLessThan(Theme.Spacing.l,   Theme.Spacing.xl)
        XCTAssertLessThan(Theme.Spacing.xl,  Theme.Spacing.xxl)
        XCTAssertLessThan(Theme.Spacing.xxl, Theme.Spacing.xxxl)
    }

    func testSpacingScaleAnchors() {
        // Anchor points the migration relies on. Reviewers should push back
        // if these change without intent.
        XCTAssertEqual(Theme.Spacing.s,  8)
        XCTAssertEqual(Theme.Spacing.m,  12)
        XCTAssertEqual(Theme.Spacing.l,  16)
        XCTAssertEqual(Theme.Spacing.xl, 24)
    }

    // MARK: - Radius scale monotonicity

    func testRadiusScaleIsMonotonic() {
        XCTAssertLessThan(Theme.Radius.xs, Theme.Radius.s)
        XCTAssertLessThan(Theme.Radius.s,  Theme.Radius.m)
        XCTAssertLessThan(Theme.Radius.m,  Theme.Radius.l)
        XCTAssertLessThan(Theme.Radius.l,  Theme.Radius.xl)
    }

    // MARK: - Elevation recipes

    func testElevationRecipesDefineNonZeroBlur() {
        for shadow in [Theme.Elevation.card, Theme.Elevation.cardHigh, Theme.Elevation.button] {
            XCTAssertGreaterThan(shadow.radius, 0)
            XCTAssertGreaterThan(shadow.yOffset, 0,
                                 "shadow falls downward (positive y)")
        }
        // Higher-elevation card casts a longer + softer shadow than the
        // resting card.
        XCTAssertGreaterThan(Theme.Elevation.cardHigh.radius,
                             Theme.Elevation.card.radius)
        XCTAssertGreaterThan(Theme.Elevation.cardHigh.yOffset,
                             Theme.Elevation.card.yOffset)
    }

    func testElevationModifierAppliesWithoutCrashing() {
        // Smoke test the .elevation(_:) view modifier is reachable.
        let _ = Color.red.elevation(Theme.Elevation.card)
        let _ = Color.blue.elevation(Theme.Elevation.button)
    }

    // MARK: - Brand color is in sync with the palette

    func testBrandPrimaryMatchesTurboMint() {
        // Theme.Color.brandPrimary must be derived from
        // Constants.Colors.turboMint — DESIGN_GAP_REPORT C4 was about
        // exactly this drifting apart.
        let expected = Color(hex: Constants.Colors.turboMint)
        XCTAssertEqual(
            Theme.Color.brandPrimary.description,
            expected.description,
            "Theme.Color.brandPrimary should hold Constants.Colors.turboMint"
        )
    }

    func testEasyGreenMatchesPalette() {
        let expected = Color(hex: Constants.Colors.easyGreen)
        XCTAssertEqual(
            Theme.Color.easyGreen.description,
            expected.description
        )
    }
}
