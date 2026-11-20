import Foundation
import SceneKit
import UIKit

// Decorations for the world-tour worlds (desert, city, seoul, wild).
// Same recipe as the original three: a handful of primitive-built props
// per chunk, placed by a hash of the chunk coordinate so the world is
// identical every time. Creatures and craft are tagged `friendName` so
// the player can fly by and say hello.
extension TerrainGenerator {

    func addWorldTourDecorations(to node: SCNNode, coord: ChunkCoord,
                                 chunkSize: Float, offsetX: Float, offsetZ: Float) {
        func hash(_ a: Int, _ b: Int, _ i: Int) -> Int {
            abs(coord.x &* a &+ coord.z &* b &+ i &* 31 &+ seed)
        }
        func spot(_ h: Int, _ m: Int) -> (Float, Float) {
            (offsetX + Float(h % Int(chunkSize)), offsetZ + Float((h &* m) % Int(chunkSize)))
        }

        // Clouds everywhere (fewer over the desert).
        for i in 0..<(theme == .desert ? 2 : 4) {
            let h = hash(7, 13, i)
            let (x, z) = spot(h, 17)
            let cloud = makeFluffyCloud()
            cloud.position = SCNVector3(x, Float(380 + h % 260), z)
            cloud.runAction(.repeatForever(.sequence([
                .moveBy(x: 6, y: 0, z: 0, duration: 5), .moveBy(x: -6, y: 0, z: 0, duration: 5)
            ])))
            node.addChildNode(cloud)
        }

        switch theme {
        case .desert:
            for i in 0..<3 {
                let h = hash(11, 23, i)
                let (x, z) = spot(h, 19)
                let y = terrainHeight(x: x, z: z)
                if y < 30 { node.addChildNode(Self.makePalm(at: SCNVector3(x, y, z))) }
            }
            if hash(5, 9, 0) % 3 == 0 {
                let h = hash(5, 9, 1)
                let (x, z) = spot(h, 13)
                let caravan = Self.makeCaravan()
                caravan.name = Self.friendName
                caravan.position = SCNVector3(x, terrainHeight(x: x, z: z) + 2, z)
                caravan.runAction(.repeatForever(.sequence([
                    .moveBy(x: 40, y: 0, z: 0, duration: 16), .moveBy(x: -40, y: 0, z: 0, duration: 16)
                ])))
                node.addChildNode(caravan)
            }
            if hash(3, 17, 0) % 5 == 0 {
                let h = hash(3, 17, 2)
                let (x, z) = spot(h, 7)
                let balloon = makeHotAirBalloon()
                balloon.name = Self.friendName
                balloon.position = SCNVector3(x, Float(330 + h % 160), z)
                balloon.runAction(.repeatForever(.sequence([
                    .moveBy(x: 0, y: 10, z: 0, duration: 3), .moveBy(x: 0, y: -10, z: 0, duration: 3)
                ])))
                node.addChildNode(balloon)
            }

        case .city:
            for i in 0..<7 {
                let h = hash(11, 23, i)
                let (x, z) = spot(h, 19)
                let y = terrainHeight(x: x, z: z)
                if y > 5 { node.addChildNode(Self.makeTownHouse(at: SCNVector3(x, y, z), variant: h)) }
            }
            if hash(5, 9, 0) % 3 == 0 {
                let h = hash(5, 9, 1)
                let (x, z) = spot(h, 13)
                if terrainHeight(x: x, z: z) < 0 {
                    let boat = Self.makeRiverBoat()
                    boat.name = Self.friendName
                    boat.position = SCNVector3(x, 1, z)
                    boat.runAction(.repeatForever(.sequence([
                        .moveBy(x: 0, y: 0, z: 50, duration: 14), .moveBy(x: 0, y: 0, z: -50, duration: 14)
                    ])))
                    node.addChildNode(boat)
                }
            }
            for i in 0..<2 {
                let h = hash(3, 7, i)
                let (x, z) = spot(h, 11)
                let pigeon = makeBird(color: UIColor(white: 0.78, alpha: 1))
                pigeon.position = SCNVector3(x, Float(260 + h % 200), z)
                pigeon.runAction(.repeatForever(.sequence([
                    .moveBy(x: 30, y: 4, z: 12, duration: 3), .moveBy(x: -30, y: -4, z: -12, duration: 3)
                ])))
                node.addChildNode(pigeon)
            }

        case .seoul:
            for i in 0..<5 {
                let h = hash(11, 23, i)
                let (x, z) = spot(h, 19)
                let y = terrainHeight(x: x, z: z)
                guard y > 14 else { continue }
                if y < 70 && i % 2 == 0 {
                    node.addChildNode(Self.makeTiledRoofHouse(at: SCNVector3(x, y, z)))
                } else if y < 150 {
                    node.addChildNode(Self.makeBlossomTree(at: SCNVector3(x, y, z)))
                }
            }
            if hash(5, 9, 0) % 4 == 0 {
                let h = hash(5, 9, 1)
                let (x, z) = spot(h, 13)
                let car = Self.makeCableCar()
                car.name = Self.friendName
                car.position = SCNVector3(x, Float(300 + h % 100), z)
                car.runAction(.repeatForever(.sequence([
                    .moveBy(x: 50, y: 18, z: 0, duration: 12), .moveBy(x: -50, y: -18, z: 0, duration: 12)
                ])))
                node.addChildNode(car)
            }
            for i in 0..<2 {
                let h = hash(3, 7, i)
                let (x, z) = spot(h, 11)
                let magpie = makeBird(color: UIColor(red: 0.12, green: 0.14, blue: 0.30, alpha: 1))
                magpie.position = SCNVector3(x, Float(280 + h % 200), z)
                magpie.runAction(.repeatForever(.sequence([
                    .moveBy(x: 28, y: 5, z: 10, duration: 3), .moveBy(x: -28, y: -5, z: -10, duration: 3)
                ])))
                node.addChildNode(magpie)
            }

        case .wild:
            for i in 0..<7 {
                let h = hash(11, 23, i)
                let (x, z) = spot(h, 19)
                let y = terrainHeight(x: x, z: z)
                if y > 30 && y < 240 { node.addChildNode(Self.makePine(at: SCNVector3(x, y, z), scale: 1 + Float(h % 3) * 0.4)) }
            }
            if hash(5, 9, 0) % 3 == 0 {
                let h = hash(5, 9, 1)
                let (x, z) = spot(h, 13)
                let eagle = makeBird(color: UIColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1))
                eagle.name = Self.friendName
                eagle.scale = SCNVector3(2.2, 2.2, 2.2)
                eagle.position = SCNVector3(x, Float(430 + h % 180), z)
                eagle.runAction(.repeatForever(.sequence([
                    .moveBy(x: 60, y: 8, z: 30, duration: 7), .moveBy(x: -60, y: -8, z: -30, duration: 7)
                ])))
                node.addChildNode(eagle)
            }

        default:
            break
        }
    }

    // MARK: - Prop builders

    private static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ color: UIColor,
                            at p: SCNVector3, chamfer: CGFloat = 0.3) -> SCNNode {
        let n = SCNNode(geometry: SCNBox(width: w, height: h, length: l, chamferRadius: chamfer))
        n.geometry?.firstMaterial?.diffuse.contents = color
        n.position = p
        return n
    }

    static func makePalm(at position: SCNVector3) -> SCNNode {
        let node = SCNNode()
        node.position = position
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.7, height: 12))
        trunk.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.40, blue: 0.24, alpha: 1)
        trunk.position = SCNVector3(0, 6, 0)
        node.addChildNode(trunk)
        for i in 0..<5 {
            let leaf = box(8, 0.4, 2, UIColor(red: 0.25, green: 0.62, blue: 0.30, alpha: 1),
                           at: SCNVector3(0, 12, 0), chamfer: 0.2)
            leaf.pivot = SCNMatrix4MakeTranslation(-4, 0, 0)
            leaf.eulerAngles = SCNVector3(0, Float(i) * 2 * .pi / 5, -0.35)
            node.addChildNode(leaf)
        }
        return node
    }

    static func makeCaravan() -> SCNNode {
        let node = SCNNode()
        let fur = UIColor(red: 0.80, green: 0.62, blue: 0.38, alpha: 1)
        for i in 0..<3 {
            let camel = SCNNode()
            camel.position = SCNVector3(Float(i) * 9, 0, 0)
            camel.addChildNode(box(5, 3, 2, fur, at: SCNVector3(0, 4, 0), chamfer: 1))
            let hump = SCNNode(geometry: SCNSphere(radius: 1.4))
            hump.geometry?.firstMaterial?.diffuse.contents = fur
            hump.position = SCNVector3(-0.3, 6, 0)
            camel.addChildNode(hump)
            camel.addChildNode(box(1, 3.4, 1, fur, at: SCNVector3(3, 6, 0), chamfer: 0.4))
            camel.addChildNode(box(2, 1.2, 1.2, fur, at: SCNVector3(3.8, 8, 0), chamfer: 0.5))
            for lx: Float in [-1.8, 1.8] {
                camel.addChildNode(box(0.7, 3, 0.7, fur, at: SCNVector3(lx, 1.5, 0), chamfer: 0.2))
            }
            camel.addChildNode(box(2.4, 0.6, 2.2, UIColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1),
                                   at: SCNVector3(-0.3, 5.7, 0)))
            node.addChildNode(camel)
        }
        return node
    }

    static func makeTownHouse(at position: SCNVector3, variant: Int) -> SCNNode {
        let node = SCNNode()
        node.position = position
        let walls: [UIColor] = [
            UIColor(red: 0.96, green: 0.90, blue: 0.80, alpha: 1), UIColor(red: 0.98, green: 0.82, blue: 0.72, alpha: 1),
            UIColor(red: 0.86, green: 0.90, blue: 0.96, alpha: 1), UIColor(red: 0.98, green: 0.93, blue: 0.70, alpha: 1)
        ]
        let h = CGFloat(8 + variant % 3 * 4)
        node.addChildNode(box(9, h, 9, walls[variant % walls.count], at: SCNVector3(0, Float(h) / 2, 0)))
        let roof = SCNNode(geometry: SCNPyramid(width: 10.5, height: 5, length: 10.5))
        roof.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.42, green: 0.46, blue: 0.62, alpha: 1)
        roof.position = SCNVector3(0, Float(h), 0)
        node.addChildNode(roof)
        return node
    }

    static func makeRiverBoat() -> SCNNode {
        let node = SCNNode()
        node.addChildNode(box(6, 2, 16, .white, at: SCNVector3(0, 1, 0), chamfer: 1))
        node.addChildNode(box(4.5, 2, 9, UIColor(red: 0.35, green: 0.60, blue: 0.90, alpha: 1),
                              at: SCNVector3(0, 3, 0), chamfer: 0.6))
        node.addChildNode(box(1.2, 3, 1.2, UIColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1),
                              at: SCNVector3(0, 5.5, -2)))
        return node
    }

    static func makeTiledRoofHouse(at position: SCNVector3) -> SCNNode {
        let node = SCNNode()
        node.position = position
        node.addChildNode(box(10, 4, 7, UIColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1),
                              at: SCNVector3(0, 2, 0)))
        // Wide, low, dark roof with upturned eaves.
        let roof = SCNNode(geometry: SCNPyramid(width: 14, height: 3.5, length: 10))
        roof.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.20, green: 0.24, blue: 0.30, alpha: 1)
        roof.position = SCNVector3(0, 4, 0)
        node.addChildNode(roof)
        node.addChildNode(box(15, 0.5, 11, UIColor(red: 0.26, green: 0.30, blue: 0.36, alpha: 1),
                              at: SCNVector3(0, 4.1, 0), chamfer: 0.25))
        for px: Float in [-4, 4] {
            node.addChildNode(box(0.6, 4, 0.6, UIColor(red: 0.55, green: 0.25, blue: 0.20, alpha: 1),
                                  at: SCNVector3(px, 2, 3.6), chamfer: 0.1))
        }
        return node
    }

    static func makeBlossomTree(at position: SCNVector3) -> SCNNode {
        let node = SCNNode()
        node.position = position
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.6, height: 6))
        trunk.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.40, green: 0.28, blue: 0.22, alpha: 1)
        trunk.position = SCNVector3(0, 3, 0)
        node.addChildNode(trunk)
        for (r, x, y, z) in [(4.0, 0.0, 8.0, 0.0), (3.0, 2.5, 7.0, 1.0), (3.0, -2.5, 7.2, -1.0)] {
            let puff = SCNNode(geometry: SCNSphere(radius: CGFloat(r)))
            puff.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.76, blue: 0.84, alpha: 1)
            puff.position = SCNVector3(Float(x), Float(y), Float(z))
            node.addChildNode(puff)
        }
        return node
    }

    static func makeCableCar() -> SCNNode {
        let node = SCNNode()
        node.addChildNode(box(7, 5, 5, UIColor(red: 0.92, green: 0.30, blue: 0.30, alpha: 1),
                              at: SCNVector3(0, 0, 0), chamfer: 1.2))
        node.addChildNode(box(7.2, 2, 4, UIColor(red: 0.80, green: 0.92, blue: 1.0, alpha: 1),
                              at: SCNVector3(0, 0.6, 0), chamfer: 0.4))
        node.addChildNode(box(0.4, 5, 0.4, UIColor(white: 0.35, alpha: 1), at: SCNVector3(0, 5, 0), chamfer: 0.1))
        return node
    }

    static func makePine(at position: SCNVector3, scale: Float) -> SCNNode {
        let node = SCNNode()
        node.position = position
        node.scale = SCNVector3(scale, scale, scale)
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.6, height: 4))
        trunk.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.40, green: 0.28, blue: 0.20, alpha: 1)
        trunk.position = SCNVector3(0, 2, 0)
        node.addChildNode(trunk)
        for (i, r) in [4.0, 3.0, 2.0].enumerated() {
            let tier = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: CGFloat(r), height: 5))
            tier.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.13, green: 0.45, blue: 0.28, alpha: 1)
            tier.position = SCNVector3(0, Float(5 + i * 3), 0)
            node.addChildNode(tier)
        }
        return node
    }
}
