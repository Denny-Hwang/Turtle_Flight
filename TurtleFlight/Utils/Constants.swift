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
        /// Per-frame slerp factor used by `FlightViewModel.updateCamera()`.
        /// 0.15 was retuned from 0.10 after the PH-launch review: sharp
        /// turns at Lv3 with 90° course corrections every couple seconds
        /// (Stage 5 air-race) produced ~100ms camera lag that read as
        /// "the camera is losing the character." 0.15 cuts that lag to
        /// ~67ms while still smoothing out the high-frequency gyro
        /// noise that 0.20+ would let through. Reduce-Motion users
        /// continue to fall back to a slower lerp in FlightViewModel.
        static let lerpSpeed: Float = 0.15
        /// Roll applied to the camera as a fraction of the player's roll
        /// input. 0.25 (≈14°) was retuned from 0.15 (≈8°) to give the
        /// banking a more readable visual hook on PH demo video frames
        /// — at 0.15 a maximum bank looked nearly level.
        static let bankingAngle: Float = 0.25
        /// Default field of view. The boost path layers `boostFOVDelta`
        /// on top of this scaled by `boostProgress` so a max-boost frame
        /// reads at ~78° and the player feels the acceleration through
        /// the lens rather than only as a number going up.
        static let fieldOfView: CGFloat = 70.0
        /// Extra degrees added to the FOV at full-boost (`boostProgress=1`).
        /// Lerped down with boost progress so the change is automatically
        /// reversible. 8° was picked so the perspective punch is visible
        /// in side-by-side without crossing into vestibular-discomfort
        /// territory. Suppressed entirely when Reduce Motion is on.
        static let boostFOVDelta: CGFloat = 8.0
        /// Extra follow-distance at full-boost. Pulling the camera back
        /// 3m while the speed is doubled keeps the character's apparent
        /// on-screen size roughly constant — without this, max-boost
        /// reads as "the screen got smaller" rather than "I got faster."
        static let boostFollowDistanceDelta: Float = 3.0
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
        /// Minimum interval between two respawn calls. Halved from 4.0s
        /// after the PH-launch review: at 4s the Free Flight rhythm
        /// stalled into "wait for stars" lulls after the initial
        /// cluster. 2.0s keeps a fresh cluster reachable without
        /// devolving into a confetti-everywhere blur.
        static let starRespawnCooldown: TimeInterval = 2.0
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
