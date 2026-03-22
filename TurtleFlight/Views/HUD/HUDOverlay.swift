import SwiftUI

struct HUDOverlay: View {
    @ObservedObject var flightVM: FlightViewModel

    var body: some View {
        VStack {
            // Top HUD Bar
            HStack {
                // Left: Speed + Sensitivity
                VStack(alignment: .leading, spacing: 4) {
                    HUDGauge(
                        label: "SPD",
                        value: "\(Int(flightVM.speed))",
                        unit: "KM/H"
                    )
                    Text("Lv.\(flightVM.sensitivityLevel.levelNumber)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(sensitivityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: Constants.Colors.panelDark).opacity(0.6))
                        )
                }

                Spacer()

                // Center: Compass + Flight Time
                VStack(spacing: 2) {
                    Text(compassText)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: Constants.Colors.hudCyan))

                    Text(flightVM.flightTime.mmss)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: Constants.Colors.panelDark).opacity(0.7))
                )

                Spacer()

                // Right: Altitude
                HUDGauge(
                    label: "ALT",
                    value: "\(Int(flightVM.altitude))",
                    unit: "M"
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Bottom: Region Name (center) + Star Counter (left)
            HStack {
                // Star counter
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color(hex: Constants.Colors.starGold))
                        .font(.system(size: 14))
                    Text("x \(flightVM.starsCollected)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: Constants.Colors.panelDark).opacity(0.6))
                )

                Spacer()

                // Region name
                if !flightVM.currentRegion.isEmpty {
                    Text(flightVM.currentRegion)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: Constants.Colors.panelDark).opacity(0.5))
                        )
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80) // Space for control buttons
        }
        .allowsHitTesting(false) // Pass touches through to SceneKit
    }

    private var compassText: String {
        let dir = MathHelpers.compassDirection(from: flightVM.heading)
        let degrees = String(format: "%03d", Int(flightVM.heading))
        return "\(dir) \(degrees)°"
    }

    private var sensitivityColor: Color {
        switch flightVM.sensitivityLevel {
        case .easy:   return Color(hex: Constants.Colors.turtleGreen)
        case .normal: return Color(hex: Constants.Colors.normalYellow)
        case .expert: return Color(hex: Constants.Colors.expertRed)
        }
    }
}

// MARK: - HUD Gauge Component

struct HUDGauge: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: Constants.Colors.hudCyan).opacity(0.7))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: Constants.Colors.hudCyan))

            Text(unit)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: Constants.Colors.hudCyan).opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: Constants.Colors.panelDark).opacity(0.7))
        )
    }
}
