import SwiftUI

/// Two shelves that take two different currencies:
///   • stars (shared by every character) buy Free Flight skies,
///   • a character's own treats buy that character's trails.
/// Nothing here costs real money.
struct ShopView: View {
    @Binding var isPresented: Bool
    @ObservedObject var missionVM: MissionViewModel
    @State var character: CharacterType

    private var progress: PlayerProgress { missionVM.progress }

    var body: some View {
        NavigationStack {
            List {
                starShelf
                treatShelf
                if SecretCodes.isEnabled {
                    Section {
                        SecretCodeField(missionVM: missionVM)
                    } header: {
                        Text(L10n.t("code.title"))
                    } footer: {
                        Text(L10n.t("code.caption"))
                    }
                }
            }
            .navigationTitle(L10n.t("shop.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { isPresented = false }
                }
            }
        }
    }

    // MARK: Stars

    private var starShelf: some View {
        Section {
            skyRow(mood: nil)
            ForEach(Shop.starItems) { item in
                if case .sky(let mood) = item.kind {
                    if progress.owns(item) {
                        skyRow(mood: mood)
                    } else {
                        buyRow(item, icon: "⭐", balance: progress.starBalance)
                    }
                }
            }
        } header: {
            HStack {
                Text(L10n.t("shop.tab.stars"))
                Spacer()
                Text("⭐ \(progress.starBalance)")
                    .accessibilityLabel(L10n.format("shop.wallet.a11y", progress.starBalance))
            }
        } footer: {
            Text(L10n.t("shop.stars.caption"))
        }
    }

    /// An owned sky (or "surprise me"): tap to pin it for Free Flight.
    private func skyRow(mood: SkyMood?) -> some View {
        let selected = progress.pinnedSky == mood
        return Button {
            Haptics.shared.play(.tap)
            missionVM.pinSky(mood)
        } label: {
            HStack {
                Text(mood.map { L10n.t("shop.sky.\($0.rawValue)") } ?? L10n.t("shop.sky.auto"))
                    .foregroundColor(.primary)
                Spacer()
                if selected {
                    Label(L10n.t("shop.equipped"), systemImage: "checkmark.circle.fill")
                        .foregroundColor(Theme.Color.easyGreen)
                } else {
                    Text(L10n.t("shop.equip")).foregroundColor(.accentColor)
                }
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Treats

    private var treatShelf: some View {
        Section {
            Picker(L10n.t("shop.tab.treats"), selection: $character) {
                ForEach(CharacterType.allCases, id: \.self) { type in
                    Text("\(type.treatEmoji) \(progress.treatBalance(type))").tag(type)
                }
            }
            .pickerStyle(.segmented)

            flairRow(item: nil)
            ForEach(Shop.treatItems(for: character)) { item in
                if progress.owns(item) {
                    flairRow(item: item)
                } else {
                    buyRow(item, icon: character.treatEmoji, balance: progress.treatBalance(character))
                }
            }
            if progress.owns(Shop.comet) { flairRow(item: Shop.comet) }
        } header: {
            HStack {
                Text(L10n.t("shop.tab.treats"))
                Spacer()
                Text("\(character.treatEmoji) \(progress.treatBalance(character))")
            }
        } footer: {
            Text(L10n.format("shop.treats.caption", character.treatName))
        }
    }

    /// An owned trail (or the vehicle's own): tap to fly with it.
    private func flairRow(item: ShopItem?) -> some View {
        let selected = progress.equippedFlair(for: character)?.id == item?.id
        return Button {
            Haptics.shared.play(.tap)
            missionVM.equipFlair(item, for: character)
        } label: {
            HStack {
                swatch(item?.trailLook)
                Text(item?.displayName ?? L10n.t("shop.flair.none"))
                    .foregroundColor(.primary)
                Spacer()
                if selected {
                    Label(L10n.t("shop.equipped"), systemImage: "checkmark.circle.fill")
                        .foregroundColor(Theme.Color.easyGreen)
                } else {
                    Text(L10n.t("shop.equip")).foregroundColor(.accentColor)
                }
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func buyRow(_ item: ShopItem, icon: String, balance: Int) -> some View {
        let affordable = progress.canAfford(item)
        return HStack {
            swatch(item.trailLook)
            Text(item.displayName)
            Spacer()
            Button {
                missionVM.buy(item)
            } label: {
                Text("\(icon) \(item.price)")
                    .font(Theme.Typography.label)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Color.brandPrimary)
            .disabled(!affordable)
            .accessibilityLabel(L10n.format("shop.buy.a11y", item.displayName, item.price))
            .accessibilityHint(affordable ? "" : L10n.format("shop.notEnough", balance, item.price))
        }
    }

    @ViewBuilder private func swatch(_ look: TrailLook?) -> some View {
        if let look {
            Circle()
                .fill(Color(look.color))
                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
        }
    }
}

/// Text field + button for a secret code, with the answer underneath.
struct SecretCodeField: View {
    @ObservedObject var missionVM: MissionViewModel
    @State private var text = ""
    @State private var message: String?
    @State private var accepted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                TextField(L10n.t("code.placeholder"), text: $text)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(redeem)
                Button(L10n.t("code.redeem"), action: redeem)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Color.brandPrimary)
                    .disabled(SecretCodes.normalise(text).isEmpty)
            }
            if let message {
                Label(message, systemImage: accepted ? "gift.fill" : "xmark.circle")
                    .font(Theme.Typography.label)
                    .foregroundColor(accepted ? Theme.Color.easyGreen : .secondary)
            }
        }
    }

    private func redeem() {
        switch missionVM.redeemCode(text) {
        case .accepted(let reward):
            accepted = true
            message = SecretCodes.message(for: reward)
            text = ""
        case .alreadyUsed:
            accepted = false
            message = L10n.t("code.result.used")
        case .unknown:
            accepted = false
            message = L10n.t("code.result.unknown")
        }
    }
}

/// The code field on its own, for the locked Star Road card.
struct SecretCodeSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var missionVM: MissionViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecretCodeField(missionVM: missionVM)
                } footer: {
                    Text(L10n.t("code.caption"))
                }
            }
            .navigationTitle(L10n.t("code.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { isPresented = false }
                }
            }
        }
    }
}
