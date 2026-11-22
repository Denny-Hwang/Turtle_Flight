import Foundation
import SceneKit
import UIKit

/// V4 (docs/VISUAL_AUDIO_PLAN.md): a painted sky for the open-sky worlds.
/// Until now the background was one flat colour plus fog. This paints a
/// cube map once per flight: a gradient from a deeper zenith to a bright
/// horizon, a sun (or moon) disc with a soft glow, and a thin layer of
/// far clouds that converge toward the horizon. The fog colour is taken
/// from the horizon so distant terrain melts into the sky instead of into
/// a grey wall. Purely cosmetic and computed once, so there is no
/// per-frame cost.
enum SkyPainter {

    struct Palette: Equatable {
        let zenith: SIMD3<Float>
        let horizon: SIMD3<Float>
        let glow: SIMD3<Float>
        let cloud: SIMD3<Float>
        /// Direction toward the sun / moon (unit vector).
        let sun: SIMD3<Float>
        /// 0 = no visible disc.
        let discStrength: Float
        let glowStrength: Float
        let cloudAmount: Float
    }

    static func palette(world: MapTheme, mood: SkyMood) -> Palette {
        let mid = rgb(mood.skyColor(base: world.backgroundColor))
        let white = SIMD3<Float>(1, 1, 1)
        // Same compass direction as the old sun sphere (ahead and to the
        // right at take-off); low at dawn and dusk.
        func dir(elevation: Float) -> SIMD3<Float> {
            let az: Float = 0.55   // radians right of north (-Z)
            return simd_normalize(SIMD3(sin(az) * cos(elevation), sin(elevation), -cos(az) * cos(elevation)))
        }
        switch mood {
        case .day:
            return Palette(zenith: mixv(mid, SIMD3(0.22, 0.46, 0.86), 0.45), horizon: mixv(mid, white, 0.3),
                           glow: SIMD3(1.0, 0.97, 0.86), cloud: SIMD3(1, 1, 1),
                           sun: dir(elevation: 0.62), discStrength: 1, glowStrength: 0.35, cloudAmount: 0.45)
        case .morning:
            return Palette(zenith: mixv(mid, SIMD3(0.40, 0.58, 0.88), 0.45), horizon: mixv(mid, SIMD3(1.0, 0.90, 0.84), 0.4),
                           glow: SIMD3(1.0, 0.86, 0.70), cloud: SIMD3(1.0, 0.94, 0.92),
                           sun: dir(elevation: 0.22), discStrength: 1, glowStrength: 0.55, cloudAmount: 0.45)
        case .sunset:
            return Palette(zenith: mixv(mid, SIMD3(0.36, 0.34, 0.66), 0.55), horizon: mixv(mid, SIMD3(1.0, 0.70, 0.46), 0.6),
                           glow: SIMD3(1.0, 0.62, 0.34), cloud: SIMD3(1.0, 0.76, 0.68),
                           sun: dir(elevation: 0.08), discStrength: 1, glowStrength: 0.9, cloudAmount: 0.6)
        case .night:
            return Palette(zenith: mixv(mid, SIMD3(0.03, 0.04, 0.14), 0.6), horizon: mixv(mid, SIMD3(0.24, 0.28, 0.46), 0.5),
                           glow: SIMD3(0.85, 0.90, 1.0), cloud: SIMD3(0.34, 0.38, 0.56),
                           sun: dir(elevation: 0.5), discStrength: 0.8, glowStrength: 0.18, cloudAmount: 0.45)
        }
    }

    /// Colour of the sky in direction `d` (unit vector).
    static func color(_ d: SIMD3<Float>, _ p: Palette) -> SIMD3<Float> {
        let elevation = asin(max(-1, min(1, d.y)))
        var c: SIMD3<Float>
        if elevation >= 0 {
            let t = pow(elevation / (.pi / 2), 0.5)
            c = mixv(p.horizon, p.zenith, t)
        } else {
            // Below the horizon (rarely seen past the terrain): a hazy
            // continuation of the horizon colour.
            c = mixv(p.horizon, p.horizon * 0.85, min(1, -elevation * 3))
        }
        // Far cloud layer: noise projected on a high plane, so the wisps
        // get smaller and denser toward the horizon.
        if d.y > 0.02, p.cloudAmount > 0 {
            let k = 1 / (d.y + 0.12)
            let n = MathHelpers.fractalNoise(x: d.x * k * 1.6 + 40, y: d.z * k * 1.6 - 15, octaves: 4, seed: 5)
            let cover = smooth(0.08, 0.5, n) * smooth(0.02, 0.12, d.y) * (1 - smooth(0.45, 0.8, d.y))
            c = mixv(c, p.cloud, cover * p.cloudAmount)
        }
        // Sun / moon: tight disc plus a wide glow.
        let g = max(0, simd_dot(d, p.sun))
        c += p.glow * (pow(g, 12) * p.glowStrength + smooth(0.9985, 0.9992, g) * p.discStrength)
        return simd_min(c, SIMD3(1, 1, 1))
    }

    /// Six faces for `scene.background.contents`, in SceneKit's
    /// +X, −X, +Y, −Y, +Z, −Z order.
    static func cubeMap(_ p: Palette, size: Int = 160) -> [UIImage] {
        let faces: [(Float, Float) -> SIMD3<Float>] = [
            { u, v in SIMD3(1, -v, -u) },
            { u, v in SIMD3(-1, -v, u) },
            { u, v in SIMD3(u, 1, v) },
            { u, v in SIMD3(u, -1, -v) },
            { u, v in SIMD3(u, -v, 1) },
            { u, v in SIMD3(-u, -v, -1) }
        ]
        return faces.map { face in
            var pixels = [UInt8](repeating: 255, count: size * size * 4)
            for y in 0..<size {
                for x in 0..<size {
                    let u = (Float(x) + 0.5) / Float(size) * 2 - 1
                    let v = (Float(y) + 0.5) / Float(size) * 2 - 1
                    let c = color(simd_normalize(face(u, v)), p)
                    let i = (y * size + x) * 4
                    pixels[i] = UInt8(c.x * 255)
                    pixels[i + 1] = UInt8(c.y * 255)
                    pixels[i + 2] = UInt8(c.z * 255)
                }
            }
            return image(pixels, size: size)
        }
    }

    /// Fog colour: the horizon, so the far terrain fades into the sky.
    static func fogColor(_ p: Palette) -> UIColor {
        UIColor(red: CGFloat(p.horizon.x), green: CGFloat(p.horizon.y), blue: CGFloat(p.horizon.z), alpha: 1)
    }

    // MARK: Helpers

    static func rgb(_ c: UIColor) -> SIMD3<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3(Float(r), Float(g), Float(b))
    }

    static func mixv(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a + (b - a) * t }

    static func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    private static func image(_ pixels: [UInt8], size: Int) -> UIImage {
        let data = Data(pixels) as CFData
        let provider = CGDataProvider(data: data)!
        let cg = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                         space: CGColorSpaceCreateDeviceRGB(),
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        return UIImage(cgImage: cg)
    }
}
