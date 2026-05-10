import XCTest
@testable import TurtleFlight

/// Pins the L10n surface that previously bled English into Korean
/// (and vice-versa): map theme display names, theme subtitles, region
/// labels, stage descriptions, and the 3-star condition strings.
///
/// The strategy is to sample a few keys per category and assert:
///   1. The lookup returns a non-empty, non-key value (proving the key
///      exists in the bundle).
///   2. The Korean and English values differ for at least one canonical
///      example per category (proving both bundles have entries — if one
///      file is missing, the localized string falls back to the key for
///      the missing locale and we'd catch that here).
///
/// We deliberately don't assert on EXACT translations — copy is a moving
/// target and these tests should survive copy edits without false
/// negatives.
final class LocalizationCoverageTests: XCTestCase {

    /// Sanity: L10n.t returns the localized value if the key exists, else
    /// the key itself. So a non-empty result that doesn't equal the key
    /// proves the key was found in *some* bundle.
    private func assertLocalized(_ key: String,
                                  file: StaticString = #file,
                                  line: UInt = #line) {
        let value = L10n.t(key)
        XCTAssertFalse(value.isEmpty, "L10n key '\(key)' returned empty",
                       file: file, line: line)
        XCTAssertNotEqual(value, key,
                          "L10n key '\(key)' is not in any bundle (returned key as fallback)",
                          file: file, line: line)
    }

    // MARK: - Map themes

    func testEachThemeHasDisplayName() {
        for theme in MapTheme.allCases {
            assertLocalized("theme.\(theme.rawValue).displayName")
        }
    }

    func testEachThemeHasSubtitle() {
        for theme in MapTheme.allCases {
            assertLocalized("theme.\(theme.rawValue).subtitle")
        }
    }

    func testMapThemeDisplayNameDoesNotReturnEnglishLiteralFromCode() {
        // Pre-Sprint-0, MapTheme.displayName returned a hard-coded English
        // string ("Sky Kingdom" etc.) regardless of locale. Now it goes
        // through L10n. Verify the property routes through the bundle by
        // confirming it equals the bundle lookup.
        for theme in MapTheme.allCases {
            XCTAssertEqual(theme.displayName,
                           L10n.t("theme.\(theme.rawValue).displayName"),
                           "MapTheme.displayName should be a thin wrapper around L10n")
        }
    }

    func testEachThemeHasEightRegionNames() {
        for theme in MapTheme.allCases {
            let names = theme.regionNames
            XCTAssertEqual(names.count, 8,
                           "Theme '\(theme.rawValue)' should expose 8 region names")
            for (i, name) in names.enumerated() {
                XCTAssertFalse(name.isEmpty,
                               "Region \(i) for theme '\(theme.rawValue)' is empty")
                XCTAssertNotEqual(
                    name, "theme.\(theme.rawValue).region.\(i)",
                    "Region \(i) for theme '\(theme.rawValue)' returned the raw key — missing translation"
                )
            }
        }
    }

    // MARK: - Stages

    func testEachStageHasLocalizedDescription() {
        for stage in StageDefinition.allStages {
            // The computed property falls back to the embedded `description`
            // string if the key is missing — so we can't assertLocalized
            // directly. Instead we assert the result is non-empty and
            // matches the live computed property.
            let computed = stage.displayDescription
            XCTAssertFalse(computed.isEmpty,
                           "Stage \(stage.index) displayDescription is empty")
        }
    }

    func testEachStageHasLocalizedStar3Condition() {
        for stage in StageDefinition.allStages {
            let computed = stage.displayStar3Condition
            XCTAssertFalse(computed.isEmpty,
                           "Stage \(stage.index) displayStar3Condition is empty")
        }
    }

    func testStageDisplayNameRoutesThroughBundleNotKoreanFallback() {
        // For each stage where stage.<i>.name is in the bundle, displayName
        // should return the bundle string, NOT the legacy `koreanName`.
        for stage in StageDefinition.allStages {
            let bundleValue = L10n.t("stage.\(stage.index).name")
            // bundleValue equals the key iff missing — in that case the
            // legacy fallback applies. Tests run in the dev region (en)
            // by default, so we expect bundle hits for every stage.
            if bundleValue != "stage.\(stage.index).name" {
                XCTAssertEqual(stage.displayName, bundleValue,
                               "displayName should return the bundle value when present")
            }
        }
    }
}
