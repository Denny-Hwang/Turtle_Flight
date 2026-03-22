import SwiftUI

struct HomeView: View {
    @StateObject private var characterVM = CharacterViewModel()
    @StateObject private var flightVM = FlightViewModel()
    @StateObject private var missionVM = MissionViewModel()

    @State private var selectedMode: FlightMode?
    @State private var showCharacterSelect = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Sky gradient background
                LinearGradient(
                    colors: [
                        Color(hex: Constants.Colors.skyBlue),
                        Color(hex: Constants.Colors.skyBlue).opacity(0.6),
                        Color.white.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    // Title
                    VStack(spacing: 8) {
                        Text("Turtle Flight")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: Constants.Colors.panelDark))

                        Text("날 수 없는 동물들의 하늘 모험")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: Constants.Colors.panelDark).opacity(0.7))
                    }
                    .padding(.top, 40)

                    Spacer()

                    // Mode Selection
                    HStack(spacing: 20) {
                        ModeButton(
                            title: "자유 비행",
                            subtitle: "Free Flight",
                            icon: "cloud.sun.fill",
                            color: Color(hex: Constants.Colors.skyBlue)
                        ) {
                            selectedMode = .freePlay
                            showCharacterSelect = true
                        }

                        ModeButton(
                            title: "Step Goal",
                            subtitle: "\(missionVM.progress.totalStars)/15",
                            icon: "target",
                            color: Color(hex: Constants.Colors.starGold)
                        ) {
                            selectedMode = .stepGoal
                            showCharacterSelect = true
                        }
                    }

                    // Sensitivity Selection
                    VStack(spacing: 12) {
                        Text("조종 민감도")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: Constants.Colors.panelDark).opacity(0.7))

                        HStack(spacing: 12) {
                            ForEach(SensitivityLevel.allCases, id: \.self) { level in
                                SensitivityButton(
                                    level: level,
                                    isSelected: flightVM.sensitivityLevel == level
                                ) {
                                    flightVM.sensitivityLevel = level
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)

                    Spacer()

                    // Stats
                    HStack {
                        Label(
                            "최고기록: \(missionVM.progress.bestFreeFlightStars)",
                            systemImage: "star.fill"
                        )
                        .foregroundColor(Color(hex: Constants.Colors.starGold))

                        Text("|")
                            .foregroundColor(.gray)

                        Label(
                            "비행시간 \(missionVM.progress.totalFlightTime.mmss)",
                            systemImage: "clock"
                        )
                        .foregroundColor(Color(hex: Constants.Colors.hudCyan))
                    }
                    .font(.system(size: 13))
                    .padding(.bottom, 30)
                }
            }
            .navigationDestination(isPresented: $showCharacterSelect) {
                CharacterSelectView(
                    characterVM: characterVM,
                    flightVM: flightVM,
                    missionVM: missionVM,
                    flightMode: selectedMode ?? .freePlay
                )
            }
        }
        .onAppear {
            characterVM.load()
            flightVM.load()
            missionVM.load()
        }
    }
}

// MARK: - Subviews

struct ModeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .opacity(0.7)
            }
            .foregroundColor(.white)
            .frame(width: 140, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .shadow(color: color.opacity(0.4), radius: 8, y: 4)
            )
        }
    }
}

struct SensitivityButton: View {
    let level: SensitivityLevel
    let isSelected: Bool
    let action: () -> Void

    private var color: Color {
        switch level {
        case .easy:   return Color(hex: Constants.Colors.turtleGreen)
        case .normal: return Color(hex: Constants.Colors.normalYellow)
        case .expert: return Color(hex: Constants.Colors.expertRed)
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(level.emoji)
                    .font(.system(size: 20))
                Text(level.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color : Color.gray.opacity(0.2))
            )
            .foregroundColor(isSelected ? .white : Color(hex: Constants.Colors.panelDark))
        }
    }
}

#Preview {
    HomeView()
}
