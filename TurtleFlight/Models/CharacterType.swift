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
                description: L10n.t("character.turtle.description")
            )
        case .penguin:
            return CharacterConfig(
                type: .penguin,
                name: "Pip",
                emoji: "🐧",
                modelName: "pip_penguin",
                defaultVehicle: .bellyGlider,
                availableVehicles: [.bellyGlider, .cloudSurf],
                description: L10n.t("character.penguin.description")
            )
        case .hamster:
            return CharacterConfig(
                type: .hamster,
                name: "Nutty",
                emoji: "🐹",
                modelName: "nutty_hamster",
                defaultVehicle: .hamsterCopter,
                availableVehicles: [.hamsterCopter, .cloudSurf],
                description: L10n.t("character.hamster.description")
            )
        case .cat:
            return CharacterConfig(
                type: .cat,
                name: "Mochi",
                emoji: "🐱",
                modelName: "mochi_cat",
                defaultVehicle: .cushionBalloon,
                availableVehicles: [.cushionBalloon, .cloudSurf],
                description: L10n.t("character.cat.description")
            )
        case .frog:
            return CharacterConfig(
                type: .frog,
                name: "Bounce",
                emoji: "🐸",
                modelName: "bounce_frog",
                defaultVehicle: .balloonBody,
                availableVehicles: [.balloonBody, .cloudSurf],
                description: L10n.t("character.frog.description")
            )
        case .bunny:
            return CharacterConfig(
                type: .bunny,
                name: "Hoppy",
                emoji: "🐰",
                modelName: "hoppy_bunny",
                defaultVehicle: .carrotJet,
                availableVehicles: [.carrotJet, .cloudSurf],
                description: L10n.t("character.bunny.description")
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
}
