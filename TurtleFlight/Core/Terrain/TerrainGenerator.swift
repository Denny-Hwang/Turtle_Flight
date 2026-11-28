import Foundation
import SceneKit

final class TerrainGenerator {
    // MARK: - Chunk Management
    struct ChunkCoord: Hashable {
        let x: Int
        let z: Int
    }

    private var loadedChunks: [ChunkCoord: SCNNode] = [:]
    private var farNode: SCNNode?
    private var farCentre: SIMD2<Float>?
    /// Sea-level water plane (worlds with water only).
    private(set) var water: WaterSurface?
    private var waterClock: Float = 0
    private let parentNode: SCNNode
    let seed: Int
    private(set) var theme: MapTheme
    let profile: WorldProfile

    init(parentNode: SCNNode, seed: Int = 42, theme: MapTheme = .sky) {
        self.parentNode = parentNode
        self.seed = seed
        self.theme = theme
        self.profile = WorldProfile.profile(for: theme)
        if WaterSurface.hasWater(theme) {
            let surface = WaterSurface(world: theme, profile: profile)
            parentNode.addChildNode(surface.node)
            water = surface
        }
    }

    /// Per-frame: keep the water under the player and its ripples moving.
    func updateWater(playerPosition: SCNVector3, deltaTime: Float) {
        guard let water else { return }
        waterClock += deltaTime
        water.update(playerPosition: playerPosition, time: waterClock)
    }

    /// Node name given to friendly creatures and craft (balloons,
    /// whales, UFOs, camels, …). Flying close to one says hello — see
    /// `FlightViewModel.checkFriendlyFlyBys`.
    static let friendName = "friend"

    /// Friends in the currently loaded chunks that have not been greeted.
    func ungreetedFriends() -> [SCNNode] {
        loadedChunks.values.flatMap { $0.childNodes.filter { $0.name == Self.friendName } }
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
            if let node = loadedChunks[coord] {
                stopAllActionsRecursively(in: node)
                node.removeFromParentNode()
            }
            loadedChunks.removeValue(forKey: coord)
        }

