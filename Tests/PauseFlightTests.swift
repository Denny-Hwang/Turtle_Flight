import XCTest
@testable import TurtleFlight

/// Pause/resume semantics on FlightViewModel — pinned in isolation so the
/// state machine can't drift even before the FlightView lifecycle is
/// involved. Closes DESIGN_GAP_REPORT §S4 (P0).
final class PauseFlightTests: XCTestCase {

    func testIsPausedDefaultsFalse() {
        let vm = FlightViewModel()
        XCTAssertFalse(vm.isPaused)
    }

    func testPauseFlightDoesNothingWhenNotFlying() {
        let vm = FlightViewModel()
        // Not flying — pause should be a no-op (otherwise the modal could
        // surface on the home screen or on the character select).
        vm.pauseFlight()
        XCTAssertFalse(vm.isPaused)
    }

    func testPauseFlightTogglesIsPausedWhenFlying() {
        let vm = FlightViewModel()
        vm.isFlying = true

        vm.pauseFlight()
        XCTAssertTrue(vm.isPaused)
    }

    func testPauseFlightIsIdempotent() {
        let vm = FlightViewModel()
        vm.isFlying = true
        vm.pauseFlight()
        vm.pauseFlight()  // second call must not toggle back off
        XCTAssertTrue(vm.isPaused)
    }

    func testResumeFlightDoesNothingWhenNotPaused() {
        let vm = FlightViewModel()
        vm.isFlying = true
        // Already running — resume should be a no-op (don't mess with gyro
        // calibration during normal gameplay).
        vm.resumeFlight()
        XCTAssertFalse(vm.isPaused)
    }

    func testResumeFlightClearsIsPaused() {
        let vm = FlightViewModel()
        vm.isFlying = true
        vm.pauseFlight()
        XCTAssertTrue(vm.isPaused)

        vm.resumeFlight()
        XCTAssertFalse(vm.isPaused)
    }

    func testUpdateLoopEarlyExitsWhilePaused() {
        // The frozen-simulation invariant: while paused, calling update()
        // must not advance time. We can't easily inspect every published
        // field without spinning up a real scene, but we can pin the most
        // visible one — flightTime — using a synthetic frame.
        let vm = FlightViewModel()
        vm.isFlying = true
        vm.pauseFlight()

        // Drive a synthetic 16ms frame.
        vm.update(deltaTime: 0.016)

        XCTAssertEqual(vm.flightTime, 0,
                       "flightTime must NOT advance while paused")
    }
}
