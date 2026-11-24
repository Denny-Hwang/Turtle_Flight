import XCTest
import SceneKit
@testable import TurtleFlight

/// V1–V8 of docs/VISUAL_AUDIO_PLAN.md.
final class VisualPassTests: XCTestCase {

    // V1
    func testTerrainNormalsLeanAwayFromTheSlope() {
        let flat = TerrainGenerator.normal(left: 10, right: 10, back: 10, front: 10, spacing: 3)
        XCTAssertEqual(flat.y, 1, accuracy: 0.0001)
        // Ground rising toward +x: the normal tips toward -x.
        let slope = TerrainGenerator.normal(left: 0, right: 12, back: 5, front: 5, spacing: 3)
        XCTAssertLessThan(slope.x, 0)
        XCTAssertLessThan(slope.y, 1)
        XCTAssertEqual(sqrt(slope.x * slope.x + slope.y * slope.y + slope.z * slope.z), 1, accuracy: 0.0001)
    }

    // V2
    func testRenderColorBlendsBandsAndTurnsSteepGroundToRock() {
        let p = WorldProfile.profile(for: .sky)
        // Far from any boundary on flat ground it is the ramp colour.
        let mid = p.renderColor(height: 50, slope: 0, variation: 0)
        let ramp = p.color(forHeight: 50)
        XCTAssertEqual(mid.x, ramp.x, accuracy: 0.001)
        // At a boundary it sits between the two colours.
        let edge = p.renderColor(height: Constants.Terrain.grassLevel, slope: 0, variation: 0)
        XCTAssertNotEqual(edge.y, p.color(forHeight: Constants.Terrain.grassLevel - 15).y, accuracy: 0.001)
        // A cliff is mostly rock.
        let cliff = p.renderColor(height: 50, slope: 0.9, variation: 0)
        let rock = p.rockTint
        XCTAssertLessThan(abs(cliff.y - rock.y), abs(mid.y - rock.y))
        // Water never turns to rock.
        let lake = p.renderColor(height: -20, slope: 0.9, variation: 0)
        XCTAssertEqual(lake.z, p.renderColor(height: -20, slope: 0, variation: 0).z, accuracy: 0.001)
    }

    // V3
    func testWaterTextureStaysPutAsThePlaneFollowsThePlayer() {
        let water = WaterSurface(world: .seoul, profile: WorldProfile.profile(for: .seoul))
        water.update(playerPosition: SCNVector3(0, 300, 0), time: 0)
        let a = water.node.geometry!.firstMaterial!.diffuse.contentsTransform
        water.update(playerPosition: SCNVector3(WaterSurface.tile, 300, 0), time: 0)
        let b = water.node.geometry!.firstMaterial!.diffuse.contentsTransform
        // Moving one tile shifts the texture by exactly one repeat.
        XCTAssertEqual(b.m41 - a.m41, 1, accuracy: 0.0001)
        XCTAssertEqual(water.node.position.x, WaterSurface.tile)
        XCTAssertEqual(water.node.position.y, WaterSurface.level)
    }

    // V4
    func testPaintedSkyIsBrighterAtTheHorizonAndHasASun() {
        for mood in SkyMood.allCases {
            let p = SkyPainter.palette(world: .sky, mood: mood)
            let up = SkyPainter.color(SIMD3(0, 1, 0), p)
            let horizon = SkyPainter.color(simd_normalize(SIMD3(-p.sun.x, 0.01, -p.sun.z)), p)
            let sun = SkyPainter.color(p.sun, p)
            XCTAssertGreaterThan(horizon.x + horizon.y + horizon.z, up.x + up.y + up.z, "\(mood) horizon")
            XCTAssertGreaterThan(sun.x + sun.y + sun.z, up.x + up.y + up.z, "\(mood) sun")
        }
        let faces = SkyPainter.cubeMap(SkyPainter.palette(world: .city, mood: .sunset), size: 16)
        XCTAssertEqual(faces.count, 6)
        XCTAssertEqual(faces[0].size.width, 16)
    }

    // V5
    func testBillboardLeansIntoTheTurnAndSettles() {
        let vm = FlightViewModel()
        for _ in 0..<120 { vm.updateBank(rollInput: 1, deltaTime: 1 / 60) }
        XCTAssertLessThan(vm.bankRoll.angle, -FlightViewModel.maxBank * 0.5, "right turn leans right (clockwise)")
        for _ in 0..<240 { vm.updateBank(rollInput: 0, deltaTime: 1 / 60) }
        XCTAssertEqual(vm.bankRoll.angle, 0, accuracy: 0.01)
    }

