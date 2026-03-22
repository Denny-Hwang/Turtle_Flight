import Foundation

enum CharacterType: String, CaseIterable, Codable {
    case turtle
    case penguin
    case hamster
    case cat
    case frog
    case bunny

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
                description: "느린 거북이도 하늘을 날 수 있다!",
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
                description: "배로 미끄러지며 하늘을 활공!",
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
                description: "햄스터볼이 하늘을 난다!",
                personality: "호기심 왕. 볼이 빵빵하게 부풀어 있음"
            )
        case .cat:
            return CharacterConfig(
                type: .cat,
                name: "Mochi",
                emoji: "🐱",
                modelName: "mochi_cat",
                defaultVehicle: .magicBroom,
                availableVehicles: [.magicBroom, .cloudSurf],
                description: "마법 빗자루를 타고 하늘을!",
                personality: "도도하지만 무서움 많은. 마녀 모자"
            )
        case .frog:
            return CharacterConfig(
                type: .frog,
                name: "Bounce",
                emoji: "🐸",
                modelName: "bounce_frog",
                defaultVehicle: .balloonBody,
                availableVehicles: [.balloonBody, .cloudSurf],
                description: "몸이 풍선이 되어 두둥실!",
                personality: "느긋한 성격. 볼이 부풀면 표정 변화"
            )
        case .bunny:
            return CharacterConfig(
                type: .bunny,
                name: "Hoppy",
                emoji: "🐰",
                modelName: "hoppy_bunny",
                defaultVehicle: .earCopter,
                availableVehicles: [.earCopter, .cloudSurf],
                description: "귀를 프로펠러처럼 돌려 이륙!",
                personality: "활발하고 용감한. 빨간 비행 고글+스카프"
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
