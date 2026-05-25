import XCTest
@testable import TurtleFlight

/// Enforces that every shipped locale's `Localizable.strings` has the
/// *exact* same key set as the development locale (en), with no empty
/// values. Adding a key to en without translating it in (say) ja would
/// otherwise ship a key-as-fallback string to Japanese users — this
/// test turns that into a build failure.
///
/// Unlike `LocalizationCoverageTests` (which samples keys via `L10n.t`
/// in the dev region), this reads each locale's `.strings` file straight
/// from the app bundle and diffs the parsed dictionaries.
final class LocalizationParityTests: XCTestCase {

    /// The bundle the .strings files are compiled into. `FlightViewModel`
    /// is an app type, so `Bundle(for:)` resolves the app bundle whether
    /// the tests run hosted in the app or against a built product.
    private var appBundle: Bundle { Bundle(for: FlightViewModel.self) }

    /// Every locale declared in Info.plist's CFBundleLocalizations.
    private let locales = ["en", "ko", "ja", "zh-Hans", "es", "fr", "de"]

    /// Load `<locale>.lproj/Localizable.strings` as a dictionary, or nil
    /// if the bundle doesn't carry that localization.
    private func strings(for locale: String) -> [String: String]? {
        guard let path = appBundle.path(forResource: "Localizable",
                                        ofType: "strings",
                                        inDirectory: nil,
                                        forLocalization: locale)
        else { return nil }
        return NSDictionary(contentsOfFile: path) as? [String: String]
    }

    func testAllDeclaredLocalesArePresent() {
        for locale in locales {
            XCTAssertNotNil(strings(for: locale),
                "Locale '\(locale)' is declared but its Localizable.strings is missing from the bundle")
        }
    }

    func testEveryLocaleMatchesEnglishKeySet() {
        guard let en = strings(for: "en") else {
            return XCTFail("en.lproj/Localizable.strings missing — cannot run parity check")
        }
        let enKeys = Set(en.keys)
        XCTAssertGreaterThan(enKeys.count, 200,
                             "Sanity: en should have the full key set")

        for locale in locales where locale != "en" {
            guard let dict = strings(for: locale) else {
                XCTFail("Missing strings for locale '\(locale)'")
                continue
            }
            let keys = Set(dict.keys)
            let missing = enKeys.subtracting(keys)
            let extra = keys.subtracting(enKeys)
            XCTAssertTrue(missing.isEmpty,
                "Locale '\(locale)' is missing \(missing.count) key(s): \(missing.sorted().prefix(10))")
            XCTAssertTrue(extra.isEmpty,
                "Locale '\(locale)' has \(extra.count) key(s) not in en: \(extra.sorted().prefix(10))")
        }
    }

    func testNoLocaleHasEmptyValues() {
        for locale in locales {
            guard let dict = strings(for: locale) else { continue }
            for (key, value) in dict {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               "Locale '\(locale)' has an empty value for key '\(key)'")
            }
        }
    }

    /// Format specifiers must match en exactly (count + kind), or
    /// `String(format:)` crashes / renders garbage at runtime in that
    /// locale. We canonicalise each value's `%lld` / `%@` specifiers and
    /// compare the multiset against en.
    func testFormatSpecifiersMatchEnglish() {
        guard let en = strings(for: "en") else {
            return XCTFail("en missing")
        }
        func specs(_ s: String) -> [String] {
            // Match %@ and %lld (the only two families used in this app).
            let pattern = "%(?:lld|@)"
            let re = try! NSRegularExpression(pattern: pattern)
            let range = NSRange(s.startIndex..., in: s)
            return re.matches(in: s, range: range)
                .compactMap { Range($0.range, in: s).map { String(s[$0]) } }
                .sorted()
        }
        for locale in locales where locale != "en" {
            guard let dict = strings(for: locale) else { continue }
            for (key, enValue) in en {
                guard let localized = dict[key] else { continue } // key-set test covers this
                XCTAssertEqual(specs(enValue), specs(localized),
                    "Format specifier mismatch for '\(key)' in '\(locale)': en=\(specs(enValue)) vs \(locale)=\(specs(localized))")
            }
        }
    }
}