        for coord in neededChunks where loadedChunks[coord] == nil {
            let chunkNode = PerfProbe.shared.measure(.chunk) { generateChunk(coord: coord) }
            parentNode.addChildNode(chunkNode)
            loadedChunks[coord] = chunkNode
        }
        updateFarTerrain(playerPosition: playerPosition)
    }

    // MARK: - Far terrain
    //
    // The detailed chunks only reach ~300 units, which was fine while
    // nothing stood on the horizon. Landmarks are visible from a cell
    // away, so they need ground under them: one coarse mesh
    // (`farCells`² quads of `farCellSize`) centred on the player and
    // rebuilt when they move a few cells. ~3k triangles, no decorations.

    static let farCellSize: Float = 100
    static let farCells = 44
    /// Rebuild when the player is this far from the mesh centre.
    static let farSnap: Float = 400

    private func updateFarTerrain(playerPosition: SCNVector3) {
        let snap = Self.farSnap
        let cx = (playerPosition.x / snap).rounded() * snap
        let cz = (playerPosition.z / snap).rounded() * snap
        if let centre = farCentre, centre.x == cx, centre.y == cz { return }
        farCentre = SIMD2<Float>(cx, cz)
        PerfProbe.shared.measure(.farTerrain) { rebuildFarTerrain(cx: cx, cz: cz) }
    }

    private func rebuildFarTerrain(cx: Float, cz: Float) {
        farNode?.removeFromParentNode()

        let n = Self.farCells
        let size = Self.farCellSize
        let half = Float(n) * size / 2
        var vertices: [SCNVector3] = []
        var colors: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []
        vertices.reserveCapacity((n + 1) * (n + 1))
        for row in 0...n {
            for col in 0...n {
                let x = cx - half + Float(col) * size
                let z = cz - half + Float(row) * size
                let h = terrainHeight(x: x, z: z)
                // Sits a little low so the detailed chunks always win.
                vertices.append(SCNVector3(x, h - 6, z))
                let n = Self.normal(left: terrainHeight(x: x - size, z: z), right: terrainHeight(x: x + size, z: z),
                                    back: terrainHeight(x: x, z: z - size), front: terrainHeight(x: x, z: z + size),
                                    spacing: size)
                normals.append(n)
                colors.append(profile.renderColor(height: h, slope: 1 - n.y, variation: colorVariation(x: x, z: z)))
            }
        }
        for row in 0..<n {
            for col in 0..<n {
                let tl = Int32(row * (n + 1) + col)
                let tr = tl + 1
                let bl = Int32((row + 1) * (n + 1) + col)
                let br = bl + 1
                indices.append(contentsOf: [tl, bl, tr, tr, bl, br])
            }
        }
        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector3>.size)
        let colorSource = SCNGeometrySource(
            data: colorData, semantic: .color,
            vectorCount: colors.count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<SCNVector3>.size
        )
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals), colorSource],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        geometry.materials = [Self.terrainMaterial()]
        let node = SCNNode(geometry: geometry)
        node.name = "far_terrain"
        parentNode.addChildNode(node)
        farNode = node
    }

    func clearAllChunks() {
        for (_, node) in loadedChunks {
            stopAllActionsRecursively(in: node)
            node.removeFromParentNode()
        }
        loadedChunks.removeAll()
        farNode?.removeFromParentNode()
        farNode = nil
        farCentre = nil
        water?.node.removeFromParentNode()
        water = nil
    }

    /// Recursively `removeAllActions()` for a node and its descendants.
    /// Required because the 3×3 visible-chunk window swaps chunks every
    /// time the player crosses a chunk boundary, and every decoration
    /// (clouds, birds, balloons, planets, UFOs, fish schools, …) is
    /// attached with `.runAction(.repeatForever(...))`. Without this
    /// sweep, an evicted chunk's actions stayed alive on the orphaned
    /// nodes until ARC finally claimed them — a slow, undetectable
    /// retain accumulation on long sessions. `removeFromParentNode()`
    /// alone does NOT cancel actions.
    private func stopAllActionsRecursively(in node: SCNNode) {
        node.removeAllActions()
        for child in node.childNodes {
            stopAllActionsRecursively(in: child)
        }
    }

    /// World-space terrain height under the (x, z) world coordinate. Used by
    /// the flight loop to decide ground-clearance — when `playerY - heightAt
    /// (...) < threshold`, a collision is registered (FlightViewModel).
    /// Public so the gameplay layer can query without copy-pasting the
    /// fractal-noise sampling. The value is deterministic for a given
    /// `seed` so tests can pin it.
    func heightAt(x: Float, z: Float) -> Float {
        terrainHeight(x: x, z: z)
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
        vertices.reserveCapacity((resolution + 1) * (resolution + 1))

        // Heights on the grid plus a one-cell border, so normals at the
        // chunk edge use the same neighbours as the next chunk (no seams).
        let side = resolution + 3
        var heights = [Float](repeating: 0, count: side * side)
        for row in 0..<side {
            for col in 0..<side {
                heights[row * side + col] = terrainHeight(x: Float(col - 1) * cellSize + offsetX,
                                                          z: Float(row - 1) * cellSize + offsetZ)
            }
        }
        for row in 0...resolution {
            for col in 0...resolution {
                let x = Float(col) * cellSize + offsetX
                let z = Float(row) * cellSize + offsetZ
                let i = (row + 1) * side + (col + 1)
                let height = heights[i]
                let normal = Self.normal(left: heights[i - 1], right: heights[i + 1],
                                         back: heights[i - side], front: heights[i + side], spacing: cellSize)
                vertices.append(SCNVector3(x, height, z))
                normals.append(normal)
                colors.append(profile.renderColor(height: height, slope: 1 - normal.y,
                                                  variation: colorVariation(x: x, z: z)))
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

        addDecorations(to: chunkNode, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)

        // V8: static ground props and meadow speckles join the terrain
        // mesh — one draw call for the whole chunk's ground.
        var mesh = PropMesh(positions: vertices, normals: normals, colors: colors, indices: indices)
        bakeStaticProps(of: chunkNode, into: &mesh)
        let ground = ChunkGround(heights: heights, side: side, cellSize: cellSize, offsetX: offsetX, offsetZ: offsetZ)
        addMeadowSpeckles(into: &mesh, coord: coord, ground: ground)

        let element = SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: mesh.sources(), elements: [element])
        geometry.materials = [Self.terrainMaterial()]
        chunkNode.geometry = geometry
        return chunkNode
    }

    // MARK: - V8 decor baking

    /// Node name for props that never move: they are baked into the
    /// chunk mesh instead of staying separate nodes.
    static let staticPropName = "staticProp"

    /// Move every `staticPropName` child of `chunk` into `mesh`.
    func bakeStaticProps(of chunk: SCNNode, into mesh: inout PropMesh) {
        for prop in chunk.childNodes where prop.name == Self.staticPropName {
            mesh.bake(prop)
            prop.removeFromParentNode()
        }
    }

    /// The chunk's own height grid (one-cell border included), sampled
    /// on the drawn triangles so speckles sit exactly on the mesh — and
    /// without paying for more fractal noise.
    struct ChunkGround {
        let heights: [Float]
        let side: Int
        let cellSize: Float
        let offsetX: Float
        let offsetZ: Float

        func height(x: Float, z: Float) -> Float {
            let gx = (x - offsetX) / cellSize + 1, gz = (z - offsetZ) / cellSize + 1
            let col = max(0, min(side - 2, Int(gx))), row = max(0, min(side - 2, Int(gz)))
            let fx = gx - Float(col), fz = gz - Float(row)
            let tl = heights[row * side + col], tr = heights[row * side + col + 1]
            let bl = heights[(row + 1) * side + col], br = heights[(row + 1) * side + col + 1]
            // Same split as the index buffer: (tl, bl, tr) and (tr, bl, br).
            if fx + fz <= 1 { return tl + fx * (tr - tl) + fz * (bl - tl) }
            return br + (1 - fx) * (bl - br) + (1 - fz) * (tr - br)
        }
    }

    /// Flower and grass-tuft speckles on gentle meadow ground, gathered
    /// in patches (a coarse noise mask) so they read as clumps rather
    /// than an even sprinkle. Deterministic per chunk.
    func addMeadowSpeckles(into mesh: inout PropMesh, coord: ChunkCoord, ground: ChunkGround) {
        guard let style = DecorVariety.speckleStyle(for: theme) else { return }
        let chunkSize = Constants.Terrain.chunkSize
        let (offsetX, offsetZ) = (ground.offsetX, ground.offsetZ)
        // Patch mask: noise on a 9×9 lattice, bilinear in between.
        let lattice = 8
        var mask = [Float](repeating: 0, count: (lattice + 1) * (lattice + 1))
        for r in 0...lattice {
            for c in 0...lattice {
                let x = offsetX + Float(c) / Float(lattice) * chunkSize
                let z = offsetZ + Float(r) / Float(lattice) * chunkSize
                mask[r * (lattice + 1) + c] = MathHelpers.fractalNoise(x: x * 0.012 + 13, y: z * 0.012 - 7,
                                                                      octaves: 2, seed: seed &+ 101)
            }
        }
        func patch(_ u: Float, _ v: Float) -> Float {
            let gx = u * Float(lattice), gz = v * Float(lattice)
            let c = min(lattice - 1, Int(gx)), r = min(lattice - 1, Int(gz))
            let fx = gx - Float(c), fz = gz - Float(r)
            let a = mask[r * (lattice + 1) + c], b = mask[r * (lattice + 1) + c + 1]
            let d = mask[(r + 1) * (lattice + 1) + c], e = mask[(r + 1) * (lattice + 1) + c + 1]
            return (a * (1 - fx) + b * fx) * (1 - fz) + (d * (1 - fx) + e * fx) * fz
        }

        let base = coord.x &* 73_856_093 ^ coord.z &* 19_349_663 ^ seed
        let lift: Float = 0.45
        let step: Float = 2
        for i in 0..<style.candidates {
            let h = base &+ i &* 2_654_435
            let u = DecorVariety.unit(h, 11), v = DecorVariety.unit(h, 12)
            guard patch(u, v) > 0.42 + DecorVariety.unit(h, 13) * 0.2 else { continue }
            let x = offsetX + u * chunkSize, z = offsetZ + v * chunkSize
            let y = ground.height(x: x, z: z)
            guard style.heights.contains(y), theme == .ocean || y > 0.5 else { continue }
            // Local slope; skip steep ground.
            let dx = (ground.height(x: x + step, z: z) - ground.height(x: x - step, z: z)) / (2 * step)
            let dz = (ground.height(x: x, z: z + step) - ground.height(x: x, z: z - step)) / (2 * step)
            let n = simd_normalize(SIMD3<Float>(-dx, 1, -dz))
            guard n.y > 0.86 else { continue }

            let isFlower = DecorVariety.unit(h, 14) < style.flowerShare
            let palette = isFlower ? style.flowers : style.tufts
            let color = palette[Int(DecorVariety.unit(h, 15) * Float(palette.count)) % palette.count]
            let normal = SCNVector3(n.x, n.y, n.z)
            // A flat polygon lying on the ground plane through (x, y, z).
            func dot(_ cx: Float, _ cz: Float, radius: Float, sides: Int, ragged: Bool, salt: Int) {
                let squash = 0.65 + DecorVariety.unit(h, salt) * 0.35
                let turn = DecorVariety.unit(h, salt + 1) * .pi
                var ring: [SCNVector3] = []
                for k in 0..<sides {
                    let a = Float(k) / Float(sides) * 2 * .pi
                    let r = radius * (ragged ? 0.75 + 0.5 * DecorVariety.unit(h, salt + 2 + k) : 1)
                    let lx = cos(a) * r, lz = sin(a) * r * squash
                    let px = cx + lx * cos(turn) - lz * sin(turn), pz = cz + lx * sin(turn) + lz * cos(turn)
                    ring.append(SCNVector3(x + px, ground.height(x: x + px, z: z + pz) + lift, z + pz))
                }
                mesh.appendFan(centre: SCNVector3(x + cx, ground.height(x: x + cx, z: z + cz) + lift + 0.15, z + cz), ring: ring,
                               normal: normal, color: color)
            }
            if isFlower {
                // A little bunch: three dots of one colour.
                for k in 0..<3 {
                    let a = DecorVariety.unit(h, 30 + k) * 2 * .pi
                    let d: Float = k == 0 ? 0 : 1.6 + DecorVariety.unit(h, 33 + k) * 1.6
                    dot(cos(a) * d, sin(a) * d, radius: 0.9 + DecorVariety.unit(h, 36 + k) * 0.8,
                        sides: 5, ragged: false, salt: 40 + k * 3)
                }
            } else {
                dot(0, 0, radius: 1.8 + DecorVariety.unit(h, 16) * 2, sides: 7, ragged: true, salt: 50)
            }
        }
    }

    // MARK: - Shading (V1/V2, docs/VISUAL_AUDIO_PLAN.md)

    /// Surface normal from the four neighbouring heights (central
    /// differences). Until V1 every vertex used (0, 1, 0), so slopes had
    /// no light and dark side and the hills read flat.
    static func normal(left: Float, right: Float, back: Float, front: Float, spacing: Float) -> SCNVector3 {
        let nx = left - right
        let nz = back - front
        let ny = 2 * spacing
        let len = (nx * nx + ny * ny + nz * nz).squareRoot()
        return SCNVector3(nx / len, ny / len, nz / len)
    }

    /// Slow light/dark variation across the ground, in [-1, 1].
    func colorVariation(x: Float, z: Float) -> Float {
        MathHelpers.fractalNoise(x: x * 0.0035 + 91, y: z * 0.0035 - 37, octaves: 2, seed: seed &+ 7)
    }

    /// Matte, vertex-coloured ground. Lambert: grass and sand shouldn't
    /// have a specular hot spot.
    static func terrainMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.isDoubleSided = true
        return material
    }

    // MARK: - Height

    func terrainHeight(x: Float, z: Float) -> Float {
        let scale = profile.noiseScale
        let noise = MathHelpers.fractalNoise(
            x: x * scale, y: z * scale,
            octaves: 4, persistence: 0.5, lacunarity: 2.0, seed: seed
        )
        return profile.height(fromNoise: noise)
    }

    // MARK: - Decorations

    private func addDecorations(to node: SCNNode, coord: ChunkCoord,
                                chunkSize: Float, offsetX: Float, offsetZ: Float) {
        switch theme {
        case .sky:   addSkyDecorations(to: node, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)
        case .space: addSpaceDecorations(to: node, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)
        case .ocean: addOceanDecorations(to: node, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)
        case .desert, .city, .seoul, .wild:
            addWorldTourDecorations(to: node, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)
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
            let cloud = makeFluffyCloud(variant: DecorVariety.variant(h, count: 3))
            DecorVariety.vary(cloud, hash: h, scale: 0.8...1.6)
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
                let tree = makeRoundTree(at: SCNVector3(tx, height, tz), variant: DecorVariety.variant(h, count: 3))
                DecorVariety.vary(tree, hash: h, scale: 0.8...1.35)
                tree.name = Self.staticPropName
                node.addChildNode(tree)
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
            balloon.name = Self.friendName
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
                SCNAction.fadeOpacity(to: 0.3, duration: Double(h % 2) + 0.5),
                SCNAction.fadeOpacity(to: 1.0, duration: Double(h % 2) + 0.5)
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
            alien.name = Self.friendName
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
            ufo.name = Self.friendName
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
            DecorVariety.vary(coral, hash: h, scale: 0.8...1.4)
            coral.name = Self.staticPropName
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
            whale.name = Self.friendName
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
            turtle.name = Self.friendName
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

    /// Puff layouts `(radius, x, y, z, y-squash)`: the original round
    /// heap, a long flat bank, and a tall billowing stack (V8).
    static let cloudShapes: [[(Float, Float, Float, Float, Float)]] = [
        [(8, 0, 0, 0, 1), (6, -5, 1, 2, 1), (5, 4, -1, -2, 1), (4, 2, 2, 3, 1)],
        [(7, 0, 0, 0, 0.6), (6, -8, -0.5, 1, 0.6), (6, 8, 0, -1, 0.6), (4.5, -14, -1, 0, 0.6), (4.5, 13, -1, 1, 0.6)],
        [(7, 0, 0, 0, 1), (5.5, 1, 6, 0.5, 1), (4, -1, 10.5, -0.5, 1), (5, -5, -1, 1, 1), (4.5, 5, -1.5, -1, 1)]
    ]

    /// One merged mesh per cloud shape (one draw call per cloud instead of
    /// one per puff), built once and shared by every cloud. Never mutated
    /// after this initialiser (lazy `static let` is thread-safe), so
    /// sharing it between the render thread and main is safe.
    nonisolated(unsafe) static let cloudGeometries: [SCNGeometry] = {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.transparency = 0.15
        return cloudShapes.map { puffs in
            var mesh = PropMesh()
            mesh.roundSegments = 20   // big and soft: keep them round
            for (r, ox, oy, oz, squash) in puffs {
                let sphere = SCNNode(geometry: SCNSphere(radius: CGFloat(r)))
                sphere.position = SCNVector3(ox, oy, oz)
                sphere.scale = SCNVector3(1, squash, 1)
                mesh.bake(sphere)
            }
            return mesh.geometry(material: material)
        }
    }()

    func makeFluffyCloud(variant: Int = 0) -> SCNNode {
        SCNNode(geometry: Self.cloudGeometries[variant % Self.cloudGeometries.count])
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

    /// Meadow tree, three shapes (V8): round crown, a cluster of three
    /// puffs, or a tall oval crown.
    func makeRoundTree(at position: SCNVector3, variant: Int = 0) -> SCNNode {
        let node = SCNNode()
        node.position = position
        func part(_ g: SCNGeometry, _ c: UIColor, _ p: SCNVector3, scale: SCNVector3 = SCNVector3(1, 1, 1)) {
            let n = SCNNode(geometry: g)
            n.position = p
            n.scale = scale
            n.geometry?.firstMaterial?.diffuse.contents = c
            node.addChildNode(n)
        }
        let bark = UIColor.brown
        switch variant % 3 {
        case 1:
            part(SCNCylinder(radius: 0.5, height: 5), bark, SCNVector3(0, 2.5, 0))
            let leaf = UIColor(red: 0.36, green: 0.78, blue: 0.34, alpha: 1)
            part(SCNSphere(radius: 2.7), leaf, SCNVector3(0, 7.6, 0))
            part(SCNSphere(radius: 2.1), leaf, SCNVector3(1.9, 6.2, 0.6))
            part(SCNSphere(radius: 2.0), UIColor(red: 0.28, green: 0.70, blue: 0.30, alpha: 1), SCNVector3(-1.7, 6.3, -0.8))
        case 2:
            part(SCNCylinder(radius: 0.45, height: 6.5), bark, SCNVector3(0, 3.2, 0))
            part(SCNSphere(radius: 2.8), UIColor(red: 0.16, green: 0.58, blue: 0.30, alpha: 1), SCNVector3(0, 9, 0),
                 scale: SCNVector3(0.85, 1.5, 0.85))
        default:
            part(SCNCylinder(radius: 0.5, height: 5), bark, SCNVector3(0, 2.5, 0))
            part(SCNSphere(radius: 3.5), UIColor(red: 0.2, green: 0.75, blue: 0.3, alpha: 1), SCNVector3(0, 7, 0))
        }
        return node
    }

    func makeBird(color: UIColor) -> SCNNode {
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

    func makeHotAirBalloon() -> SCNNode {
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
                UIColor(red: 1, green: 0.7, blue: 0.2, alpha: CGFloat(1 - Float(i) * 0.2))
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
            let branchHeight = Float(4 + seed % 3)
            let branch = SCNNode(geometry: SCNCylinder(radius: 0.4, height: CGFloat(branchHeight)))
            branch.position = SCNVector3(cos(angle) * 1.5, 2, sin(angle) * 1.5)
            branch.eulerAngles = SCNVector3(cos(angle) * 0.3, 0, sin(angle) * 0.3)
            branch.geometry?.firstMaterial?.diffuse.contents = color
            node.addChildNode(branch)
            // Tip bulb
            let tip = SCNNode(geometry: SCNSphere(radius: 0.8))
            tip.position = SCNVector3(cos(angle) * 1.5, branchHeight + 2, sin(angle) * 1.5)
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
