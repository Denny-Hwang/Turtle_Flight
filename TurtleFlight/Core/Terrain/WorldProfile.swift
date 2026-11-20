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

    func height(fromNoise noise: Float) -> Float {
        switch shape {
        case .rolling:
            return noise * maxHeight
        case .dunes(let base):
            return abs(noise) * maxHeight + base
        case .plain(let plateau):
            let h = noise * maxHeight
            return h > plateau ? plateau + (h - plateau) * 0.25 : h
        }
    }

    func color(forHeight height: Float) -> SCNVector3 {
        for stop in ramp where height < stop.below { return stop.color }
        return peak
    }

    static func profile(for theme: MapTheme) -> WorldProfile {
        let t = Constants.Terrain.self
        func rgb(_ r: Float, _ g: Float, _ b: Float) -> SCNVector3 { SCNVector3(r, g, b) }
        switch theme {
        case .sky:
            return WorldProfile(
                noiseScale: 0.005, maxHeight: t.maxHeight, shape: .rolling,
                ramp: [(t.waterLevel, rgb(0.33, 0.53, 0.87)), (t.sandLevel, rgb(0.93, 0.87, 0.68)),
                       (t.grassLevel, rgb(0.30, 0.69, 0.31)), (t.rockLevel, rgb(0.55, 0.43, 0.33)),
                       (t.snowLevel, rgb(0.45, 0.35, 0.28))],
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
                ramp: [(0, rgb(0.28, 0.52, 0.80)), (6, rgb(0.82, 0.80, 0.74)),
                       (16, rgb(0.48, 0.72, 0.42))],
                peak: rgb(0.62, 0.68, 0.56),
                landmarks: [.ironLaceTower, .grandArch, .riverBridge, .skyWheel])
        case .seoul:
            return WorldProfile(
                noiseScale: 0.0045, maxHeight: 200, shape: .rolling,
                ramp: [(0, rgb(0.33, 0.58, 0.84)), (14, rgb(0.86, 0.84, 0.76)),
                       (70, rgb(0.52, 0.76, 0.44)), (130, rgb(0.36, 0.62, 0.38))],
                peak: rgb(0.95, 0.72, 0.80),
                landmarks: [.hilltopTower, .palaceGate, .hanokVillage, .moonBridge])
        case .wild:
            return WorldProfile(
                noiseScale: 0.004, maxHeight: 420, shape: .rolling,
                ramp: [(0, rgb(0.18, 0.48, 0.70)), (30, rgb(0.56, 0.64, 0.40)),
                       (120, rgb(0.20, 0.50, 0.30)), (240, rgb(0.72, 0.44, 0.30)),
                       (330, rgb(0.56, 0.52, 0.50))],
                peak: rgb(0.96, 0.97, 0.99),
                landmarks: [.greatFalls, .canyonArch, .auroraPeak, .giantTree])
        }
    }
}
