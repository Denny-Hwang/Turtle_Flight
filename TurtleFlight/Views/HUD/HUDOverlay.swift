import SwiftUI

struct HUDOverlay: View {
    @ObservedObject var flightVM: FlightViewModel

    /// Pulsing scale applied to the star counter on each pickup. Starts
    /// at 1.0, springs to 1.4 on collection, then settles back. Driven
    /// by `.onChange(of: starsCollected)` below — there's no direct
    /// "pickup happened" event, but the published counter monotonically
    /// increases so any rise is a pickup.
    @State private var starCounterScale: CGFloat = 1.0

    var body: some View {
        VStack {
            // Top HUD Bar
            HStack {
                // Left: Speed + Sensitivity
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HUDGauge(
                        label: "SPD",
                        value: "\(Int(flightVM.speed))",
                        unit: "KM/H"
                    )
                    Text("Lv.\(flightVM.sensitivityLevel.levelNumber)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(sensitivityColor)
                        .padding(.horizontal, Theme.Spacing.xs + 2)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.xs - 2)
                                .fill(Theme.Color.surfaceOverlay)
                        )
                }

                Spacer()

                // Center: Compass + Flight Time
                VStack(spacing: Theme.Spacing.xxs) {
                    Text(compassText)
                        .font(Theme.Typography.hudCompass)
                        .foregroundColor(Theme.Color.hudCyan)

                    Text(flightVM.flightTime.mmss)
                        .font(Theme.Typography.hudTimer)
                        .foregroundColor(Theme.Color.textOnDark)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s - 2)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.s)
                        .fill(Theme.Color.surfaceOverlay)
                )

                Spacer()

                // Right: Altitude
                HUDGauge(
                    label: "ALT",
                    value: "\(Int(flightVM.altitude))",
                    unit: "M"
                )
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)

            Spacer()

            // Bottom: Region Name (center) + Star Counter (left)
            HStack {
                // Star counter — pulses scale on each pickup so the
                // visceral "I just got one" feedback loop reads even
                // without watching the world animate.
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Theme.Color.starGold)
                        .font(.system(size: 14))
                    Text("x \(flightVM.starsCollected)")
                        .font(Theme.Typography.hudGaugeSmall)
                        .foregroundColor(Theme.Color.textOnDark)
                }
                .padding(.horizontal, Theme.Spacing.s + 2)
                .padding(.vertical, Theme.Spacing.s - 2)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.s)
                        .fill(Theme.Color.surfaceOverlay)
                )
                .scaleEffect(starCounterScale)
                .onChange(of: flightVM.starsCollected) { _ in
                    // Spring up, then settle back. The delayed return
                    // beat lets the eye register the count change before
                    // the chip relaxes — under 0.4s total so it never
                    // blocks the next pickup's animation.
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                        starCounterScale = 1.4
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                            starCounterScale = 1.0
                        }
                    }
                }

                Spacer()

                // Region name
                if !flightVM.currentRegion.isEmpty {
                    Text(flightVM.currentRegion)
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Color.textOnDark)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, Theme.Spacing.s - 2)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.s)
                                .fill(Theme.Color.surfaceOverlayMuted)
                        )
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.l)
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
        case .easy:   return Theme.Color.easyGreen
        case .normal: return Theme.Color.normalYellow
        case .expert: return Theme.Color.expertRed
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
                .font(Theme.Typography.microLabel)
                .foregroundColor(Theme.Color.hudCyan.opacity(0.7))

            Text(value)
                .font(Theme.Typography.hudGauge)
                .foregroundColor(Theme.Color.hudCyan)

            Text(unit)
                .font(Theme.Typography.microLabel)
                .foregroundColor(Theme.Color.hudCyan.opacity(0.7))
        }
        .padding(.horizontal, Theme.Spacing.s + 2)
        .padding(.vertical, Theme.Spacing.s - 2)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.s)
                .fill(Theme.Color.surfaceOverlay)
        )
    }
}
