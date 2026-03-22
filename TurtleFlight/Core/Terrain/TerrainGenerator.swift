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

    init(parentNode: SCNNode, seed: Int = 42) {
        self.parentNode = parentNode
        self.seed = seed
    }

    // MARK: - Public

    /// Update visible chunks based on player position
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

        // Unload chunks that are no longer visible
        let chunksToRemove = loadedChunks.keys.filter { !neededChunks.contains($0) }
        for coord in chunksToRemove {
            loadedChunks[coord]?.removeFromParentNode()
            loadedChunks.removeValue(forKey: coord)
        }

        // Load new chunks
        for coord in neededChunks where loadedChunks[coord] == nil {
            let chunkNode = generateChunk(coord: coord)
            parentNode.addChildNode(chunkNode)
            loadedChunks[coord] = chunkNode
        }
    }

    /// Remove all chunks
    func clearAllChunks() {
        for (_, node) in loadedChunks {
            node.removeFromParentNode()
        }
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

        // Generate height map and create geometry
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [SCNVector3] = []
        var indices: [Int32] = []

        for row in 0...resolution {
            for col in 0...resolution {
                let x = Float(col) * cellSize + offsetX
                let z = Float(row) * cellSize + offsetZ

                let height = terrainHeight(x: x, z: z)

                vertices.append(SCNVector3(x, height, z))
                normals.append(SCNVector3(0, 1, 0)) // Simplified normal
                colors.append(colorForHeight(height))
            }
        }

        // Build triangle indices
        for row in 0..<resolution {
            for col in 0..<resolution {
                let topLeft = Int32(row * (resolution + 1) + col)
                let topRight = topLeft + 1
                let bottomLeft = Int32((row + 1) * (resolution + 1) + col)
                let bottomRight = bottomLeft + 1

                indices.append(contentsOf: [topLeft, bottomLeft, topRight])
                indices.append(contentsOf: [topRight, bottomLeft, bottomRight])
            }
        }

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)

        // Color source
        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector3>.size)
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, normalSource, colorSource], elements: [element])

        let material = SCNMaterial()
        material.isDoubleSided = true
        geometry.materials = [material]

        chunkNode.geometry = geometry

        // Add decoration objects
        addDecorations(to: chunkNode, coord: coord, chunkSize: chunkSize, offsetX: offsetX, offsetZ: offsetZ)

        return chunkNode
    }

    // MARK: - Height Calculation

    private func terrainHeight(x: Float, z: Float) -> Float {
        let scale: Float = 0.005
        let noise = MathHelpers.fractalNoise(
            x: x * scale,
            y: z * scale,
            octaves: 4,
            persistence: 0.5,
            lacunarity: 2.0,
            seed: seed
        )
        return noise * Constants.Terrain.maxHeight
    }

    // MARK: - Color by Altitude

    private func colorForHeight(_ height: Float) -> SCNVector3 {
        if height < Constants.Terrain.waterLevel {
            return SCNVector3(0.33, 0.53, 0.87) // Water blue
        } else if height < Constants.Terrain.sandLevel {
            return SCNVector3(0.93, 0.87, 0.68) // Sand
        } else if height < Constants.Terrain.grassLevel {
            return SCNVector3(0.30, 0.69, 0.31) // Grass green
        } else if height < Constants.Terrain.rockLevel {
            return SCNVector3(0.55, 0.43, 0.33) // Rock brown
        } else if height < Constants.Terrain.snowLevel {
            return SCNVector3(0.45, 0.35, 0.28) // Dark rock
        } else {
            return SCNVector3(0.95, 0.95, 0.97) // Snow white
        }
    }

    // MARK: - Decorations

    private func addDecorations(to chunkNode: SCNNode, coord: ChunkCoord, chunkSize: Float, offsetX: Float, offsetZ: Float) {
        // Add clouds at high altitude
        let cloudCount = 3
        for i in 0..<cloudCount {
            let hash = abs(coord.x * 7 + coord.z * 13 + i * 31 + seed)
            let cx = offsetX + Float(hash % Int(chunkSize))
            let cz = offsetZ + Float((hash * 17) % Int(chunkSize))
            let cy = Float(200 + hash % 300)

            let cloud = createCloud()
            cloud.position = SCNVector3(cx, cy, cz)
            chunkNode.addChildNode(cloud)
        }

        // Add trees on grass-level terrain
        let treeCount = 5
        for i in 0..<treeCount {
            let hash = abs(coord.x * 11 + coord.z * 23 + i * 41 + seed)
            let tx = offsetX + Float(hash % Int(chunkSize))
            let tz = offsetZ + Float((hash * 19) % Int(chunkSize))
            let height = terrainHeight(x: tx, z: tz)

            if height > Constants.Terrain.sandLevel && height < Constants.Terrain.grassLevel {
                let tree = createTree()
                tree.position = SCNVector3(tx, height, tz)
                chunkNode.addChildNode(tree)
            }
        }
    }

    private func createCloud() -> SCNNode {
        let node = SCNNode()
        let sizes: [Float] = [8, 6, 5]
        let offsets: [(Float, Float)] = [(0, 0), (-5, 2), (4, -1)]

        for (i, size) in sizes.enumerated() {
            let sphere = SCNNode(geometry: SCNSphere(radius: CGFloat(size)))
            sphere.position = SCNVector3(offsets[i].0, 0, offsets[i].1)
            sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            sphere.geometry?.firstMaterial?.transparency = 0.7
            node.addChildNode(sphere)
        }
        return node
    }

    private func createTree() -> SCNNode {
        let node = SCNNode()

        // Trunk
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.5, height: 5))
        trunk.position = SCNVector3(0, 2.5, 0)
        trunk.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
        node.addChildNode(trunk)

        // Foliage
        let foliage = SCNNode(geometry: SCNSphere(radius: 3))
        foliage.position = SCNVector3(0, 6, 0)
        foliage.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1)
        node.addChildNode(foliage)

        return node
    }
}
