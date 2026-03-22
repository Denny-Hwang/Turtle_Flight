import SwiftUI

struct ControlButtons: View {
    let onBoost: () -> Void
    let onFire: () -> Void
    let onCalibrate: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack {
            // Top-right: Exit + Calibrate
            HStack {
                Spacer()

                HStack(spacing: 12) {
                    // Calibrate button
                    SmallButton(icon: "scope", label: "보정") {
                        onCalibrate()
                    }

                    // Exit button
                    SmallButton(icon: "xmark", label: "종료") {
                        onExit()
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            Spacer()

            // Bottom: Boost (left) + Fire (right)
            HStack {
                // Boost Button (left bottom)
                ThumbButton(
                    icon: "flame.fill",
                    label: "부스터",
                    color: Color(hex: Constants.Colors.boostOrange),
                    action: onBoost
                )
                .padding(.leading, Constants.Controls.buttonPadding)

                Spacer()

                // Fire Button (right bottom)
                ThumbButton(
                    icon: "star.fill",
                    label: "아이템",
                    color: Color(hex: Constants.Colors.starGold),
                    action: onFire
                )
                .padding(.trailing, Constants.Controls.buttonPadding)
            }
            .padding(.bottom, Constants.Controls.buttonPadding)
        }
    }
}

// MARK: - Thumb Button (72pt minimum)

struct ThumbButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: Constants.Controls.buttonSize, height: Constants.Controls.buttonSize)
            .background(
                Circle()
                    .fill(color)
                    .shadow(color: color.opacity(0.5), radius: 6, y: 2)
            )
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Small Button (for exit, calibrate)

struct SmallButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(Color(hex: Constants.Colors.panelDark).opacity(0.6))
            )
        }
    }
}
