import Foundation
import GameKit
import UIKit
import os

private let log = Logger(subsystem: "com.turtleflight.app", category: "GameCenter")

/// Thin, opt-in wrapper over GameKit. Nothing here runs unless the
/// player flips "Game Center" on in Settings — the app's privacy story
/// is "no sign-in" by default and this keeps it that way. When enabled:
///   • leaderboards: campaign stars, Daily Run score (one board, the
///     day is in the score context), Sky Run best
///   • achievements: first bullseye, combo 10, Sky Run 50 gates,
///     campaign 15★, 7-day streak
/// Leaderboard / achievement IDs must exist in App Store Connect; until
/// they do GameKit just logs an error and the game carries on.
final class GameCenterManager: NSObject {

    static let shared = GameCenterManager()

    enum Leaderboard: String {
        case campaignStars = "tf.campaign.stars"
        case dailyRun      = "tf.daily.score"
        case endless       = "tf.endless.score"
    }

    enum Achievement: String, CaseIterable {
        case firstBullseye   = "tf.ach.first_bullseye"
        case combo10         = "tf.ach.combo_10"
        case endless50       = "tf.ach.endless_50"
        case campaignComplete = "tf.ach.campaign_15"
        case streak7         = "tf.ach.streak_7"
    }

    private(set) var isEnabled = false
    private(set) var isAuthenticated = false
    /// Presented by the authenticate handler when GameKit wants UI.
    var presentAuthUI: ((UIViewController) -> Void)?

    private override init() { super.init() }

    /// Turn the integration on/off. Enabling kicks off authentication.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        guard enabled else {
            isAuthenticated = false
            return
        }
        authenticate()
    }

    private func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            if let viewController {
                self.presentAuthUI?(viewController)
                return
            }
            if let error {
                log.error("Game Center auth failed: \(error.localizedDescription, privacy: .public)")
                self.isAuthenticated = false
                return
            }
            self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            log.info("Game Center authenticated: \(self.isAuthenticated)")
        }
    }

    // MARK: - Reporting

    /// Called on every mission completion. Decides which boards and
    /// achievements the result touches.
    func report(result: StageResult, stage: StageDefinition?, progress: PlayerProgress) {
        guard isEnabled, isAuthenticated else { return }
        if let stage {
            if stage.isDailyRun {
                submit(score: result.score ?? 0, to: .dailyRun)
            } else if stage.isEndless {
                submit(score: result.score ?? 0, to: .endless)
                if result.ringsCompleted >= 50 { unlock(.endless50) }
            } else {
                submit(score: progress.totalStars, to: .campaignStars)
                if progress.totalStars >= StageDefinition.allStages.count * 3 {
                    unlock(.campaignComplete)
                }
            }
        }
        if (result.bullseyes ?? 0) > 0 { unlock(.firstBullseye) }
        if (result.maxCombo ?? 0) >= 10 { unlock(.combo10) }
        if Analytics.shared.currentStreak() >= 7 { unlock(.streak7) }
    }

    func submit(score: Int, to board: Leaderboard) {
        guard isEnabled, isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [board.rawValue]) { error in
            if let error {
                log.error("Leaderboard \(board.rawValue, privacy: .public) submit failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func unlock(_ achievement: Achievement) {
        guard isEnabled, isAuthenticated else { return }
        let a = GKAchievement(identifier: achievement.rawValue)
        a.percentComplete = 100
        a.showsCompletionBanner = true
        GKAchievement.report([a]) { error in
            if let error {
                log.error("Achievement \(achievement.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
