import SwiftUI

/// Free Flight extras drawn over the scene: a compass chip pointing at
/// the nearest landmark this character has not visited, and one-shot
/// banners for postcards and hellos. Separate from `HUDOverlay` so it
/// stays up in "clean view".
struct SightseeingOverlay: View {
    @ObservedObject var flightVM: FlightViewModel
    @State private var shownToast: FlightViewModel.FlightToast?

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            if let toast = shownToast {
                toastView(toast)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            Spacer()
            if let hint = flightVM.landmarkHint {
                hintChip(hint)
                    .transition(.opacity)
            }
        }
        .padding(.top, HUDOverlay.controlRowClearance + Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.m)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.35), value: shownToast)
        .animation(.easeInOut(duration: 0.25), value: flightVM.landmarkHint)
        .allowsHitTesting(false)
        .onChange(of: flightVM.flightToast) { toast in
            guard let toast else { return }
            shownToast = toast
            let id = toast.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                if shownToast?.id == id { shownToast = nil }
            }
        }
    }

    private func hintChip(_ hint: FlightViewModel.LandmarkHint) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "location.north.fill")
                .rotationEffect(.radians(hint.bearing))
                .foregroundColor(Theme.Color.starGold)
            Image(systemName: hint.kind.symbol)
                .foregroundColor(Theme.Color.hudCyan)
            Text(L10n.format("landmark.hint.format", hint.kind.displayName, hint.distance))
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Color.textOnDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s - 2)
        .background(Capsule().fill(Theme.Color.surfaceOverlay))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("landmark.hint.format", hint.kind.displayName, hint.distance))
    }

    @ViewBuilder
    private func toastView(_ toast: FlightViewModel.FlightToast) -> some View {
        switch toast.kind {
        case .postcard(let kind, let isNew):
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: isNew ? "photo.on.rectangle.angled" : "seal.fill")
                Text(L10n.format(isNew ? "postcard.toast.new" : "postcard.toast.stamp", kind.displayName))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(Theme.Typography.titleSmall)
            .foregroundColor(Theme.Color.textPrimary)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background(Capsule().fill(Theme.Color.starGold))
            .elevation(Theme.Elevation.cardHigh)
        case .hello:
            Text(L10n.t("hello.toast"))
                .font(Theme.Typography.titleSmall)
                .foregroundColor(Theme.Color.textOnDark)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)
                .background(Capsule().fill(Theme.Color.brandPrimary))
        case .milestone(let world, let milestone):
            banner(symbol: milestone == .complete ? "party.popper.fill" : "rectangle.stack.fill",
                   text: L10n.format("postcard.milestone.toast.\(milestone.rawValue)", world.displayName, milestone.stars),
                   fill: Theme.Color.starGold, onDark: false)
        case .wonder(let wonder, _):
            banner(symbol: wonder.symbol,
                   text: L10n.format("wonder.toast.format", wonder.displayName),
                   fill: Theme.Color.surfaceOverlay, onDark: true)
        case .wonderBonus(_, let stars):
            banner(symbol: "star.fill",
                   text: L10n.format("wonder.bonus.toast", stars),
                   fill: Theme.Color.brandPrimary, onDark: true)
        case .ringTrail(let stars):
            banner(symbol: "circle.circle.fill",
                   text: L10n.format("ringtrail.toast.complete", stars),
                   fill: Theme.Color.brandPrimary, onDark: true)
        case .companion(let companion, let stars):
            banner(symbol: "bird.fill",
                   text: L10n.format("companion.toast", companion.displayName, stars),
                   fill: Theme.Color.brandPrimary, onDark: true)
        case .setPiece(let piece, let isNew, let stars):
            banner(symbol: Self.symbol(for: piece.effect),
                   text: Self.setPieceText(piece, isNew: isNew, stars: stars),
                   fill: isNew ? Theme.Color.starGold : Theme.Color.surfaceOverlay, onDark: !isNew)
        }
    }

    static func symbol(for effect: SetPiece.Effect) -> String {
        switch effect {
        case .passThrough: return "sparkles"
        case .lift:        return "wind"
        case .boost:       return "flame.fill"
        case .stars:       return "star.fill"
        }
    }

    static func setPieceText(_ piece: SetPiece, isNew: Bool, stars: Int) -> String {
        let name = piece.displayName
        if isNew {
            return stars > 0 ? L10n.format("setpiece.toast.newStars", name, stars)
                             : L10n.format("setpiece.toast.new", name)
        }
        switch piece.effect {
        case .stars:       return L10n.format("setpiece.toast.stars", name, stars)
        case .boost:       return L10n.t("setpiece.toast.boost")
        case .lift:        return L10n.t("setpiece.toast.lift")
        case .passThrough: return name
        }
    }

    private func banner(symbol: String, text: String, fill: Color, onDark: Bool) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: symbol)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(Theme.Typography.titleSmall)
        .foregroundColor(onDark ? Theme.Color.textOnDark : Theme.Color.textPrimary)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(Capsule().fill(fill))
        .elevation(Theme.Elevation.cardHigh)
        .accessibilityElement(children: .combine)
    }
}
