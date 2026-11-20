import UIKit

// MARK: - Treats

/// Every animal collects its own favourite snack by flying. Treats buy
/// that character's own trails; stars (shared by everyone) buy different
/// things — see `Shop`.
extension CharacterType {
    var treatEmoji: String {
        switch self {
        case .turtle:  return "🥬"
        case .penguin: return "🐟"
        case .hamster: return "🌻"
        case .cat:     return "🧶"
        case .frog:    return "✨"
        case .bunny:   return "🥕"
        }
    }

    var treatName: String { L10n.t("treat.\(rawValue).name") }

    /// Colour family the character's treat trails are drawn from.
    fileprivate var treatHue: CGFloat {
        switch self {
        case .turtle:  return 0.30
        case .penguin: return 0.55
        case .hamster: return 0.13
        case .cat:     return 0.88
        case .frog:    return 0.19
        case .bunny:   return 0.07
        }
    }
}

// MARK: - Shop

/// How a trail bought in the shop looks.
struct TrailLook: Equatable {
    let color: UIColor
    /// ± hue wobble per particle (0 = one flat colour).
    var hueSpread: Float = 0
}

struct ShopItem: Identifiable, Equatable {
    enum Currency: Equatable {
        case stars
        case treat(CharacterType)
    }
    enum Kind: Equatable {
        /// Lets the player choose this sky for Free Flight.
        case sky(SkyMood)
        /// A trail for one character (nil = everyone; code reward only).
        case flair(tier: Int, character: CharacterType?)
    }
    let id: String
    let price: Int
    let currency: Currency
    let kind: Kind

    var displayName: String {
        switch kind {
        case .sky(let mood):
            return L10n.t("shop.sky.\(mood.rawValue)")
        case .flair(let tier, let character):
            guard let character else { return L10n.t("shop.flair.comet") }
            return L10n.format("shop.flair.nameFormat", character.treatName, L10n.t("shop.flair.tier\(tier)"))
        }
    }

    var trailLook: TrailLook? {
        guard case .flair(let tier, let character) = kind else { return nil }
        guard let character else {
            return TrailLook(color: UIColor(red: 0.75, green: 0.95, blue: 1.0, alpha: 1), hueSpread: 0.06)
        }
        let hue = character.treatHue
        switch tier {
        case 1:  return TrailLook(color: UIColor(hue: hue, saturation: 0.85, brightness: 1.0, alpha: 1))
        case 2:  return TrailLook(color: UIColor(hue: hue, saturation: 0.40, brightness: 1.0, alpha: 1))
        default: return TrailLook(color: UIColor(hue: hue, saturation: 0.75, brightness: 1.0, alpha: 1),
                                  hueSpread: 0.14)
        }
    }
}

enum Shop {
    static let flairPrices = [6, 14, 28]
    /// Free with a secret code; never sold.
    static let cometID = "flair.comet"

    /// Bought with stars (shared by all characters).
    static let starItems: [ShopItem] = [
        ShopItem(id: "sky.morning", price: 10, currency: .stars, kind: .sky(.morning)),
        ShopItem(id: "sky.sunset",  price: 15, currency: .stars, kind: .sky(.sunset)),
        ShopItem(id: "sky.night",   price: 20, currency: .stars, kind: .sky(.night))
    ]

    /// Bought with `character`'s own treats.
    static func treatItems(for character: CharacterType) -> [ShopItem] {
        flairPrices.enumerated().map { offset, price in
            ShopItem(id: "flair.\(character.rawValue).\(offset + 1)", price: price,
                     currency: .treat(character),
                     kind: .flair(tier: offset + 1, character: character))
        }
    }

    static let comet = ShopItem(id: cometID, price: 0, currency: .stars,
                                kind: .flair(tier: 3, character: nil))

    static func item(id: String) -> ShopItem? {
        if id == cometID { return comet }
        if let found = starItems.first(where: { $0.id == id }) { return found }
        for character in CharacterType.allCases {
            if let found = treatItems(for: character).first(where: { $0.id == id }) { return found }
        }
        return nil
    }
}

// MARK: - Earning

enum RewardRules {
    /// Treats for clearing a course (campaign, route or daily).
    static func treats(forCourse result: StageResult) -> Int {
        1 + result.stars + min(3, (result.bullseyes ?? 0) / 2)
    }
    /// Treats for a Sky Run.
    static func treats(forEndlessRings rings: Int) -> Int { min(8, rings / 5) }
    /// Treats for a Free Flight.
    static func treats(forFreeFlightStars stars: Int) -> Int { min(6, stars / 3) }
}

/// What the last flight paid out; the result screens show it.
struct RewardGrant: Equatable {
    var stars = 0
    var treats = 0
    var character: CharacterType?
    var isEmpty: Bool { stars == 0 && treats == 0 }

