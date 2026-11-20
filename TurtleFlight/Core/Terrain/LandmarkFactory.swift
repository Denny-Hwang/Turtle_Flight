import Foundation
import SceneKit
import UIKit

/// Builds each landmark from SceneKit primitives — no model files, so
/// the whole set costs a few kilobytes of code instead of megabytes of
/// assets. Each is roughly 100–300 units across so it reads from a
/// cell away, and is flattened into a single node per material.
enum LandmarkFactory {

    static func build(_ kind: LandmarkKind) -> SCNNode {
        let root = SCNNode()
        switch kind {
        case .floatingCastle: floatingCastle(root)
        case .rainbowGate:    rainbowGate(root)
        case .windmillHill:   windmillHill(root)
        case .greatPyramids:  greatPyramids(root)
        case .sandGuardian:   sandGuardian(root)
        case .palmOasis:      palmOasis(root)
        case .sunObelisk:     sunObelisk(root)
        case .ironLaceTower:  ironLaceTower(root)
        case .grandArch:      grandArch(root)
        case .riverBridge:    bridge(root, deck: c(0.86, 0.84, 0.80), tower: c(0.70, 0.72, 0.78), cable: c(0.95, 0.95, 0.98))
        case .skyWheel:       skyWheel(root)
        case .hilltopTower:   hilltopTower(root)
        case .palaceGate:     palaceGate(root)
        case .hanokVillage:   hanokVillage(root)
        case .moonBridge:     moonBridge(root)
        case .greatFalls:     greatFalls(root)
        case .canyonArch:     canyonArch(root)
        case .auroraPeak:     auroraPeak(root)
        case .giantTree:      giantTree(root)
        case .ringPlanet:     ringPlanet(root)
        case .spaceStation:   spaceStation(root)
        case .moonBase:       moonBase(root)
        case .shipwreck:      shipwreck(root)
        case .seaVolcano:     seaVolcano(root)
        case .shellPalace:    shellPalace(root)
        }
        // Spinning / glowing parts are added to `root` under this name
        // and kept out of the flattened static mesh.
        let moving = root.childNodes.filter { $0.name == movingName }
        moving.forEach { $0.removeFromParentNode() }
        let flat = root.flattenedClone()
        moving.forEach { flat.addChildNode($0) }
        return flat
    }

    private static let movingName = "moving"

    // MARK: - Helpers

