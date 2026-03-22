import Foundation

enum SensitivityLevel: String, CaseIterable, Codable {
    case easy
    case normal
    case expert

    var displayName: String {
        switch self {
        case .easy:   return "Easy"
        case .normal: return "Normal"
        case .expert: return "Expert"
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
