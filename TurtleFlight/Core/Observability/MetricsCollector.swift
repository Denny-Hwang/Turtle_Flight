import Foundation
import MetricKit
import os

private let log = Logger(subsystem: "com.turtleflight.app", category: "MetricsCollector")

/// Subscribes to `MXMetricManager` and logs the daily diagnostic /
/// metric payloads to OSLog. No third-party SDK, no PII out of device —
/// Apple gathers the payload on-device and hands it to us via the
/// subscriber callback once per day.
///
/// Why this exists: the senior review (2026-05-12) called out a missing
/// observability path. Without telemetry the team has no signal on
/// production crash rates, hang counts, disk-write spikes, or
/// app-launch performance regressions. MetricKit is the lightest-weight
/// option — Apple-native, zero dependencies, opt-in to user by way of
/// device participation in iOS analytics.
///
/// Privacy: MetricKit payloads aggregate hardware-level metrics and
/// contain no app-defined event data; they do not collect content the
/// user has entered. Apple delivers them only when the user has agreed
/// to share analytics with developers (Settings → Privacy & Security →
/// Analytics & Improvements → Share with App Developers).
///
/// Subscriber registration is in `TurtleFlightApp.init`. The shared
/// instance is retained for the lifetime of the app so the subscriber
/// list inside `MXMetricManager` keeps a strong reference.
final class MetricsCollector: NSObject {

    static let shared = MetricsCollector()

    private override init() { super.init() }

    /// Register as a subscriber. Idempotent — calling more than once
    /// adds and immediately removes a duplicate registration so the
    /// final subscriber list still has exactly one copy of self.
    func register() {
        let manager = MXMetricManager.shared
        // Defensive: drop any previous registration so a re-entry from
        // a hot-reloaded debug build doesn't double-deliver payloads.
        manager.remove(self)
        manager.add(self)
        log.info("MetricsCollector registered with MXMetricManager")
    }
}

extension MetricsCollector: MXMetricManagerSubscriber {
    /// Daily metric payload. Includes app-launch times, hang rate, CPU
    /// time, memory peak, disk writes, animation frame stats, etc.
    /// Logged to OSLog so the Console.app stream surfaces it during
    /// development and TestFlight has it available via Sysdiagnose
    /// captures. Not persisted to disk by this app.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            let json = String(data: payload.jsonRepresentation(),
                              encoding: .utf8) ?? "<unencodable>"
            log.info("MXMetricPayload (\(payload.timeStampBegin)→\(payload.timeStampEnd)): \(json, privacy: .public)")
        }
    }

    /// Daily diagnostic payload. Crashes, hangs, disk-write exceptions,
    /// CPU exceptions — the actual incident reports a production app
    /// most cares about. Same logging treatment as metrics.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let json = String(data: payload.jsonRepresentation(),
                              encoding: .utf8) ?? "<unencodable>"
            log.error("MXDiagnosticPayload (\(payload.timeStampBegin)→\(payload.timeStampEnd)): \(json, privacy: .public)")
        }
    }
}