    // V6
    func testEveryLandmarkUsesTheSharedMaterialLanguage() {
        for kind in LandmarkKind.allCases {
            let (root, moving) = LandmarkFactory.styledParts(kind)
            let (lo, hi) = root.boundingBox
            XCTAssertGreaterThan(hi.y - lo.y, 10, "\(kind) gradient spans the landmark")
            var lit = 0
            for part in [root] + moving {
                for m in LandmarkStyle.litMaterials(under: part) {
                    lit += 1
                    XCTAssertEqual(m.shaderModifiers?[.surface], LandmarkStyle.surfaceModifier, "\(kind)")
                    XCTAssertEqual(m.shaderModifiers?[.lightingModel], LandmarkStyle.lightingModifier, "\(kind)")
                    XCTAssertNotNil(m.value(forKey: LandmarkStyle.bottomKey), "\(kind)")
                    XCTAssertNotNil(m.value(forKey: LandmarkStyle.rimKey), "\(kind)")
                }
            }
            XCTAssertGreaterThan(lit, 0, "\(kind) has lit parts")
            // Glowing parts keep their flat look.
            root.enumerateHierarchy { node, _ in
                for m in node.geometry?.materials ?? [] where m.lightingModel == .constant {
                    XCTAssertNil(m.shaderModifiers, "\(kind)")
                }
            }
        }
    }

    // V7
    func testNestedGeometryIsLiftedUnderTheRootWithoutMoving() {
        let (root, _) = LandmarkFactory.styledParts(.hanokVillage)
        var before: [ObjectIdentifier: SCNVector3] = [:]
        root.enumerateChildNodes { node, _ in
            if node.geometry != nil { before[ObjectIdentifier(node)] = node.worldPosition }
        }
        XCTAssertGreaterThan(before.count, 20)
        LandmarkFactory.liftNestedGeometry(root)
        var after = 0
        root.enumerateChildNodes { node, _ in
            guard node.geometry != nil else { return }
            after += 1
            XCTAssertTrue(node.parent === root, "every piece sits straight under the root")
            let p = before[ObjectIdentifier(node)]!
            XCTAssertEqual(node.worldPosition.x, p.x, accuracy: 0.01)
            XCTAssertEqual(node.worldPosition.y, p.y, accuracy: 0.01)
            XCTAssertEqual(node.worldPosition.z, p.z, accuracy: 0.01)
        }
        XCTAssertEqual(after, before.count)
    }

    // V8
    func testPropVariantsAreStableAndEvenlySpread() {
        var counts = [0, 0, 0]
        for h in 0..<600 {
            let v = DecorVariety.variant(h, count: 3)
            XCTAssertEqual(v, DecorVariety.variant(h, count: 3), "same spot, same prop")
            counts[v] += 1
            let u = DecorVariety.unit(h, 2)
            XCTAssertTrue(u >= 0 && u < 1)
        }
        // Neighbouring hashes don't all get the same shape.
        for c in counts { XCTAssertGreaterThan(c, 150) }
        // Size and turn come from the hash too.
        let a = SCNNode(), b = SCNNode()
        DecorVariety.vary(a, hash: 77, scale: 0.8...1.4)
        DecorVariety.vary(b, hash: 77, scale: 0.8...1.4)
        XCTAssertEqual(a.scale.x, b.scale.x)
        XCTAssertEqual(a.eulerAngles.y, b.eulerAngles.y)
        XCTAssertTrue((0.8...1.4).contains(a.scale.x))
    }

    func testEveryRepeatedPropHasThreeDistinctShapes() {
        let terrain = TerrainGenerator(parentNode: SCNNode(), theme: .sky)
        let origin = SCNVector3Zero
        let builders: [(String, (Int) -> SCNNode)] = [
            ("tree", { terrain.makeRoundTree(at: origin, variant: $0) }),
            ("cloud", { terrain.makeFluffyCloud(variant: $0) }),
            ("pine", { TerrainGenerator.makePine(at: origin, scale: 1, variant: $0) }),
            ("palm", { TerrainGenerator.makePalm(at: origin, variant: $0) }),
            ("blossom", { TerrainGenerator.makeBlossomTree(at: origin, variant: $0) }),
            ("hanok", { TerrainGenerator.makeTiledRoofHouse(at: origin, variant: $0) }),
            ("house", { TerrainGenerator.makeTownHouse(at: origin, variant: 0, shape: $0) })
        ]
        for (name, make) in builders {
            var signatures = Set<String>()
            for v in 0..<3 {
                let node = make(v)
                var mesh = PropMesh()
                if node.geometry != nil, node.childNodes.isEmpty {
                    // Clouds are already one merged mesh.
                    let (lo, hi) = node.boundingBox
                    signatures.insert("\(Int(hi.x - lo.x))x\(Int(hi.y - lo.y))")
                    continue
                }
                mesh.bake(node)
                XCTAssertFalse(mesh.isEmpty, name)
                let top = mesh.positions.map(\.y).max()!
                signatures.insert("\(mesh.positions.count)/\(Int(top * 10))")
            }
            XCTAssertEqual(signatures.count, 3, "\(name) shapes should differ")
        }
    }

