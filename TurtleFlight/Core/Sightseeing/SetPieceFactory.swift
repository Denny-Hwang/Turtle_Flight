import Foundation
import SceneKit
import UIKit

/// Builds the set pieces (`SetPiece`) from SceneKit primitives. Each is
/// built facing -Z with the opening / touch zone centred on the origin;
/// the caller turns it toward the player's heading.
///
/// Budget: static parts are baked into one mesh per material (a handful
/// of draw calls, `bake`); only the parts that move (spin, bob, twinkle) and particle
/// systems stay separate. All original shapes — nothing reproduces a real
/// structure.
enum SetPieceFactory {

    static func build(_ piece: SetPiece) -> SCNNode {
        let root = SCNNode()
        root.name = "setpiece_\(piece.rawValue)"
        let still = SCNNode()
        let live = SCNNode()
        live.name = "live"
        switch piece {
        case .rainbowArch:       rainbowArch(still, live)
        case .cloudTunnel:       cloudTunnel(still, live)
        case .thermal:           thermal(still, live)
        case .sandWindRing:      sandWindRing(still, live)
        case .cactusGate:        cactusGate(still, live)
        case .mirageOasis:       mirageOasis(still, live)
        case .flagLine:          flagLine(still, live)
        case .laundryBridge:     laundryBridge(still, live)
        case .bubbleFountain:    bubbleFountain(still, live)
        case .lanternTunnel:     lanternTunnel(still, live)
        case .roofGate:          roofGate(still, live)
        case .kiteWind:          kiteWind(still, live)
        case .waterfallArch:     waterfallArch(still, live)
        case .logBridge:         logBridge(still, live)
        case .fireflies:         fireflies(still, live)
        case .ringedPlanet:      ringedPlanet(still, live)
        case .constellationGate: constellationGate(still, live)
        case .cometTail:         cometTail(still, live)
        case .kelpArch:          kelpArch(still, live)
        case .coralGate:         coralGate(still, live)
        case .bubbleColumn:      bubbleColumn(still, live)
        }
        root.addChildNode(bake(still))
        root.addChildNode(live)
        root.opacity = 0
        root.runAction(.fadeIn(duration: 1.2))
        return root
    }

    // MARK: - Baking

    /// Merge the static parts into one mesh per material (a handful of
    /// draw calls instead of ~50–100 nodes), the same way V8 bakes chunk
    /// props (`PropMesh`). `flattenedClone()` is not an option: in the
    /// simulator it lost rotated parents' transforms and, in tests, came
    /// back with no triangles. Shapes `PropMesh` cannot rebuild (torus,
    /// capsule, tube) stay as their own nodes.
    static func bake(_ still: SCNNode) -> SCNNode {
        let out = SCNNode()
        out.name = "still"
        var meshes: [String: PropMesh] = [:]
        var spheres: [String: SmoothSpheres] = [:]
        var materials: [String: SCNMaterial] = [:]
        var order: [String] = []
        func walk(_ node: SCNNode, _ parent: simd_float4x4) {
            let m = parent * node.simdTransform
            if let geometry = node.geometry {
                if isBakeable(geometry), let material = geometry.firstMaterial {
                    let key = materialKey(material)
                    if materials[key] == nil {
                        var mesh = PropMesh()
                        mesh.roundSegments = 14
                        meshes[key] = mesh
                        spheres[key] = SmoothSpheres()
                        materials[key] = material
                        order.append(key)
                    }
                    if let sphere = geometry as? SCNSphere {
                        // PropMesh spheres are flat-shaded; puffs and
                        // lanterns need to look round.
                        spheres[key]!.append(radius: Float(sphere.radius), transform: m)
                    } else {
                        meshes[key]!.bake(SCNNode(geometry: geometry), parent: m)
                    }
                } else {
                    let keep = SCNNode(geometry: geometry)
                    keep.simdTransform = m
                    out.addChildNode(keep)
                }
            }
            for child in node.childNodes { walk(child, m) }
        }
        walk(still, matrix_identity_float4x4)
        for key in order {
            guard let material = materials[key] else { continue }
            if let mesh = meshes[key], !mesh.isEmpty {
                out.addChildNode(SCNNode(geometry: mesh.geometry(material: material)))
            }
            if let round = spheres[key], !round.indices.isEmpty {
                out.addChildNode(SCNNode(geometry: round.geometry(material: material)))
            }
        }
        return out
    }

    /// Smooth-shaded spheres merged into one mesh.
    struct SmoothSpheres {
        static let rings = 10
        static let segments = 16
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []

        mutating func append(radius: Float, transform m: simd_float4x4) {
            let m3 = simd_float3x3(SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                                   SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                                   SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z))
            let nm = simd_transpose(simd_inverse(m3))
            let base = Int32(positions.count)
            for i in 0...Self.rings {
                let theta = Float(i) / Float(Self.rings) * .pi
                for j in 0...Self.segments {
                    let phi = Float(j) / Float(Self.segments) * 2 * .pi
                    let dir = SIMD3<Float>(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
                    let w = m * SIMD4(dir * radius, 1)
                    let n = simd_normalize(nm * dir)
                    positions.append(SCNVector3(w.x, w.y, w.z))
                    normals.append(SCNVector3(n.x, n.y, n.z))
                }
            }
            let stride = Int32(Self.segments + 1)
            for i in 0..<Int32(Self.rings) {
                for j in 0..<Int32(Self.segments) {
                    let a = base + i * stride + j, b = a + stride
                    indices += [a, a + 1, b, b, a + 1, b + 1]
                }
            }
        }

