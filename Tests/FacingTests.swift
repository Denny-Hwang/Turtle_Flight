import XCTest
import SceneKit
@testable import TurtleFlight

/// In flight the character faces where it is flying (back art) unless the
/// player turns it round with "Look at me".
final class FacingTests: XCTestCase {

    func testEveryCharacterHasBackAtlasesForBothRides() {
        for character in CharacterType.allCases {
            for vehicle in [VehicleType.cloudSurf, character.defaultVehicleForTests] {
                let name = CharacterRegistry.backAtlasName(for: character, vehicle: vehicle)
                XCTAssertNotNil(UIImage(named: name), "missing \(name)")
                let back = CharacterRegistry.atlasImage(for: character, vehicle: vehicle, lookingAtCamera: false)
                let front = CharacterRegistry.atlasImage(for: character, vehicle: vehicle, lookingAtCamera: true)
                XCTAssertNotNil(back)
                XCTAssertNotNil(front)
                XCTAssertFalse(back === front, "\(character) back and front must differ")
            }
        }
    }

    func testFlightDefaultsToFacingAheadAndCanTurnRound() {
        let vm = FlightViewModel()
        let node = CharacterRegistry.shared.buildInflightBillboard(for: .cat, vehicle: .cloudSurf, lookingAtCamera: false)
        vm.characterNode = node
        vm.currentCharacter = .cat
        vm.currentVehicle = .cloudSurf
        let backImage = node.geometry?.firstMaterial?.diffuse.contents as? UIImage
        XCTAssertFalse(vm.isLookingAtCamera)
        let cellBefore = node.geometry?.firstMaterial?.diffuse.contentsTransform

        vm.setLookingAtCamera(true)
        XCTAssertTrue(vm.isLookingAtCamera)
        let frontImage = node.geometry?.firstMaterial?.diffuse.contents as? UIImage
        XCTAssertNotNil(frontImage)
        XCTAssertFalse(frontImage === backImage)
        // The expression cell is kept.
        XCTAssertTrue(SCNMatrix4EqualToMatrix4(cellBefore!, node.geometry!.firstMaterial!.diffuse.contentsTransform))

        vm.setLookingAtCamera(false)
        XCTAssertFalse(vm.isLookingAtCamera)
    }
}

private extension CharacterType {
    var defaultVehicleForTests: VehicleType {
        config.defaultVehicle
    }
}
