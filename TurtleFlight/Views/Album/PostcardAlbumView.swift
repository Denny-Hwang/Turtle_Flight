import SwiftUI

/// The postcard collection: every landmark, grouped by world. A found
/// landmark shows its picture card and the friends who have stamped
/// it; an unfound one shows only its world, so there is something to
/// look forward to without spoiling the name.
struct PostcardAlbumView: View {
    @Binding var isPresented: Bool
    private let album = PostcardAlbum.shared

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
                            LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                                ForEach(LandmarkKind.kinds(in: world), id: \.self) { kind in
                                    PostcardCard(kind: kind, visitors: album.visitors(of: kind))
                                }
                            }
                        }
                    }
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
