import Foundation

enum CharacterType: String, CaseIterable, Codable {
    case turtle
    case penguin
    case hamster
    case cat
    case frog
    case bunny

    /// Asset-name prefix used by every imageset in `Assets.xcassets/Characters/`.
    /// e.g. `.turtle.assetPrefix == "turbo"` → `Image("turbo_icon")`.
    var assetPrefix: String {
        switch self {
        case .turtle:  return "turbo"
        case .penguin: return "pip"
        case .hamster: return "nutty"
        case .cat:     return "mochi"
        case .frog:    return "bounce"
        case .bunny:   return "hoppy"
        }
    }

    var config: CharacterConfig {
        switch self {
        case .turtle:
            return CharacterConfig(
                type: .turtle,
                name: "Turbo",
                emoji: "🐢",
                modelName: "turbo_turtle",
                defaultVehicle: .shellJet,
                availableVehicles: [.shellJet, .cloudSurf],
                description: L10n.t("character.turtle.description"),
                personality: "느리지만 꿋꿋한. 고글 착용"
            )
        case .penguin:
            return CharacterConfig(
                type: .penguin,
                name: "Pip",
                emoji: "🐧",
                modelName: "pip_penguin",
                defaultVehicle: .bellyGlider,
                availableVehicles: [.bellyGlider, .cloudSurf],
                description: L10n.t("character.penguin.description"),
                personality: "통통하고 명랑. 스카프 휘날림"
            )
        case .hamster:
            return CharacterConfig(
                type: .hamster,
                name: "Nutty",
                emoji: "🐹",
                modelName: "nutty_hamster",
                defaultVehicle: .hamsterCopter,
                availableVehicles: [.hamsterCopter, .cloudSurf],
                description: L10n.t("character.hamster.description"),
                personality: "호기심 왕. 볼이 빵빵하게 부풀어 있음"
            )
        case .cat:
            return CharacterConfig(
                type: .cat,
                name: "Mochi",
                emoji: "🐱",
                modelName: "mochi_cat",
                defaultVehicle: .cushionBalloon,
                availableVehicles: [.cushionBalloon, .cloudSurf],
                description: L10n.t("character.cat.description"),
                personality: "도도한 츤데레. 별 표시 + 방울 목걸이"
            )
        case .frog:
            return CharacterConfig(
                type: .frog,
                name: "Bounce",
                emoji: "🐸",
                modelName: "bounce_frog",
                defaultVehicle: .balloonBody,
                availableVehicles: [.balloonBody, .cloudSurf],
                description: L10n.t("character.frog.description"),
                personality: "느긋한 성격. 볼이 부풀면 표정 변화"
            )
        case .bunny:
            return CharacterConfig(
                type: .bunny,
                name: "Hoppy",
                emoji: "🐰",
                modelName: "hoppy_bunny",
                defaultVehicle: .carrotJet,
                availableVehicles: [.carrotJet, .cloudSurf],
                description: L10n.t("character.bunny.description"),
                personality: "수줍지만 모험심 많은. 한쪽 귀에 꽃, 한쪽 귀가 살짝 처짐"
            )
        }
    }
}

struct CharacterConfig {
    let type: CharacterType
    let name: String
    let emoji: String
    let modelName: String
    let defaultVehicle: VehicleType
    let availableVehicles: [VehicleType]
    let description: String
    let personality: String
}
