import XCTest
@testable import TurtleFlight

/// Regressions found while capturing App Store screenshots (2026-11-20).
final class LaunchPolishTests: XCTestCase {

    /// The HUD showed "Stage 101: 오늘의 코스" to English players: special
    /// courses fell back to their Korean `koreanName`.
    func testSpecialCoursesUseLocalizedNames() {
        let daily = DailyRun.stage(for: Date())
        XCTAssertTrue(daily.isDailyRun)
        XCTAssertEqual(daily.displayName, L10n.t("daily.title"))

        let endless = EndlessCourse.stage()
        XCTAssertTrue(endless.isEndless)
        XCTAssertEqual(endless.displayName, L10n.t("endless.title"))
    }

    func testCampaignStagesStillUseStageStrings() {
        for stage in StageDefinition.allStages {
            XCTAssertEqual(stage.displayName, L10n.t("stage.\(stage.index).name"))
        }
    }
}
