import Foundation
import UserNotifications
import os

private let log = Logger(subsystem: "com.turtleflight.app", category: "Reminders")

/// Minimal seam over `UNUserNotificationCenter` so tests can stub it.
protocol NotificationCenterLike {
    func requestAuthorization(options: UNAuthorizationOptions,
                              completionHandler: @escaping (Bool, Error?) -> Void)
    func add(_ request: UNNotificationRequest, withCompletionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

/// Two opt-in local notifications, nothing more:
///   • "Today's course is ready" every day at 18:00 local time
///   • "Your streak ends tonight" at 20:30 on days the app wasn't opened
///     (scheduled on each launch for the *next* day and cancelled by
///     the next launch, so it only ever fires after a missed day)
/// Local only — no push service, no device token, no server.
final class ReminderScheduler {

    static let shared = ReminderScheduler(center: nil)

    enum Identifier {
        static let daily  = "tf.reminder.daily"
        static let streak = "tf.reminder.streak"
    }

    private let center: NotificationCenterLike?
    /// Requests scheduled through this instance (ids), for tests / debug.
    private(set) var scheduledIdentifiers: Set<String> = []

    init(center: NotificationCenterLike?) {
        self.center = center
    }

    private var liveCenter: NotificationCenterLike {
        center ?? UNUserNotificationCenter.current()
    }

    /// Ask for permission and, if granted, schedule both reminders.
    func enable(dailyBody: String, streakBody: String, title: String,
                completion: ((Bool) -> Void)? = nil) {
        liveCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error {
                log.error("Notification auth error: \(error.localizedDescription, privacy: .public)")
            }
            guard granted, let self else {
                completion?(false)
                return
            }
            self.schedule(dailyBody: dailyBody, streakBody: streakBody, title: title)
            completion?(true)
        }
    }

    /// Schedule / refresh both requests. Safe to call on every launch.
    func schedule(dailyBody: String, streakBody: String, title: String) {
        let c = liveCenter
        c.removePendingNotificationRequests(withIdentifiers: [Identifier.daily, Identifier.streak])

        let daily = UNMutableNotificationContent()
        daily.title = title
        daily.body = dailyBody
        daily.sound = .default
        var dailyTime = DateComponents()
        dailyTime.hour = 18
        dailyTime.minute = 0
        let dailyTrigger = UNCalendarNotificationTrigger(dateMatching: dailyTime, repeats: true)
        c.add(UNNotificationRequest(identifier: Identifier.daily, content: daily, trigger: dailyTrigger)) { error in
            if let error { log.error("daily reminder: \(error.localizedDescription, privacy: .public)") }
        }
        scheduledIdentifiers.insert(Identifier.daily)

        // Streak nudge: tomorrow 20:30, one shot. Re-scheduled (i.e. pushed
        // a day out) by every launch, so it only fires after a day with
        // no launch at all.
        let streak = UNMutableNotificationContent()
        streak.title = title
        streak.body = streakBody
        streak.sound = .default
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) {
            var comps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            comps.hour = 20
            comps.minute = 30
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            c.add(UNNotificationRequest(identifier: Identifier.streak, content: streak, trigger: trigger)) { error in
                if let error { log.error("streak reminder: \(error.localizedDescription, privacy: .public)") }
            }
            scheduledIdentifiers.insert(Identifier.streak)
        }
    }

    func disable() {
        liveCenter.removePendingNotificationRequests(withIdentifiers: [Identifier.daily, Identifier.streak])
        scheduledIdentifiers.removeAll()
    }
}

extension UNUserNotificationCenter: NotificationCenterLike {}
