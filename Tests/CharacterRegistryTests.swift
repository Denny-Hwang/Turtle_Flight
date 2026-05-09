import XCTest
import SceneKit
@testable import TurtleFlight

final class CharacterRegistryTests: XCTestCase {

    func testAllCharactersAvailable() {
        let registry = CharacterRegistry.shared
        XCTAssertEqual(registry.allCharacters.count, 6)
    }

    func testCharacterConfigs() {
        for character in CharacterType.allCases {
            let config = character.config
            XCTAssertFalse(config.name.isEmpty)
            XCTAssertFalse(config.emoji.isEmpty)
            XCTAssertFalse(config.modelName.isEmpty)
            XCTAssertFalse(config.description.isEmpty)
            XCTAssertTrue(config.availableVehicles.contains(config.defaultVehicle))
            XCTAssertTrue(config.availableVehicles.contains(.cloudSurf))
        }
    }

    func testTurtleConfig() {
        let config = CharacterType.turtle.config
        XCTAssertEqual(config.name, "Turbo")
        XCTAssertEqual(config.defaultVehicle, .shellJet)
        XCTAssertEqual(config.availableVehicles.count, 2)
    }

    func testAllVehicleTypes() {
        XCTAssertEqual(VehicleType.allCases.count, 7) // 6 character-specific + 1 shared
    }

    func testCloudSurfIsShared() {
        XCTAssertTrue(VehicleType.cloudSurf.isShared)
        XCTAssertFalse(VehicleType.shellJet.isShared)
    }

    func testCharacterNodeCreation() {
        let registry = CharacterRegistry.shared
        for character in CharacterType.allCases {
            let node = registry.buildCharacterNode(for: character)
            XCTAssertEqual(node.name, character.rawValue)
            XCTAssertGreaterThan(node.childNodes.count, 0)
        }
    }

    func testVehicleNodeCreation() {
        let registry = CharacterRegistry.shared
        for vehicle in VehicleType.allCases {
            let node = registry.buildVehicleNode(for: vehicle)
            XCTAssertEqual(node.name, vehicle.rawValue)
        }
    }

    func testAll12Combinations() {
        let registry = CharacterRegistry.shared
        // 6 characters × 2 vehicles each = 12 combinations
        var combinationCount = 0
        for character in CharacterType.allCases {
            let config = character.config
            for vehicle in config.availableVehicles {
                let charNode = registry.buildCharacterNode(for: character)
                let vehNode = registry.buildVehicleNode(for: vehicle)
                XCTAssertNotNil(charNode)
                XCTAssertNotNil(vehNode)
                combinationCount += 1
            }
        }
        XCTAssertEqual(combinationCount, 12)
    }

    // MARK: - In-flight billboard

    func testBillboardNodeForEveryCharacter() {
        let registry = CharacterRegistry.shared
        for character in CharacterType.allCases {
            let node = registry.buildInflightBillboard(for: character)
            XCTAssertEqual(node.name, character.rawValue)
            XCTAssertNotNil(node.geometry as? SCNPlane,
                            "Billboard should be an SCNPlane (got \(type(of: node.geometry)))")
            XCTAssertFalse(node.constraints?.isEmpty ?? true,
                           "Billboard must carry a constraint to face the camera")
            XCTAssertTrue(node.constraints?.first is SCNBillboardConstraint,
                          "Constraint must be SCNBillboardConstraint per design spec")
            XCTAssertEqual(node.geometry?.firstMaterial?.lightingModel, .constant,
                           "2D chibi art should ignore scene lighting")
        }
    }

    func testUVTransformPicksCorrectAtlasCell() {
        // 2×2 atlas, cells are 0.5 wide. Each cell's UV transform should
        // crop the texture to that cell exactly.
        // Per CHARACTER_DESIGN_PROMPT.md:
        //   default = top-left, joy = top-right,
        //   scared = bottom-left, speed = bottom-right.
        let cases: [(CharacterExpression, Float, Float)] = [
            (.default, 0.0, 0.5),  // col 0, row 1 (top)
            (.joy,     0.5, 0.5),
            (.scared,  0.0, 0.0),  // col 0, row 0 (bottom)
            (.speed,   0.5, 0.0),
        ]
        for (expr, expectedTx, expectedTy) in cases {
            let m = CharacterRegistry.uvTransform(forCell: expr.atlasCell)
            XCTAssertEqual(m.m11, 0.5, accuracy: 1e-6, "scale.x for \(expr)")
            XCTAssertEqual(m.m22, 0.5, accuracy: 1e-6, "scale.y for \(expr)")
            XCTAssertEqual(m.m41, expectedTx, accuracy: 1e-6, "tx for \(expr)")
            XCTAssertEqual(m.m42, expectedTy, accuracy: 1e-6, "ty for \(expr)")
        }
    }

    func testSetExpressionUpdatesUVTransform() {
        let registry = CharacterRegistry.shared
        let node = registry.buildInflightBillboard(for: .turtle)
        let animator = CharacterAnimator()

        // Default after creation
        let initial = node.geometry!.firstMaterial!.diffuse.contentsTransform
        XCTAssertEqual(initial.m41, 0.0, accuracy: 1e-6)
        XCTAssertEqual(initial.m42, 0.5, accuracy: 1e-6)

        animator.setExpression(.speed, on: node, duration: 0)
        let after = node.geometry!.firstMaterial!.diffuse.contentsTransform
        XCTAssertEqual(after.m41, 0.5, accuracy: 1e-6, "speed cell should sit in col 1")
        XCTAssertEqual(after.m42, 0.0, accuracy: 1e-6, "speed cell should sit in row 0")
    }
}
