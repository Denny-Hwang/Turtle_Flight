import Foundation

enum FlightMode: String, CaseIterable, Codable {
    case freePlay
    case stepGoal

    var displayName: String {
        switch self {
        case .freePlay: return "자유 비행"
        case .stepGoal: return "Step Goal"
        }
    }

    var icon: String {
        switch self {
        case .freePlay: return "🌤️"
        case .stepGoal: return "🎯"
        }
    }
}
