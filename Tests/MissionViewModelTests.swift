import XCTest
@testable import TurtleFlight

/// Pins the stage-progression API the MissionHUD relies on. Until this
/// PR, the "Next" button on the stage-clear overlay called
/// `returnToSelect()`, so Stage 5 was unreachable through normal play
/// (DESIGN_GAP_REPORT §S6, P0).
final class MissionViewModelTests: XCTestCase {

    func testHasNextStageIsTrueForAllButTheLastStage() {
        let vm = MissionViewModel()
        let last = vm.stages.count - 1
        for i in 0..<last {
            vm.currentStageIndex = i
            XCTAssertTrue(
                vm.hasNextStage,
                "stage \(i) of \(vm.stages.count) should have a next stage"
            )
        }
        vm.currentStageIndex = last
        XCTAssertFalse(
            vm.hasNextStage,
            "the last stage must NOT report a next stage — gates the campaign-clear flow"
        )
    }

    func testAdvanceToNextStageIncrementsAndReturnsTrue() {
        let vm = MissionViewModel()
        vm.currentStageIndex = 0
        XCTAssertTrue(vm.advanceToNextStage())
        XCTAssertEqual(vm.currentStageIndex, 1)

        XCTAssertTrue(vm.advanceToNextStage())
        XCTAssertEqual(vm.currentStageIndex, 2)
    }

    func testAdvanceToNextStageIsNoOpAtLastStage() {
        let vm = MissionViewModel()
        vm.currentStageIndex = vm.stages.count - 1

        XCTAssertFalse(vm.advanceToNextStage(),
                       "must not silently roll past the campaign end")
        XCTAssertEqual(vm.currentStageIndex, vm.stages.count - 1,
                       "currentStageIndex must remain pinned at the last stage")
    }

    func testAdvanceFromFirstReachesLast() {
        // Walk the entire chain — until this PR, only stage 0 was reachable
        // through the Next button. This is the regression guard.
        let vm = MissionViewModel()
        vm.currentStageIndex = 0
        var advances = 0
        while vm.advanceToNextStage() { advances += 1 }
        XCTAssertEqual(advances, vm.stages.count - 1)
        XCTAssertEqual(vm.currentStageIndex, vm.stages.count - 1)
        XCTAssertFalse(vm.hasNextStage)
    }
}
