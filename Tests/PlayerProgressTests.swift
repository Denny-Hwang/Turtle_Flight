import XCTest
@testable import TurtleFlight

final class PlayerProgressTests: XCTestCase {

    // MARK: - Default State

    func testDefaultProgressInitialValues() {
        let progress = PlayerProgress.defaultProgress
        XCTAssertEqual(progress.totalStars, 0)
        XCTAssertEqual(progress.totalFlightTime, 0)
        XCTAssertEqual(progress.bestFreeFlightStars, 0)
        XCTAssertEqual(progress.selectedCharacter, .turtle)
        XCTAssertEqual(progress.selectedVehicle, .shellJet)
        XCTAssertEqual(progress.sensitivityLevel, .easy)
        XCTAssertTrue(progress.stageResults.isEmpty)
    }

    func testDefaultMaxUnlockedStageIsZero() {
        let progress = PlayerProgress.defaultProgress
        XCTAssertEqual(progress.maxUnlockedStage, 0)
    }

    // MARK: - Stage Unlocking

    func testCompletingStage0UnlocksStage1() {
        var progress = PlayerProgress.defaultProgress
        let result = makeResult(stageIndex: 0, stars: 1)
        progress.updateStageResult(result)
        XCTAssertEqual(progress.maxUnlockedStage, 1)
    }

    func testCompletingStage1UnlocksStage2() {
        var progress = PlayerProgress.defaultProgress
        progress.updateStageResult(makeResult(stageIndex: 0, stars: 1))
        progress.updateStageResult(makeResult(stageIndex: 1, stars: 1))
        XCTAssertEqual(progress.maxUnlockedStage, 2)
    }

    func testSequentialCompletionUnlocksAll() {
        var progress = PlayerProgress.defaultProgress
        for i in 0..<5 {
            progress.updateStageResult(makeResult(stageIndex: i, stars: 1))
        }
        XCTAssertEqual(progress.maxUnlockedStage, 4)  // Capped at 4 (index of last stage)
    }

    func testMaxUnlockedStageCapAt4() {
        var progress = PlayerProgress.defaultProgress
        for i in 0..<5 {
            progress.updateStageResult(makeResult(stageIndex: i, stars: 3))
        }
        // All 5 stages completed, max should be 4 (can't unlock beyond last stage)
        XCTAssertEqual(progress.maxUnlockedStage, 4)
    }

    func testOnlyBestResultKept() {
        var progress = PlayerProgress.defaultProgress
        // First attempt: 1 star
        progress.updateStageResult(makeResult(stageIndex: 0, stars: 1))
        XCTAssertEqual(progress.stageResults[0]?.stars, 1)

        // Better attempt: 3 stars
        progress.updateStageResult(makeResult(stageIndex: 0, stars: 3))
        XCTAssertEqual(progress.stageResults[0]?.stars, 3)
    }

    func testWorseResultNotReplaced() {
        var progress = PlayerProgress.defaultProgress
        // First attempt: 3 stars
        progress.updateStageResult(makeResult(stageIndex: 0, stars: 3))
        XCTAssertEqual(progress.stageResults[0]?.stars, 3)

        // Worse attempt: 1 star
        progress.updateStageResult(makeResult(stageIndex: 0, stars: 1))
        XCTAssertEqual(progress.stageResults[0]?.stars, 3,
                       "Worse result should not replace better one")
    }

    // MARK: - Total Stars Calculation

    func testTotalStarsCalculation() {
        var progress = PlayerProgress.defaultProgress
        progress.updateStageResult(makeResult(stageIndex: 0, stars: 3))
        progress.updateStageResult(makeResult(stageIndex: 1, stars: 2))
        progress.updateStageResult(makeResult(stageIndex: 2, stars: 1))
        XCTAssertEqual(progress.totalStars, 6)
    }

    func testTotalStarsUpdatesOnImprovement() {
        var progress = PlayerProgress.defaultProgress
        progress.updateStageResult(makeResult(stageIndex: 0, stars: 1))
        XCTAssertEqual(progress.totalStars, 1)

        progress.updateStageResult(makeResult(stageIndex: 0, stars: 3))
        XCTAssertEqual(progress.totalStars, 3, "Total stars should update when stage improved")
    }

    func testTotalStarsMaxPossibleIs15() {
        var progress = PlayerProgress.defaultProgress
        for i in 0..<5 {
            progress.updateStageResult(makeResult(stageIndex: i, stars: 3))
        }
        XCTAssertEqual(progress.totalStars, 15, "Max 5 stages × 3 stars = 15")
    }

    // MARK: - Codable Round-Trip

    func testEncodeDecode() throws {
        var progress = PlayerProgress.defaultProgress
        progress.updateStageResult(makeResult(stageIndex: 0, stars: 2))
        progress.updateStageResult(makeResult(stageIndex: 1, stars: 3))

        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: data)

        XCTAssertEqual(decoded.totalStars, progress.totalStars)
        XCTAssertEqual(decoded.maxUnlockedStage, progress.maxUnlockedStage)
        XCTAssertEqual(decoded.selectedCharacter, progress.selectedCharacter)
        XCTAssertEqual(decoded.sensitivityLevel, progress.sensitivityLevel)
        XCTAssertEqual(decoded.stageResults[0]?.stars, 2)
        XCTAssertEqual(decoded.stageResults[1]?.stars, 3)
    }

    func testEncodeDecodeDefaultProgress() throws {
        let progress = PlayerProgress.defaultProgress
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: data)
        XCTAssertEqual(decoded.totalStars, 0)
        XCTAssertEqual(decoded.selectedCharacter, .turtle)
    }

    // MARK: - StageResult

    func testStageResultIsCompletedWhenStarsAboveZero() {
        let result = makeResult(stageIndex: 0, stars: 1)
        XCTAssertTrue(result.isCompleted)
    }

    func testStageResultNotCompletedWhenZeroStars() {
        let result = makeResult(stageIndex: 0, stars: 0)
        XCTAssertFalse(result.isCompleted)
    }

    // MARK: - Helpers

    private func makeResult(stageIndex: Int, stars: Int) -> StageResult {
        StageResult(
            stageIndex: stageIndex,
            stars: stars,
            completionTime: 45,
            collisions: 0,
            starsCollected: 3,
            ringsCompleted: 10,
            totalRings: 10,
            date: Date()
        )
    }
}
