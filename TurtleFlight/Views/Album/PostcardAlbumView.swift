import SwiftUI

/// The postcard collection: every landmark, grouped by world. A found
/// landmark shows its picture card and the friends who have stamped
/// it; an unfound one shows only its world, so there is something to
/// look forward to without spoiling the name.
struct PostcardAlbumView: View {
    @Binding var isPresented: Bool
    @ObservedObject var missionVM: MissionViewModel
    private let album = PostcardAlbum.shared
    private let wonders = WonderLog.shared

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.m)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Text(L10n.t("album.empty.hint"))
                        .font(Theme.Typography.label)
                        .foregroundColor(.secondary)

                    ForEach(MapTheme.allCases, id: \.self) { world in
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            HStack {
                                Text("\(world.emoji)  \(world.displayName)")
                                    .font(Theme.Typography.titleSmall)
                                Spacer()
                                Text("\(album.postcardCount(in: world))/\(LandmarkKind.kinds(in: world).count)")
                                    .font(Theme.Typography.label)
                                    .foregroundColor(.secondary)
                            }
                            milestoneRow(world)
                            LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                                ForEach(LandmarkKind.kinds(in: world), id: \.self) { kind in
                                    PostcardCard(kind: kind, visitors: album.visitors(of: kind))
                                }
                            }
                        }
                    }

                    wondersSection
                }
                .padding(Theme.Spacing.l)
            }
            .navigationTitle(L10n.t("album.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(L10n.t("album.title")).font(.headline)
                        Text(L10n.format("album.progress.format", album.postcardCount, PostcardAlbum.totalPostcards))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { isPresented = false }
                }
            }
        }
    }
}

extension PostcardAlbumView {

    /// "½ +5 ⭐ · 🎉 Festival +10 ⭐" with what is reached ticked, and the
    /// Festival switch once the world is complete.
    @ViewBuilder
    func milestoneRow(_ world: MapTheme) -> some View {
        let found = album.postcardCount(in: world)
        let total = LandmarkKind.kinds(in: world).count
        HStack(spacing: Theme.Spacing.m) {
            ForEach(PostcardMilestone.allCases, id: \.self) { milestone in
                let reached = found >= milestone.required(of: total)
                Label(L10n.format("album.milestone.\(milestone.rawValue).format", milestone.stars),
                      systemImage: reached ? "checkmark.seal.fill" : "seal")
                    .font(Theme.Typography.labelSmall)
                    .foregroundColor(reached ? Theme.Color.easyGreen : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
            if PostcardRewards.isFestivalUnlocked(world, album: album) {
                Toggle(L10n.t("album.festival.toggle"), isOn: Binding(
                    get: { missionVM.progress.festivalEnabled(in: world, album: album) },
                    set: { missionVM.setFestival($0, in: world) }
                ))
                .font(Theme.Typography.labelSmall)
                .fixedSize()
            }
        }
    }

    /// Rare sights from Free Flight. Unseen ones stay a mystery.
    var wondersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("✨  \(L10n.t("album.wonders.title"))")
                    .font(Theme.Typography.titleSmall)
                Spacer()
                Text("\(wonders.seenCount)/\(SkyWonder.allCases.count)")
                    .font(Theme.Typography.label)
                    .foregroundColor(.secondary)
            }
            Text(L10n.t("album.wonders.hint"))
                .font(Theme.Typography.labelSmall)
                .foregroundColor(.secondary)
            LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                ForEach(SkyWonder.allCases, id: \.self) { wonder in
                    let seen = wonders.hasSeen(wonder)
                    VStack(spacing: Theme.Spacing.xs) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.Radius.m)
                                .fill(LinearGradient(colors: seen ? [Color(red: 0.16, green: 0.20, blue: 0.45), Color(red: 0.45, green: 0.35, blue: 0.75)]
                                                              : [Color.gray.opacity(0.35), Color.gray.opacity(0.2)],
                                                     startPoint: .top, endPoint: .bottom))
                            Image(systemName: seen ? wonder.symbol : "questionmark")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white.opacity(seen ? 0.95 : 0.6))
                        }
                        .frame(height: 78)
                        Text(seen ? wonder.displayName : L10n.t("album.undiscovered"))
                            .font(Theme.Typography.labelSmall)
                            .foregroundColor(seen ? .primary : .secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .padding(Theme.Spacing.s)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.l).fill(Color(.secondarySystemBackground)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(seen ? wonder.displayName : L10n.t("album.undiscovered"))
                }
            }
        }
    }
}

struct PostcardCard: View {
    let kind: LandmarkKind
    let visitors: [CharacterType]

    private var found: Bool { !visitors.isEmpty }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .fill(LinearGradient(colors: found ? kind.world.uiGradient : [Color.gray.opacity(0.35), Color.gray.opacity(0.2)],
                                         startPoint: .top, endPoint: .bottom))
                Image(systemName: found ? kind.symbol : "questionmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white.opacity(found ? 0.95 : 0.6))
                    .shadow(radius: found ? 3 : 0)
            }
            .frame(height: 78)
            .overlay(alignment: .bottomTrailing) {
                // Stamps: one little portrait per friend who visited.
                HStack(spacing: -6) {
                    ForEach(visitors, id: \.self) { character in
                        Image("\(character.assetPrefix)_icon")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(.white))
                            .clipShape(Circle())
                    }
                }
                .padding(Theme.Spacing.xs)
            }

            Text(found ? kind.displayName : L10n.t("album.undiscovered"))
                .font(Theme.Typography.labelSmall)
                .foregroundColor(found ? .primary : .secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .padding(Theme.Spacing.s)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.l).fill(Color(.secondarySystemBackground)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(found ? kind.displayName : L10n.t("album.undiscovered"))
    }
}
