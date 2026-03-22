import SwiftUI
import SceneKit

struct CharacterSelectView: View {
    @ObservedObject var characterVM: CharacterViewModel
    @ObservedObject var flightVM: FlightViewModel
    @ObservedObject var missionVM: MissionViewModel
    let flightMode: FlightMode

    @State private var showFlight = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(hex: Constants.Colors.skyBlue).opacity(0.3),
                    Color(hex: Constants.Colors.skyBlue).opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    Spacer()
                    Text("캐릭터 선택")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: startFlight) {
                        Text("START")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: Constants.Colors.turtleGreen))
                            )
                    }
                }
                .padding(.horizontal)

                // Character 3D Preview
                VStack {
                    CharacterPreviewView(character: characterVM.selectedCharacter)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text("\(characterVM.currentConfig.emoji) \(characterVM.currentConfig.name)")
                        .font(.system(size: 24, weight: .bold))
                }

                // Character Grid (horizontal scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(CharacterType.allCases, id: \.self) { character in
                            CharacterTile(
                                character: character,
                                isSelected: characterVM.selectedCharacter == character
                            ) {
                                characterVM.selectCharacter(character)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Vehicle Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("탈것 선택")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        ForEach(characterVM.availableVehicles, id: \.self) { vehicle in
                            VehicleTile(
                                vehicle: vehicle,
                                isSelected: characterVM.selectedVehicle == vehicle
                            ) {
                                characterVM.selectVehicle(vehicle)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Character Description
                Text(characterVM.currentConfig.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: Constants.Colors.panelDark).opacity(0.6))
                    .italic()
                    .padding(.horizontal)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showFlight) {
            FlightView(
                flightVM: flightVM,
                missionVM: missionVM,
                character: characterVM.selectedCharacter,
                vehicle: characterVM.selectedVehicle,
                flightMode: flightMode
            )
        }
    }

    private func startFlight() {
        characterVM.save()
        showFlight = true
    }
}

// MARK: - Character Preview (SceneKit)

struct CharacterPreviewView: UIViewRepresentable {
    let character: CharacterType

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true

        let scene = SCNScene()
        let charNode = CharacterRegistry.shared.buildCharacterNode(for: character)
        scene.rootNode.addChildNode(charNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0.5, 3)
        scene.rootNode.addChildNode(cameraNode)

        // Auto-rotate
        let rotate = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 8)
        charNode.runAction(.repeatForever(rotate))

        scnView.scene = scene
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Rebuild when character changes
        guard let scene = uiView.scene else { return }
        scene.rootNode.childNodes.filter { $0.name != nil && CharacterType(rawValue: $0.name!) != nil }
            .forEach { $0.removeFromParentNode() }

        let charNode = CharacterRegistry.shared.buildCharacterNode(for: character)
        let rotate = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 8)
        charNode.runAction(.repeatForever(rotate))
        scene.rootNode.addChildNode(charNode)
    }
}

// MARK: - Tiles

struct CharacterTile: View {
    let character: CharacterType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(character.config.emoji)
                    .font(.system(size: 32))
                Text(character.config.name)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(width: 60, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: Constants.Colors.turtleGreen) : Color.white)
                    .shadow(radius: isSelected ? 4 : 1)
            )
            .foregroundColor(isSelected ? .white : Color(hex: Constants.Colors.panelDark))
        }
    }
}

struct VehicleTile: View {
    let vehicle: VehicleType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(vehicle.icon)
                    .font(.system(size: 24))
                Text(vehicle.displayName)
                    .font(.system(size: 10, weight: .medium))
                Text(vehicle.isShared ? "(공통)" : "(고유)")
                    .font(.system(size: 9))
                    .opacity(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(hex: Constants.Colors.boostOrange) : Color.white)
                    .shadow(radius: isSelected ? 3 : 1)
            )
            .foregroundColor(isSelected ? .white : Color(hex: Constants.Colors.panelDark))
        }
    }
}
