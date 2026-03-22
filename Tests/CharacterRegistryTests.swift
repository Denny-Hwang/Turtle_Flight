import XCTest
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
}
