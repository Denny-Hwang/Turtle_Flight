import Foundation
import SceneKit

final class TerrainGenerator {
    // MARK: - Chunk Management
    struct ChunkCoord: Hashable {
        let x: Int
        let z: Int
    }

    private var loadedChunks: [ChunkCoord: SCNNode] = [:]
    private let parentNode: SCNNode
    private let seed: Int
    private(set) var theme: MapTheme

    init(parentNode: SCNNode, seed: Int = 42, theme: MapTheme = .sky) {
        self.parentNode = parentNode
        self.seed = seed
        self.theme = theme
    }

    // MARK: - Public

    func updateChunks(playerPosition: SCNVector3) {
        let chunkSize = Constants.Terrain.chunkSize
        let currentChunkX = Int(floor(playerPosition.x / chunkSize))
        let currentChunkZ = Int(floor(playerPosition.z / chunkSize))
        let halfVisible = Constants.Terrain.visibleChunks / 2
        var neededChunks = Set<ChunkCoord>()

        for dx in -halfVisible...halfVisible {
            for dz in -halfVisible...halfVisible {
                neededChunks.insert(ChunkCoord(x: currentChunkX + dx, z: currentChunkZ + dz))
            }
        }

        let chunksToRemove = loadedChunks.keys.filter { !neededChunks.contains($0) }
        for coord in chunksToRemove {
            loadedChunks[coord]?.removeFromParentNode()
            loadedChunks.removeValue(forKey: coord)
        }

        for coord in neededChunks where loadedChunks[coord] == nil {
            let chunkNode = generateChunk(coord: coord)
            parentNode.addChildNode(chunkNode)
            loadedChunks[coord] = chunkNode
        }
    }

    func clearAllChunks() {
        for (_, node) in loadedChunks { node.removeFromParentNode() }
        loadedChunks.removeAll()
    }

    // MARK: - Chunk Generation

    private func generateChunk(coord: ChunkCoord) -> SCNNode {
        let chunkNode = SCNNode()
        chunkNode.name = "chunk_\(coord.x)_\(coord.z)"

        let chunkSize = Constants.Terrain.chunkSize
        let resolution = Constants.Terrain.gridResolution
        let cellSize = chunkSize / Float(resolution)
        let offsetX = Float(coord.x) * chunkSize
        let offsetZ = Float(coord.z) * chunkSize

        var vertices: [SCNVector3] = []
        var normals:  [SCNVector3] = []
        var colors:   [SCNVector3] = []
        var indices:  [Int32] = []

        for row in 0...resolution {
            for col in 0...resolution {
                let x = Float(col) * cellSize + offsetX
                let z = Float(row) * cellSize + offsetZ
                let height = terrainHeight(x: x, z: z)
                vertices.append(SCNVector3(x, height, z))
                normals.append(SCNVector3(0, 1, 0))
                colors.append(colorForHeight(height))
            }
        }

        for row in 0..<resolution {
            for col in 0..<resolution {
                let tl = Int32(row * (resolution + 1) + col)
                let tr = tl + 1
                let bl = Int32((row + 1) * (resolution + 1) + col)
                let br = bl + 1
                indices.append(contentsOf: [tl, bl, tr, tr, bl, br])
            }
        }

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector3>.size)
        let colorSource = SCNGeometrySource(
            data: colorData, semantic: .color,
            vectorCount: colors.count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<SCNVector3>.size
        )
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, normalSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.isDoubleSided = true
        geometry.materials = [material]
        chunkNode.geometry = geometry

