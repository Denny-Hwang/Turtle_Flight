import Foundation
import os

private let log = Logger(subsystem: "com.turtleflight.app", category: "CloudSync")

/// Opt-in progress sync through iCloud Key-Value Storage.
///
/// Why KVS and not CloudKit: the whole progress blob is a few KB, KVS
/// needs no schema, no container setup beyond the entitlement, and it
/// merges by "last writer wins" per key — which we make safe by only
/// ever accepting a remote blob that is *ahead* of the local one (more
/// campaign stars, then more bonus stars, then more flight time). A
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
    func start(local: PlayerProgress) {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.pull(local: local)
        }
        _ = liveStore.synchronize()
        pull(local: local)
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    // MARK: - Sync

    /// Push the local blob if it is at least as far along as the remote.
    func push(_ progress: PlayerProgress) {
        if let remote = remoteProgress(), Self.isAhead(remote, of: progress) {
            log.info("cloud push skipped: remote is ahead")
            return
        }
        guard let data = try? JSONEncoder().encode(progress) else { return }
        liveStore.set(data, forKey: Self.progressKey)
        _ = liveStore.synchronize()
    }

    /// Accept the remote blob when it is strictly ahead of the local one.
    /// Returns the merged progress (remote, or local when unchanged).
    @discardableResult
    func pull(local: PlayerProgress) -> PlayerProgress {
        guard let remote = remoteProgress() else { return local }
        guard Self.isAhead(remote, of: local) else { return local }
        log.info("cloud pull: accepting remote progress (\(remote.totalStars)★)")
        onRemoteProgress?(remote)
        return remote
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
