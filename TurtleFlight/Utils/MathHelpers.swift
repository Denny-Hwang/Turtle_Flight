import Foundation
import simd

enum MathHelpers {
    /// Perlin-like noise using value noise with smooth interpolation
    static func valueNoise2D(x: Float, y: Float, seed: Int = 0) -> Float {
        let xi = Int(floor(x))
        let yi = Int(floor(y))
        let xf = x - floor(x)
        let yf = y - floor(y)

        // Smooth interpolation
        let u = xf * xf * (3 - 2 * xf)
        let v = yf * yf * (3 - 2 * yf)

        let aa = pseudoRandom(x: xi, y: yi, seed: seed)
        let ab = pseudoRandom(x: xi, y: yi + 1, seed: seed)
        let ba = pseudoRandom(x: xi + 1, y: yi, seed: seed)
        let bb = pseudoRandom(x: xi + 1, y: yi + 1, seed: seed)

        let x1 = Float.lerp(aa, ba, t: u)
        let x2 = Float.lerp(ab, bb, t: u)

        return Float.lerp(x1, x2, t: v)
    }

    /// Multi-octave fractal noise
    static func fractalNoise(x: Float, y: Float, octaves: Int = 4, persistence: Float = 0.5, lacunarity: Float = 2.0, seed: Int = 0) -> Float {
        var total: Float = 0
        var frequency: Float = 1
        var amplitude: Float = 1
        var maxValue: Float = 0

        for i in 0..<octaves {
            total += valueNoise2D(x: x * frequency, y: y * frequency, seed: seed + i) * amplitude
            maxValue += amplitude
            amplitude *= persistence
            frequency *= lacunarity
        }

        return total / maxValue
    }

    /// Pseudo-random hash function
    private static func pseudoRandom(x: Int, y: Int, seed: Int) -> Float {
        var hash = seed
        hash = hash &+ x &* 374761393
        hash = hash &+ y &* 668265263
        hash = (hash ^ (hash >> 13)) &* 1274126177
        hash = hash ^ (hash >> 16)
        return Float(abs(hash) % 10000) / 10000.0
    }

    /// Compass direction from heading angle (degrees)
    static func compassDirection(from heading: Float) -> String {
        let normalized = ((heading.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)

        switch normalized {
        case 337.5...360, 0..<22.5:     return "N"
        case 22.5..<67.5:               return "NE"
        case 67.5..<112.5:              return "E"
        case 112.5..<157.5:             return "SE"
        case 157.5..<202.5:             return "S"
        case 202.5..<247.5:             return "SW"
        case 247.5..<292.5:             return "W"
        case 292.5..<337.5:             return "NW"
        default:                        return "N"
        }
    }

    /// Distance between two 3D points
    static func distance(_ a: simd_float3, _ b: simd_float3) -> Float {
        simd_distance(a, b)
    }
}
