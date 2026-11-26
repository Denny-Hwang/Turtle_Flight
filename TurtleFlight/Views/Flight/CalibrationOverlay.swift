import SwiftUI

/// Start-of-flight calibration: "hold the phone the way you like". The
/// world waits underneath (`FlightViewModel.isCalibrating`) until the
/// phone has been still for a moment, then the pose becomes neutral.
/// The ring fills while the phone is still; "Start now" takes the current
/// pose straight away.
struct CalibrationOverlay: View {
    @ObservedObject var gyro: GyroController
    let onStartNow: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .stroke(Theme.Color.textOnDark.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: gyro.calibrationProgress)
                    .stroke(Theme.Color.brandPrimary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: gyro.calibrationProgress)
                Image(systemName: "iphone.landscape")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(Theme.Color.textOnDark)
            }
            .frame(width: 72, height: 72)
            .accessibilityHidden(true)

            Text(L10n.t("flight.calibrate.title"))
                .font(Theme.Typography.titleDynamic)
                .foregroundColor(Theme.Color.textOnDark)
                .multilineTextAlignment(.center)

            Text(L10n.t("flight.calibrate.body"))
                .font(Theme.Typography.bodyDynamic)
                .foregroundColor(Theme.Color.textOnDarkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onStartNow) {
                Text(L10n.t("flight.calibrate.now"))
                    .font(Theme.Typography.button)
                    .foregroundColor(Theme.Color.textPrimary)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.m)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Theme.Color.brandPrimary))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 380)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl)
                .fill(Theme.Color.surfacePanel)
        )
        .accessibilityElement(children: .contain)
        .deviceCanvas()
    }
}