    func testPropMeshBakesPrimitivesAtTheirRealSize() {
        // SceneKit's own vertex sources are a unit template; the baker
        // must use the real dimensions and face outward.
        var mesh = PropMesh()
        let box = SCNNode(geometry: SCNBox(width: 2, height: 4, length: 6, chamferRadius: 0))
        box.position = SCNVector3(10, 0, 0)
        mesh.bake(box)
        XCTAssertEqual(mesh.positions.map(\.x).min()!, 9, accuracy: 0.001)
        XCTAssertEqual(mesh.positions.map(\.y).max()!, 2, accuracy: 0.001)
        XCTAssertEqual(mesh.positions.map(\.z).max()!, 3, accuracy: 0.001)

        var ball = PropMesh()
        ball.bake(SCNNode(geometry: SCNSphere(radius: 3)))
        for (p, n) in zip(ball.positions, ball.normals) {
            XCTAssertEqual(sqrt(p.x * p.x + p.y * p.y + p.z * p.z), 3, accuracy: 0.01)
            XCTAssertGreaterThan(p.x * n.x + p.y * n.y + p.z * n.z, 0, "normals face out")
        }
        // Triangles wind counter-clockwise seen from outside.
        for t in stride(from: 0, to: ball.indices.count, by: 3) {
            let a = ball.positions[Int(ball.indices[t])], b = ball.positions[Int(ball.indices[t + 1])]
            let c = ball.positions[Int(ball.indices[t + 2])]
            let u = SIMD3(b.x - a.x, b.y - a.y, b.z - a.z), v = SIMD3(c.x - a.x, c.y - a.y, c.z - a.z)
            XCTAssertGreaterThan(simd_dot(simd_cross(u, v), SIMD3(a.x + b.x + c.x, a.y + b.y + c.y, a.z + b.z + c.z)), 0)
        }

        var roof = PropMesh()
        roof.bake(SCNNode(geometry: SCNPyramid(width: 4, height: 5, length: 4)))
        XCTAssertEqual(roof.positions.map(\.y).min()!, 0, accuracy: 0.001, "pyramids stand on their base")
        XCTAssertEqual(roof.positions.map(\.y).max()!, 5, accuracy: 0.001)

        // Colours are converted to the linear space SceneKit reads vertex colours in.
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.5, green: 1, blue: 0, alpha: 1)
        let c = PropMesh.vertexColor(m)
        XCTAssertEqual(c.x, 0.214, accuracy: 0.002)
        XCTAssertEqual(c.y, 1, accuracy: 0.001)
    }

    func testStaticPropsAndSpecklesJoinTheChunkMeshDeterministically() {
        func chunks(_ world: MapTheme) -> [String: SCNNode] {
            let parent = SCNNode()
            TerrainGenerator(parentNode: parent, seed: 42, theme: world).updateChunks(playerPosition: SCNVector3(100, 0, 100))
            return Dictionary(uniqueKeysWithValues: parent.childNodes.compactMap { n in
                n.name?.hasPrefix("chunk_") == true ? (n.name!, n) : nil
            })
        }
        let gridVertices = (Constants.Terrain.gridResolution + 1) * (Constants.Terrain.gridResolution + 1)
        func vertices(_ n: SCNNode) -> Int { n.geometry!.sources(for: .vertex).first!.vectorCount }

        for world in [MapTheme.sky, .city, .seoul, .wild, .desert] {
            let a = chunks(world), b = chunks(world)
            XCTAssertEqual(a.count, 9)
            var extra = 0
            for (name, chunk) in a {
                XCTAssertEqual(chunk.geometry?.elements.count, 1, "\(world) \(name): one draw call for the ground")
                var stray = 0
                chunk.enumerateChildNodes { n, _ in if n.name == TerrainGenerator.staticPropName { stray += 1 } }
                XCTAssertEqual(stray, 0, "\(world) \(name): static props are baked, not left as nodes")
                XCTAssertEqual(vertices(chunk), vertices(b[name]!), "\(world) \(name): same chunk every time")
                extra += vertices(chunk) - gridVertices
            }
            XCTAssertGreaterThan(extra, 500, "\(world): props/speckles added to the ground")
        }
        // Space has no ground props or speckles.
        for chunk in chunks(.space).values { XCTAssertEqual(vertices(chunk), gridVertices) }
    }
}
