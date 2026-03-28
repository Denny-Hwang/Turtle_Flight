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
            // Background adapts to selected map theme
            themeBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Choose Your Adventure")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: startFlight) {
                        Text("FLY!")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(themeAccentColor)
                                    .shadow(color: themeAccentColor.opacity(0.5), radius: 6, y: 3)
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // ── MAP THEME SELECTION ──
                VStack(alignment: .leading, spacing: 8) {
                    Label("Select Map", systemImage: "map.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal)

                    HStack(spacing: 10) {
                        ForEach(MapTheme.allCases, id: \.self) { theme in
                            MapThemeCard(
                                theme: theme,
                                isSelected: characterVM.selectedMapTheme == theme
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    characterVM.selectMapTheme(theme)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Divider().background(Color.white.opacity(0.3))

                // ── CHARACTER PREVIEW ──
                VStack(spacing: 6) {
                    CharacterPreviewView(character: characterVM.selectedCharacter)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 8)

                    Text("\(characterVM.currentConfig.emoji)  \(characterVM.currentConfig.name)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                // ── CHARACTER GRID ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
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

                // ── VEHICLE SELECTION ──
                VStack(alignment: .leading, spacing: 6) {
                    Label("Vehicle", systemImage: "wind")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal)

                    HStack(spacing: 10) {
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

                // Description
                Text(characterVM.currentConfig.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
                    .multilineTextAlignment(.center)
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
                flightMode: flightMode,
                mapTheme: characterVM.selectedMapTheme
            )
        }
    }

    // MARK: - Helpers

    private var themeBackground: some View {
        switch characterVM.selectedMapTheme {
        case .sky:
            return LinearGradient(
                colors: [Color(hex: 0x87CEEB), Color(hex: 0xFFFDE7)],
                startPoint: .top, endPoint: .bottom
            ).eraseToAnyView()
        case .space:
            return LinearGradient(
                colors: [Color(hex: 0x0D0025), Color(hex: 0x2A0A4A)],
                startPoint: .top, endPoint: .bottom
            ).eraseToAnyView()
        case .ocean:
            return LinearGradient(
                colors: [Color(hex: 0x006994), Color(hex: 0x40E0D0)],
                startPoint: .top, endPoint: .bottom
            ).eraseToAnyView()
        }
    }

    private var themeAccentColor: Color {
        switch characterVM.selectedMapTheme {
        case .sky:   return Color(hex: Constants.Colors.turtleGreen)
        case .space: return Color(hex: 0x7B2FBE)
        case .ocean: return Color(hex: 0x0077B6)
        }
    }

    private func startFlight() {
        characterVM.save()
        showFlight = true
    }
}

// MARK: - Map Theme Card

struct MapThemeCard: View {
    let theme: MapTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(theme.emoji)
                    .font(.system(size: 28))
                Text(theme.displayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(theme.subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? cardAccent.opacity(0.85) : Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.white.opacity(0.8) : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: isSelected ? cardAccent.opacity(0.5) : .clear, radius: 8, y: 4)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }

    private var cardAccent: Color {
        switch theme {
        case .sky:   return Color(hex: 0x29B6F6)
        case .space: return Color(hex: 0x7B2FBE)
        case .ocean: return Color(hex: 0x0077B6)
        }
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

        charNode.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 8)))
        scnView.scene = scene
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = uiView.scene else { return }
        scene.rootNode.childNodes
            .filter { node in
                guard let name = node.name else { return false }
                return CharacterType(rawValue: name) != nil
            }
            .forEach { $0.removeFromParentNode() }
        let charNode = CharacterRegistry.shared.buildCharacterNode(for: character)
        charNode.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 8)))
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
                    .font(.system(size: 30))
                Text(character.config.name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .frame(width: 64, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.2))
                    .shadow(radius: isSelected ? 5 : 1)
            )
            .foregroundColor(isSelected ? Color(hex: Constants.Colors.panelDark) : .white)
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .animation(.spring(response: 0.25), value: isSelected)
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
                    .font(.system(size: 22))
                Text(vehicle.displayName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(vehicle.isShared ? "Shared" : "Unique")
                    .font(.system(size: 8))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: Constants.Colors.boostOrange) : Color.white.opacity(0.2))
                    .shadow(radius: isSelected ? 4 : 1)
            )
            .foregroundColor(.white)
        }
    }
}

// MARK: - View Extension

extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}
