import Foundation

/// The player's collection of "sky postcards": one per landmark, stamped
/// by every character that has flown past it. Earned only by playing —
/// there is nothing to buy and nothing random.
///
/// Stored on-device in `UserDefaults` (`postcards.v1`); nothing leaves
/// the phone. Thread-safe, because discovery happens on the SceneKit
/// render thread while the album screen reads on main.
/// `@unchecked Sendable`: every stored property is read and written under `lock`.
final class PostcardAlbum: @unchecked Sendable {
    static let shared = PostcardAlbum()

    private let defaults: UserDefaults
    private let key = "postcards.v1"
    private let lock = NSLock()
    /// `LandmarkKind.rawValue` → `CharacterType.rawValue`s, in visit order.
    private var stamps: [String: [String]]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.stamps = (defaults.dictionary(forKey: key) as? [String: [String]]) ?? [:]
    }

    /// What a visit added to the album.
    enum Visit: Equatable {
        /// First time anyone found this landmark.
        case newPostcard
        /// The postcard existed; this character had not been here yet.
        case newStamp
        case alreadyStamped
    }

    @discardableResult
    func recordVisit(_ landmark: LandmarkKind, by character: CharacterType) -> Visit {
        lock.lock()
        defer { lock.unlock() }
        var visitors = stamps[landmark.rawValue] ?? []
        guard !visitors.contains(character.rawValue) else { return .alreadyStamped }
        let result: Visit = visitors.isEmpty ? .newPostcard : .newStamp
        visitors.append(character.rawValue)
        stamps[landmark.rawValue] = visitors
        defaults.set(stamps, forKey: key)
        return result
    }

    func hasPostcard(_ landmark: LandmarkKind) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !(stamps[landmark.rawValue] ?? []).isEmpty
    }

    func hasStamp(_ landmark: LandmarkKind, by character: CharacterType) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return (stamps[landmark.rawValue] ?? []).contains(character.rawValue)
    }

    func visitors(of landmark: LandmarkKind) -> [CharacterType] {
        lock.lock(); defer { lock.unlock() }
        return (stamps[landmark.rawValue] ?? []).compactMap(CharacterType.init(rawValue:))
    }

    /// Postcards collected (distinct landmarks).
    var postcardCount: Int {
        lock.lock(); defer { lock.unlock() }
        return LandmarkKind.allCases.filter { !(stamps[$0.rawValue] ?? []).isEmpty }.count
    }

    func postcardCount(in world: MapTheme) -> Int {
        LandmarkKind.kinds(in: world).filter(hasPostcard).count
    }

    static var totalPostcards: Int { LandmarkKind.allCases.count }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        stamps = [:]
        defaults.removeObject(forKey: key)
    }
}
