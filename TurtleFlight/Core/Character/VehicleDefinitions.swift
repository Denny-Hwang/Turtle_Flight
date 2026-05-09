import Foundation

/// Defines vehicle properties and relationships
struct VehicleDefinition {
    let type: VehicleType
    let ownerCharacter: CharacterType?  // nil for shared vehicles
    let displayName: String
    let koreanName: String
    let boostEffect: String   // Description of visual effect
    let soundEffect: String   // Sound file name

    static let all: [VehicleDefinition] = [
        VehicleDefinition(
            type: .shellJet,
            ownerCharacter: .turtle,
            displayName: "Shell Jet",
            koreanName: "등껍질 제트",
            boostEffect: "화염 분사, 머리/팔다리 쏙 들어갔다 나옴",
            soundEffect: "jet_whoosh"
        ),
        VehicleDefinition(
            type: .bellyGlider,
            ownerCharacter: .penguin,
            displayName: "Belly Glider",
            koreanName: "배 활공",
            boostEffect: "날개로 밸런스, 미끄러지며 활공",
            soundEffect: "glide_wind"
        ),
        VehicleDefinition(
            type: .hamsterCopter,
            ownerCharacter: .hamster,
            displayName: "Hamster Ball Copter",
            koreanName: "햄스터볼 헬리콥터",
            boostEffect: "공이 회전하며 프로펠러 역할, 안에서 달림",
            soundEffect: "copter_spin"
        ),
        VehicleDefinition(
            type: .cushionBalloon,
            ownerCharacter: .cat,
            displayName: "Cushion Hot Air Balloon",
            koreanName: "쿠션 열기구",
            boostEffect: "고양이 침대 모양 바구니에 누워 부유, 라벤더 화염으로 가속",
            soundEffect: "balloon_hiss"
        ),
        VehicleDefinition(
            type: .balloonBody,
            ownerCharacter: .frog,
            displayName: "Balloon Body",
            koreanName: "풍선 비행",
            boostEffect: "몸이 부풀어 떠오름, 공기 빠지면 부스트",
            soundEffect: "balloon_inflate"
        ),
        VehicleDefinition(
            type: .carrotJet,
            ownerCharacter: .bunny,
            displayName: "Carrot Jet",
            koreanName: "당근 제트",
            boostEffect: "당근 제트기로 가속, 잎사귀 꼬리 핀, 하트 모양 배기",
            soundEffect: "jet_whoosh_soft"
        ),
        VehicleDefinition(
            type: .cloudSurf,
            ownerCharacter: nil,
            displayName: "Cloud Surf",
            koreanName: "구름 서핑",
            boostEffect: "구름 서핑보드에 서서 비행",
            soundEffect: "cloud_whoosh"
        )
    ]

    static func definition(for type: VehicleType) -> VehicleDefinition? {
        all.first { $0.type == type }
    }

    static func availableVehicles(for character: CharacterType) -> [VehicleDefinition] {
        all.filter { $0.ownerCharacter == character || $0.ownerCharacter == nil }
    }
}
