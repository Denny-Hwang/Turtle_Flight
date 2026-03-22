import Foundation
import CoreGraphics

enum Constants {
    // MARK: - App
    enum App {
        static let name = "Turtle Flight"
        static let subtitle = "Tilt to Fly"
    }

    // MARK: - Colors (Hex)
    enum Colors {
        static let skyBlue = 0x87CEEB
        static let turtleGreen = 0x2ECC71
        static let boostOrange = 0xFF6B35
        static let starGold = 0xFFD700
        static let hudCyan = 0x7FDBFF
        static let panelDark = 0x1A1A2E
        static let normalYellow = 0xF39C12
        static let expertRed = 0xE74C3C
    }

    // MARK: - Flight
    enum Flight {
        static let defaultAltitude: Float = 500.0
        static let defaultSpeed: Float = 200.0
        static let boostMultiplier: Float = 2.0
        static let boostDuration: TimeInterval = 3.0
        static let maxAltitude: Float = 10000.0
        static let gravity: Float = 9.8
    }

    // MARK: - Camera
    enum Camera {
        static let followDistance: Float = 15.0
        static let followHeight: Float = 5.0
        static let lerpSpeed: Float = 0.1
        static let bankingAngle: Float = 0.15
    }

    // MARK: - Terrain
    enum Terrain {
        static let chunkSize: Float = 200.0
        static let gridResolution: Int = 64
        static let visibleChunks: Int = 3 // 3x3 grid
        static let maxHeight: Float = 300.0
        static let waterLevel: Float = 0.0
        static let sandLevel: Float = 20.0
        static let grassLevel: Float = 80.0
        static let rockLevel: Float = 180.0
        static let snowLevel: Float = 250.0
    }

    // MARK: - Controls
    enum Controls {
        static let buttonSize: CGFloat = 72.0
        static let buttonPadding: CGFloat = 20.0
    }

    // MARK: - Sensor
    enum Sensor {
        static let updateInterval: TimeInterval = 1.0 / 60.0 // 60 Hz
    }

    // MARK: - Items
    enum Items {
        static let starCollectionRadius: Float = 10.0
        static let projectileSpeed: Float = 50.0
        static let projectileLifetime: TimeInterval = 3.0
    }

    // MARK: - Region Names
    static let regionNames = [
        "구름 왕국 ☁️",
        "무지개 계곡 🌈",
        "반짝이 호수 ✨",
        "바람의 언덕 🌬️",
        "별빛 평원 ⭐",
        "해바라기 들판 🌻",
        "수정 동굴 💎",
        "노을빛 해안 🌅"
    ]
}