    private static func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }

    @discardableResult
    private static func add(_ geometry: SCNGeometry, _ color: UIColor, to parent: SCNNode,
                            at p: SCNVector3 = SCNVector3Zero, euler: SCNVector3 = SCNVector3Zero,
                            glow: Bool = false) -> SCNNode {
        let node = SCNNode(geometry: geometry)
        let m = SCNMaterial()
        m.diffuse.contents = color
        if glow { m.emission.contents = color; m.lightingModel = .constant }
        if color.cgColor.alpha < 1 { m.isDoubleSided = true }
        geometry.materials = [m]
        node.position = p
        node.eulerAngles = euler
        parent.addChildNode(node)
        return node
    }

    private static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, chamfer: CGFloat = 1) -> SCNBox {
        SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
    }

    private static func v(_ x: Float, _ y: Float, _ z: Float) -> SCNVector3 { SCNVector3(x, y, z) }

    /// Curved-eave tiled roof used by the palace gate and hanok houses.
    private static func tiledRoof(width: CGFloat, length: CGFloat, to parent: SCNNode, y: Float) {
        add(SCNPyramid(width: width, height: width * 0.22, length: length), c(0.20, 0.25, 0.32), to: parent, at: v(0, y, 0))
        add(box(width * 1.08, width * 0.03, length * 1.1, chamfer: 0.5), c(0.27, 0.33, 0.40), to: parent, at: v(0, y, 0))
    }

    // MARK: - Sky

    private static func floatingCastle(_ r: SCNNode) {
        add(SCNCone(topRadius: 70, bottomRadius: 8, height: 60), c(0.55, 0.43, 0.33), to: r, at: v(0, -30, 0))
        add(SCNCylinder(radius: 72, height: 8), c(0.38, 0.75, 0.40), to: r, at: v(0, 4, 0))
        add(box(60, 40, 60, chamfer: 3), c(0.96, 0.94, 0.98), to: r, at: v(0, 28, 0))
        for (x, z) in [(-34, -34), (34, -34), (-34, 34), (34, 34)] as [(Float, Float)] {
            add(SCNCylinder(radius: 10, height: 64), c(0.93, 0.90, 0.97), to: r, at: v(x, 40, z))
            add(SCNCone(topRadius: 0, bottomRadius: 13, height: 26), c(0.93, 0.42, 0.55), to: r, at: v(x, 85, z))
        }
        add(SCNCylinder(radius: 14, height: 80), c(0.96, 0.94, 0.98), to: r, at: v(0, 70, 0))
        add(SCNCone(topRadius: 0, bottomRadius: 18, height: 36), c(0.42, 0.56, 0.93), to: r, at: v(0, 128, 0))
        for i in 0..<3 {
            add(SCNSphere(radius: 22), c(1, 1, 1, 0.9), to: r, at: v(Float(i - 1) * 60, -52, Float(i % 2) * 30))
        }
    }

    private static func rainbowGate(_ r: SCNNode) {
        let colours = [c(0.95, 0.30, 0.30), c(1.0, 0.62, 0.20), c(1.0, 0.88, 0.25),
                       c(0.35, 0.80, 0.40), c(0.30, 0.55, 0.95), c(0.60, 0.40, 0.90)]
        for (i, colour) in colours.enumerated() {
            add(SCNTorus(ringRadius: CGFloat(120 - i * 9), pipeRadius: 5), colour.withAlphaComponent(0.85),
                to: r, euler: v(.pi / 2, 0, 0), glow: true)
        }
        for sx: Float in [-1, 1] {
            for i in 0..<3 {
                add(SCNSphere(radius: CGFloat(26 - i * 4)), c(1, 1, 1, 0.92), to: r,
                    at: v(sx * (100 + Float(i) * 14), -20 + Float(i) * 8, Float(i) * 10 - 10))
            }
        }
    }

    private static func windmillHill(_ r: SCNNode) {
        add(SCNSphere(radius: 90), c(0.42, 0.74, 0.40), to: r, at: v(0, -55, 0))
        add(SCNCone(topRadius: 12, bottomRadius: 20, height: 80), c(0.97, 0.95, 0.90), to: r, at: v(0, 70, 0))
        add(SCNCone(topRadius: 0, bottomRadius: 17, height: 22), c(0.85, 0.32, 0.30), to: r, at: v(0, 121, 0))
        let sails = SCNNode()
        sails.name = movingName
        sails.position = v(0, 104, 18)
        for i in 0..<4 {
            let blade = add(box(8, 62, 2, chamfer: 0.5), c(0.99, 0.97, 0.92), to: sails, at: v(0, 31, 0))
            blade.pivot = SCNMatrix4MakeTranslation(0, -31, 0)
            blade.position = SCNVector3Zero
            blade.eulerAngles.z = Float(i) * .pi / 2
        }
        sails.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: .pi * 2, duration: 9)))
        r.addChildNode(sails)
    }

    // MARK: - Desert

    private static func greatPyramids(_ r: SCNNode) {
        let stone = c(0.88, 0.72, 0.44), cap = c(0.98, 0.86, 0.45)
        for (x, z, w) in [(0, 0, 220), (-190, 110, 150), (170, 140, 110)] as [(Float, Float, CGFloat)] {
            add(SCNPyramid(width: w, height: w * 0.64, length: w), stone, to: r, at: v(x, 0, z))
            add(SCNPyramid(width: w * 0.16, height: w * 0.11, length: w * 0.16), cap, to: r,
                at: v(x, Float(w) * 0.54, z), glow: true)
        }
        add(box(40, 6, 260, chamfer: 1), c(0.80, 0.64, 0.40), to: r, at: v(0, 3, -210))
    }

    private static func sandGuardian(_ r: SCNNode) {
        let stone = c(0.84, 0.68, 0.42)
        add(box(60, 34, 150, chamfer: 12), stone, to: r, at: v(0, 17, 0))
        add(box(26, 14, 70, chamfer: 6), stone, to: r, at: v(-22, 7, 100))
        add(box(26, 14, 70, chamfer: 6), stone, to: r, at: v(22, 7, 100))
        add(SCNSphere(radius: 30), stone, to: r, at: v(0, 62, 62))
        // Friendly cat-like ears and a striped collar: a made-up guardian.
        for sx: Float in [-1, 1] {
            add(SCNCone(topRadius: 0, bottomRadius: 10, height: 22), stone, to: r, at: v(sx * 17, 94, 60))
        }
        add(SCNTorus(ringRadius: 26, pipeRadius: 5), c(0.25, 0.60, 0.70), to: r, at: v(0, 36, 58))
        add(box(90, 6, 190, chamfer: 2), c(0.76, 0.60, 0.38), to: r, at: v(0, -1, 10))
    }

    private static func palmOasis(_ r: SCNNode) {
        add(SCNCylinder(radius: 80, height: 3), c(0.25, 0.68, 0.80), to: r, at: v(0, 2, 0), glow: false)
        add(SCNTorus(ringRadius: 88, pipeRadius: 10), c(0.40, 0.72, 0.36), to: r, at: v(0, 2, 0))
        for i in 0..<8 {
            let a = Float(i) * .pi / 4
            let palm = TerrainGenerator.makePalm(at: v(cos(a) * 92, 4, sin(a) * 92))
            palm.scale = v(4, 4, 4)
            r.addChildNode(palm)
        }
        for (x, z, col) in [(-30, 20, c(0.90, 0.30, 0.30)), (25, -18, c(0.98, 0.80, 0.30)), (0, 40, c(0.95, 0.95, 0.95))] as [(Float, Float, UIColor)] {
            add(SCNCone(topRadius: 0, bottomRadius: 18, height: 24), col, to: r, at: v(x * 3.4, 16, z * 3.4))
        }
    }

    private static func sunObelisk(_ r: SCNNode) {
        add(box(70, 12, 70, chamfer: 2), c(0.80, 0.64, 0.40), to: r, at: v(0, 6, 0))
        add(SCNCone(topRadius: 9, bottomRadius: 15, height: 170), c(0.90, 0.76, 0.50), to: r, at: v(0, 97, 0))
        add(SCNPyramid(width: 20, height: 22, length: 20), c(1.0, 0.86, 0.35), to: r, at: v(0, 182, 0), glow: true)
        let disc = add(SCNTorus(ringRadius: 34, pipeRadius: 4), c(1.0, 0.80, 0.30), to: r, at: v(0, 215, 0),
                       euler: v(.pi / 2, 0, 0), glow: true)
        disc.name = movingName
        disc.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 12)))
        for (x, z) in [(-60, -60), (60, -60), (-60, 60), (60, 60)] as [(Float, Float)] {
            add(SCNCylinder(radius: 6, height: 50), c(0.86, 0.70, 0.46), to: r, at: v(x, 25, z))
        }
    }

    // MARK: - City

    private static func ironLaceTower(_ r: SCNNode) {
        // A lattice tower on four splayed legs with three decks — the
        // generic silhouette of 19th-century iron towers, in a rose-gold
        // colour of our own and with a beacon instead of an antenna.
        let iron = c(0.72, 0.50, 0.42)
        for (sx, sz) in [(-1, -1), (1, -1), (-1, 1), (1, 1)] as [(Float, Float)] {
            add(box(12, 96, 12, chamfer: 1), iron, to: r, at: v(sx * 38, 44, sz * 38),
                euler: v(sz * 0.36, 0, -sx * 0.36))
        }
        add(box(86, 8, 86, chamfer: 2), iron, to: r, at: v(0, 88, 0))
        add(SCNCone(topRadius: 16, bottomRadius: 34, height: 80), iron, to: r, at: v(0, 132, 0))
        add(box(48, 6, 48, chamfer: 2), iron, to: r, at: v(0, 172, 0))
        add(SCNCone(topRadius: 5, bottomRadius: 16, height: 110), iron, to: r, at: v(0, 228, 0))
        add(box(18, 5, 18, chamfer: 1), iron, to: r, at: v(0, 282, 0))
        add(SCNSphere(radius: 7), c(1.0, 0.85, 0.40), to: r, at: v(0, 296, 0), glow: true)
        add(SCNCylinder(radius: 90, height: 3), c(0.50, 0.74, 0.44), to: r, at: v(0, 1.5, 0))
    }

    private static func grandArch(_ r: SCNNode) {
        let stone = c(0.93, 0.90, 0.82)
        for sx: Float in [-1, 1] {
            add(box(38, 110, 44, chamfer: 2), stone, to: r, at: v(sx * 46, 55, 0))
        }
        add(box(130, 34, 44, chamfer: 2), stone, to: r, at: v(0, 127, 0))
        add(box(140, 8, 50, chamfer: 2), c(0.82, 0.78, 0.70), to: r, at: v(0, 148, 0))
        add(SCNCylinder(radius: 27, height: 44), c(0.62, 0.74, 0.93, 0.0), to: r, at: v(0, 110, 0), euler: v(.pi / 2, 0, 0))
        for i in 0..<5 {
            add(SCNSphere(radius: 5), c(1.0, 0.82, 0.35), to: r, at: v(Float(i - 2) * 26, 158, 0), glow: true)
        }
    }

    private static func bridge(_ r: SCNNode, deck: UIColor, tower: UIColor, cable: UIColor) {
        add(box(34, 6, 340, chamfer: 1), deck, to: r, at: v(0, 34, 0))
        for sz: Float in [-1, 1] {
            for sx: Float in [-1, 1] {
                add(box(8, 120, 10, chamfer: 1), tower, to: r, at: v(sx * 17, 60, sz * 90))
            }
            add(box(46, 8, 10, chamfer: 1), tower, to: r, at: v(0, 116, sz * 90))
            for i in 1...5 {
                let z = sz * 90 + Float(i) * 13
                let z2 = sz * 90 - Float(i) * 13
                let h = CGFloat(76 - i * 12)
                for zz in [z, z2] {
                    add(SCNCylinder(radius: 0.9, height: h), cable, to: r, at: v(-17, 37 + Float(h) / 2, zz))
                    add(SCNCylinder(radius: 0.9, height: h), cable, to: r, at: v(17, 37 + Float(h) / 2, zz))
                }
            }
        }
        add(box(60, 4, 380, chamfer: 1), c(0.28, 0.52, 0.80), to: r, at: v(0, 1, 0))
    }

    private static func skyWheel(_ r: SCNNode) {
        for sx: Float in [-1, 1] {
            add(box(8, 130, 8, chamfer: 1), c(0.85, 0.87, 0.92), to: r, at: v(sx * 26, 60, 0), euler: v(0, 0, sx * 0.2))
        }
        let wheel = SCNNode()
        wheel.name = movingName
        wheel.position = v(0, 120, 0)
        add(SCNTorus(ringRadius: 96, pipeRadius: 3.5), c(0.95, 0.96, 1.0), to: wheel, euler: v(.pi / 2, 0, 0))
        let cabins = [c(0.95, 0.35, 0.40), c(1.0, 0.75, 0.25), c(0.35, 0.75, 0.50), c(0.35, 0.60, 0.95)]
        for i in 0..<12 {
            let a = Float(i) * .pi / 6
            add(SCNCylinder(radius: 1.2, height: 96), c(0.90, 0.92, 0.97), to: wheel,
                at: v(cos(a) * 48, sin(a) * 48, 0), euler: v(0, 0, a - .pi / 2))
            add(SCNSphere(radius: 9), cabins[i % cabins.count], to: wheel, at: v(cos(a) * 96, sin(a) * 96, 0))
        }
        wheel.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: .pi * 2, duration: 40)))
        r.addChildNode(wheel)
    }

    // MARK: - Seoul

    private static func hilltopTower(_ r: SCNNode) {
        // A slim observation tower standing on a wooded hill.
        add(SCNCone(topRadius: 40, bottomRadius: 150, height: 110), c(0.34, 0.62, 0.38), to: r, at: v(0, 55, 0))
        for i in 0..<10 {
            let a = Float(i) * .pi / 5
            add(SCNSphere(radius: 14), i % 3 == 0 ? c(1.0, 0.76, 0.84) : c(0.28, 0.58, 0.34), to: r,
                at: v(cos(a) * 80, 70, sin(a) * 80))
        }
        add(SCNCylinder(radius: 26, height: 14), c(0.90, 0.90, 0.88), to: r, at: v(0, 117, 0))
        add(SCNCylinder(radius: 7, height: 130), c(0.93, 0.93, 0.95), to: r, at: v(0, 189, 0))
        add(SCNCylinder(radius: 20, height: 16), c(0.80, 0.86, 0.93), to: r, at: v(0, 250, 0))
        add(SCNCone(topRadius: 20, bottomRadius: 12, height: 10), c(0.93, 0.93, 0.95), to: r, at: v(0, 237, 0))
        add(SCNCone(topRadius: 2, bottomRadius: 12, height: 26), c(0.93, 0.93, 0.95), to: r, at: v(0, 271, 0))
        add(SCNCylinder(radius: 1.6, height: 60), c(0.90, 0.30, 0.30), to: r, at: v(0, 314, 0))
        add(SCNSphere(radius: 4), c(1.0, 0.35, 0.35), to: r, at: v(0, 346, 0), glow: true)
    }

    private static func palaceGate(_ r: SCNNode) {
        add(box(190, 44, 60, chamfer: 2), c(0.84, 0.82, 0.76), to: r, at: v(0, 22, 0))
        for x: Float in [-50, 0, 50] {
            add(box(26, 34, 64, chamfer: 10), c(0.30, 0.20, 0.18), to: r, at: v(x, 17, 0))
        }
        for level in 0..<2 {
            let y = Float(44 + level * 34)
            let w = CGFloat(150 - level * 34)
            for i in 0..<5 {
                add(SCNCylinder(radius: 3, height: 24), c(0.70, 0.22, 0.20), to: r,
                    at: v(Float(i - 2) * Float(w) / 5, y + 12, 22))
                add(SCNCylinder(radius: 3, height: 24), c(0.70, 0.22, 0.20), to: r,
                    at: v(Float(i - 2) * Float(w) / 5, y + 12, -22))
            }
            add(box(w, 22, 40, chamfer: 1), c(0.20, 0.52, 0.48), to: r, at: v(0, y + 12, 0))
            let roof = SCNNode()
            roof.position = v(0, y + 24, 0)
            tiledRoof(width: w * 1.25, length: 78, to: roof, y: 0)
            r.addChildNode(roof)
        }
    }

    private static func hanokVillage(_ r: SCNNode) {
        add(box(240, 3, 240, chamfer: 1), c(0.86, 0.82, 0.72), to: r, at: v(0, 1.5, 0))
        for (i, pos) in [(-70, -60), (10, -70), (80, -40), (-80, 30), (0, 20), (75, 50), (-30, 90), (50, 110)].enumerated() {
            let house = SCNNode()
            house.position = v(Float(pos.0), 3, Float(pos.1))
            house.eulerAngles.y = Float(i) * 0.4
            add(box(44, 16, 30, chamfer: 1), c(0.97, 0.94, 0.87), to: house, at: v(0, 8, 0))
            for px: Float in [-18, 0, 18] {
                add(box(2.5, 16, 2.5, chamfer: 0.3), c(0.48, 0.28, 0.20), to: house, at: v(px, 8, 15.5))
            }
            tiledRoof(width: 58, length: 42, to: house, y: 16)
            r.addChildNode(house)
        }
        for (x, z) in [(-110, -100), (110, 100), (-100, 110), (105, -105)] as [(Float, Float)] {
            let tree = TerrainGenerator.makeBlossomTree(at: v(x, 3, z))
            tree.scale = v(3, 3, 3)
            r.addChildNode(tree)
        }
    }

    private static func moonBridge(_ r: SCNNode) {
        // A river crossing with a full-moon arch and a rainbow of lamps.
        add(box(60, 4, 360, chamfer: 1), c(0.30, 0.55, 0.82), to: r, at: v(0, 1, 0))
        add(box(30, 6, 330, chamfer: 1), c(0.90, 0.90, 0.92), to: r, at: v(0, 30, 0))
        for i in 0..<7 {
            add(SCNCylinder(radius: 5, height: 30), c(0.82, 0.83, 0.86), to: r, at: v(0, 15, Float(i - 3) * 50))
        }
        add(SCNTorus(ringRadius: 70, pipeRadius: 4), c(0.96, 0.96, 0.98), to: r, at: v(0, 33, 0), euler: v(0, 0, .pi / 2))
        let lamps = [c(0.95, 0.30, 0.30), c(1.0, 0.62, 0.20), c(1.0, 0.88, 0.25), c(0.35, 0.80, 0.40),
                     c(0.30, 0.55, 0.95), c(0.60, 0.40, 0.90)]
        for i in 0..<18 {
            for sx: Float in [-1, 1] {
                add(SCNSphere(radius: 3), lamps[i % lamps.count], to: r,
                    at: v(sx * 15, 35, Float(i) * 18 - 153), glow: true)
            }
        }
    }

    // MARK: - Wild

    private static func greatFalls(_ r: SCNNode) {
        add(box(260, 190, 90, chamfer: 14), c(0.48, 0.44, 0.42), to: r, at: v(0, 95, -45))
        add(box(280, 20, 110, chamfer: 8), c(0.24, 0.56, 0.32), to: r, at: v(0, 196, -45))
        for (x, w) in [(-60, 46), (0, 70), (66, 40)] as [(Float, CGFloat)] {
            add(box(w, 186, 6, chamfer: 3), c(0.80, 0.93, 1.0, 0.85), to: r, at: v(x, 97, 3), glow: true)
        }
        add(SCNCylinder(radius: 130, height: 3), c(0.30, 0.62, 0.82), to: r, at: v(0, 2, 70))
        for i in 0..<7 {
            add(SCNSphere(radius: CGFloat(16 + i % 3 * 5)), c(1, 1, 1, 0.75), to: r, at: v(Float(i - 3) * 30, 12, 14))
        }
        let rainbow = add(SCNTorus(ringRadius: 80, pipeRadius: 3), c(1.0, 0.70, 0.75, 0.6), to: r, at: v(0, 20, 60),
                          euler: v(.pi / 2, 0, 0), glow: true)
        rainbow.name = movingName
    }

    private static func canyonArch(_ r: SCNNode) {
        let rock = c(0.76, 0.42, 0.28), band = c(0.88, 0.58, 0.36)
        for sx: Float in [-1, 1] {
            add(box(60, 170, 70, chamfer: 16), rock, to: r, at: v(sx * 95, 85, 0))
            add(box(64, 14, 74, chamfer: 6), band, to: r, at: v(sx * 95, 60, 0))
            add(box(64, 10, 74, chamfer: 5), band, to: r, at: v(sx * 95, 120, 0))
        }
        add(box(260, 46, 66, chamfer: 20), rock, to: r, at: v(0, 180, 0))
        add(box(264, 8, 70, chamfer: 4), band, to: r, at: v(0, 170, 0))
        for (x, z, h) in [(-170, 60, 90), (180, -50, 120), (-200, -70, 60)] as [(Float, Float, CGFloat)] {
            add(SCNCone(topRadius: 14, bottomRadius: 24, height: h), rock, to: r, at: v(x, Float(h) / 2, z))
        }
    }

    private static func auroraPeak(_ r: SCNNode) {
        add(SCNCone(topRadius: 0, bottomRadius: 150, height: 300), c(0.55, 0.60, 0.68), to: r, at: v(0, 150, 0))
        add(SCNCone(topRadius: 0, bottomRadius: 62, height: 124), c(0.97, 0.98, 1.0), to: r, at: v(0, 238, 0))
        for (x, z, h) in [(-150, 40, 170), (140, -60, 200)] as [(Float, Float, CGFloat)] {
            add(SCNCone(topRadius: 0, bottomRadius: 90, height: h), c(0.50, 0.56, 0.64), to: r, at: v(x, Float(h) / 2, z))
            add(SCNCone(topRadius: 0, bottomRadius: 36, height: h * 0.4), c(0.97, 0.98, 1.0), to: r, at: v(x, Float(h) * 0.8, z))
        }
        let ribbons = SCNNode()
        ribbons.name = movingName
        ribbons.position = v(0, 380, 0)
        for (i, col) in [c(0.35, 1.0, 0.70, 0.45), c(0.45, 0.80, 1.0, 0.40), c(0.80, 0.55, 1.0, 0.35)].enumerated() {
            add(SCNTube(innerRadius: CGFloat(190 + i * 40), outerRadius: CGFloat(194 + i * 40), height: 70),
                col, to: ribbons, at: v(0, Float(i) * 16, 0), glow: true)
        }
        ribbons.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 60)))
        r.addChildNode(ribbons)
    }

    private static func giantTree(_ r: SCNNode) {
        add(SCNCone(topRadius: 22, bottomRadius: 44, height: 200), c(0.44, 0.30, 0.22), to: r, at: v(0, 100, 0))
        for i in 0..<6 {
            let a = Float(i) * .pi / 3
            add(SCNCone(topRadius: 6, bottomRadius: 16, height: 60), c(0.44, 0.30, 0.22), to: r,
                at: v(cos(a) * 46, 12, sin(a) * 46), euler: v(sin(a) * 0.7, 0, -cos(a) * 0.7))
        }
        let leaf = [c(0.18, 0.55, 0.30), c(0.26, 0.66, 0.36), c(0.14, 0.46, 0.28)]
        for (i, p) in [(0, 250, 0, 90), (-70, 220, 20, 62), (72, 226, -16, 64), (10, 230, 76, 58),
                       (-16, 232, -74, 58), (-40, 290, 30, 52), (44, 296, -24, 50)].enumerated() {
            add(SCNSphere(radius: CGFloat(p.3)), leaf[i % 3], to: r, at: v(Float(p.0), Float(p.1), Float(p.2)))
        }
        add(box(34, 22, 30, chamfer: 3), c(0.86, 0.70, 0.46), to: r, at: v(52, 150, 0))
        add(SCNPyramid(width: 42, height: 16, length: 38), c(0.80, 0.34, 0.30), to: r, at: v(52, 161, 0))
        for i in 0..<5 {
            add(SCNSphere(radius: 4), c(1.0, 0.90, 0.50), to: r, at: v(Float(i - 2) * 40, 210 - Float(abs(i - 2)) * 14, 84), glow: true)
        }
    }

    // MARK: - Space

    private static func ringPlanet(_ r: SCNNode) {
        add(SCNSphere(radius: 110), c(0.93, 0.70, 0.45), to: r)
        add(SCNTorus(ringRadius: 111, pipeRadius: 6), c(0.86, 0.56, 0.38), to: r, at: v(0, 24, 0))
        add(SCNTorus(ringRadius: 108, pipeRadius: 5), c(0.98, 0.82, 0.60), to: r, at: v(0, -30, 0))
        let rings = SCNNode()
        rings.name = movingName
        rings.eulerAngles = v(0.35, 0, 0.2)
        for (i, col) in [c(0.95, 0.85, 0.70, 0.8), c(0.80, 0.72, 0.95, 0.7), c(1.0, 0.92, 0.80, 0.6)].enumerated() {
            add(SCNTube(innerRadius: CGFloat(150 + i * 26), outerRadius: CGFloat(170 + i * 26), height: 2), col, to: rings)
        }
        rings.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 50)))
        r.addChildNode(rings)
        add(SCNSphere(radius: 20), c(0.80, 0.84, 0.92), to: r, at: v(230, 60, 40))
    }

    private static func spaceStation(_ r: SCNNode) {
        let hull = c(0.90, 0.92, 0.96)
        add(SCNCylinder(radius: 22, height: 130), hull, to: r, euler: v(0, 0, .pi / 2))
        add(SCNSphere(radius: 34), hull, to: r)
        add(SCNSphere(radius: 16), c(0.45, 0.85, 1.0), to: r, at: v(0, 0, 26), glow: true)
        for sx: Float in [-1, 1] {
            add(box(80, 2, 44, chamfer: 0.5), c(0.25, 0.40, 0.85), to: r, at: v(sx * 110, 0, 0))
            add(box(80, 2.4, 2, chamfer: 0.5), c(0.95, 0.80, 0.40), to: r, at: v(sx * 110, 0, 0))
        }
        let wheel = SCNNode()
        wheel.name = movingName
        add(SCNTorus(ringRadius: 80, pipeRadius: 9), c(0.96, 0.60, 0.40), to: wheel, euler: v(.pi / 2, 0, 0))
        for i in 0..<4 {
            let a = Float(i) * .pi / 2
            add(SCNCylinder(radius: 3, height: 80), hull, to: wheel, at: v(cos(a) * 40, sin(a) * 40, 0), euler: v(0, 0, a - .pi / 2))
        }
        wheel.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: .pi * 2, duration: 24)))
        r.addChildNode(wheel)
    }

    private static func moonBase(_ r: SCNNode) {
        add(SCNCylinder(radius: 150, height: 6), c(0.62, 0.58, 0.74), to: r, at: v(0, 3, 0))
        for (x, z, rad, col) in [(0, 0, 54, c(0.75, 0.90, 1.0, 0.75)), (-90, 40, 34, c(0.85, 0.80, 1.0, 0.75)),
                                 (86, -34, 38, c(0.75, 1.0, 0.90, 0.75))] as [(Float, Float, CGFloat, UIColor)] {
            add(SCNSphere(radius: rad), col, to: r, at: v(x, 6, z))
            add(SCNTorus(ringRadius: rad, pipeRadius: 4), c(0.92, 0.93, 0.97), to: r, at: v(x, 8, z))
        }
        add(SCNCylinder(radius: 9, height: 90), c(0.95, 0.95, 0.98), to: r, at: v(40, 60, 80))
        add(SCNCone(topRadius: 0, bottomRadius: 9, height: 24), c(0.92, 0.32, 0.34), to: r, at: v(40, 117, 80))
        for i in 0..<3 {
            let a = Float(i) * 2 * .pi / 3
            add(box(4, 22, 14, chamfer: 1), c(0.92, 0.32, 0.34), to: r, at: v(40 + cos(a) * 11, 22, 80 + sin(a) * 11), euler: v(0, -a, 0))
        }
        let dish = add(SCNCone(topRadius: 26, bottomRadius: 4, height: 16), c(0.90, 0.92, 0.96), to: r, at: v(-50, 60, -80),
                       euler: v(0.6, 0, 0))
        dish.name = movingName
        dish.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 16)))
        add(SCNCylinder(radius: 3, height: 50), c(0.80, 0.82, 0.88), to: r, at: v(-50, 28, -80))
    }

    // MARK: - Ocean

    private static func shipwreck(_ r: SCNNode) {
        let wood = c(0.50, 0.34, 0.24)
        let hull = SCNNode()
        hull.eulerAngles = v(0, 0.3, 0.28)
        add(box(60, 44, 200, chamfer: 20), wood, to: hull, at: v(0, 26, 0))
        add(box(62, 6, 204, chamfer: 3), c(0.64, 0.46, 0.30), to: hull, at: v(0, 48, 0))
        add(box(44, 34, 50, chamfer: 4), wood, to: hull, at: v(0, 66, -70))
        for z: Float in [-30, 40] {
            add(SCNCylinder(radius: 4, height: 150), c(0.42, 0.30, 0.22), to: hull, at: v(0, 122, z))
            add(box(70, 50, 2, chamfer: 1), c(0.90, 0.86, 0.74, 0.8), to: hull, at: v(0, 140, z + 3))
        }
        r.addChildNode(hull)
        add(box(26, 18, 20, chamfer: 3), c(0.60, 0.40, 0.22), to: r, at: v(70, 9, 60))
        add(SCNSphere(radius: 9), c(1.0, 0.84, 0.30), to: r, at: v(70, 22, 60), glow: true)
    }

    private static func seaVolcano(_ r: SCNNode) {
        add(SCNCone(topRadius: 34, bottomRadius: 170, height: 220), c(0.22, 0.30, 0.42), to: r, at: v(0, 110, 0))
        add(SCNCone(topRadius: 30, bottomRadius: 44, height: 20), c(1.0, 0.50, 0.25), to: r, at: v(0, 222, 0), glow: true)
        for (x, z) in [(-40, 30), (30, -50), (60, 40)] as [(Float, Float)] {
            add(box(8, 150, 8, chamfer: 3), c(1.0, 0.45, 0.22), to: r, at: v(x, 120, z), euler: v(z * 0.004, 0, -x * 0.004), glow: true)
        }
        let bubbles = SCNNode()
        bubbles.name = movingName
        for i in 0..<8 {
            add(SCNSphere(radius: CGFloat(6 + i % 3 * 3)), c(0.85, 0.97, 1.0, 0.5), to: bubbles,
                at: v(Float(i % 3 - 1) * 16, 240 + Float(i) * 22, Float(i % 2) * 14))
        }
        bubbles.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 40, z: 0, duration: 4), .moveBy(x: 0, y: -40, z: 0, duration: 0)])))
        r.addChildNode(bubbles)
    }

    private static func shellPalace(_ r: SCNNode) {
        add(SCNCylinder(radius: 130, height: 8), c(0.96, 0.90, 0.76), to: r, at: v(0, 4, 0))
        // A giant open clam with a glowing pearl, ringed by coral towers.
        add(SCNSphere(radius: 80), c(0.99, 0.80, 0.86), to: r, at: v(0, 6, 0)).scale = v(1, 0.38, 1)
        let lid = add(SCNSphere(radius: 80), c(0.98, 0.72, 0.82), to: r, at: v(0, 60, -52))
        lid.scale = v(1, 0.34, 1)
        lid.eulerAngles = v(-1.0, 0, 0)
        let pearl = add(SCNSphere(radius: 26), c(1.0, 0.98, 0.94), to: r, at: v(0, 50, 0), glow: true)
        pearl.name = movingName
        pearl.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 8, z: 0, duration: 2), .moveBy(x: 0, y: -8, z: 0, duration: 2)])))
        for i in 0..<6 {
            let a = Float(i) * .pi / 3
            let col = i % 2 == 0 ? c(1.0, 0.55, 0.50) : c(0.55, 0.80, 0.95)
            add(SCNCone(topRadius: 6, bottomRadius: 16, height: 110), col, to: r, at: v(cos(a) * 112, 60, sin(a) * 112))
            add(SCNSphere(radius: 13), c(1.0, 0.88, 0.45), to: r, at: v(cos(a) * 112, 122, sin(a) * 112))
        }
    }
}
