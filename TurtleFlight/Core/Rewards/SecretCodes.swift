import Foundation
import CryptoKit

/// Free promo codes typed into Settings.
///
/// Everything a code gives can also be earned by playing, nothing is
/// sold, and the check is fully offline. The app only carries salted
/// hashes of the codes — the words themselves never go in the
/// repository (it has been public before).
enum SecretCodes {

    /// Flip to false to hide the code field everywhere (e.g. if App
    /// Review objects to it).
    static let isEnabled = true

    enum Reward: Equatable {
        case unlockRoute(RouteID)
        case stars(Int)
        case treatsForAll(Int)
        case item(String)
        case starterPack(stars: Int, treats: Int)
    }

    struct Entry: Equatable {
        /// Hex SHA-256 of `salt + normalised code`. Doubles as the id
        /// stored in `PlayerProgress.redeemedCodes`.
        let hash: String
        let reward: Reward
    }

    enum Outcome: Equatable {
        case accepted(Reward)
        case alreadyUsed
        case unknown
    }

    static let salt = "turtleflight.code.v1:"

    static let entries: [Entry] = [
        Entry(hash: "f939c10ae07e6fad93013c07b880017fc4109a21dd970dfa281ca1dda82064cb",
              reward: .unlockRoute(.starRoad)),
        Entry(hash: "289169dab733724bf0a836c2abd463b2b785540152e62430268945991a295fa3",
              reward: .stars(30)),
        Entry(hash: "074a80963b077ffbbe14b3973aae0bcd411a2ce99bc8422dfd33c1a7ccd9ba39",
              reward: .treatsForAll(15)),
        Entry(hash: "7406b1945e6e71b24fbbced4396dba7834619cafe1da300b8a47d803b2f75fd5",
              reward: .item(Shop.cometID)),
        Entry(hash: "dfc00850a90bc23bda1878a8978f43cb8adbb8f8c51bdcc223f579d5af503bf0",
              reward: .starterPack(stars: 10, treats: 5))
    ]

    /// Upper-case letters and digits only, so "sky friend", "Sky-Friend"
    /// and "SKYFRIEND" are the same code.
    static func normalise(_ raw: String) -> String {
        // Japanese / Chinese keyboards may type full-width letters.
        let folded = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
        return String(folded.uppercased().unicodeScalars.filter {
            ("A"..."Z").contains($0) || ("0"..."9").contains($0)
        }.map(Character.init))
    }

    static func hash(_ raw: String) -> String {
        let digest = SHA256.hash(data: Data((salt + normalise(raw)).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Check `raw` and, when it is a fresh valid code, pay it into
    /// `progress`.
    static func redeem(_ raw: String, into progress: inout PlayerProgress,
                       entries: [Entry] = SecretCodes.entries) -> Outcome {
        let normalised = normalise(raw)
        guard !normalised.isEmpty, normalised.count <= 24 else { return .unknown }
        let digest = hash(raw)
        guard let entry = entries.first(where: { $0.hash == digest }) else { return .unknown }
        guard !progress.redeemedCodes.contains(entry.hash) else { return .alreadyUsed }
        progress.redeemedCodes.insert(entry.hash)
        apply(entry.reward, to: &progress)
        return .accepted(entry.reward)
    }

    private static func apply(_ reward: Reward, to progress: inout PlayerProgress) {
        switch reward {
        case .unlockRoute(let route):
            progress.unlockedRoutes.insert(route.rawValue)
        case .stars(let count):
            progress.earnStars(count)
        case .treatsForAll(let count):
            for character in CharacterType.allCases { progress.earnTreats(count, for: character) }
        case .item(let id):
            progress.ownedItems.insert(id)
        case .starterPack(let stars, let treats):
            progress.earnStars(stars)
            for character in CharacterType.allCases { progress.earnTreats(treats, for: character) }
        }
    }

    /// One line telling the player what they just got.
    static func message(for reward: Reward) -> String {
        switch reward {
        case .unlockRoute(let route):
            return L10n.format("code.reward.route", route.displayName)
        case .stars(let count):
            return L10n.format("code.reward.stars", count)
        case .treatsForAll(let count):
            return L10n.format("code.reward.treats", count)
        case .item:
            return L10n.t("code.reward.comet")
        case .starterPack(let stars, let treats):
            return L10n.format("code.reward.starter", stars, treats)
        }
    }
}