    /// "+2 ⭐  +4 🥕" for the result screens.
    var summary: String {
        var parts: [String] = []
        if stars > 0 { parts.append("+\(stars) ⭐") }
        if treats > 0, let character { parts.append("+\(treats) \(character.treatEmoji)") }
        return parts.joined(separator: "   ")
    }

    var accessibilityText: String {
        L10n.format("reward.a11y.format", stars, treats, character?.treatName ?? "")
    }
}

// MARK: - Wallet, purchases and unlocks

extension PlayerProgress {

    /// Stars available to spend. Spending never lowers `effectiveStars`,
    /// so trail tiers earned by star count stay earned.
    var starBalance: Int { max(0, starsBanked - starsSpent) }

    func treatBalance(_ character: CharacterType) -> Int {
        treats[character.rawValue] ?? 0
    }

    mutating func earnStars(_ count: Int) {
        guard count > 0 else { return }
        starsBanked += count
    }

    mutating func earnTreats(_ count: Int, for character: CharacterType) {
        guard count > 0 else { return }
        treats[character.rawValue, default: 0] += count
    }

    func owns(_ item: ShopItem) -> Bool { ownedItems.contains(item.id) }

    func canAfford(_ item: ShopItem) -> Bool {
        switch item.currency {
        case .stars:               return starBalance >= item.price
        case .treat(let character): return treatBalance(character) >= item.price
        }
    }

    /// Buy `item`. False (and nothing changes) when already owned or too
    /// expensive.
    @discardableResult
    mutating func buy(_ item: ShopItem) -> Bool {
        guard !owns(item), canAfford(item) else { return false }
        switch item.currency {
        case .stars:
            starsSpent += item.price
        case .treat(let character):
            treats[character.rawValue, default: 0] -= item.price
        }
        ownedItems.insert(item.id)
        return true
    }

    // MARK: Equipped cosmetics

    /// Trail the character flies with, if they have one equipped and
    /// still own it.
    func equippedFlair(for character: CharacterType) -> ShopItem? {
        guard let id = equippedFlair[character.rawValue], ownedItems.contains(id),
              let item = Shop.item(id: id),
              case .flair(_, let owner) = item.kind,
              owner == nil || owner == character else { return nil }
        return item
    }

    mutating func equipFlair(_ item: ShopItem?, for character: CharacterType) {
        guard let item else {
            equippedFlair[character.rawValue] = nil
            return
        }
        guard owns(item), case .flair(_, let owner) = item.kind,
              owner == nil || owner == character else { return }
        equippedFlair[character.rawValue] = item.id
    }

    /// Sky the player pinned for Free Flight (nil = surprise me).
    var pinnedSky: SkyMood? {
        guard let raw = preferredSky, let mood = SkyMood(rawValue: raw),
              ownedItems.contains("sky.\(raw)") else { return nil }
        return mood
    }

    mutating func pinSky(_ mood: SkyMood?) {
        guard let mood else { preferredSky = nil; return }
        guard ownedItems.contains("sky.\(mood.rawValue)") else { return }
        preferredSky = mood.rawValue
    }

    // MARK: Routes

    func isCourseCleared(_ index: Int) -> Bool {
        stageResults[index]?.isCompleted == true
    }

    /// A route is open from the start, except the finale: that needs
    /// every other route finished, or a secret code.
    func isRouteUnlocked(_ route: RouteID) -> Bool {
        guard route.isFinale else { return true }
        if unlockedRoutes.contains(route.rawValue) { return true }
        return RouteID.allCases.filter { !$0.isFinale }.allSatisfy { other in
            guard let last = RouteCatalog.courses(in: other).last else { return true }
            return isCourseCleared(last.index)
        }
    }

    /// First course of an open route is always playable; after that the
    /// previous course has to be cleared (or the course opened with stars).
    func isCourseUnlocked(_ index: Int) -> Bool {
        guard let here = RouteCatalog.location(of: index) else { return false }
        guard isRouteUnlocked(here.route) else { return false }
        if here.step == 0 || openedCourses.contains(index) { return true }
        return isCourseCleared(RouteCatalog.courses(in: here.route)[here.step - 1].index)
    }

    /// True for the one locked course per route that stars can open:
    /// the next in line on a route that is itself open.
    func canOpenEarly(_ index: Int) -> Bool {
        guard let here = RouteCatalog.location(of: index), here.step > 0,
              isRouteUnlocked(here.route), !isCourseUnlocked(index) else { return false }
        return isCourseUnlocked(RouteCatalog.courses(in: here.route)[here.step - 1].index)
    }

    @discardableResult
    mutating func openCourseEarly(_ index: Int) -> Bool {
        guard canOpenEarly(index), starBalance >= RouteCatalog.earlyOpenPrice else { return false }
        starsSpent += RouteCatalog.earlyOpenPrice
        openedCourses.insert(index)
        return true
    }
}
