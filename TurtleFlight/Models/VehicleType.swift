import Foundation

enum VehicleType: String, CaseIterable, Codable {
    // Character-specific
    case shellJet         // 🐢 등껍질 제트
    case bellyGlider      // 🐧 배 활공
    case hamsterCopter    // 🐹 햄스터볼 헬리콥터
    case cushionBalloon   // 🐱 쿠션 열기구 (cushion-basket hot air balloon)
    case balloonBody      // 🐸 풍선 비행
    case carrotJet        // 🐰 당근 제트
    // Shared
    case cloudSurf        // ☁️ 구름 서핑 (ALL)

    var displayName: String {
        switch self {
        case .shellJet:        return L10n.t("vehicle.shellJet")
        case .bellyGlider:     return L10n.t("vehicle.bellyGlider")
        case .hamsterCopter:   return L10n.t("vehicle.hamsterCopter")
        case .cushionBalloon:  return L10n.t("vehicle.cushionBalloon")
        case .balloonBody:     return L10n.t("vehicle.balloonBody")
        case .carrotJet:       return L10n.t("vehicle.carrotJet")
        case .cloudSurf:       return L10n.t("vehicle.cloudSurf")
        }
    }

    var icon: String {
        switch self {
        case .shellJet:        return "🔥"
        case .bellyGlider:     return "🐧"
        case .hamsterCopter:   return "🔄"
        case .cushionBalloon:  return "🎀"
        case .balloonBody:     return "🎈"
        case .carrotJet:       return "🥕"
        case .cloudSurf:       return "☁️"
        }
    }

    var isShared: Bool {
        self == .cloudSurf
    }

    /// Imageset name for the vehicle-only artwork in
    /// `Assets.xcassets/Characters/{name}_vehicle_only.imageset`.
    /// Each character-owned vehicle has its own asset; the shared Cloud Surf
    /// has no per-character asset, so callers fall back to the emoji `icon`.
    var vehicleOnlyAssetName: String? {
        switch self {
        case .shellJet:        return "turbo_vehicle_only"
        case .bellyGlider:     return "pip_vehicle_only"
        case .hamsterCopter:   return "nutty_vehicle_only"
        case .cushionBalloon:  return "mochi_vehicle_only"
        case .balloonBody:     return "bounce_vehicle_only"
        case .carrotJet:       return "hoppy_vehicle_only"
        case .cloudSurf:       return nil
        }
    }

    /// Per-vehicle flight-feel multipliers. The MVP shipped with all six
    /// vehicles sharing identical physics — visual flavour only — which
    /// playtesters consistently flagged as "why does my character matter?"
    /// These multipliers are intentionally small (±15%) so the sensitivity
    /// profile remains the dominant tuning axis but each vehicle has a
    /// recognisable signature when the player flips between them.
    ///
    /// Conventions:
    ///   • `turn` scales `SensitivityProfile.turnSpeed` (heading response)
    ///   • `pitch` scales `SensitivityProfile.pitchSpeed` (climb/dive)
    ///   • `bank` scales the visible camera roll on `bankingAngle` so
    ///     fast vehicles look more committed and balloon types look
    ///     more level.
    var handling: VehicleHandling {
        switch self {
        case .shellJet:       return VehicleHandling(turn: 0.90, pitch: 0.95, bank: 1.00)
        case .bellyGlider:    return VehicleHandling(turn: 1.00, pitch: 1.10, bank: 1.10)
        case .hamsterCopter:  return VehicleHandling(turn: 1.15, pitch: 0.95, bank: 0.90)
        case .cushionBalloon: return VehicleHandling(turn: 0.85, pitch: 1.05, bank: 0.80)
        case .balloonBody:    return VehicleHandling(turn: 0.95, pitch: 1.15, bank: 0.95)
        case .carrotJet:      return VehicleHandling(turn: 1.10, pitch: 1.05, bank: 1.20)
        case .cloudSurf:      return VehicleHandling(turn: 1.00, pitch: 1.00, bank: 1.00)
        }
    }
}

/// Small tuning vector applied on top of the sensitivity profile so each
/// character/vehicle pair has a distinguishable flight feel. Values are
/// dimensionless multipliers centred at 1.0.
struct VehicleHandling: Equatable {
    let turn: Float
    let pitch: Float
    let bank: Float

    /// Identity handling — every multiplier 1.0. Used when no vehicle is
    /// selected (initial state, unit tests, fallback).
    static let neutral = VehicleHandling(turn: 1.0, pitch: 1.0, bank: 1.0)
}
