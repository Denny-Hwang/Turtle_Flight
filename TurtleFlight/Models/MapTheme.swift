import Foundation
import UIKit

enum MapTheme: String, CaseIterable, Codable {
    case sky
    case space
    case ocean

    var displayName: String {
        switch self {
        case .sky:   return "Sky Kingdom"
        case .space: return "Cosmic Voyage"
        case .ocean: return "Ocean Dream"
        }
    }

    var emoji: String {
        switch self {
        case .sky:   return "☁️"
        case .space: return "🚀"
        case .ocean: return "🐠"
        }
    }

    var subtitle: String {
        switch self {
        case .sky:   return "Clouds & Rainbows"
        case .space: return "Stars & Planets"
        case .ocean: return "Coral & Bubbles"
        }
    }

    var icon: String {
        switch self {
        case .sky:   return "cloud.sun.fill"
        case .space: return "moon.stars.fill"
        case .ocean: return "water.waves"
        }
    }

    // MARK: - Scene Colors

    var backgroundColor: UIColor {
        switch self {
        case .sky:
            return UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0)
        case .space:
            return UIColor(red: 0.05, green: 0.02, blue: 0.15, alpha: 1.0)
        case .ocean:
            return UIColor(red: 0.10, green: 0.40, blue: 0.65, alpha: 1.0)
        }
    }

    var ambientLightColor: UIColor {
        switch self {
        case .sky:   return .white
        case .space: return UIColor(red: 0.6, green: 0.6, blue: 0.9, alpha: 1.0)
        case .ocean: return UIColor(red: 0.5, green: 0.8, blue: 0.9, alpha: 1.0)
        }
    }

    var ambientLightIntensity: CGFloat {
        switch self {
        case .sky:   return 600
        case .space: return 300
        case .ocean: return 500
        }
    }

    var sunLightColor: UIColor {
        switch self {
        case .sky:   return .white
        case .space: return UIColor(red: 0.9, green: 0.85, blue: 1.0, alpha: 1.0)
        case .ocean: return UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 1.0)
        }
    }

    var sunLightIntensity: CGFloat {
        switch self {
        case .sky:   return 800
        case .space: return 400
        case .ocean: return 600
        }
    }

    // MARK: - Region Names

    var regionNames: [String] {
        switch self {
        case .sky:
            return [
                "Cloud Kingdom",
                "Rainbow Valley",
                "Sparkle Lake",
                "Windy Hills",
                "Starlight Plains",
                "Sunflower Fields",
                "Crystal Caves",
                "Sunset Beach"
            ]
        case .space:
            return [
                "Milky Way Lane",
                "Nebula Garden",
                "Saturn's Ring Park",
                "Shooting Star Alley",
                "Moon Bounce Zone",
                "Comet Trail",
                "Galaxy Whirlpool",
                "Asteroid Playground"
            ]
        case .ocean:
            return [
                "Coral Castle",
                "Bubble Boulevard",
                "Seaweed Forest",
                "Pearl Harbor Cove",
                "Jellyfish Meadow",
                "Treasure Reef",
                "Whale Song Bay",
                "Starfish Garden"
            ]
        }
    }
}
