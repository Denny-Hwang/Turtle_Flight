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
        case .shellJet:      return "Shell Jet"
        case .bellyGlider:   return "Belly Glider"
        case .hamsterCopter: return "Hamster Ball Copter"
        case .magicBroom:    return "Magic Broom"
        case .balloonBody:   return "Balloon Body"
        case .earCopter:     return "Ear Copter"
        case .cloudSurf:     return "Cloud Surf"
        }
    }

    var koreanName: String {
        switch self {
        case .shellJet:      return "등껍질 제트"
        case .bellyGlider:   return "배 활공"
        case .hamsterCopter: return "햄스터볼 헬리콥터"
        case .magicBroom:    return "마법 빗자루"
        case .balloonBody:   return "풍선 비행"
        case .earCopter:     return "귀 헬리콥터"
        case .cloudSurf:     return "구름 서핑"
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
