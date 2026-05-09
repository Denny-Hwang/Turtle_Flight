import Foundation

enum VehicleType: String, CaseIterable, Codable {
    // Character-specific
    case shellJet         // 🐢 등껍질 제트
    case bellyGlider      // 🐧 배 활공
    case hamsterCopter    // 🐹 햄스터볼 헬리콥터
    case cushionBalloon   // 🐱 쿠션 열기구 (cushion-basket hot air balloon)
    case balloonBody      // 🐸 풍선 비행
    case carrotJet        // 🐰 당근 제트
    // Shared
    case cloudSurf        // ☁️ 구름 서핑 (ALL)

    var displayName: String {
        switch self {
        case .shellJet:        return L10n.t("vehicle.shellJet")
        case .bellyGlider:     return L10n.t("vehicle.bellyGlider")
        case .hamsterCopter:   return L10n.t("vehicle.hamsterCopter")
        case .cushionBalloon:  return L10n.t("vehicle.cushionBalloon")
        case .balloonBody:     return L10n.t("vehicle.balloonBody")
        case .carrotJet:       return L10n.t("vehicle.carrotJet")
        case .cloudSurf:       return L10n.t("vehicle.cloudSurf")
        }
    }

    var icon: String {
        switch self {
        case .shellJet:        return "🔥"
        case .bellyGlider:     return "🐧"
        case .hamsterCopter:   return "🔄"
        case .cushionBalloon:  return "🎀"
        case .balloonBody:     return "🎈"
        case .carrotJet:       return "🥕"
        case .cloudSurf:       return "☁️"
        }
    }

    var isShared: Bool {
        self == .cloudSurf
    }
}
