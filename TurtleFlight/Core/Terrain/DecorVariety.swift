import Foundation
import SceneKit
import UIKit
import simd

/// V8 (docs/VISUAL_AUDIO_PLAN.md): ground props that don't look stamped.
///
/// - Every repeated prop (trees, palms, pines, houses, clouds, coral)
///   comes in 2–3 shapes, plus its own size and turn, all picked from
///   the prop's placement hash — the same spot always gets the same prop,
///   so screenshots and ghosts stay stable.
/// - Static ground props are baked into the chunk's terrain mesh
///   (`PropMesh`), so a chunk with a dozen trees is still one draw call.
///   Before V8 every tree was 2 draw calls and every house 2–5.
/// - Meadows get a scatter of flower and grass-tuft speckles, baked into
///   the same mesh (no per-frame cost, no extra draw call).
enum DecorVariety {

    /// Deterministic value in [0, 1) from a placement hash and a salt
    /// (a splitmix-style mix, so neighbouring hashes give unrelated values).
    static func unit(_ h: Int, _ salt: Int) -> Float {
        var z = UInt64(bitPattern: Int64(h)) &+ UInt64(bitPattern: Int64(salt)) &* 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Float(z >> 40) / Float(1 << 24)
    }

    /// Which of `count` shapes the prop at `h` gets.
    static func variant(_ h: Int, count: Int) -> Int {
        min(count - 1, Int(unit(h, 1) * Float(count)))
    }

    /// Give a prop its own size and turn.
    static func vary(_ node: SCNNode, hash h: Int, scale: ClosedRange<Float>) {
        let s = scale.lowerBound + (scale.upperBound - scale.lowerBound) * unit(h, 2)
        node.scale = SCNVector3(s, s, s)
        node.eulerAngles.y = unit(h, 3) * 2 * .pi
    }

    // MARK: - Meadow speckles

    struct SpeckleStyle {
        /// Ground heights the speckles grow on.
        let heights: ClosedRange<Float>
        /// Candidates per chunk (about half land in a meadow patch).
        let candidates: Int
        /// Small, bright flower dots.
        let flowers: [SIMD3<Float>]
        /// Larger grass tufts, a little darker/lighter than the ground.
        let tufts: [SIMD3<Float>]
        /// Share of speckles that are flowers.
        let flowerShare: Float
    }

    static func speckleStyle(for world: MapTheme) -> SpeckleStyle? {
        let white = SIMD3<Float>(0.97, 0.96, 0.90), yellow = SIMD3<Float>(1.0, 0.85, 0.32)
        switch world {
        case .sky:
            return SpeckleStyle(heights: 22...150, candidates: 640,
                                flowers: [white, yellow, SIMD3(1.0, 0.62, 0.74), SIMD3(0.74, 0.64, 0.96)],
                                tufts: [SIMD3(0.24, 0.56, 0.26), SIMD3(0.50, 0.78, 0.38)], flowerShare: 0.45)
        case .seoul:
            return SpeckleStyle(heights: 10...120, candidates: 640,
                                flowers: [SIMD3(1.0, 0.74, 0.84), SIMD3(1.0, 0.86, 0.90), white, yellow],
                                tufts: [SIMD3(0.30, 0.56, 0.30), SIMD3(0.56, 0.78, 0.44)], flowerShare: 0.5)
        case .wild:
            return SpeckleStyle(heights: 22...165, candidates: 640,
                                flowers: [white, yellow, SIMD3(0.62, 0.50, 0.90), SIMD3(0.95, 0.50, 0.36)],
                                tufts: [SIMD3(0.14, 0.40, 0.22), SIMD3(0.40, 0.62, 0.32)], flowerShare: 0.35)
        case .city:
            return SpeckleStyle(heights: 15...80, candidates: 520,
                                flowers: [white, yellow, SIMD3(1.0, 0.55, 0.50)],
                                tufts: [SIMD3(0.28, 0.52, 0.28), SIMD3(0.52, 0.72, 0.42)], flowerShare: 0.35)
        case .desert:
            return SpeckleStyle(heights: 4...95, candidates: 260,
                                flowers: [SIMD3(0.70, 0.52, 0.34), SIMD3(0.92, 0.80, 0.60)],
                                tufts: [SIMD3(0.56, 0.58, 0.34), SIMD3(0.66, 0.60, 0.38)], flowerShare: 0.5)
        case .ocean:
            return SpeckleStyle(heights: -400...400, candidates: 420,
                                flowers: [SIMD3(0.96, 0.88, 0.80), SIMD3(1.0, 0.70, 0.62)],
                                tufts: [SIMD3(0.20, 0.56, 0.50), SIMD3(0.30, 0.68, 0.56)], flowerShare: 0.3)
        case .space:
            return nil
        }
    }
}

/// Plain vertex-coloured triangles in world space — the format of the
/// terrain chunk mesh, so baked props and speckles append straight onto it.
struct PropMesh {
    var positions: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var colors: [SCNVector3] = []
    var indices: [Int32] = []

