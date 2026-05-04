import Foundation

enum VehicleType: String, CaseIterable, Codable {
    // Character-specific
    case shellJet       // 🐢 등껍질 제트
    case bellyGlider    // 🐧 배 활공
    case hamsterCopter  // 🐹 햄스터볼 헬리콥터
    case magicBroom     // 🐱 마법 빗자루
    case balloonBody    // 🐸 풍선 비행
    case earCopter      // 🐰 귀 헬리콥터
    // Shared
    case cloudSurf      // ☁️ 구름 서핑 (ALL)

    var displayName: String {
        switch self {
        case .shellJet:      return L10n.t("vehicle.shellJet")
        case .bellyGlider:   return L10n.t("vehicle.bellyGlider")
        case .hamsterCopter: return L10n.t("vehicle.hamsterCopter")
        case .magicBroom:    return L10n.t("vehicle.magicBroom")
        case .balloonBody:   return L10n.t("vehicle.balloonBody")
        case .earCopter:     return L10n.t("vehicle.earCopter")
        case .cloudSurf:     return L10n.t("vehicle.cloudSurf")
        }
    }

    var icon: String {
        switch self {
        case .shellJet:      return "🔥"
        case .bellyGlider:   return "🐧"
        case .hamsterCopter: return "🔄"
        case .magicBroom:    return "🧹"
        case .balloonBody:   return "🎈"
        case .earCopter:     return "🚁"
        case .cloudSurf:     return "☁️"
        }
    }

    var isShared: Bool {
        self == .cloudSurf
    }
}
