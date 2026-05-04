import Foundation

/// Lightweight wrapper around `NSLocalizedString` that keeps call sites short
/// and gives format-string keys a typed signature.
///
/// Usage:
///     L10n.t("common.ok")
///     L10n.format("mission.collisions.format", 3)
enum L10n {
    /// Plain lookup. The key itself doubles as the comment so genstrings/Xcode
    /// can extract it; concrete translations live in Localizable.strings.
    static func t(_ key: String) -> String {
        NSLocalizedString(key, comment: key)
    }

    /// Localized format string applied to `args`. Uses CVarArg so call sites
    /// can pass Int, Int64, String, etc. without manual casting.
    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: key), arguments: args)
    }
}
