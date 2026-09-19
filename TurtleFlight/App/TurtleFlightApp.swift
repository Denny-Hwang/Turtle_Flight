import SwiftUI

@main
struct TurtleFlightApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Register the MetricKit subscriber early so the first daily
        // payload after install lands. See Core/Observability/
        // MetricsCollector.swift for the rationale + privacy notes.
        MetricsCollector.shared.register()
        // On-device funnel counters (no network). Records today as a
        // play day and bumps the session count — see Analytics.swift.
        Analytics.shared.markSessionStart()
        // Phase 3 opt-ins are re-applied on every launch: the streak
        // reminder is pushed a day out (so it only fires after a missed
        // day) and Game Center re-authenticates silently if enabled.
        let missionVM = MissionViewModel()
        missionVM.load()
        if missionVM.progress.remindersEnabled {
            ReminderScheduler.shared.schedule(
                dailyBody: L10n.t("reminder.daily.body"),
                streakBody: L10n.t("reminder.streak.body"),
                title: L10n.t("reminder.title")
            )
        }
        if missionVM.progress.gameCenterEnabled {
            GameCenterManager.shared.setEnabled(true)
        }
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
