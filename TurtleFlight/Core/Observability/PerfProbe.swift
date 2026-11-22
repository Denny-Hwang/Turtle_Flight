import Foundation

/// On-device performance log for device verification (A3 in
/// docs/LAUNCH_POLISH_PLAN.md). Off unless the app is launched with
/// `-TFPerfProbe YES`; then once a second it appends one CSV line —
/// frames per second, worst frame time, memory footprint, thermal state —
/// to `Documents/perf.csv`, which `scripts/device/verify.sh` copies off
/// the phone. Nothing leaves the device on its own.
///
/// `@unchecked Sendable`: `frame(at:)` runs on the SceneKit render thread
/// only; the stored counters are touched nowhere else.
final class PerfProbe: @unchecked Sendable {
    static let shared = PerfProbe()

    static let isEnabled = UserDefaults.standard.bool(forKey: "TFPerfProbe")

    private var windowStart: TimeInterval = 0
    private var lastFrame: TimeInterval = 0
    private var frames = 0
    private var worstFrame: TimeInterval = 0
    private var startedAt: TimeInterval = 0
    private var handle: FileHandle?

    static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("perf.csv")
    }

    /// Call once per rendered frame with the renderer's timestamp.
    func frame(at time: TimeInterval) {
        guard Self.isEnabled else { return }
        if startedAt == 0 {
            startedAt = time
            windowStart = time
            lastFrame = time
            openFile()
            return
        }
        frames += 1
        worstFrame = max(worstFrame, time - lastFrame)
        lastFrame = time
        guard time - windowStart >= 1 else { return }
        let fps = Double(frames) / (time - windowStart)
        let line = String(format: "%.0f,%.1f,%.1f,%.0f,%d\n",
                          time - startedAt, fps, worstFrame * 1000,
                          Self.footprintMB(), ProcessInfo.processInfo.thermalState.rawValue)
        handle?.write(Data(line.utf8))
        frames = 0
        worstFrame = 0
        windowStart = time
    }

    private func openFile() {
        let url = Self.fileURL
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let header = "# \(machine) \(os)\nseconds,fps,worst_frame_ms,memory_mb,thermal_state\n"
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