        addDecorations(to: chunkNode, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)
        return chunkNode
    }

    // MARK: - Height

    private func terrainHeight(x: Float, z: Float) -> Float {
        let scale: Float = 0.005
        let noise = MathHelpers.fractalNoise(
            x: x * scale, y: z * scale,
            octaves: 4, persistence: 0.5, lacunarity: 2.0, seed: seed
        )
        return noise * Constants.Terrain.maxHeight
    }

    // MARK: - Theme Colors

    private func colorForHeight(_ height: Float) -> SCNVector3 {
        switch theme {
        case .sky:
            if height < Constants.Terrain.waterLevel  { return SCNVector3(0.33, 0.53, 0.87) }
            if height < Constants.Terrain.sandLevel   { return SCNVector3(0.93, 0.87, 0.68) }
            if height < Constants.Terrain.grassLevel  { return SCNVector3(0.30, 0.69, 0.31) }
            if height < Constants.Terrain.rockLevel   { return SCNVector3(0.55, 0.43, 0.33) }
            if height < Constants.Terrain.snowLevel   { return SCNVector3(0.45, 0.35, 0.28) }
            return SCNVector3(0.95, 0.95, 0.97)

        case .space:
            if height < Constants.Terrain.waterLevel  { return SCNVector3(0.05, 0.02, 0.20) }
            if height < Constants.Terrain.sandLevel   { return SCNVector3(0.20, 0.10, 0.35) }
            if height < Constants.Terrain.grassLevel  { return SCNVector3(0.30, 0.15, 0.50) }
            if height < Constants.Terrain.rockLevel   { return SCNVector3(0.40, 0.20, 0.60) }
            if height < Constants.Terrain.snowLevel   { return SCNVector3(0.55, 0.35, 0.75) }
            return SCNVector3(0.80, 0.70, 1.00)

        case .ocean:
            if height < Constants.Terrain.waterLevel  { return SCNVector3(0.05, 0.20, 0.50) }
            if height < Constants.Terrain.sandLevel   { return SCNVector3(0.10, 0.40, 0.65) }
            if height < Constants.Terrain.grassLevel  { return SCNVector3(0.15, 0.60, 0.55) }
            if height < Constants.Terrain.rockLevel   { return SCNVector3(0.20, 0.65, 0.45) }
            if height < Constants.Terrain.snowLevel   { return SCNVector3(0.60, 0.85, 0.70) }
            return SCNVector3(0.90, 0.98, 0.95)
        }
    }

    // MARK: - Decorations

    private func addDecorations(to node: SCNNode, coord: ChunkCoord,
                                chunkSize: Float, offsetX: Float, offsetZ: Float) {
        switch theme {
        case .sky:   addSkyDecorations(to: node, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)
        case .space: addSpaceDecorations(to: node, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)
        case .ocean: addOceanDecorations(to: node, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)
        }
    }

    // MARK: Sky Decorations

    private func addSkyDecorations(to node: SCNNode, coord: ChunkCoord,
                                   chunkSize: Float, offsetX: Float, offsetZ: Float) {
        // White fluffy clouds
        for i in 0..<4 {
            let h = abs(coord.x * 7 + coord.z * 13 + i * 31 + seed)
            let cx = offsetX + Float(h % Int(chunkSize))
            let cz = offsetZ + Float((h * 17) % Int(chunkSize))
            let cy = Float(200 + h % 300)
            let cloud = makeFluffyCloud()
            cloud.position = SCNVector3(cx, cy, cz)
            // Gentle drift
            let drift = SCNAction.sequence([
                SCNAction.moveBy(x: 5, y: 0, z: 0, duration: 4),
                SCNAction.moveBy(x: -5, y: 0, z: 0, duration: 4)
            ])
            cloud.runAction(.repeatForever(drift))
            node.addChildNode(cloud)
        }

        // Rainbow arches
        if abs(coord.x + coord.z) % 4 == 0 {
            let rainbow = makeRainbow()
            rainbow.position = SCNVector3(offsetX + chunkSize / 2, 250, offsetZ + chunkSize / 2)
            node.addChildNode(rainbow)
        }

        // Trees
        for i in 0..<5 {
            let h = abs(coord.x * 11 + coord.z * 23 + i * 41 + seed)
            let tx = offsetX + Float(h % Int(chunkSize))
            let tz = offsetZ + Float((h * 19) % Int(chunkSize))
            let height = terrainHeight(x: tx, z: tz)
            if height > Constants.Terrain.sandLevel && height < Constants.Terrain.grassLevel {
                node.addChildNode(makeRoundTree(at: SCNVector3(tx, height, tz)))
            }
        }

        // Sky NPC birds
        for i in 0..<2 {
            let h = abs(coord.x * 3 + coord.z * 7 + i * 17 + seed)
            let bx = offsetX + Float(h % Int(chunkSize))
            let bz = offsetZ + Float((h * 11) % Int(chunkSize))
            let by = Float(300 + h % 200)
            let bird = makeBird(color: UIColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1))
            bird.position = SCNVector3(bx, by, bz)
            let flyPath = SCNAction.sequence([
                SCNAction.moveBy(x: 30, y: 5, z: 10, duration: 3),
                SCNAction.moveBy(x: -30, y: -5, z: -10, duration: 3)
            ])
            bird.runAction(.repeatForever(flyPath))
            node.addChildNode(bird)
        }

        // Hot air balloon NPC
        if abs(coord.x * 5 + coord.z * 9) % 6 == 0 {
            let h = abs(coord.x * 5 + coord.z * 9 + seed)
            let bx = offsetX + Float(h % Int(chunkSize))
            let bz = offsetZ + Float((h * 13) % Int(chunkSize))
            let balloon = makeHotAirBalloon()
            balloon.position = SCNVector3(bx, Float(350 + h % 150), bz)
            let bob = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 10, z: 0, duration: 3),
                SCNAction.moveBy(x: 0, y: -10, z: 0, duration: 3)
            ])
            balloon.runAction(.repeatForever(bob))
            node.addChildNode(balloon)
        }

        // Butterflies
        for i in 0..<3 {
            let h = abs(coord.x * 19 + coord.z * 23 + i * 7 + seed)
            let bx = offsetX + Float(h % Int(chunkSize))
            let bz = offsetZ + Float((h * 5) % Int(chunkSize))
            let bf = makeButterfly()
            bf.position = SCNVector3(bx, Float(150 + h % 100), bz)
            let flutter = SCNAction.sequence([
                SCNAction.moveBy(x: 8, y: 3, z: 5, duration: 2),
                SCNAction.moveBy(x: -8, y: -3, z: -5, duration: 2)
            ])
            bf.runAction(.repeatForever(flutter))
            node.addChildNode(bf)
        }
    }

    // MARK: Space Decorations

    private func addSpaceDecorations(to node: SCNNode, coord: ChunkCoord,
                                     chunkSize: Float, offsetX: Float, offsetZ: Float) {
        // Star field
        for i in 0..<12 {
            let h = abs(coord.x * 7 + coord.z * 11 + i * 29 + seed)
            let sx = offsetX + Float(h % Int(chunkSize))
            let sz = offsetZ + Float((h * 13) % Int(chunkSize))
            let sy = Float(100 + h % 600)
            let star = makeSpaceStar()
            star.position = SCNVector3(sx, sy, sz)
            let twinkle = SCNAction.sequence([
                SCNAction.fadeAlpha(to: 0.3, duration: Double(h % 2) + 0.5),
                SCNAction.fadeAlpha(to: 1.0, duration: Double(h % 2) + 0.5)
            ])
            star.runAction(.repeatForever(twinkle))
            node.addChildNode(star)
        }

        // Planets
        if abs(coord.x + coord.z * 3) % 5 == 0 {
            let h = abs(coord.x * 3 + coord.z * 7 + seed)
            let px = offsetX + chunkSize / 2
            let pz = offsetZ + chunkSize / 2
            let py = Float(400 + h % 200)
            let planet = makePlanet(seed: h)
            planet.position = SCNVector3(px, py, pz)
            planet.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 20)))
            node.addChildNode(planet)
        }

        // Asteroids
        for i in 0..<3 {
            let h = abs(coord.x * 17 + coord.z * 5 + i * 43 + seed)
            let ax = offsetX + Float(h % Int(chunkSize))
            let az = offsetZ + Float((h * 7) % Int(chunkSize))
            let ay = Float(200 + h % 400)
            let asteroid = makeAsteroid()
            asteroid.position = SCNVector3(ax, ay, az)
            asteroid.runAction(.repeatForever(.rotateBy(x: 1, y: 1, z: 0.5, duration: 4)))
            node.addChildNode(asteroid)
        }

        // Alien NPC
        if abs(coord.x * 7 + coord.z) % 4 == 0 {
            let h = abs(coord.x * 7 + coord.z + seed)
            let alien = makeAlien()
            alien.position = SCNVector3(
                offsetX + Float(h % Int(chunkSize)),
                Float(300 + h % 200),
                offsetZ + Float((h * 3) % Int(chunkSize))
            )
            let hover = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 15, z: 0, duration: 2),
                SCNAction.moveBy(x: 0, y: -15, z: 0, duration: 2)
            ])
            alien.runAction(.repeatForever(hover))
            node.addChildNode(alien)
        }

        // UFO NPC
        if abs(coord.x + coord.z * 5) % 7 == 0 {
            let h = abs(coord.x + coord.z * 5 + seed)
            let ufo = makeUFO()
            ufo.position = SCNVector3(
                offsetX + chunkSize / 3,
                Float(450 + h % 100),
                offsetZ + chunkSize / 3
            )
            let ufoPath = SCNAction.sequence([
                SCNAction.moveBy(x: 40, y: 10, z: 0, duration: 3),
                SCNAction.moveBy(x: -40, y: -10, z: 0, duration: 3)
            ])
            ufo.runAction(.repeatForever(ufoPath))
            node.addChildNode(ufo)
        }

        // Shooting comet
        for i in 0..<2 {
            let h = abs(coord.x * 23 + coord.z * 11 + i * 37 + seed)
            let comet = makeComet()
            comet.position = SCNVector3(
                offsetX + Float(h % Int(chunkSize)),
                Float(500 + h % 200),
                offsetZ + Float((h * 9) % Int(chunkSize))
            )
            let shoot = SCNAction.sequence([
                SCNAction.moveBy(x: 80, y: -30, z: 30, duration: 2),
                SCNAction.moveBy(x: -80, y: 30, z: -30, duration: 2)
            ])
            comet.runAction(.repeatForever(shoot))
            node.addChildNode(comet)
        }
    }

    // MARK: Ocean Decorations

    private func addOceanDecorations(to node: SCNNode, coord: ChunkCoord,
                                     chunkSize: Float, offsetX: Float, offsetZ: Float) {
        // Bubbles rising
        for i in 0..<8 {
            let h = abs(coord.x * 5 + coord.z * 9 + i * 13 + seed)
            let bx = offsetX + Float(h % Int(chunkSize))
            let bz = offsetZ + Float((h * 7) % Int(chunkSize))
            let by = Float(100 + h % 300)
            let bubble = makeBubble()
            bubble.position = SCNVector3(bx, by, bz)
            let rise = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 60, z: 0, duration: 3),
                SCNAction.fadeOut(duration: 0.3),
                SCNAction.move(to: SCNVector3(bx, by, bz), duration: 0),
                SCNAction.fadeIn(duration: 0.1)
            ])
            bubble.runAction(.repeatForever(rise))
            node.addChildNode(bubble)
        }

        // Coral clusters
        for i in 0..<4 {
            let h = abs(coord.x * 11 + coord.z * 7 + i * 19 + seed)
            let cx = offsetX + Float(h % Int(chunkSize))
            let cz = offsetZ + Float((h * 11) % Int(chunkSize))
            let height = terrainHeight(x: cx, z: cz)
            let coral = makeCoral(seed: h)
            coral.position = SCNVector3(cx, height, cz)
            node.addChildNode(coral)
        }

        // Jellyfish NPCs
        for i in 0..<3 {
            let h = abs(coord.x * 13 + coord.z * 17 + i * 23 + seed)
            let jx = offsetX + Float(h % Int(chunkSize))
            let jz = offsetZ + Float((h * 5) % Int(chunkSize))
            let jy = Float(200 + h % 250)
            let jelly = makeJellyfish(seed: h)
            jelly.position = SCNVector3(jx, jy, jz)
            let pulse = SCNAction.sequence([
                SCNAction.scale(to: 1.15, duration: 0.8),
                SCNAction.scale(to: 0.90, duration: 0.8),
                SCNAction.moveBy(x: 5, y: 8, z: 3, duration: 1.5),
                SCNAction.moveBy(x: -5, y: -8, z: -3, duration: 1.5)
            ])
            jelly.runAction(.repeatForever(pulse))
            node.addChildNode(jelly)
        }

        // Fish school NPC
        if abs(coord.x + coord.z * 3) % 3 == 0 {
            let h = abs(coord.x + coord.z * 3 + seed)
            let school = makeFishSchool(seed: h)
            school.position = SCNVector3(
                offsetX + chunkSize / 2,
                Float(280 + h % 150),
                offsetZ + chunkSize / 2
            )
            let swim = SCNAction.sequence([
                SCNAction.moveBy(x: 50, y: 5, z: 10, duration: 4),
                SCNAction.moveBy(x: -50, y: -5, z: -10, duration: 4)
            ])
            school.runAction(.repeatForever(swim))
            node.addChildNode(school)
        }

        // Whale NPC (rare, big)
        if abs(coord.x * 3 + coord.z * 7) % 9 == 0 {
            let h = abs(coord.x * 3 + coord.z * 7 + seed)
            let whale = makeWhale()
            whale.position = SCNVector3(
                offsetX + chunkSize / 2,
                Float(350 + h % 100),
                offsetZ + chunkSize / 2
            )
            let swim = SCNAction.sequence([
                SCNAction.moveBy(x: 80, y: 20, z: 0, duration: 8),
                SCNAction.moveBy(x: -80, y: -20, z: 0, duration: 8)
            ])
            whale.runAction(.repeatForever(swim))
            node.addChildNode(whale)
        }

        // Sea turtle NPC
        if abs(coord.x * 5 + coord.z) % 5 == 0 {
            let h = abs(coord.x * 5 + coord.z + seed)
            let turtle = makeSeaTurtle()
            turtle.position = SCNVector3(
                offsetX + Float(h % Int(chunkSize)),
                Float(250 + h % 100),
                offsetZ + Float((h * 3) % Int(chunkSize))
            )
            turtle.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 12)))
            node.addChildNode(turtle)
        }
    }

    // MARK: - Sky NPC Builders

    private func makeFluffyCloud() -> SCNNode {
        let node = SCNNode()
        let configs: [(Float, Float, Float, Float)] = [
            (8, 0, 0, 0), (6, -5, 1, 2), (5, 4, -1, -2), (4, 2, 2, 3)
        ]
        for (r, ox, oy, oz) in configs {
            let sphere = SCNNode(geometry: SCNSphere(radius: CGFloat(r)))
            sphere.position = SCNVector3(ox, oy, oz)
            sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            sphere.geometry?.firstMaterial?.transparency = 0.15
            node.addChildNode(sphere)
        }
        return node
    }

    private func makeRainbow() -> SCNNode {
        let node = SCNNode()
        let colors: [UIColor] = [
            UIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            UIColor(red: 1, green: 0.5, blue: 0, alpha: 0.5),
            UIColor(red: 1, green: 1, blue: 0, alpha: 0.5),
            UIColor(red: 0, green: 0.8, blue: 0, alpha: 0.5),
            UIColor(red: 0, green: 0, blue: 1, alpha: 0.5),
            UIColor(red: 0.5, green: 0, blue: 1, alpha: 0.5)
        ]
        for (i, color) in colors.enumerated() {
            let radius = CGFloat(30 + i * 5)
            let torus = SCNTorus(ringRadius: radius, pipeRadius: 1.5)
            let arcNode = SCNNode(geometry: torus)
            arcNode.geometry?.firstMaterial?.diffuse.contents = color
            arcNode.eulerAngles.x = .pi / 2
            node.addChildNode(arcNode)
        }
        return node
    }

    private func makeRoundTree(at position: SCNVector3) -> SCNNode {
        let node = SCNNode()
        node.position = position
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.5, height: 5))
        trunk.position = SCNVector3(0, 2.5, 0)
        trunk.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
        node.addChildNode(trunk)
        let foliage = SCNNode(geometry: SCNSphere(radius: 3.5))
        foliage.position = SCNVector3(0, 7, 0)
        foliage.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.2, green: 0.75, blue: 0.3, alpha: 1)
        node.addChildNode(foliage)
        return node
    }

    private func makeBird(color: UIColor) -> SCNNode {
        let node = SCNNode()
        let body = SCNNode(geometry: SCNSphere(radius: 1.2))
        body.geometry?.firstMaterial?.diffuse.contents = color
        node.addChildNode(body)
        // Wings
        for sign: Float in [-1, 1] {
            let wing = SCNNode(geometry: SCNBox(width: 3, height: 0.2, length: 1.5, chamferRadius: 0.3))
            wing.position = SCNVector3(sign * 2, 0, 0)
            wing.geometry?.firstMaterial?.diffuse.contents = color
            node.addChildNode(wing)
        }
        let flap = SCNAction.sequence([
            SCNAction.rotateBy(x: 0.3, y: 0, z: 0, duration: 0.3),
            SCNAction.rotateBy(x: -0.3, y: 0, z: 0, duration: 0.3)
        ])
        node.runAction(.repeatForever(flap))
        return node
    }

    private func makeHotAirBalloon() -> SCNNode {
        let node = SCNNode()
        // Balloon envelope
        let balloon = SCNNode(geometry: SCNSphere(radius: 10))
        balloon.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 1.0, green: 0.4, blue: 0.5, alpha: 1)
        balloon.position = SCNVector3(0, 10, 0)
        node.addChildNode(balloon)
        // Stripes
        let stripe = SCNNode(geometry: SCNSphere(radius: 10.1))
        stripe.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 1.0, green: 1.0, blue: 0.3, alpha: 0.6)
        stripe.position = SCNVector3(0, 10, 0)
        node.addChildNode(stripe)
        // Basket
        let basket = SCNNode(geometry: SCNBox(width: 5, height: 3, length: 5, chamferRadius: 0.5))
        basket.position = SCNVector3(0, -2, 0)
        basket.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.7, green: 0.5, blue: 0.2, alpha: 1)
        node.addChildNode(basket)
        return node
    }

    private func makeButterfly() -> SCNNode {
        let node = SCNNode()
        let colors: [UIColor] = [
            UIColor(red: 1, green: 0.5, blue: 0.8, alpha: 0.9),
            UIColor(red: 0.5, green: 0.8, blue: 1, alpha: 0.9),
            UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.9)
        ]
        let color = colors[abs(seed) % colors.count]
        for sign: Float in [-1, 1] {
            let wing = SCNNode(geometry: SCNBox(width: 2.5, height: 0.1, length: 2, chamferRadius: 0.8))
            wing.position = SCNVector3(sign * 1.5, 0, 0)
            wing.geometry?.firstMaterial?.diffuse.contents = color
            wing.geometry?.firstMaterial?.transparency = 0.2
            node.addChildNode(wing)
        }
        return node
    }

    // MARK: - Space NPC Builders

    private func makeSpaceStar() -> SCNNode {
        let node = SCNNode()
        let sphere = SCNNode(geometry: SCNSphere(radius: 0.8))
        sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        sphere.geometry?.firstMaterial?.emission.contents = UIColor.white
        node.addChildNode(sphere)
        return node
    }

    private func makePlanet(seed: Int) -> SCNNode {
        let node = SCNNode()
        let planetColors: [UIColor] = [
            UIColor(red: 0.9, green: 0.5, blue: 0.3, alpha: 1),  // Mars-like
            UIColor(red: 0.6, green: 0.8, blue: 0.4, alpha: 1),  // Alien green
            UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1),  // Ice blue
            UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1),  // Saturn-like
        ]
        let color = planetColors[abs(seed) % planetColors.count]
        let radius = CGFloat(12 + seed % 8)
        let body = SCNNode(geometry: SCNSphere(radius: radius))
        body.geometry?.firstMaterial?.diffuse.contents = color
        node.addChildNode(body)
        // Ring (for some planets)
        if seed % 2 == 0 {
            let ring = SCNTorus(ringRadius: radius * 1.6, pipeRadius: 1.5)
            let ringNode = SCNNode(geometry: ring)
            ringNode.eulerAngles.x = .pi / 4
            ringNode.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 0.6)
            node.addChildNode(ringNode)
        }
        return node
    }

    private func makeAsteroid() -> SCNNode {
        let node = SCNNode()
        let geo = SCNSphere(radius: CGFloat(Float.random(in: 2...5)))
        let rock = SCNNode(geometry: geo)
        rock.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.5, green: 0.45, blue: 0.4, alpha: 1)
        node.addChildNode(rock)
        return node
    }

    private func makeAlien() -> SCNNode {
        let node = SCNNode()
        // Head (big)
        let head = SCNNode(geometry: SCNSphere(radius: 3))
        head.position = SCNVector3(0, 5, 0)
        head.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1)
        node.addChildNode(head)
        // Eyes
        for sign: Float in [-1.2, 1.2] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.7))
            eye.position = SCNVector3(sign, 6, 2.5)
            eye.geometry?.firstMaterial?.diffuse.contents = UIColor.black
            eye.geometry?.firstMaterial?.emission.contents = UIColor.purple
            node.addChildNode(eye)
        }
        // Body
        let body = SCNNode(geometry: SCNCylinder(radius: 1.5, height: 4))
        body.position = SCNVector3(0, 1, 0)
        body.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1)
        node.addChildNode(body)
        return node
    }

    private func makeUFO() -> SCNNode {
        let node = SCNNode()
        // Saucer body
        let disc = SCNNode(geometry: SCNSphere(radius: 8))
        disc.scale = SCNVector3(1, 0.3, 1)
        disc.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.8, green: 0.8, blue: 0.9, alpha: 1)
        node.addChildNode(disc)
        // Dome
        let dome = SCNNode(geometry: SCNSphere(radius: 4))
        dome.position = SCNVector3(0, 2, 0)
        dome.scale = SCNVector3(1, 0.6, 1)
        dome.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.6, green: 0.9, blue: 1.0, alpha: 0.6)
        dome.geometry?.firstMaterial?.transparency = 0.3
        node.addChildNode(dome)
        // Lights
        for i in 0..<5 {
            let angle = Float(i) / 5.0 * .pi * 2
            let light = SCNNode(geometry: SCNSphere(radius: 0.8))
            light.position = SCNVector3(cos(angle) * 7, -1, sin(angle) * 7)
            light.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            light.geometry?.firstMaterial?.emission.contents = UIColor.yellow
            node.addChildNode(light)
        }
        node.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 5)))
        return node
    }

    private func makeComet() -> SCNNode {
        let node = SCNNode()
        let head = SCNNode(geometry: SCNSphere(radius: 2))
        head.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1)
        head.geometry?.firstMaterial?.emission.contents =
            UIColor(red: 1, green: 0.7, blue: 0.2, alpha: 1)
        node.addChildNode(head)
        // Tail segments
        for i in 1...4 {
            let tail = SCNNode(geometry: SCNSphere(radius: CGFloat(2 - Float(i) * 0.3)))
            tail.position = SCNVector3(Float(i) * 2.5, 0, 0)
            tail.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 1, green: 0.7, blue: 0.2, alpha: Float(1) - Float(i) * 0.2)
            node.addChildNode(tail)
        }
        return node
    }

    // MARK: - Ocean NPC Builders

    private func makeBubble() -> SCNNode {
        let node = SCNNode()
        let size = Float.random(in: 1.5...4)
        let sphere = SCNNode(geometry: SCNSphere(radius: CGFloat(size)))
        sphere.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.3)
        sphere.geometry?.firstMaterial?.transparency = 0.6
        sphere.geometry?.firstMaterial?.isDoubleSided = true
        node.addChildNode(sphere)
        return node
    }

    private func makeCoral(seed: Int) -> SCNNode {
        let node = SCNNode()
        let coralColors: [UIColor] = [
            UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1),
            UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1),
            UIColor(red: 0.9, green: 0.3, blue: 0.6, alpha: 1),
            UIColor(red: 0.5, green: 0.8, blue: 0.9, alpha: 1)
        ]
        let color = coralColors[abs(seed) % coralColors.count]
        let branchCount = 3 + seed % 3
        for i in 0..<branchCount {
            let angle = Float(i) / Float(branchCount) * .pi * 2
            let branch = SCNNode(geometry: SCNCylinder(radius: 0.4, height: CGFloat(4 + seed % 3)))
            branch.position = SCNVector3(cos(angle) * 1.5, 2, sin(angle) * 1.5)
            branch.eulerAngles = SCNVector3(cos(angle) * 0.3, 0, sin(angle) * 0.3)
            branch.geometry?.firstMaterial?.diffuse.contents = color
            node.addChildNode(branch)
            // Tip bulb
            let tip = SCNNode(geometry: SCNSphere(radius: 0.8))
            tip.position = SCNVector3(cos(angle) * 1.5, CGFloat(4 + seed % 3) + 2, sin(angle) * 1.5)
            tip.geometry?.firstMaterial?.diffuse.contents = color
            node.addChildNode(tip)
        }
        return node
    }

    private func makeJellyfish(seed: Int) -> SCNNode {
        let node = SCNNode()
        let jellyColors: [UIColor] = [
            UIColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 0.7),
            UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.7),
            UIColor(red: 0.8, green: 0.5, blue: 1.0, alpha: 0.7)
        ]
        let color = jellyColors[abs(seed) % jellyColors.count]
        // Bell
        let bell = SCNNode(geometry: SCNSphere(radius: 5))
        bell.scale = SCNVector3(1, 0.6, 1)
        bell.geometry?.firstMaterial?.diffuse.contents = color
        bell.geometry?.firstMaterial?.transparency = 0.3
        node.addChildNode(bell)
        // Tentacles
        for i in 0..<6 {
            let angle = Float(i) / 6 * .pi * 2
            let tentacle = SCNNode(geometry: SCNCylinder(radius: 0.3, height: CGFloat(6 + seed % 4)))
            tentacle.position = SCNVector3(cos(angle) * 3, -5, sin(angle) * 3)
            tentacle.geometry?.firstMaterial?.diffuse.contents = color
            node.addChildNode(tentacle)
        }
        return node
    }

    private func makeFishSchool(seed: Int) -> SCNNode {
        let node = SCNNode()
        let fishColors: [UIColor] = [
            UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1),
            UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1),
            UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1)
        ]
        for i in 0..<8 {
            let h = abs(seed + i * 7)
            let fish = SCNNode()
            let body = SCNNode(geometry: SCNSphere(radius: 1.2))
            body.scale = SCNVector3(1.5, 1, 1)
            body.geometry?.firstMaterial?.diffuse.contents = fishColors[h % fishColors.count]
            fish.addChildNode(body)
            let tail = SCNNode(geometry: SCNBox(width: 1.5, height: 1.2, length: 0.3, chamferRadius: 0.1))
            tail.position = SCNVector3(-1.5, 0, 0)
            tail.geometry?.firstMaterial?.diffuse.contents = fishColors[h % fishColors.count]
            fish.addChildNode(tail)
            fish.position = SCNVector3(
                Float(h % 20) - 10,
                Float((h * 3) % 10) - 5,
                Float((h * 7) % 20) - 10
            )
            node.addChildNode(fish)
        }
        return node
    }

    private func makeWhale() -> SCNNode {
        let node = SCNNode()
        // Body
        let body = SCNNode(geometry: SCNSphere(radius: 12))
        body.scale = SCNVector3(2.5, 1, 1)
        body.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.2, green: 0.3, blue: 0.7, alpha: 1)
        node.addChildNode(body)
        // Belly
        let belly = SCNNode(geometry: SCNSphere(radius: 9))
        belly.scale = SCNVector3(2.0, 0.7, 0.9)
        belly.position = SCNVector3(0, -3, 0)
        belly.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.85, green: 0.87, blue: 0.90, alpha: 1)
        node.addChildNode(belly)
        // Tail
        let tail = SCNNode(geometry: SCNBox(width: 10, height: 5, length: 2, chamferRadius: 1))
        tail.position = SCNVector3(-22, 0, 0)
        tail.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.2, green: 0.3, blue: 0.7, alpha: 1)
        node.addChildNode(tail)
        // Fin
        let fin = SCNNode(geometry: SCNBox(width: 5, height: 8, length: 1, chamferRadius: 1))
        fin.position = SCNVector3(0, 10, 0)
        fin.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.2, green: 0.3, blue: 0.7, alpha: 1)
        node.addChildNode(fin)
        // Spout (water vapor)
        let spout = SCNNode(geometry: SCNCylinder(radius: 1, height: 8))
        spout.position = SCNVector3(18, 12, 0)
        spout.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 0.5)
        node.addChildNode(spout)
        return node
    }

    private func makeSeaTurtle() -> SCNNode {
        let node = SCNNode()
        let shell = SCNNode(geometry: SCNSphere(radius: 4))
        shell.scale = SCNVector3(1, 0.5, 1)
        shell.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.2, green: 0.55, blue: 0.35, alpha: 1)
        node.addChildNode(shell)
        let head = SCNNode(geometry: SCNSphere(radius: 1.5))
        head.position = SCNVector3(4.5, 0, 0)
        head.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.25, green: 0.5, blue: 0.3, alpha: 1)
        node.addChildNode(head)
        for (dx, dz): (Float, Float) in [(2, 3), (2, -3), (-2, 3), (-2, -3)] {
            let flipper = SCNNode(geometry: SCNBox(width: 3, height: 0.4, length: 1.5, chamferRadius: 0.5))
            flipper.position = SCNVector3(dx, 0, dz)
            flipper.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.25, green: 0.5, blue: 0.3, alpha: 1)
            node.addChildNode(flipper)
        }
        return node
    }
}
