// Benchmark example (benchmark/PLAN.md B1) — NOT part of the app target.
//
// Ideas taken from FastNoise2's node graph (Fractal FBm / Ridged,
// DomainWarp, Cellular-style masks), written as plain Swift on top of
// whatever 2D base noise the app already has. The app's base noise is
// `MathHelpers.valueNoise2D` (range [0, 1)), so every recipe here takes
// and returns values in [0, 1].
//
// Existing worlds must keep `MathHelpers.fractalNoise` exactly as it is
// (courses, ghosts and landmark placement depend on those heights). These
// recipes are for new worlds or opt-in profiles only.

import simd

enum NoiseRecipes {
    /// Base noise: (x, y, seed) -> [0, 1].
    typealias Base = (_ x: Float, _ y: Float, _ seed: Int) -> Float

    /// Plain fractal Brownian motion. Same maths as
    /// `MathHelpers.fractalNoise`, but with the base noise passed in.
    static func fbm(_ base: Base, x: Float, y: Float, octaves: Int = 4,
                    gain: Float = 0.5, lacunarity: Float = 2, seed: Int) -> Float {
        var total: Float = 0, amplitude: Float = 1, frequency: Float = 1, norm: Float = 0
        for i in 0..<octaves {
            total += base(x * frequency, y * frequency, seed + i) * amplitude
            norm += amplitude
            amplitude *= gain
            frequency *= lacunarity
        }
        return total / norm
    }

    /// Ridged multifractal (Musgrave): sharp crests where the base noise
    /// crosses its middle value. Each octave is weighted by the previous
    /// one, so the ridges get detail and the valleys stay smooth. Good
    /// for a canyon or mountain-spine world.
    static func ridged(_ base: Base, x: Float, y: Float, octaves: Int = 5,
                       gain: Float = 0.5, lacunarity: Float = 2, seed: Int) -> Float {
        var total: Float = 0, amplitude: Float = 1, frequency: Float = 1, norm: Float = 0
        var weight: Float = 1
        for i in 0..<octaves {
            var signal = 1 - abs(base(x * frequency, y * frequency, seed + i) * 2 - 1)
            signal *= signal * weight
            weight = simd_clamp(signal * 2, 0, 1)
            total += signal * amplitude
            norm += amplitude
            amplitude *= gain
            frequency *= lacunarity
        }
        return total / norm
    }

    /// Billow: round puffy hills (|noise| folded). Softer than `.dunes`.
    static func billow(_ base: Base, x: Float, y: Float, octaves: Int = 4, seed: Int) -> Float {
        fbm({ x, y, s in abs(base(x, y, s) * 2 - 1) }, x: x, y: y, octaves: octaves, seed: seed)
    }

    /// Domain warp: move the sample point by another noise before
    /// sampling. Turns straight blobs into winding valleys and ridges.
    /// `amplitude` is in noise-space units (1 = one base cell).
    static func warped(_ base: Base, x: Float, y: Float, amplitude: Float = 1.5,
                       seed: Int, shape: (Float, Float) -> Float) -> Float {
        // Two decorrelated offsets so the warp is not along one diagonal.
        let qx = fbm(base, x: x, y: y, octaves: 3, seed: seed &+ 101)
        let qy = fbm(base, x: x + 5.2, y: y + 1.3, octaves: 3, seed: seed &+ 202)
        return shape(x + amplitude * (qx * 2 - 1), y + amplitude * (qy * 2 - 1))
    }

    /// Island mask: 1 inside `radius`, falling to 0 over `falloff`.
    /// Multiply a height by it to get islands in the sea; place several
    /// centres on a jittered grid for an archipelago (Cellular idea).
    static func islandMask(distance d: Float, radius: Float, falloff: Float) -> Float {
        let t = simd_clamp((d - radius) / falloff, 0, 1)
        return 1 - t * t * (3 - 2 * t)
    }
}

// Example: a canyon world height in metres.
//
//   let base: NoiseRecipes.Base = { x, y, s in MathHelpers.valueNoise2D(x: x, y: y, seed: s) }
//   func canyonHeight(x: Float, z: Float, seed: Int) -> Float {
//       let s: Float = 0.004
//       let n = NoiseRecipes.warped(base, x: x * s, y: z * s, amplitude: 1.2, seed: seed) { wx, wy in
//           NoiseRecipes.ridged(base, x: wx, y: wy, seed: seed)
//       }
//       return n * 260 - 40   // ridges up to 220 m, valley floors under the river line
//   }
