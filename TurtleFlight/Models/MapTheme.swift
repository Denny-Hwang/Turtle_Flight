import Foundation
import SwiftUI
import UIKit

/// A world the player can fly in. The first three shipped in 1.0 (sky,
/// space, ocean); the "world tour" four (desert, city, seoul, wild)
/// were added later. Raw values are persisted — never rename a case.
///
/// Everything that differs per world lives here or in `WorldProfile`
/// (terrain shape, colours, landmarks), so adding a world is a
/// two-file change plus strings.
enum MapTheme: String, CaseIterable, Codable {
    case sky
    case desert
    case city
    case seoul
    case wild
    case space
    case ocean

    /// Localized title shown in the map-picker card. Falls through to the
    /// raw key if a `.strings` file omits the entry — that surfaces the
    /// missing translation in QA rather than silently shipping English.
    var displayName: String {
        L10n.t("theme.\(rawValue).displayName")
    }

    var emoji: String {
        switch self {
        case .sky:    return "☁️"
        case .desert: return "🏜️"
        case .city:   return "🌉"
        case .seoul:  return "🌸"
        case .wild:   return "🏔️"
        case .space:  return "🚀"
        case .ocean:  return "🐠"
        }
    }

    /// Localized subtitle ("Clouds & Rainbows", "별과 행성", …).
    var subtitle: String {
        L10n.t("theme.\(rawValue).subtitle")
    }

    var icon: String {
        switch self {
        case .sky:    return "cloud.sun.fill"
        case .desert: return "sun.max.fill"
        case .city:   return "building.2.fill"
        case .seoul:  return "leaf.fill"
        case .wild:   return "mountain.2.fill"
        case .space:  return "moon.stars.fill"
        case .ocean:  return "water.waves"
        }
    }

    /// Worlds with a real sky above them: these get the sun and the
    /// per-flight time of day (`SkyMood`). Space and ocean keep their
    /// own fixed look.
    var hasOpenSky: Bool {
        switch self {
        case .space, .ocean: return false
        default:             return true
        }
    }

    // MARK: - Scene Colors

    var backgroundColor: UIColor {
        switch self {
        case .sky:    return UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0)
        case .desert: return UIColor(red: 0.98, green: 0.80, blue: 0.58, alpha: 1.0)
        case .city:   return UIColor(red: 0.62, green: 0.74, blue: 0.93, alpha: 1.0)
        case .seoul:  return UIColor(red: 0.66, green: 0.85, blue: 0.95, alpha: 1.0)
        case .wild:   return UIColor(red: 0.47, green: 0.76, blue: 0.90, alpha: 1.0)
        case .space:  return UIColor(red: 0.05, green: 0.02, blue: 0.15, alpha: 1.0)
        case .ocean:  return UIColor(red: 0.10, green: 0.40, blue: 0.65, alpha: 1.0)
        }
    }

    var ambientLightColor: UIColor {
        switch self {
        case .desert: return UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1.0)
        case .space:  return UIColor(red: 0.6, green: 0.6, blue: 0.9, alpha: 1.0)
        case .ocean:  return UIColor(red: 0.5, green: 0.8, blue: 0.9, alpha: 1.0)
        default:      return .white
        }
    }

    var ambientLightIntensity: CGFloat {
        switch self {
        case .space: return 300
        case .ocean: return 500
        // V1: with real terrain normals, 600 ambient + 800 sun clipped flat
        // ground to white. Less fill, a touch more sun: slopes read.
        default:     return 420
        }
    }

    var sunLightColor: UIColor {
        switch self {
        case .desert: return UIColor(red: 1.0, green: 0.92, blue: 0.78, alpha: 1.0)
        case .space:  return UIColor(red: 0.9, green: 0.85, blue: 1.0, alpha: 1.0)
        case .ocean:  return UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 1.0)
        default:      return .white
        }
    }

    var sunLightIntensity: CGFloat {
        switch self {
        case .space: return 400
        case .ocean: return 600
        default:     return 850
        }
    }

    // MARK: - SwiftUI palette
    //
    // Used by CharacterSelectView for the screen background gradient and the
    // theme-specific accent (FLY! button + selected tile background).

    /// Two-stop background gradient for the selection screen.
    var uiGradient: [Color] {
        switch self {
        case .sky:    return [Color(hex: 0x87CEEB), Color(hex: 0xFFFDE7)]
        case .desert: return [Color(hex: 0xF6B26B), Color(hex: 0xFFE8B8)]
        case .city:   return [Color(hex: 0x5B7FD1), Color(hex: 0xF7C8A0)]
        case .seoul:  return [Color(hex: 0x7EC8E3), Color(hex: 0xFFD6E4)]
        case .wild:   return [Color(hex: 0x2E8B6F), Color(hex: 0xBFE8D2)]
        case .space:  return [Color(hex: 0x0D0025), Color(hex: 0x2A0A4A)]
        case .ocean:  return [Color(hex: 0x006994), Color(hex: 0x40E0D0)]
        }
    }

    /// Primary accent (FLY! button, selected map-theme card fill).
    var uiAccent: Color {
        switch self {
        case .sky:    return Color(hex: Constants.Colors.easyGreen)
        case .desert: return Color(hex: 0xD9722B)
        case .city:   return Color(hex: 0x3D5AFE)
        case .seoul:  return Color(hex: 0xE0558A)
        case .wild:   return Color(hex: 0x1B8A5A)
        case .space:  return Color(hex: 0x7B2FBE)
        case .ocean:  return Color(hex: 0x0077B6)
        }
    }

    /// Distinct hue for the map card itself (so the card and the FLY! button
    /// don't look identical on the sky theme).
    var uiCardAccent: Color {
        switch self {
        case .sky: return Color(hex: 0x29B6F6)
        default:   return uiAccent
        }
    }

    // MARK: - Region Names

    /// Region names that fade in/out at the bottom of the HUD as the
    /// player moves through the world. The original three worlds have 8
    /// hand-written names (`theme.<id>.region.<n>`).
    /// `FlightViewModel.computeRegionName` indexes modulo the count.
    var regionNames: [String] {
        switch self {
        case .sky, .space, .ocean:
            return (0..<8).map { L10n.t("theme.\(rawValue).region.\($0)") }
        default:
            // The landmark chip names the actual places; the region
            // label just says which world this is.
            return [displayName]
        }
    }
}
