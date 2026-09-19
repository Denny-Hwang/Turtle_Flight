import Foundation
import ReplayKit
import SwiftUI
import os

private let log = Logger(subsystem: "com.turtleflight.app", category: "Clips")

/// Opt-in flight recording with ReplayKit so a run can be shared as a
/// short video from the result screen — the share loop that a text
/// "flight time + stars" blurb never delivered.
///
/// Off by default. When the player enables "Record clips" in Settings,
/// `startIfEnabled()` begins a screen recording at flight start and the
/// result screen offers "Share clip", which stops the recording and
/// presents Apple's `RPPreviewViewController` (trim + save + share).
/// ReplayKit shows its own permission prompt the first time; audio from
/// the microphone is never enabled.
final class ClipRecorder: NSObject {

    static let shared = ClipRecorder()

    private(set) var isRecording = false
    private var recorder: RPScreenRecorder { RPScreenRecorder.shared() }

    private override init() { super.init() }

    /// Whether the device / OS can record at all.
    var isAvailable: Bool { recorder.isAvailable }

    /// Start recording when the feature is enabled. Safe to call every
    /// flight start; no-op when already recording or unavailable.
    func startIfEnabled(_ enabled: Bool) {
        guard enabled, isAvailable, !isRecording else { return }
        recorder.isMicrophoneEnabled = false
        recorder.startRecording { [weak self] error in
            if let error {
                log.error("ReplayKit start failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            self?.isRecording = true
        }
    }

    /// Stop and hand back the preview controller (nil when nothing was
    /// recorded or the user has nothing to share).
    func stop(completion: @escaping (RPPreviewViewController?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }
        recorder.stopRecording { [weak self] preview, error in
            self?.isRecording = false
            if let error {
                log.error("ReplayKit stop failed: \(error.localizedDescription, privacy: .public)")
            }
            DispatchQueue.main.async { completion(preview) }
        }
    }

    /// Discard the current recording without offering a preview (Home /
    /// Retry paths).
    func discard() {
        guard isRecording else { return }
        recorder.stopRecording { [weak self] _, _ in
            self?.isRecording = false
            self?.recorder.discardRecording {}
        }
    }
}

extension RPPreviewViewController: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

/// SwiftUI bridge for `RPPreviewViewController`.
struct ReplayPreview: UIViewControllerRepresentable {
    let controller: RPPreviewViewController
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> RPPreviewViewController {
        controller.previewControllerDelegate = context.coordinator
        controller.modalPresentationStyle = .fullScreen
        return controller
    }

    func updateUIViewController(_ uiViewController: RPPreviewViewController, context: Context) {}

    final class Coordinator: NSObject, RPPreviewViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
            onDismiss()
        }
    }
}
