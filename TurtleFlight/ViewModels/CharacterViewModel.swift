import Foundation
import Combine

final class CharacterViewModel: ObservableObject {
    @Published var selectedCharacter: CharacterType = .turtle
    @Published var selectedVehicle: VehicleType = .shellJet
    @Published var selectedMapTheme: MapTheme = .sky

    var currentConfig: CharacterConfig {
        selectedCharacter.config
    }

    var availableVehicles: [VehicleType] {
        selectedCharacter.config.availableVehicles
    }

    func selectCharacter(_ character: CharacterType) {
        selectedCharacter = character
        selectedVehicle = character.config.defaultVehicle
    }

    func selectVehicle(_ vehicle: VehicleType) {
        guard availableVehicles.contains(vehicle) else { return }
        selectedVehicle = vehicle
    }

    func selectMapTheme(_ theme: MapTheme) {
        selectedMapTheme = theme
    }

    func save() {
        UserDefaults.standard.set(selectedCharacter.rawValue, forKey: "selectedCharacter")
        UserDefaults.standard.set(selectedVehicle.rawValue, forKey: "selectedVehicle")
        UserDefaults.standard.set(selectedMapTheme.rawValue, forKey: "selectedMapTheme")
    }

    func load() {
        if let charStr = UserDefaults.standard.string(forKey: "selectedCharacter"),
           let char = CharacterType(rawValue: charStr) {
            selectedCharacter = char
        }
        if let vehStr = UserDefaults.standard.string(forKey: "selectedVehicle"),
           let veh = VehicleType(rawValue: vehStr) {
            selectedVehicle = veh
        }
        if let themeStr = UserDefaults.standard.string(forKey: "selectedMapTheme"),
           let theme = MapTheme(rawValue: themeStr) {
            selectedMapTheme = theme
        }
    }
}
