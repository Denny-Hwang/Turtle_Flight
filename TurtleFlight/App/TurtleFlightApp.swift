import SwiftUI

@main
struct TurtleFlightApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Register the MetricKit subscriber early so the first daily
        // payload after install lands. See Core/Observability/
        // MetricsCollector.swift for the rationale + privacy notes.
        MetricsCollector.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - AppDelegate for orientation lock

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .landscape
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }
}