    var isEmpty: Bool { indices.isEmpty }

    /// Append every geometry under `node` (its own transform included),
    /// coloured by each element's material diffuse colour.
    mutating func bake(_ node: SCNNode, parent: simd_float4x4 = matrix_identity_float4x4) {
        let m = parent * node.simdTransform
        if let geometry = node.geometry { append(geometry, transform: m) }
        for child in node.childNodes { bake(child, parent: m) }
    }

    /// Append a flat polygon fan (centre + ring) — one speckle.
    mutating func appendFan(centre: SCNVector3, ring: [SCNVector3], normal: SCNVector3, color: SIMD3<Float>) {
        let base = Int32(positions.count)
        let c = SCNVector3(color.x, color.y, color.z)
        positions.append(centre)
        positions.append(contentsOf: ring)
        normals.append(contentsOf: repeatElement(normal, count: ring.count + 1))
        colors.append(contentsOf: repeatElement(c, count: ring.count + 1))
        for i in 0..<Int32(ring.count) {
            indices.append(contentsOf: [base, base + 1 + (i + 1) % Int32(ring.count), base + 1 + i])
        }
    }

    /// One geometry with one material (used for the drifting clouds).
    /// Without vertex colours, so the material's colour and transparency
    /// apply exactly as they did to the separate puffs.
    func geometry(material: SCNMaterial) -> SCNGeometry {
        let g = SCNGeometry(sources: Array(sources().prefix(2)),
                            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        g.materials = [material]
        return g
    }

    func sources() -> [SCNGeometrySource] {
        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector3>.size)
        let colorSource = SCNGeometrySource(
            data: colorData, semantic: .color, vectorCount: colors.count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<SCNVector3>.size)
        return [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals), colorSource]
    }

    // MARK: Primitive meshes

    /// Segments around round props. They are a few metres across and
    /// seen from tens of metres up: 12 is plenty (SceneKit draws 48).
    /// Parts under a metre across get 8.
    var roundSegments = 12

    /// A primitive's triangles in its own space: three vertices per
    /// triangle, wound counter-clockwise from outside, with normals.
    struct Template: Sendable {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
    }

    /// Built templates by shape and size. Chunks are generated on the
    /// render thread and tests on main, so the cache is behind a lock.
    nonisolated(unsafe) private static var templates: [String: Template] = [:]
    private static let templateLock = NSLock()

    /// Append `geometry` drawn with transform `m`.
    private mutating func append(_ geometry: SCNGeometry, transform m: simd_float4x4) {
        guard let t = Self.template(for: geometry, segments: roundSegments) else { return }
        let color = geometry.firstMaterial.map(Self.vertexColor) ?? SIMD3(1, 1, 1)
        let m3 = simd_float3x3(SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                               SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                               SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z))
        let nm = simd_transpose(simd_inverse(m3))
        let mirrored = simd_determinant(m3) < 0
        let c = SCNVector3(color.x, color.y, color.z)
        let base = Int32(positions.count)
        positions.reserveCapacity(positions.count + t.positions.count)
        normals.reserveCapacity(normals.count + t.positions.count)
        colors.reserveCapacity(colors.count + t.positions.count)
        indices.reserveCapacity(indices.count + t.positions.count)
        for i in 0..<t.positions.count {
            let w = m * SIMD4(t.positions[i], 1)
            let n = simd_normalize(nm * t.normals[i])
            positions.append(SCNVector3(w.x, w.y, w.z))
            normals.append(SCNVector3(n.x, n.y, n.z))
            colors.append(c)
        }
        var i: Int32 = 0
        while Int(i) + 2 < t.positions.count {
            // A mirrored transform flips the winding back.
            if mirrored {
                indices += [base + i, base + i + 2, base + i + 1]
            } else {
                indices += [base + i, base + i + 1, base + i + 2]
            }
            i += 3
        }
    }

    static func template(for geometry: SCNGeometry, segments: Int) -> Template? {
        let key: String
        switch geometry {
        case let g as SCNBox: key = "box \(g.width) \(g.height) \(g.length)"
        case let g as SCNSphere: key = "sphere \(g.radius) \(segments)"
        case let g as SCNCylinder: key = "cyl \(g.radius) \(g.height) \(segments)"
        case let g as SCNCone: key = "cone \(g.topRadius) \(g.bottomRadius) \(g.height) \(segments)"
        case let g as SCNPyramid: key = "pyr \(g.width) \(g.height) \(g.length)"
        default:
            assertionFailure("PropMesh cannot bake \(type(of: geometry))")
            return nil
        }
        templateLock.lock()
        defer { templateLock.unlock() }
        if let t = templates[key] { return t }
        let t = build(geometry, segments: segments)
        templates[key] = t
        return t
    }

    /// SceneKit's own vertex sources for its parametric shapes are a
    /// normalised template (the real size is applied out of sight), so the
    /// five shapes props use are rebuilt from their parameters. All five
    /// are convex, so each triangle is turned to face away from the centre.
    private static func build(_ geometry: SCNGeometry, segments: Int) -> Template {
        var tris: [SIMD3<Float>] = []
        var s = segments
        func ring(_ r: Float, _ y: Float) -> [SIMD3<Float>] {
            (0..<s).map { i in
                let a = Float(i) / Float(s) * 2 * .pi
                return SIMD3(cos(a) * r, y, sin(a) * r)
            }
        }
        func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
            tris += [a, b, c, a, c, d]
        }
        func disc(_ pts: [SIMD3<Float>], _ centre: SIMD3<Float>) {
            for i in 0..<pts.count { tris += [centre, pts[i], pts[(i + 1) % pts.count]] }
        }
        func band(_ lo: [SIMD3<Float>], _ hi: [SIMD3<Float>]) {
            for i in 0..<lo.count {
                let j = (i + 1) % lo.count
                quad(lo[i], lo[j], hi[j], hi[i])
            }
        }
        var centre = SIMD3<Float>(0, 0, 0)
        var smooth = false

        switch geometry {
        case let g as SCNBox:
            let x = Float(g.width) / 2, y = Float(g.height) / 2, z = Float(g.length) / 2
            let c = [SIMD3(-x, -y, -z), SIMD3(x, -y, -z), SIMD3(x, y, -z), SIMD3(-x, y, -z),
                     SIMD3(-x, -y, z), SIMD3(x, -y, z), SIMD3(x, y, z), SIMD3(-x, y, z)]
            for f in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]] {
                quad(c[f[0]], c[f[1]], c[f[2]], c[f[3]])
            }
        case let g as SCNSphere:
            let r = Float(g.radius)
            if r < 1 { s = min(s, 8) }
            let rings = s / 2
            var prev = [SIMD3<Float>](repeating: SIMD3(0, -r, 0), count: s)
            for k in 1...rings {
                let phi = -Float.pi / 2 + Float(k) / Float(rings) * .pi
                let next = k == rings ? [SIMD3<Float>](repeating: SIMD3(0, r, 0), count: s) : ring(r * cos(phi), r * sin(phi))
                band(prev, next)
                prev = next
            }
            smooth = true
        case let g as SCNCylinder:
            let r = Float(g.radius), h = Float(g.height) / 2
            if r < 1 { s = min(s, 8) }
            let lo = ring(r, -h), hi = ring(r, h)
            band(lo, hi)
            disc(lo, SIMD3(0, -h, 0))
            disc(hi, SIMD3(0, h, 0))
        case let g as SCNCone:
            let h = Float(g.height) / 2
            if g.bottomRadius < 1 { s = min(s, 8) }
            let lo = ring(Float(g.bottomRadius), -h)
            if g.topRadius > 0 {
                let hi = ring(Float(g.topRadius), h)
                band(lo, hi)
                disc(hi, SIMD3(0, h, 0))
            } else {
                disc(lo, SIMD3(0, h, 0))
            }
            disc(lo, SIMD3(0, -h, 0))
            centre = SIMD3(0, -h / 2, 0)
        case let g as SCNPyramid:
            let x = Float(g.width) / 2, z = Float(g.length) / 2, top = SIMD3<Float>(0, Float(g.height), 0)
            let b = [SIMD3(-x, 0, -z), SIMD3(x, 0, -z), SIMD3(x, 0, z), SIMD3(-x, 0, z)]
            for i in 0..<4 { tris += [b[i], b[(i + 1) % 4], top] }
            quad(b[0], b[1], b[2], b[3])
            centre = SIMD3(0, Float(g.height) / 4, 0)
        default:
            break
        }

        var out = Template()
        var t = 0
        while t + 2 < tris.count {
            var (a, b, d) = (tris[t], tris[t + 1], tris[t + 2])
            t += 3
            var n = simd_cross(b - a, d - a)
            guard simd_length_squared(n) > 1e-12 else { continue }
            // Outward, counter-clockwise.
            if simd_dot(n, (a + b + d) / 3 - centre) < 0 { swap(&b, &d); n = -n }
            let flat = simd_normalize(n)
            for p in [a, b, d] {
                out.positions.append(p)
                out.normals.append(smooth ? simd_normalize(p - centre) : flat)
            }
        }
        return out
    }

    /// The material's diffuse colour as a vertex colour. SceneKit reads
    /// vertex colours as linear while a `UIColor` is sRGB, so convert —
    /// otherwise every baked prop comes out pale.
    static func vertexColor(_ material: SCNMaterial) -> SIMD3<Float> {
        guard let color = material.diffuse.contents as? UIColor else { return SIMD3(1, 1, 1) }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3(linear(Float(r)), linear(Float(g)), linear(Float(b)))
    }

    static func linear(_ c: Float) -> Float {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
}
