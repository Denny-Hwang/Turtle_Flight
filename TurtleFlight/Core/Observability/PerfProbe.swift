import Foundation
import QuartzCore
import SceneKit

/// On-device performance log for device verification (A3 in
/// docs/LAUNCH_POLISH_PLAN.md, B0 in benchmark/PLAN.md). Off unless the
/// app is launched with `-TFPerfProbe YES`; then once a second it appends
/// one CSV line to `Documents/perf.csv`, which `scripts/device/verify.sh`
/// copies off the phone. Nothing leaves the device on its own.
///
/// Columns (`PerfWindow.header`):
/// - frames per second, worst frame time, memory footprint, thermal state;
/// - terrain work in that second: detailed chunks built, the slowest
///   chunk build, the slowest far-terrain rebuild (both on the render
///   thread, which is where hitches come from);
/// - the last scene snapshot (taken every `sceneInterval` seconds):
///   visible nodes, triangles, draw elements, particle systems.
///   These are scene *content*, not what survived frustum culling. They
///   show what grows, not the exact GPU load.
///
/// `@unchecked Sendable`: every stored property is guarded by `lock`.
/// `frame(at:sceneRoot:)` runs on the SceneKit render thread; `measure`
/// can also run on main (the first chunks are built in `startFlight`).
final class PerfProbe: @unchecked Sendable {
    static let shared = PerfProbe()

    static let isEnabled = UserDefaults.standard.bool(forKey: "TFPerfProbe")
    /// Seconds between scene snapshots (walking the graph costs ~1 ms).
    static let sceneInterval: TimeInterval = 10

    enum Work { case chunk, farTerrain }

    private let lock = NSLock()
    private var window = PerfWindow()
    private var windowStart: TimeInterval = 0
    private var lastFrame: TimeInterval = 0
    private var startedAt: TimeInterval = 0
    private var lastSnapshot: TimeInterval = -.infinity
    private var handle: FileHandle?

    static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("perf.csv")
    }

    /// Call once per rendered frame with the renderer's timestamp.
    /// `sceneRoot` is only evaluated when a snapshot is due.
    func frame(at time: TimeInterval, sceneRoot: @autoclosure () -> SCNNode? = nil) {
        guard Self.isEnabled else { return }
        lock.lock()
        defer { lock.unlock() }
        if startedAt == 0 {
            startedAt = time
            windowStart = time
            lastFrame = time
            openFile()
            return
        }
        window.frame(interval: time - lastFrame)
        lastFrame = time
        if time - lastSnapshot >= Self.sceneInterval, let root = sceneRoot() {
            window.scene = SceneStats.collect(root)
            lastSnapshot = time
        }
        guard time - windowStart >= 1 else { return }
        let line = window.line(seconds: time - startedAt, elapsed: time - windowStart,
                               memoryMB: Self.footprintMB(),
                               thermal: ProcessInfo.processInfo.thermalState.rawValue)
        handle?.write(Data(line.utf8))
        window.reset()
        windowStart = time
    }

    /// Runs `body`, and when the probe is on, files its duration under `work`.
    @discardableResult
    func measure<T>(_ work: Work, _ body: () -> T) -> T {
        guard Self.isEnabled else { return body() }
        let start = CACurrentMediaTime()
        let result = body()
        let ms = (CACurrentMediaTime() - start) * 1000
        lock.lock()
        window.add(work, ms: ms)
        lock.unlock()
        return result
    }

    private func openFile() {
        let url = Self.fileURL
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let header = "# \(machine) \(os)\n\(PerfWindow.header)\n"
        try? Data(header.utf8).write(to: url)
        handle = try? FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
    }

    /// Physical memory footprint — the number Xcode's memory gauge and
    /// the jetsam limit use.
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }
}

/// One second of probe data. A value type so tests can drive it without
/// a renderer.
struct PerfWindow: Equatable {
    static let header = "seconds,fps,worst_frame_ms,memory_mb,thermal_state,"
        + "chunk_builds,chunk_worst_ms,far_worst_ms,"
        + "scene_nodes,scene_triangles,scene_draws,scene_particles"

    var frames = 0
    var worstFrame: TimeInterval = 0
    var chunkBuilds = 0
    var chunkWorstMs: Double = 0
    var farWorstMs: Double = 0
    /// Last snapshot; carried over between windows.
    var scene = SceneStats()

    mutating func frame(interval: TimeInterval) {
        frames += 1
        worstFrame = max(worstFrame, interval)
    }

    mutating func add(_ work: PerfProbe.Work, ms: Double) {
        switch work {
        case .chunk:
            chunkBuilds += 1
            chunkWorstMs = max(chunkWorstMs, ms)
        case .farTerrain:
            farWorstMs = max(farWorstMs, ms)
        }
    }

    /// Clears the per-second counters; keeps the scene snapshot.
    mutating func reset() {
        self = PerfWindow(scene: scene)
    }

    func line(seconds: TimeInterval, elapsed: TimeInterval, memoryMB: Double, thermal: Int) -> String {
        let fps = elapsed > 0 ? Double(frames) / elapsed : 0
        return String(format: "%.0f,%.1f,%.1f,%.0f,%d,%d,%.1f,%.1f,%d,%d,%d,%d\n",
                      seconds, fps, worstFrame * 1000, memoryMB, thermal,
                      chunkBuilds, chunkWorstMs, farWorstMs,
                      scene.nodes, scene.triangles, scene.draws, scene.particles)
    }
}

/// What a scene holds right now. Hidden subtrees are skipped (SceneKit
/// does not draw them); everything else counts, on screen or not.
struct SceneStats: Equatable {
    var nodes = 0
    var triangles = 0
    /// Geometry elements: SceneKit issues roughly one draw per element.
    var draws = 0
    var particles = 0

    static func collect(_ root: SCNNode) -> SceneStats {
        var stats = SceneStats()
        visit(root, into: &stats)
        return stats
    }

    private static func visit(_ node: SCNNode, into stats: inout SceneStats) {
        guard !node.isHidden else { return }
        stats.nodes += 1
        if let geometry = node.geometry {
            for element in geometry.elements {
                stats.draws += 1
                switch element.primitiveType {
                case .triangles, .triangleStrip: stats.triangles += element.primitiveCount
                default: break
                }
            }
        }
        stats.particles += node.particleSystems?.count ?? 0
        for child in node.childNodes { visit(child, into: &stats) }
    }
}
