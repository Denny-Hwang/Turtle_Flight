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
        // Turbo brand mint — matches docs/CHARACTER_DESIGN_PROMPT.md (Turbo primary)
        static let turboMint = 0x5DCAA5
        // Generic positive / Easy-difficulty / safe-state green (NOT Turbo's brand)
        static let easyGreen = 0x2ECC71
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
        /// Refill threshold — once uncollected pool drops below this count
        /// (and the cooldown has elapsed), the flight loop spawns a fresh
        /// cluster around the player. Tuned so the player rarely *sees*
        /// the field empty without making it feel infinite either.
        static let starRespawnThreshold: Int = 3
        /// Minimum interval between two respawn calls. A flat-out flier
        /// could otherwise dump a fresh cluster every couple of seconds.
        static let starRespawnCooldown: TimeInterval = 4.0
    }

    // MARK: - Collision
    enum Collision {
        /// Vertical clearance (in world units) between the character billboard
        /// and the terrain mesh below it. Below this the flight loop registers
        /// a collision with `MissionEngine.registerCollision()`. Tuned so the
        /// player has to actually graze the surface — not so loose that
        /// hovering 30m up trips it constantly.
        static let groundClearance: Float = 8.0
        /// Minimum gap between consecutive collision events. A flat hilltop
        /// would otherwise spam ~60 collisions/sec at 60fps, killing the
        /// 3-star eligibility on the first contact frame. 0.5s gives the
        /// player time to correct before a second penalty.
        static let cooldown: TimeInterval = 0.5
    }

    // MARK: - Region Names (fallback — themes supply their own)
    static let regionNames = [
        "Cloud Kingdom",
        "Rainbow Valley",
        "Sparkle Lake",
        "Windy Hills",
        "Starlight Plains",
        "Sunflower Fields",
        "Crystal Caves",
        "Sunset Beach"
    ]

    // MARK: - Map Theme Colors
    enum ThemeColors {
        // Sky
        static let skyPrimary   = 0x87CEEB
        static let skySecondary = 0xFFFACD
        // Space
        static let spacePrimary   = 0x0D0025
        static let spaceSecondary = 0x6A0DAD
        // Ocean
        static let oceanPrimary   = 0x006994
        static let oceanSecondary = 0x40E0D0
    }
}
