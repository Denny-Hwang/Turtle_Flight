import XCTest
import SceneKit
@testable import TurtleFlight

/// V1–V7 of docs/VISUAL_AUDIO_PLAN.md.
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
}
