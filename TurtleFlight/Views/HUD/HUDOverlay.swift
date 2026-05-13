import SwiftUI

struct HUDOverlay: View {
    @ObservedObject var flightVM: FlightViewModel

    /// Pulsing scale applied to the star counter on each pickup. Starts
    /// at 1.0, springs to 1.4 on collection, then settles back. Driven
    /// by `.onChange(of: starsCollected)` below — there's no direct
    /// "pickup happened" event, but the published counter monotonically
    /// increases so any rise is a pickup.
    @State private var starCounterScale: CGFloat = 1.0

    /// Opacity of a thin red rim that flashes around the screen on each
    /// collision. Pairs with the existing haptic + sound feedback so a
    /// deaf / silent-phone / hard-of-hearing player still gets a visual
    /// cue. Edge-driven by `flightVM.collisionFlashTrigger` (a monotonic
    /// counter incremented inside the flight loop).
    @State private var collisionFlashOpacity: Double = 0

    /// Honors the system-wide Reduce Motion toggle. When ON we skip the
    /// star-counter spring pulse so vestibular-sensitive players don't
    /// get a chip animation on every pickup.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            // Landscape on Dynamic-Island iPhones puts the system inset on
            // the leading edge (~59pt). We honour that inset on both sides
            // and fall back to Theme.l on devices with zero insets so the
            // chrome never crowds the Dynamic Island or notch.
            let horizontalInset = max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing, Theme.Spacing.l)

            ZStack {
            // Collision flash — full-screen red rim that fades out over
            // ~0.45s. Behind the HUD chips so the gauges stay readable,
            // but above the SceneKit scene so it reads as a UI effect
            // rather than a world event. Hidden from VoiceOver because
            // the existing audio + haptic cues already announce the
            // collision; this is for the deaf / silenced path.
            Rectangle()
                .stroke(Theme.Color.expertRed, lineWidth: 10)
                .ignoresSafeArea()
                .opacity(collisionFlashOpacity)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
                .onChange(of: flightVM.collisionFlashTrigger) { _ in
                    // Two-stage animation: snap visible, then fade. Gives
                    // a sharp "tick" feel on impact rather than a slow
                    // bloom. Reduce Motion still shows the flash (it's
                    // information, not decoration) but skips the eased
                    // ramp so the rim simply blinks.
                    if reduceMotion {
                        collisionFlashOpacity = 0.9
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            collisionFlashOpacity = 0
                        }
                    } else {
                        collisionFlashOpacity = 0.9
                        withAnimation(.easeOut(duration: 0.45)) {
                            collisionFlashOpacity = 0
                        }
                    }
                }

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
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.format("a11y.hud.speed.format", Int(flightVM.speed)))
                        Text("Lv.\(flightVM.sensitivityLevel.levelNumber)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(sensitivityColor)
                            .padding(.horizontal, Theme.Spacing.xs + 2)
                            .padding(.vertical, Theme.Spacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.xs - 2)
                                    .fill(Theme.Color.surfaceOverlay)
                            )
                            .accessibilityLabel(L10n.format("a11y.hud.sensitivity.format", flightVM.sensitivityLevel.levelNumber))
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.format("a11y.hud.compass.format", MathHelpers.compassDirection(from: flightVM.heading), Int(flightVM.heading), flightVM.flightTime.mmss))

                    Spacer()

                    // Right: Altitude
                    HUDGauge(
                        label: "ALT",
                        value: "\(Int(flightVM.altitude))",
                        unit: "M"
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.format("a11y.hud.altitude.format", Int(flightVM.altitude)))
                }
                .padding(.horizontal, horizontalInset)
                .padding(.top, max(proxy.safeAreaInsets.top, Theme.Spacing.s))

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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.format("a11y.hud.stars.format", flightVM.starsCollected))
                    .onChange(of: flightVM.starsCollected) { newCount in
                        // Spring up, then settle back. The delayed return
                        // beat lets the eye register the count change before
                        // the chip relaxes — under 0.4s total so it never
                        // blocks the next pickup's animation. Reduce Motion
                        // skips the spring so vestibular-sensitive players
                        // don't get a chip pulse on every pickup.
                        if !reduceMotion {
                            withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                                starCounterScale = 1.4
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                                    starCounterScale = 1.0
                                }
                            }
                        }
                        UIAccessibility.post(notification: .announcement, argument: L10n.format("a11y.hud.stars.announce.format", newCount))
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
                            .accessibilityLabel(L10n.format("a11y.hud.region.format", flightVM.currentRegion))
                    }

                    Spacer()
                }
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 80, 80)) // Space for control buttons
            }
            }   // ← closes the wrapping ZStack (collision flash + VStack)
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
