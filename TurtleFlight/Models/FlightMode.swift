import Foundation

enum FlightMode: String, CaseIterable, Codable {
    case freePlay
    case stepGoal

    var displayName: String {
        switch self {
        case .freePlay: return L10n.t("flight.mode.freePlay")
        case .stepGoal: return L10n.t("flight.mode.stepGoal")
        }
    }

    var icon: String {
        switch self {
        case .freePlay: return "🌤️"
        case .stepGoal: return "🎯"
        }
    }
}
