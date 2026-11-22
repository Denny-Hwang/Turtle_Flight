import Foundation
import SceneKit

/// Terrain shape + colour + landmark list for one world. Pure data, so
/// tests can pin every world without building a scene.
struct WorldProfile {
    /// How raw fractal noise in [-1, 1] becomes a height.
    enum Shape {
        /// `noise * maxHeight` — hills with water below zero (the 1.0 look).
        case rolling
        /// `abs(noise) * maxHeight + base` — dunes: no water, soft ridges.
        case dunes(base: Float)
        /// Rolling, but everything above `plateau` is squashed, giving
        /// wide flat ground for a city with a river through it.
        case plain(plateau: Float)
    }

    let noiseScale: Float
    let maxHeight: Float
    let shape: Shape
    /// Ascending `(below this height, colour)` stops; `peak` above the last.
    let ramp: [(below: Float, color: SCNVector3)]
    let peak: SCNVector3
    let landmarks: [LandmarkKind]
    /// Lowers the whole world so its valleys dip under sea level (V3).
    /// The fractal noise is in [0, 1], so without this no world ever had
    /// water. Only the 1.1 worlds use it — the 1.0 worlds (sky, space,
    /// ocean) keep their shape under existing courses and ghosts.
    var seaOffset: Float = 0

    func height(fromNoise noise: Float) -> Float {
        switch shape {
        case .rolling:
            return noise * maxHeight - seaOffset
        case .dunes(let base):
            return abs(noise) * maxHeight + base
        case .plain(let plateau):
            let h = noise * maxHeight - seaOffset
            return h > plateau ? plateau + (h - plateau) * 0.25 : h
        }
    }

    func color(forHeight height: Float) -> SCNVector3 {
        for stop in ramp where height < stop.below { return stop.color }
        return peak
    }

    // MARK: Rendered colour (V2, docs/VISUAL_AUDIO_PLAN.md)

    /// How far either side of a ramp boundary the two colours blend.
    static let blendBand: Float = 10

    /// The colour a terrain vertex is drawn with: the height ramp with
    /// soft boundaries, steep ground turning to rock, and a gentle
    /// low-frequency light/dark variation so wide areas aren't flat.
    /// `slope` is 0 for flat ground, 1 for a vertical wall;
    /// `variation` is in [-1, 1]. `color(forHeight:)` stays the plain
    /// step ramp (it describes the world; this describes the picture).
    func renderColor(height: Float, slope: Float, variation: Float) -> SCNVector3 {
        // 1. Ramp with blended boundaries.
        var color = peak
        for (i, stop) in ramp.enumerated() {
            // Narrow bands (the city's 2 m riverbank) blend over a
            // proportionally narrow range so they keep their colour.
            let below = i > 0 ? stop.below - ramp[i - 1].below : Self.blendBand * 4
            let above = i + 1 < ramp.count ? ramp[i + 1].below - stop.below : Self.blendBand * 4
            let band = min(Self.blendBand, below * 0.3, above * 0.3)
            guard height < stop.below + band else { continue }
            let next = i + 1 < ramp.count ? ramp[i + 1].color : peak
            let t = Self.smoothstep(stop.below - band, stop.below + band, height)
            color = Self.mix(stop.color, next, t)
            break
        }
        // 2. Steep slopes show bare rock (never under water).
        if height > 0 {
            let r = Self.smoothstep(0.42, 0.72, slope)
            color = Self.mix(color, rockTint, r * 0.7)
        }
        // 3. Broad brightness variation, ±7%.
        let k = 1 + variation * 0.07
        return SCNVector3(min(1, color.x * k), min(1, color.y * k), min(1, color.z * k))
    }

    /// Bare-rock colour for steep ground.
    var rockTint: SCNVector3 {
        let base = ramp.last?.color ?? peak
        return Self.mix(base, SCNVector3(0.50, 0.46, 0.42), 0.6)
    }

