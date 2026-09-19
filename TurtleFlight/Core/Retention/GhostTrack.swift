import Foundation
import SceneKit

/// A recorded flight path: (time, position) samples at ~10 Hz. Small
/// enough to keep one per course (a 2-minute run is ~1,200 samples,
/// ~20 KB as JSON) and to replay as a translucent "ghost" of your own
/// best run — the cheapest possible rival for a solo precision game.
struct GhostTrack: Codable, Equatable {
    struct Sample: Codable, Equatable {
        let t: Float
        let x: Float
        let y: Float
        let z: Float
    }

    /// Identifies the course this ghost belongs to ("stage-2",
    /// "daily-2026-09-19").
    let courseKey: String
    /// Score the run achieved — the ghost only gets replaced by a run
    /// that beats it.
    let score: Int
    let completionTime: TimeInterval
    let character: CharacterType
    var samples: [Sample]

    var isEmpty: Bool { samples.isEmpty }
    var duration: Float { samples.last?.t ?? 0 }

    /// Interpolated position at `time` (clamped to the track's range).
    func position(at time: Float) -> SCNVector3? {
        guard let first = samples.first, let last = samples.last else { return nil }
        if time <= first.t { return SCNVector3(first.x, first.y, first.z) }
        if time >= last.t { return SCNVector3(last.x, last.y, last.z) }
        // Binary search for the segment containing `time`.
        var lo = 0
        var hi = samples.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if samples[mid].t <= time { lo = mid } else { hi = mid }
        }
        let a = samples[lo]
        let b = samples[hi]
        let span = b.t - a.t
        let u = span > 0 ? (time - a.t) / span : 0
        return SCNVector3(a.x + (b.x - a.x) * u,
                          a.y + (b.y - a.y) * u,
                          a.z + (b.z - a.z) * u)
    }
}

/// Accumulates samples during a run. Call `record(time:position:)` every
/// frame; it keeps one sample per `interval` seconds.
struct GhostRecorder {
    let interval: Float
    private(set) var samples: [GhostTrack.Sample] = []
    private var nextSampleTime: Float = 0

    init(interval: Float = 0.1) {
        self.interval = interval
    }

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        nextSampleTime = 0
    }

    mutating func record(time: Float, position: SCNVector3) {
        guard time >= nextSampleTime else { return }
        samples.append(.init(t: time, x: position.x, y: position.y, z: position.z))
        nextSampleTime = time + interval
    }

    func makeTrack(courseKey: String, score: Int, completionTime: TimeInterval,
                   character: CharacterType) -> GhostTrack {
        GhostTrack(courseKey: courseKey, score: score, completionTime: completionTime,
                   character: character, samples: samples)
    }
}

/// On-disk store: one JSON file per course key under
/// Application Support/ghosts. Replaced only by a higher-scoring run.
final class GhostStore {

    static let shared = GhostStore()

    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("ghosts", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory,
                                                 withIntermediateDirectories: true)
    }

    private func url(for key: String) -> URL {
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent(safe).appendingPathExtension("json")
    }

    func load(courseKey: String) -> GhostTrack? {
        guard let data = try? Data(contentsOf: url(for: courseKey)) else { return nil }
        return try? JSONDecoder().decode(GhostTrack.self, from: data)
    }

    /// Store `track` if it beats the existing ghost (or none exists).
    /// Returns true when it was written.
    @discardableResult
    func saveIfBetter(_ track: GhostTrack) -> Bool {
        guard !track.isEmpty else { return false }
        if let existing = load(courseKey: track.courseKey), existing.score >= track.score {
            return false
        }
        guard let data = try? JSONEncoder().encode(track) else { return false }
        return (try? data.write(to: url(for: track.courseKey), options: .atomic)) != nil
    }

    func delete(courseKey: String) {
        try? FileManager.default.removeItem(at: url(for: courseKey))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
