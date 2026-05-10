import SwiftUI

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

            VStack(spacing: Theme.Spacing.l) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(Theme.Color.textOnDark)
                    }
                    Spacer()
                    Text(L10n.t("characterSelect.title"))
                        .font(Theme.Typography.titleSmall)
                        .foregroundColor(Theme.Color.textOnDark)
                    Spacer()
                    Button(action: startFlight) {
                        Text(L10n.t("characterSelect.fly"))
                            .font(Theme.Typography.button)
                            .foregroundColor(Theme.Color.textOnDark)
                            .padding(.horizontal, Theme.Spacing.xl - 4)
                            .padding(.vertical, Theme.Spacing.s + 2)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.m)
                                    .fill(themeAccentColor)
                                    .shadow(color: themeAccentColor.opacity(0.5), radius: 6, y: 3)
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.s)

                // ── MAP THEME SELECTION ──
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Label(L10n.t("characterSelect.section.map"), systemImage: "map.fill")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Color.textOnDark.opacity(0.85))
                        .padding(.horizontal)

                    HStack(spacing: Theme.Spacing.m - 2) {
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

                Divider().background(Theme.Color.textOnDark.opacity(0.3))

                // ── CHARACTER PREVIEW ──
                VStack(spacing: Theme.Spacing.xs + 2) {
                    CharacterPreviewView(character: characterVM.selectedCharacter)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
                        .shadow(radius: 8)

                    Text("\(characterVM.currentConfig.emoji)  \(characterVM.currentConfig.name)")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Color.textOnDark)
                }

                // ── CHARACTER GRID ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.m - 2) {
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
                VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
                    Label(L10n.t("characterSelect.section.vehicle"), systemImage: "wind")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Color.textOnDark.opacity(0.85))
                        .padding(.horizontal)

                    HStack(spacing: Theme.Spacing.m - 2) {
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
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Color.textOnDarkMuted)
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
        LinearGradient(
            colors: characterVM.selectedMapTheme.uiGradient,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var themeAccentColor: Color {
        characterVM.selectedMapTheme.uiAccent
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
            VStack(spacing: Theme.Spacing.xs + 2) {
                Text(theme.emoji)
                    .font(.system(size: 28))
                Text(theme.displayName)
                    .font(Theme.Typography.labelSmall)
                    .foregroundColor(isSelected ? Theme.Color.textOnDark : Theme.Color.textOnDark.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(theme.subtitle)
                    .font(Theme.Typography.microLabel)
                    .foregroundColor(isSelected ? Theme.Color.textOnDark.opacity(0.9) : Theme.Color.textOnDarkFaint)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.l - 2)
                    .fill(isSelected ? theme.uiCardAccent.opacity(0.85) : Theme.Color.textOnDark.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.l - 2)
                            .stroke(isSelected ? Theme.Color.textOnDark.opacity(0.8) : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: isSelected ? theme.uiCardAccent.opacity(0.5) : .clear, radius: 8, y: 4)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

// MARK: - Character Preview

/// Hero portrait for the selection screen. Renders the canonical
/// `{name}_default.imageset` (vector PDF) with a gentle floating wiggle so the
/// character feels alive without pretending to be 3D — the chibi 2D art style
/// is the design direction (`docs/CHARACTER_DESIGN_PROMPT.md`).
struct CharacterPreviewView: View {
    let character: CharacterType
    @State private var bob: CGFloat = 0
    @State private var lean: Double = 0

    var body: some View {
        Image("\(character.assetPrefix)_default")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .padding(Theme.Spacing.s)
            .offset(y: bob)
            .rotationEffect(.degrees(lean))
            .accessibilityLabel(character.config.name)
            .onAppear {
                // Reset state when the selected character changes — onAppear
                // doesn't fire on re-render, so the .id() below ties the
                // animation lifecycle to the character identity.
                bob = 0
                lean = 0
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    bob = -8
                }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    lean = 3
                }
            }
            .id(character)
    }
}

// MARK: - Tiles

struct CharacterTile: View {
    let character: CharacterType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xxs) {
                Image("\(character.assetPrefix)_icon")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .adaptiveFrame(compactWidth: 44, compactHeight: 44)
                Text(character.config.name)
                    .font(Theme.Typography.tileLabel)
            }
            .adaptiveFrame(compactWidth: 64, compactHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.l - 2)
                    .fill(isSelected ? Theme.Color.surfaceSelected : Theme.Color.surfaceMuted)
                    .shadow(radius: isSelected ? 5 : 1)
            )
            .foregroundColor(isSelected ? Theme.Color.textPrimary : Theme.Color.textOnDark)
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
            VStack(spacing: Theme.Spacing.xs) {
                vehicleArtwork
                    .frame(height: 40)
                Text(vehicle.displayName)
                    .font(Theme.Typography.tileLabel)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(vehicle.isShared ? L10n.t("vehicle.tag.shared") : L10n.t("vehicle.tag.unique"))
                    .font(.system(size: 8))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s + 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .fill(isSelected ? Theme.Color.boostOrange : Theme.Color.surfaceMuted)
                    .shadow(radius: isSelected ? 4 : 1)
            )
            .foregroundColor(Theme.Color.textOnDark)
        }
    }

    @ViewBuilder
    private var vehicleArtwork: some View {
        if let asset = vehicle.vehicleOnlyAssetName {
            Image(asset)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            // Cloud Surf has no per-character vehicle art; fall back to emoji.
            Text(vehicle.icon)
                .font(.system(size: 28))
        }
    }
}

// MARK: - View Extension

extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}