    static func smoothstep(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    static func mix(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
        SCNVector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
    }

    static func profile(for theme: MapTheme) -> WorldProfile {
        let t = Constants.Terrain.self
        func rgb(_ r: Float, _ g: Float, _ b: Float) -> SCNVector3 { SCNVector3(r, g, b) }
        switch theme {
        case .sky:
            return WorldProfile(
                noiseScale: 0.005, maxHeight: t.maxHeight, shape: .rolling,
                // V2: meadows reach higher (the "Cloud Kingdom" read brown
                // because most of it sits between 80 and 180 m).
                ramp: [(t.waterLevel, rgb(0.33, 0.53, 0.87)), (t.sandLevel, rgb(0.93, 0.87, 0.68)),
                       (t.grassLevel, rgb(0.36, 0.72, 0.34)), (150, rgb(0.27, 0.60, 0.32)),
                       (t.rockLevel + 30, rgb(0.55, 0.47, 0.38)), (t.snowLevel, rgb(0.50, 0.42, 0.36))],
                peak: rgb(0.95, 0.95, 0.97),
                landmarks: [.floatingCastle, .rainbowGate, .windmillHill])
        case .space:
            return WorldProfile(
                noiseScale: 0.005, maxHeight: t.maxHeight, shape: .rolling,
                ramp: [(t.waterLevel, rgb(0.05, 0.02, 0.20)), (t.sandLevel, rgb(0.20, 0.10, 0.35)),
                       (t.grassLevel, rgb(0.30, 0.15, 0.50)), (t.rockLevel, rgb(0.40, 0.20, 0.60)),
                       (t.snowLevel, rgb(0.55, 0.35, 0.75))],
                peak: rgb(0.80, 0.70, 1.00),
                landmarks: [.ringPlanet, .spaceStation, .moonBase])
        case .ocean:
            return WorldProfile(
                noiseScale: 0.005, maxHeight: t.maxHeight, shape: .rolling,
                ramp: [(t.waterLevel, rgb(0.05, 0.20, 0.50)), (t.sandLevel, rgb(0.10, 0.40, 0.65)),
                       (t.grassLevel, rgb(0.15, 0.60, 0.55)), (t.rockLevel, rgb(0.20, 0.65, 0.45)),
                       (t.snowLevel, rgb(0.60, 0.85, 0.70))],
                peak: rgb(0.90, 0.98, 0.95),
                landmarks: [.shipwreck, .seaVolcano, .shellPalace])
        case .desert:
            return WorldProfile(
                noiseScale: 0.004, maxHeight: 130, shape: .dunes(base: 4),
                ramp: [(22, rgb(0.95, 0.83, 0.56)), (55, rgb(0.90, 0.73, 0.45)),
                       (95, rgb(0.83, 0.62, 0.38))],
                peak: rgb(0.74, 0.52, 0.33),
                landmarks: [.greatPyramids, .sandGuardian, .palmOasis, .sunObelisk])
        case .city:
            return WorldProfile(
                noiseScale: 0.0035, maxHeight: 90, shape: .plain(plateau: 14),
                ramp: [(0, rgb(0.28, 0.52, 0.80)), (6, rgb(0.80, 0.77, 0.68)),
                       (16, rgb(0.40, 0.64, 0.36))],
                peak: rgb(0.52, 0.60, 0.46),
                landmarks: [.ironLaceTower, .grandArch, .riverBridge, .skyWheel],
                seaOffset: 32)   // ~15% river
        case .seoul:
            return WorldProfile(
                noiseScale: 0.0045, maxHeight: 200, shape: .rolling,
                ramp: [(0, rgb(0.33, 0.58, 0.84)), (8, rgb(0.86, 0.84, 0.76)),
                       (45, rgb(0.50, 0.74, 0.42)), (90, rgb(0.34, 0.60, 0.36))],
                peak: rgb(0.95, 0.72, 0.80),
                landmarks: [.hilltopTower, .palaceGate, .hanokVillage, .moonBridge],
                seaOffset: 71)   // ~15% river and lakes
        case .wild:
            return WorldProfile(
                noiseScale: 0.004, maxHeight: 420, shape: .rolling,
                ramp: [(0, rgb(0.18, 0.48, 0.70)), (20, rgb(0.56, 0.64, 0.40)),
                       (90, rgb(0.20, 0.50, 0.30)), (170, rgb(0.72, 0.44, 0.30)),
                       (230, rgb(0.56, 0.52, 0.50))],
                peak: rgb(0.96, 0.97, 0.99),
                landmarks: [.greatFalls, .canyonArch, .auroraPeak, .giantTree],
                seaOffset: 139)  // ~10% lakes
        }
    }
}
