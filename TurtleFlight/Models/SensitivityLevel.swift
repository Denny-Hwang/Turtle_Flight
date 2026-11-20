import Foundation

enum SensitivityLevel: String, CaseIterable, Codable {
    case easy
    case normal
    case expert

    var displayName: String {
        switch self {
        case .easy:   return L10n.t("sensitivity.easy")
        case .normal: return L10n.t("sensitivity.normal")
        case .expert: return L10n.t("sensitivity.expert")
        }
    }

    var emoji: String {
        switch self {
        case .easy:   return "🟢"
        case .normal: return "🟡"
        case .expert: return "🔴"
        }
    }

    var levelNumber: Int {
        switch self {
        case .easy:   return 1
        case .normal: return 2
        case .expert: return 3
        }
    }
}
