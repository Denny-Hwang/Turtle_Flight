import Foundation
import os

private let log = Logger(subsystem: "com.turtleflight.app", category: "CloudSync")

/// Opt-in progress sync through iCloud Key-Value Storage.
///
/// Why KVS and not CloudKit: the whole progress blob is a few KB, KVS
/// needs no schema, no container setup beyond the entitlement, and it
/// merges by "last writer wins" per key — which we make safe by merging
/// the two blobs field by field (see `merge`) instead of replacing one
/// with the other. A
/// player who reinstalls or moves phones gets their stars back; a
/// player with two devices never has a newer device clobbered by an
/// older one.
///
/// Off by default so the "nothing leaves the device" promise holds until
/// the player flips the toggle. When on, the only thing that leaves is
/// the `PlayerProgress` JSON, to the player's own iCloud account.
/// Minimal seam over `NSUbiquitousKeyValueStore` for tests.
protocol KeyValueStoreLike: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    func synchronize() -> Bool
}

final class CloudSync {

    static let shared = CloudSync(store: nil)

    static let progressKey = "playerProgress.v1"

    private let store: KeyValueStoreLike?
    private var observer: NSObjectProtocol?
    /// Called on main when a remote blob was accepted, with the merged
    /// progress. MissionViewModel re-loads from it.
    var onRemoteProgress: ((PlayerProgress) -> Void)?

    init(store: KeyValueStoreLike?) {
        self.store = store
    }

    private var liveStore: KeyValueStoreLike {
        store ?? NSUbiquitousKeyValueStore.default
    }

    // MARK: - Lifecycle

    /// Begin observing remote changes and pull once.
    /// `local` is asked each time, so a change that arrives mid-session is
    /// compared with the progress as it is then, not as it was at launch.
    func start(local: @escaping () -> PlayerProgress) {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.pull(local: local())
        }
        _ = liveStore.synchronize()
        pull(local: local())
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    // MARK: - Sync

    /// Push the local blob merged with whatever is already in iCloud, so
    /// neither side's clears, purchases or treats are ever dropped.
    func push(_ progress: PlayerProgress) {
        var outgoing = progress
        if let remote = remoteProgress() {
            outgoing = Self.merge(local: progress, remote: remote)
            // Device-only switches don't travel.
            outgoing.kidsMode = remote.kidsMode
            if Self.same(outgoing, remote) {
                log.info("cloud push skipped: nothing new")
                return
            }
            outgoing.kidsMode = progress.kidsMode
        }
        guard let data = try? JSONEncoder().encode(outgoing) else { return }
        liveStore.set(data, forKey: Self.progressKey)
        _ = liveStore.synchronize()
    }

    /// Fold the remote blob into the local one. Returns the merged
    /// progress, and reports it through `onRemoteProgress` when the
    /// remote added anything.
    @discardableResult
    func pull(local: PlayerProgress) -> PlayerProgress {
        guard let remote = remoteProgress() else { return local }
        let merged = Self.merge(local: local, remote: remote)
        guard !Self.same(merged, local) else { return local }
        log.info("cloud pull: merged remote progress (\(merged.totalStars)★)")
        onRemoteProgress?(merged)
        return merged
    }

    /// Combine two saves without losing anything either one earned.
    ///
    /// Settings and counters come from whichever side is further along
    /// (`isAhead`). Everything that is a collection is combined: the best
    /// result per course, the union of owned items / opened courses /
    /// routes / used codes, and the larger of each balance. Kids mode is
    /// a per-device switch and always stays as it is locally.
    static func merge(local: PlayerProgress, remote: PlayerProgress) -> PlayerProgress {
        let remoteLeads = isAhead(remote, of: local)
        var out = remoteLeads ? remote : local
        let other = remoteLeads ? local : remote

        func best(_ a: [Int: StageResult], _ b: [Int: StageResult]) -> [Int: StageResult] {
            a.merging(b) { mine, theirs in theirs.stars > mine.stars ? theirs : mine }
        }
        out.stageResults = best(out.stageResults, other.stageResults)
        out.kidsResults = best(out.kidsResults, other.kidsResults)
        out.totalStars = max(out.totalStars, other.totalStars,
                             out.stageResults.values.reduce(0) { $0 + $1.stars })
        out.starsBanked = max(out.starsBanked, other.starsBanked)
        out.starsSpent = max(out.starsSpent, other.starsSpent)
        out.treats = out.treats.merging(other.treats) { max($0, $1) }
        out.ownedItems.formUnion(other.ownedItems)
        out.openedCourses.formUnion(other.openedCourses)
        out.unlockedRoutes.formUnion(other.unlockedRoutes)
        out.redeemedCodes.formUnion(other.redeemedCodes)
        out.kidsMode = local.kidsMode
        return out
    }

    /// Value equality through the encoded form (the blob isn't Equatable).
    static func same(_ a: PlayerProgress, _ b: PlayerProgress) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(a)) == (try? encoder.encode(b))
    }

    func remoteProgress() -> PlayerProgress? {
        guard let data = liveStore.data(forKey: Self.progressKey) else { return nil }
        return try? JSONDecoder().decode(PlayerProgress.self, from: data)
    }

    /// "a is ahead of b": strictly more campaign stars; ties broken by
    /// bonus stars, then lifetime flight time. Equal on all three → not
    /// ahead (so neither side clobbers the other).
    static func isAhead(_ a: PlayerProgress, of b: PlayerProgress) -> Bool {
        if a.totalStars != b.totalStars { return a.totalStars > b.totalStars }
        if a.bonusStars != b.bonusStars { return a.bonusStars > b.bonusStars }
        return a.totalFlightTime > b.totalFlightTime + 1
    }
}

extension NSUbiquitousKeyValueStore: KeyValueStoreLike {}