        func geometry(material: SCNMaterial) -> SCNGeometry {
            let g = SCNGeometry(sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)],
                                elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
            g.materials = [material]
            return g
        }
    }

    private static func isBakeable(_ g: SCNGeometry) -> Bool {
        g is SCNBox || g is SCNSphere || g is SCNCylinder || g is SCNCone || g is SCNPyramid
    }

    private static func materialKey(_ m: SCNMaterial) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        (m.diffuse.contents as? UIColor)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%.3f %.3f %.3f %.3f %@", r, g, b, a, m.lightingModel.rawValue)
    }

    // MARK: - Helpers

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func material(_ color: UIColor, glow: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        if glow { m.emission.contents = color; m.lightingModel = .constant }
        if color.cgColor.alpha < 1 { m.isDoubleSided = true; m.writesToDepthBuffer = false }
        return m
    }

    @discardableResult
    private static func put(_ geometry: SCNGeometry, _ color: UIColor, in parent: SCNNode,
                            at p: SCNVector3 = SCNVector3Zero, glow: Bool = false) -> SCNNode {
        geometry.materials = [material(color, glow: glow)]
        let node = SCNNode(geometry: geometry)
        node.position = p
        parent.addChildNode(node)
        return node
    }

    /// A rod from `a` to `b`.
    @discardableResult
    private static func rod(from a: SCNVector3, to b: SCNVector3, radius: CGFloat, _ color: UIColor,
                            in parent: SCNNode, glow: Bool = false) -> SCNNode {
        let d = SIMD3<Float>(b.x - a.x, b.y - a.y, b.z - a.z)
        let length = simd_length(d)
        let node = put(SCNCylinder(radius: radius, height: CGFloat(length)), color, in: parent,
                       at: SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2), glow: glow)
        if length > 0.001 {
            node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: d / length)
        }
        return node
    }

    /// Points on an arc in the XY plane (angles in radians, 0 = +X).
    private static func arcPoints(center: SCNVector3, radius: Float, from a0: Float, to a1: Float,
                                  count: Int, z: Float = 0) -> [SCNVector3] {
        (0...count).map { i in
            let a = a0 + (a1 - a0) * Float(i) / Float(count)
            return SCNVector3(center.x + cos(a) * radius, center.y + sin(a) * radius, center.z + z)
        }
    }

    /// A curved band made of rods.
    private static func arc(center: SCNVector3, radius: Float, from a0: Float = 0, to a1: Float = .pi,
                            segments: Int = 14, thickness: CGFloat, _ color: UIColor, in parent: SCNNode,
                            z: Float = 0, glow: Bool = false) {
        let pts = arcPoints(center: center, radius: radius, from: a0, to: a1, count: segments, z: z)
        for i in 0..<(pts.count - 1) {
            rod(from: pts[i], to: pts[i + 1], radius: thickness, color, in: parent, glow: glow)
        }
        // Round joints so the band reads as one piece.
        for p in pts { put(SCNSphere(radius: thickness), color, in: parent, at: p, glow: glow) }
    }

    /// Cloud puff. Opaque on purpose: transparent puffs merged into one
    /// mesh sort badly (striped artefacts in the simulator).
    private static func puff(_ parent: SCNNode, _ p: SCNVector3, _ r: CGFloat) {
        put(SCNSphere(radius: r), UIColor(white: 0.98, alpha: 1), in: parent, at: p)
    }

    /// A small floating island: rock cone underneath, a flat top.
    private static func island(_ parent: SCNNode, at p: SCNVector3, radius: CGFloat, top: UIColor,
                               rock: UIColor = rgb(0.55, 0.45, 0.38)) {
        let cap = put(SCNCylinder(radius: radius, height: 8), top, in: parent, at: p)
        cap.scale = SCNVector3(1, 1, 0.85)
        let cone = put(SCNCone(topRadius: radius * 0.95, bottomRadius: 2, height: radius * 0.9), rock, in: parent,
                       at: SCNVector3(p.x, p.y - Float(radius) * 0.45 - 4, p.z))
        cone.scale = SCNVector3(1, 1, 0.85)
    }

    private static func particles(_ configure: (SCNParticleSystem) -> Void) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = WonderFactory.dotImage
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        configure(ps)
        return ps
    }

    private static func emitter(_ parent: SCNNode, at p: SCNVector3 = SCNVector3Zero,
                                _ configure: (SCNParticleSystem) -> Void) {
        let node = SCNNode()
        node.position = p
        node.addParticleSystem(particles(configure))
        parent.addChildNode(node)
    }

    private static func bob(_ node: SCNNode, by dy: Float, period: TimeInterval) {
        node.runAction(.repeatForever(.sequence([
            .moveBy(x: 0, y: CGFloat(dy), z: 0, duration: period / 2),
            .moveBy(x: 0, y: CGFloat(-dy), z: 0, duration: period / 2)
        ])))
    }

    private static func spin(_ node: SCNNode, axis: SCNVector3, period: TimeInterval) {
        node.runAction(.repeatForever(.rotate(by: .pi * 2, around: axis, duration: period)))
    }

    /// A small glowing five-point star (reward cue).
    private static func starToken(_ parent: SCNNode, at p: SCNVector3) {
        let star = SCNNode()
        star.position = p
        put(SCNSphere(radius: 3.5), rgb(1, 0.92, 0.5), in: star, glow: true)
        for i in 0..<5 {
            let ray = put(SCNBox(width: 3, height: 9, length: 2, chamferRadius: 1), rgb(1, 0.85, 0.3), in: star, glow: true)
            ray.eulerAngles.z = Float(i) * 2 * .pi / 5
            ray.position = SCNVector3(-sin(ray.eulerAngles.z) * 5, cos(ray.eulerAngles.z) * 5, 0)
        }
        star.constraints = [SCNBillboardConstraint()]
        parent.addChildNode(star)
        bob(star, by: 6, period: 2.4)
    }

    private static let rainbow: [UIColor] = [
        rgb(0.95, 0.30, 0.30, 0.85), rgb(1.0, 0.62, 0.20, 0.85), rgb(1.0, 0.88, 0.25, 0.85),
        rgb(0.35, 0.80, 0.40, 0.85), rgb(0.30, 0.55, 0.95, 0.85), rgb(0.60, 0.40, 0.90, 0.85)
    ]

    // MARK: - Sky

    private static func rainbowArch(_ s: SCNNode, _ l: SCNNode) {
        let c = SCNVector3(0, -30, 0)
        for (i, colour) in rainbow.enumerated() {
            arc(center: c, radius: 76 - Float(i) * 4.4, thickness: 2.2, colour, in: s, glow: true)
        }
        for sx: Float in [-1, 1] {
            puff(s, SCNVector3(sx * 66, -34, 0), 20)
            puff(s, SCNVector3(sx * 80, -30, 6), 15)
            puff(s, SCNVector3(sx * 56, -26, -8), 14)
        }
    }

    private static func cloudTunnel(_ s: SCNNode, _ l: SCNNode) {
        var rng = SeededRandom(seed: 11)
        for z: Float in [-48, -16, 16, 48] {
            for i in 0..<12 {
                let a = Float(i) / 12 * 2 * .pi + z * 0.01
                let r = rng.nextFloat(in: 60...66)
                puff(s, SCNVector3(cos(a) * r, sin(a) * r, z + rng.nextFloat(in: -6...6)),
                     CGFloat(rng.nextFloat(in: 12...17)))
            }
        }
        // Sunlight sparkles drifting through.
        emitter(l) { ps in
            ps.birthRate = 12
            ps.particleLifeSpan = 3
            ps.emitterShape = SCNBox(width: 80, height: 80, length: 100, chamferRadius: 0)
            ps.birthLocation = .volume
            ps.particleVelocity = 6
            ps.spreadingAngle = 180
            ps.particleSize = 2.5
            ps.particleColor = rgb(1, 0.97, 0.8, 0.8)
        }
    }

    private static func thermal(_ s: SCNNode, _ l: SCNNode) {
        let h = CGFloat(SetPiece.liftHalfHeight * 2)
        put(SCNCylinder(radius: 42, height: h), rgb(1, 0.95, 0.80, 0.12), in: s)
        // A lazy spiral of glints showing the air turning upward.
        let helix = SCNNode()
        for i in 0..<28 {
            let t = Float(i) / 28
            let a = t * 6 * .pi
            put(SCNSphere(radius: 2.2), rgb(1, 0.9, 0.55), in: helix,
                at: SCNVector3(cos(a) * 36, -SetPiece.liftHalfHeight + t * SetPiece.liftHalfHeight * 2, sin(a) * 36),
                glow: true)
        }
        l.addChildNode(helix)
        spin(helix, axis: SCNVector3(0, 1, 0), period: 9)
        emitter(l, at: SCNVector3(0, -SetPiece.liftHalfHeight, 0)) { ps in
            ps.birthRate = 30
            ps.particleLifeSpan = 5
            ps.emitterShape = SCNCylinder(radius: 34, height: 4)
            ps.birthLocation = .volume
            ps.emittingDirection = SCNVector3(0, 1, 0)
            ps.spreadingAngle = 6
            ps.particleVelocity = 90
            ps.particleSize = 3
            ps.particleColor = rgb(1, 1, 0.92, 0.7)
        }
    }

    // MARK: - Desert

    private static func sandWindRing(_ s: SCNNode, _ l: SCNNode) {
        let ring = SCNNode()
        ring.eulerAngles.x = .pi / 2
        put(SCNTorus(ringRadius: 60, pipeRadius: 5), rgb(0.93, 0.78, 0.52, 0.65), in: ring)
        put(SCNTorus(ringRadius: 67, pipeRadius: 2.5), rgb(0.98, 0.88, 0.66, 0.5), in: ring)
        put(SCNTorus(ringRadius: 53, pipeRadius: 1.8), rgb(0.85, 0.62, 0.38, 0.5), in: ring)
        let spinner = SCNNode()
        spinner.addChildNode(ring)
        l.addChildNode(spinner)
        spin(spinner, axis: SCNVector3(0, 0, 1), period: 7)
        let sand = particles { ps in
            ps.birthRate = 45
            ps.particleLifeSpan = 1.6
            ps.emitterShape = SCNTorus(ringRadius: 60, pipeRadius: 6)
            ps.birthLocation = .surface
            ps.particleVelocity = 12
            ps.spreadingAngle = 180
            ps.particleSize = 2.4
            ps.blendMode = .alpha
            ps.particleColor = rgb(0.92, 0.76, 0.50, 0.8)
        }
        ring.addParticleSystem(sand)
    }

    private static func cactus(_ s: SCNNode, x: Float, base: Float, height: Float) {
        let green = rgb(0.36, 0.62, 0.36)
        stalk(s, x: x, y0: base, y1: base + height, radius: 7, green)
        for (dy, side, armH) in [(height * 0.45, Float(-1), Float(34)), (height * 0.62, Float(1), Float(28))] {
            let elbow = SCNVector3(x + side * 16, base + dy, 0)
            rod(from: SCNVector3(x, base + dy, 0), to: elbow, radius: 4.5, green, in: s)
            stalk(s, x: elbow.x, y0: elbow.y, y1: elbow.y + armH - 6, radius: 4.5, green)
        }
        // A flower on top.
        put(SCNSphere(radius: 4), rgb(1, 0.45, 0.6), in: s, at: SCNVector3(x, base + height + 2, 0))
    }

    private static func cactusGate(_ s: SCNNode, _ l: SCNNode) {
        island(s, at: SCNVector3(0, -78, 0), radius: 85, top: rgb(0.93, 0.80, 0.56))
        cactus(s, x: -58, base: -74, height: 140)
        cactus(s, x: 58, base: -74, height: 140)
        // Bunting between the tops.
        let pts = arcPoints(center: SCNVector3(0, 120, 0), radius: 72, from: -.pi * 0.78, to: -.pi * 0.22, count: 10)
        for i in 0..<(pts.count - 1) {
            rod(from: pts[i], to: pts[i + 1], radius: 0.7, rgb(0.45, 0.32, 0.22), in: s)
            let flag = put(SCNPyramid(width: 7, height: 9, length: 1), rainbow[i % rainbow.count].withAlphaComponent(1), in: s,
                           at: SCNVector3(pts[i].x + 3.5, pts[i].y - 5, 0))
            flag.eulerAngles.z = .pi
        }
    }

    private static func palm(_ s: SCNNode, at p: SCNVector3) {
        let trunk = rgb(0.58, 0.42, 0.26)
        var a = p
        for i in 0..<4 {
            let b = SCNVector3(a.x + Float(i) * 1.5, a.y + 11, a.z)
            rod(from: a, to: b, radius: 2.6 - CGFloat(i) * 0.3, trunk, in: s)
            a = b
        }
        for i in 0..<6 {
            let leaf = put(SCNBox(width: 3, height: 1, length: 20, chamferRadius: 0.5), rgb(0.30, 0.65, 0.30), in: s, at: a)
            leaf.eulerAngles = SCNVector3(-0.45, Float(i) * .pi / 3, 0)
            leaf.pivot = SCNMatrix4MakeTranslation(0, 0, 10)
        }
    }

    /// A vertical rod with rounded ends (a capsule `PropMesh` can bake).
    private static func stalk(_ s: SCNNode, x: Float, y0: Float, y1: Float, radius: CGFloat, _ colour: UIColor) {
        put(SCNCylinder(radius: radius, height: CGFloat(y1 - y0)), colour, in: s, at: SCNVector3(x, (y0 + y1) / 2, 0))
        put(SCNSphere(radius: radius), colour, in: s, at: SCNVector3(x, y1, 0))
        put(SCNSphere(radius: radius), colour, in: s, at: SCNVector3(x, y0, 0))
    }

    private static func mirageOasis(_ s: SCNNode, _ l: SCNNode) {
        island(s, at: SCNVector3(0, -44, 0), radius: 62, top: rgb(0.95, 0.84, 0.60))
        put(SCNCylinder(radius: 26, height: 1.5), rgb(0.35, 0.75, 0.95), in: s, at: SCNVector3(-8, -39.5, 4), glow: true)
        palm(s, at: SCNVector3(26, -40, -10))
        palm(s, at: SCNVector3(-34, -40, -16))
        for (i, x) in [Float(-16), 0, 16].enumerated() {
            starToken(l, at: SCNVector3(x, -6 + Float(i % 2) * 8, 0))
        }
        emitter(l, at: SCNVector3(-8, -36, 4)) { ps in
            ps.birthRate = 10
            ps.particleLifeSpan = 2.5
            ps.emitterShape = SCNCylinder(radius: 26, height: 1)
            ps.birthLocation = .surface
            ps.emittingDirection = SCNVector3(0, 1, 0)
            ps.particleVelocity = 10
            ps.particleSize = 2
            ps.particleColor = rgb(0.75, 0.95, 1, 0.8)
        }
    }

    // MARK: - City

    private static func flagLine(_ s: SCNNode, _ l: SCNNode) {
        for sx: Float in [-1, 1] {
            put(SCNCylinder(radius: 14, height: 4), rgb(0.70, 0.70, 0.75), in: s, at: SCNVector3(sx * 74, -88, 0))
            put(SCNCylinder(radius: 2.4, height: 170), UIColor(white: 0.96, alpha: 1), in: s, at: SCNVector3(sx * 74, -3, 0))
            put(SCNSphere(radius: 4), rgb(1, 0.82, 0.3), in: s, at: SCNVector3(sx * 74, 84, 0))
        }
        // Two sagging strings of flags, above and below the opening.
        for (row, (y, sag)) in [(Float(66), Float(14)), (Float(-58), Float(10))].enumerated() {
            let pts = arcPoints(center: SCNVector3(0, y + 280, 0), radius: 280 + sag,
                                from: -.pi / 2 - 0.26, to: -.pi / 2 + 0.26, count: 14)
            for i in 0..<(pts.count - 1) {
                rod(from: pts[i], to: pts[i + 1], radius: 0.6, UIColor(white: 0.3, alpha: 1), in: s)
                let flag = put(SCNPyramid(width: 7, height: 10, length: 1), rainbow[(i + row * 3) % rainbow.count]
                                .withAlphaComponent(1), in: s, at: SCNVector3(pts[i].x + 4, pts[i].y - 5.5, 0))
                flag.eulerAngles.z = .pi
            }
        }
    }

    private static func laundryBridge(_ s: SCNNode, _ l: SCNNode) {
        let stone = rgb(0.80, 0.72, 0.62)
        arc(center: SCNVector3(0, -36, 0), radius: 70, segments: 12, thickness: 7, stone, in: s)
        put(SCNBox(width: 170, height: 7, length: 22, chamferRadius: 1), rgb(0.72, 0.62, 0.52), in: s,
            at: SCNVector3(0, 38, 0))
        for sx: Float in [-1, 1] {
            put(SCNBox(width: 16, height: 120, length: 22, chamferRadius: 1), stone, in: s, at: SCNVector3(sx * 78, -22, 0))
            put(SCNCylinder(radius: 1.2, height: 26), UIColor(white: 0.35, alpha: 1), in: s, at: SCNVector3(sx * 60, 54, 0))
        }
        // Washing line across the top, with laundry.
        rod(from: SCNVector3(-60, 64, 0), to: SCNVector3(60, 64, 0), radius: 0.5, UIColor(white: 0.25, alpha: 1), in: s)
        let shirts = [rgb(0.95, 0.45, 0.45), rgb(0.45, 0.65, 0.95), rgb(1, 0.85, 0.35), rgb(0.55, 0.85, 0.55), rgb(0.95, 0.6, 0.85)]
        for (i, colour) in shirts.enumerated() {
            let x = -44 + Float(i) * 22
            put(SCNBox(width: 11, height: 13, length: 0.8, chamferRadius: 0.5), colour, in: s, at: SCNVector3(x, 56, 0))
        }
    }

    private static func bubbleFountain(_ s: SCNNode, _ l: SCNNode) {
        let stone = rgb(0.82, 0.80, 0.78)
        island(s, at: SCNVector3(0, -52, 0), radius: 40, top: stone, rock: rgb(0.62, 0.60, 0.62))
        put(SCNTube(innerRadius: 22, outerRadius: 26, height: 8), stone, in: s, at: SCNVector3(0, -44, 0))
        put(SCNCylinder(radius: 22, height: 2), rgb(0.45, 0.78, 0.98), in: s, at: SCNVector3(0, -45, 0), glow: true)
        put(SCNCylinder(radius: 3.5, height: 22), stone, in: s, at: SCNVector3(0, -36, 0))
        var rng = SeededRandom(seed: 7)
        for _ in 0..<8 {
            let b = put(SCNSphere(radius: CGFloat(rng.nextFloat(in: 5...10))),
                        UIColor(hue: CGFloat(rng.nextFloat(in: 0.45...0.85)), saturation: 0.35, brightness: 1, alpha: 0.35),
                        in: l, at: SCNVector3(rng.nextFloat(in: -40...40), rng.nextFloat(in: -20...40),
                                              rng.nextFloat(in: -20...20)), glow: true)
            bob(b, by: rng.nextFloat(in: 6...14), period: TimeInterval(rng.nextFloat(in: 2.5...4)))
        }
        emitter(l, at: SCNVector3(0, -26, 0)) { ps in
            ps.birthRate = 25
            ps.particleLifeSpan = 3
            ps.emittingDirection = SCNVector3(0, 1, 0)
            ps.spreadingAngle = 25
            ps.particleVelocity = 22
            ps.particleSize = 3
            ps.particleColor = rgb(0.85, 0.95, 1, 0.8)
        }
    }

    // MARK: - Seoul

    private static func lanternTunnel(_ s: SCNNode, _ l: SCNNode) {
        let colours = [rgb(0.95, 0.30, 0.28), rgb(1.0, 0.62, 0.25), rgb(1.0, 0.55, 0.65), rgb(0.98, 0.82, 0.35)]
        for (k, z) in [Float(-45), -15, 15, 45].enumerated() {
            let pts = arcPoints(center: SCNVector3(0, -20, 0), radius: 62, from: 0.12, to: .pi - 0.12, count: 8, z: z)
            for i in 0..<(pts.count - 1) {
                rod(from: pts[i], to: pts[i + 1], radius: 0.5, UIColor(white: 0.25, alpha: 1), in: s)
            }
            for (i, p) in pts.enumerated() {
                let lantern = put(SCNSphere(radius: 4.6), colours[(i + k) % colours.count], in: s,
                                  at: SCNVector3(p.x, p.y - 6, p.z), glow: true)
                lantern.scale = SCNVector3(1, 1.3, 1)
                put(SCNCylinder(radius: 2.2, height: 1.4), UIColor(white: 0.2, alpha: 1), in: s,
                    at: SCNVector3(p.x, p.y - 0.4, p.z))
            }
        }
    }

    /// A hanok-style gate (original design): stout dark red-brown pillars
    /// on stone footings, a green lintel with a painted bracket band and a
    /// name plaque, under a heavy grey tiled hip roof whose eaves sweep
    /// up at the corners. Kept clearly apart from a shrine-gate silhouette:
    /// the roof is the biggest thing, and nothing pokes out past it.
    private static func roofGate(_ s: SCNNode, _ l: SCNNode) {
        let pillar = rgb(0.48, 0.20, 0.14)
        let green = rgb(0.20, 0.52, 0.45)
        let paint = [rgb(0.22, 0.58, 0.50), rgb(0.90, 0.45, 0.25), rgb(0.30, 0.42, 0.75), rgb(0.95, 0.80, 0.35)]
        let tile = rgb(0.33, 0.35, 0.39)
        for sx: Float in [-1, 1] {
            for dz: Float in [-8, 8] { puff(s, SCNVector3(sx * 56 + dz * 0.5, -94, dz), 18) }
            put(SCNBox(width: 20, height: 12, length: 20, chamferRadius: 1), rgb(0.80, 0.78, 0.74), in: s,
                at: SCNVector3(sx * 56, -80, 0))
            put(SCNCylinder(radius: 8, height: 124), pillar, in: s, at: SCNVector3(sx * 56, -12, 0))
        }
        put(SCNBox(width: 128, height: 9, length: 14, chamferRadius: 1), green, in: s, at: SCNVector3(0, 54, 0))
        for i in 0..<13 {
            put(SCNBox(width: 8, height: 8, length: 18, chamferRadius: 1), paint[i % paint.count], in: s,
                at: SCNVector3(-60 + Float(i) * 10, 62, 0))
        }
        // Name plaque.
        put(SCNBox(width: 30, height: 14, length: 2, chamferRadius: 1), rgb(0.95, 0.80, 0.35), in: s,
            at: SCNVector3(0, 60, 10))
        put(SCNBox(width: 26, height: 10, length: 2.4, chamferRadius: 1), rgb(0.18, 0.16, 0.15), in: s,
            at: SCNVector3(0, 60, 10.2))
        // Heavy hip roof: front and back slopes, thick tile edge, ridge.
        for sz: Float in [-1, 1] {
            let slope = put(SCNBox(width: 170, height: 8, length: 44, chamferRadius: 2), tile, in: s,
                            at: SCNVector3(0, 80, sz * 16))
            slope.eulerAngles.x = sz * 0.5
        }
        for sx: Float in [-1, 1] {
            let side = put(SCNBox(width: 40, height: 8, length: 60, chamferRadius: 2), tile, in: s,
                           at: SCNVector3(sx * 76, 80, 0))
            side.eulerAngles.z = -sx * 0.5
            // Corner eaves sweep up.
            for sz: Float in [-1, 1] {
                let tip = put(SCNBox(width: 24, height: 5, length: 10, chamferRadius: 2), tile, in: s,
                              at: SCNVector3(sx * 98, 78, sz * 30))
                tip.eulerAngles.z = sx * 0.45
            }
        }
        put(SCNBox(width: 110, height: 9, length: 9, chamferRadius: 3), rgb(0.26, 0.27, 0.30), in: s,
            at: SCNVector3(0, 96, 0))
        for sx: Float in [-1, 1] {
            let end = put(SCNBox(width: 14, height: 7, length: 8, chamferRadius: 2), rgb(0.26, 0.27, 0.30), in: s,
                          at: SCNVector3(sx * 58, 99, 0))
            end.eulerAngles.z = sx * 0.5
        }
    }

    private static func kiteWind(_ s: SCNNode, _ l: SCNNode) {
        let wheel = SCNNode()
        let colours = [rgb(0.95, 0.30, 0.30), rgb(0.30, 0.55, 0.95), rgb(1, 0.85, 0.30),
                       rgb(0.35, 0.80, 0.45), rgb(0.95, 0.55, 0.85), rgb(1, 0.6, 0.25)]
        for (i, colour) in colours.enumerated() {
            let a = Float(i) / Float(colours.count) * 2 * .pi
            let kite = SCNNode()
            kite.position = SCNVector3(cos(a) * 44, sin(a) * 44, 0)
            let body = put(SCNBox(width: 15, height: 15, length: 0.8, chamferRadius: 0), colour, in: kite)
            body.eulerAngles.z = .pi / 4
            put(SCNBox(width: 1, height: 21, length: 1, chamferRadius: 0), UIColor(white: 1, alpha: 0.8), in: kite)
            for t in 0..<3 {
                put(SCNBox(width: 3.5, height: 2, length: 0.6, chamferRadius: 0.5), colour, in: kite,
                    at: SCNVector3(0, -14 - Float(t) * 6, 0))
            }
            rod(from: SCNVector3(0, -11, 0), to: SCNVector3(0, -30, 0), radius: 0.3, UIColor(white: 0.9, alpha: 1), in: kite)
            kite.eulerAngles.z = a - .pi / 2
            wheel.addChildNode(kite)
        }
        l.addChildNode(wheel)
        spin(wheel, axis: SCNVector3(0, 0, 1), period: 14)
        emitter(l) { ps in
            ps.birthRate = 20
            ps.particleLifeSpan = 1.6
            ps.emitterShape = SCNTorus(ringRadius: 44, pipeRadius: 10)
            ps.birthLocation = .volume
            ps.emittingDirection = SCNVector3(0, 0, 1)
            ps.spreadingAngle = 10
            ps.particleVelocity = 40
            ps.particleSize = 2
            ps.stretchFactor = 0.25
            ps.particleColor = UIColor(white: 1, alpha: 0.7)
        }
    }

    // MARK: - Wild

    private static func waterfallArch(_ s: SCNNode, _ l: SCNNode) {
        let rock = rgb(0.55, 0.50, 0.45)
        let pts = arcPoints(center: SCNVector3(0, -40, 0), radius: 70, from: 0, to: .pi, count: 14)
        for (i, p) in pts.enumerated() {
            put(SCNSphere(radius: 12 + CGFloat(i % 3) * 2), rock, in: s, at: p)
            if i > 1 && i < pts.count - 2 {
                put(SCNSphere(radius: 7), rgb(0.40, 0.68, 0.35), in: s, at: SCNVector3(p.x, p.y + 9, p.z))
            }
        }
        for sx: Float in [-1, 1] { put(SCNSphere(radius: 22), rock, in: s, at: SCNVector3(sx * 70, -52, 0)) }
        // A ribbon of water off the right shoulder.
        put(SCNBox(width: 10, height: 120, length: 1, chamferRadius: 0), rgb(0.70, 0.88, 1, 0.55), in: s,
            at: SCNVector3(86, -40, 6), glow: true)
        emitter(l, at: SCNVector3(86, 20, 6)) { ps in
            ps.birthRate = 40
            ps.particleLifeSpan = 1.8
            ps.emitterShape = SCNBox(width: 10, height: 1, length: 2, chamferRadius: 0)
            ps.birthLocation = .volume
            ps.emittingDirection = SCNVector3(0, -1, 0)
            ps.spreadingAngle = 4
            ps.particleVelocity = 60
            ps.particleSize = 3
            ps.particleColor = rgb(0.85, 0.95, 1, 0.85)
        }
    }

    private static func logBridge(_ s: SCNNode, _ l: SCNNode) {
        let rock = rgb(0.52, 0.48, 0.44)
        for sx: Float in [-1, 1] {
            for (i, y) in [Float(-90), -60, -30, 0, 30].enumerated() {
                put(SCNSphere(radius: 16 - CGFloat(i)), rock, in: s, at: SCNVector3(sx * 72, y, Float(i % 2) * 4))
            }
        }
        let log = put(SCNCylinder(radius: 11, height: 180), rgb(0.50, 0.34, 0.20), in: s, at: SCNVector3(0, 56, 0))
        log.eulerAngles.z = .pi / 2
        for sx: Float in [-1, 1] {
            let end = put(SCNCylinder(radius: 10, height: 1), rgb(0.85, 0.70, 0.48), in: s, at: SCNVector3(sx * 90.5, 56, 0))
            end.eulerAngles.z = .pi / 2
        }
        for x: Float in [-40, 10, 45] {
            put(SCNSphere(radius: 7), rgb(0.40, 0.68, 0.35), in: s, at: SCNVector3(x, 66, 0))
        }
        var rng = SeededRandom(seed: 5)
        for x: Float in [-55, -30, -8, 20, 38, 58] {
            let len = rng.nextFloat(in: 10...22)
            rod(from: SCNVector3(x, 46, 4), to: SCNVector3(x + 1, 46 - len, 4), radius: 0.9, rgb(0.35, 0.62, 0.30), in: s)
            put(SCNSphere(radius: 2.2), rgb(0.45, 0.75, 0.38), in: s, at: SCNVector3(x + 1, 46 - len, 4))
        }
    }

    private static func fireflies(_ s: SCNNode, _ l: SCNNode) {
        island(s, at: SCNVector3(0, -48, 0), radius: 38, top: rgb(0.35, 0.58, 0.32))
        put(SCNCylinder(radius: 11, height: 22), rgb(0.48, 0.34, 0.22), in: s, at: SCNVector3(0, -33, 0))
        put(SCNCylinder(radius: 10, height: 1), rgb(0.80, 0.66, 0.45), in: s, at: SCNVector3(0, -21.5, 0))
        for (x, z) in [(Float(-20), Float(10)), (18, -12), (24, 14)] {
            put(SCNCylinder(radius: 1.2, height: 6), UIColor(white: 0.95, alpha: 1), in: s, at: SCNVector3(x, -41, z))
            let cap = put(SCNSphere(radius: 4), rgb(0.92, 0.35, 0.30), in: s, at: SCNVector3(x, -37.5, z))
            cap.scale = SCNVector3(1, 0.6, 1)
        }
        var rng = SeededRandom(seed: 3)
        let swarm = SCNNode()
        for _ in 0..<16 {
            let f = put(SCNSphere(radius: 1.8), rgb(0.85, 1, 0.45), in: swarm,
                        at: SCNVector3(rng.nextFloat(in: -50...50), rng.nextFloat(in: -20...40), rng.nextFloat(in: -40...40)),
                        glow: true)
            f.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.2, duration: TimeInterval(rng.nextFloat(in: 0.6...1.4))),
                                                  .fadeOpacity(to: 1, duration: TimeInterval(rng.nextFloat(in: 0.6...1.4)))])))
        }
        l.addChildNode(swarm)
        spin(swarm, axis: SCNVector3(0, 1, 0), period: 20)
        for (i, x) in [Float(-16), 0, 16].enumerated() {
            starToken(l, at: SCNVector3(x, 4 + Float(i % 2) * 8, 0))
        }
    }

    // MARK: - Space

    private static func ringedPlanet(_ s: SCNNode, _ l: SCNNode) {
        let planet = SCNNode()
        planet.position = SCNVector3(108, 0, 0)
        put(SCNSphere(radius: 44), rgb(0.95, 0.62, 0.45), in: planet)
        for (dy, colour) in [(Float(-14), rgb(0.85, 0.48, 0.38)), (12, rgb(1, 0.78, 0.55))] {
            let band = put(SCNCylinder(radius: 44 * CGFloat(cos(asin(dy / 44))) + 0.6, height: 7), colour, in: planet,
                           at: SCNVector3(0, dy, 0))
            band.opacity = 0.95
        }
        l.addChildNode(planet)
        spin(planet, axis: SCNVector3(0, 1, 0), period: 30)
        for (radius, pipe, colour) in [(CGFloat(158), CGFloat(5), rgb(0.85, 0.80, 1, 0.75)),
                                       (170, 2, rgb(0.70, 0.85, 1, 0.5))] {
            put(SCNTorus(ringRadius: radius, pipeRadius: pipe), colour, in: s,
                at: SCNVector3(108, 0, 0), glow: true).eulerAngles.x = .pi / 2
        }
    }

    private static func constellationGate(_ s: SCNNode, _ l: SCNNode) {
        var rng = SeededRandom(seed: 21)
        var pts: [SCNVector3] = []
        for i in 0..<9 {
            let a = Float(i) / 9 * 2 * .pi
            let r = rng.nextFloat(in: 56...68)
            pts.append(SCNVector3(cos(a) * r, sin(a) * r, 0))
        }
        for i in 0..<pts.count {
            rod(from: pts[i], to: pts[(i + 1) % pts.count], radius: 0.45, rgb(0.65, 0.80, 1, 0.6), in: s, glow: true)
        }
        for p in pts {
            let star = SCNNode()
            star.position = p
            put(SCNSphere(radius: 3), rgb(1, 0.97, 0.85), in: star, glow: true)
            for angle: Float in [0, .pi / 2] {
                let ray = put(SCNBox(width: 14, height: 1.2, length: 1.2, chamferRadius: 0.6), rgb(1, 0.95, 0.75), in: star, glow: true)
                ray.eulerAngles.z = angle
            }
            star.constraints = [SCNBillboardConstraint()]
            star.runAction(.repeatForever(.sequence([
                .fadeOpacity(to: 0.45, duration: TimeInterval(rng.nextFloat(in: 0.8...1.6))),
                .fadeOpacity(to: 1, duration: TimeInterval(rng.nextFloat(in: 0.8...1.6)))
            ])))
            l.addChildNode(star)
        }
    }

    private static func cometTail(_ s: SCNNode, _ l: SCNNode) {
        put(SCNSphere(radius: 10), rgb(0.85, 0.95, 1), in: l, glow: true)
        put(SCNSphere(radius: 20), rgb(0.6, 0.85, 1, 0.22), in: l, glow: true)
        emitter(l) { ps in
            ps.birthRate = 80
            ps.particleLifeSpan = 2.4
            ps.emittingDirection = SCNVector3(1, 0.25, 0.3)
            ps.spreadingAngle = 9
            ps.particleVelocity = 70
            ps.particleVelocityVariation = 20
            ps.particleSize = 5
            ps.particleSizeVariation = 2
            ps.particleColor = rgb(0.65, 0.85, 1, 0.8)
            ps.particleColorVariation = SCNVector4(0.1, 0.1, 0, 0)
        }
        bob(l, by: 10, period: 5)
    }

    // MARK: - Ocean

    private static func kelpArch(_ s: SCNNode, _ l: SCNNode) {
        let kelp = rgb(0.30, 0.58, 0.30)
        let sway = SCNNode()
        for sx: Float in [-1, 1] {
            put(SCNSphere(radius: 16), rgb(0.50, 0.46, 0.42), in: s, at: SCNVector3(sx * 70, -82, 0))
        }
        let pts = arcPoints(center: SCNVector3(0, -40, 0), radius: 70, from: 0.05, to: .pi - 0.05, count: 16)
        for i in 0..<(pts.count - 1) {
            rod(from: pts[i], to: pts[i + 1], radius: 3.2, kelp, in: sway)
            let blade = put(SCNSphere(radius: 6), rgb(0.38, 0.70, 0.36), in: sway,
                            at: SCNVector3(pts[i].x, pts[i].y, pts[i].z + (i % 2 == 0 ? 5 : -5)))
            blade.scale = SCNVector3(0.5, 1.4, 0.25)
            blade.eulerAngles.z = Float(i) * 0.4
        }
        for sx: Float in [-1, 1] {
            rod(from: SCNVector3(sx * 70, -76, 0), to: pts[sx < 0 ? pts.count - 1 : 0], radius: 3.2, kelp, in: sway)
        }
        l.addChildNode(sway)
        sway.runAction(.repeatForever(.sequence([.rotateBy(x: 0, y: 0, z: 0.04, duration: 2.5),
                                                 .rotateBy(x: 0, y: 0, z: -0.04, duration: 2.5)])))
    }

    private static func coralGate(_ s: SCNNode, _ l: SCNNode) {
        // Rotate the torus node itself (it stays its own node when baking).
        put(SCNTorus(ringRadius: 60, pipeRadius: 4), rgb(1, 0.52, 0.55), in: s).eulerAngles.x = .pi / 2
        let colours = [rgb(1, 0.45, 0.55), rgb(1, 0.62, 0.30), rgb(0.70, 0.45, 0.90), rgb(1, 0.80, 0.40)]
        for i in 0..<14 {
            let a = Float(i) / 14 * 2 * .pi
            let base = SCNVector3(cos(a) * 60, sin(a) * 60, 0)
            let tip = SCNVector3(cos(a) * 80, sin(a) * 80, Float(i % 3 - 1) * 4)
            let colour = colours[i % colours.count]
            rod(from: base, to: tip, radius: 2.6, colour, in: s)
            put(SCNSphere(radius: 4), colour, in: s, at: tip)
            let twig = SCNVector3(tip.x + cos(a + 0.8) * 8, tip.y + sin(a + 0.8) * 8, tip.z)
            rod(from: SCNVector3((base.x + tip.x) / 2, (base.y + tip.y) / 2, 0), to: twig, radius: 1.6, colour, in: s)
        }
        let school = SCNNode()
        for i in 0..<6 {
            let a = Float(i) / 6 * 2 * .pi
            let fish = put(SCNSphere(radius: 3), rgb(1, 0.62, 0.20), in: school, at: SCNVector3(cos(a) * 92, sin(a) * 92, 8))
            fish.scale = SCNVector3(1.6, 0.9, 0.7)
        }
        l.addChildNode(school)
        spin(school, axis: SCNVector3(0, 0, 1), period: 12)
    }

    private static func bubbleColumn(_ s: SCNNode, _ l: SCNNode) {
        let h = SetPiece.liftHalfHeight
        put(SCNCylinder(radius: 40, height: CGFloat(h * 2)), rgb(0.70, 0.92, 1, 0.10), in: s)
        let clam = put(SCNSphere(radius: 22), rgb(0.85, 0.78, 0.92), in: s, at: SCNVector3(0, -h, 0))
        clam.scale = SCNVector3(1.3, 0.5, 1.1)
        emitter(l, at: SCNVector3(0, -h + 8, 0)) { ps in
            ps.birthRate = 45
            ps.particleLifeSpan = 5
            ps.emitterShape = SCNCylinder(radius: 30, height: 2)
            ps.birthLocation = .volume
            ps.emittingDirection = SCNVector3(0, 1, 0)
            ps.spreadingAngle = 5
            ps.particleVelocity = 95
            ps.particleSize = 4
            ps.particleSizeVariation = 2
            ps.blendMode = .alpha
            ps.particleColor = rgb(0.90, 0.97, 1, 0.7)
        }
    }

    /// Axis-aligned extent of every piece of geometry under `node`, in
    /// `node`'s space (a node's own `boundingBox` ignores its children).
    static func extent(of node: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        node.enumerateHierarchy { child, _ in
            guard child.geometry != nil else { return }
            let (a, b) = child.boundingBox
            for x in [a.x, b.x] { for y in [a.y, b.y] { for z in [a.z, b.z] {
                let p = child.convertPosition(SCNVector3(x, y, z), to: node)
                lo = simd_min(lo, SIMD3(p.x, p.y, p.z))
                hi = simd_max(hi, SIMD3(p.x, p.y, p.z))
            } } }
        }
        guard lo.x <= hi.x else { return (SCNVector3Zero, SCNVector3Zero) }
        return (SCNVector3(lo.x, lo.y, lo.z), SCNVector3(hi.x, hi.y, hi.z))
    }

    /// Distance from the origin to the furthest geometry, for tests
    /// (pieces must stay within a sane footprint).
    static func footprint(of node: SCNNode) -> Float {
        let (lo, hi) = extent(of: node)
        return max(abs(lo.x), abs(lo.y), abs(lo.z), abs(hi.x), abs(hi.y), abs(hi.z))
    }
}
