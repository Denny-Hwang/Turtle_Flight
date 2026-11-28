import XCTest
import SwiftUI
@testable import TurtleFlight

/// On-screen joystick + control modes (owner 2026-11-26).
final class JoystickTests: XCTestCase {

    private var saved: [String: Any?] = [:]
    private let keys = [ControlPreferences.modeKey, ControlPreferences.legacyTouchKey,
                        ControlPreferences.invertStickKey, ControlPreferences.stickOnLeftKey]

    override func setUp() {
        super.setUp()
        for k in keys {
            saved[k] = UserDefaults.standard.object(forKey: k)
            UserDefaults.standard.removeObject(forKey: k)
        }
    }

    override func tearDown() {
        for k in keys {
            if let v = saved[k] ?? nil { UserDefaults.standard.set(v, forKey: k) }
            else { UserDefaults.standard.removeObject(forKey: k) }
        }
        super.tearDown()
    }

    private func run(_ stick: StickInput, _ profile: SensitivityProfile, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { stick.step(deltaTime: 1.0 / 60, profile: profile) }
    }

    // MARK: - Filter

    func testHeldStickReachesFullInput() {
        // The old drag path only smoothed while the finger moved.
        let stick = StickInput()
        stick.hold(x: 1, y: 0)
        run(stick, .easy, seconds: 1.5)
        XCTAssertEqual(stick.roll, 1, accuracy: 0.01)
        XCTAssertEqual(stick.pitch, 0)
    }

    func testReleaseReturnsToCentreQuickly() {
        // Old bug: lifting the finger kept 65–92% of the turn forever.
        let stick = StickInput()
        stick.hold(x: 1, y: 1)
        run(stick, .normal, seconds: 1)
        stick.release()
        run(stick, .normal, seconds: 0.25)
        XCTAssertLessThan(abs(stick.roll), 0.02)
        XCTAssertLessThan(abs(stick.pitch), 0.02)
    }

    func testDeadZoneAndClamp() {
        XCTAssertEqual(StickInput.shape(0.08, exponent: 1), 0)
        XCTAssertEqual(StickInput.shape(1, exponent: 1.6), 1, accuracy: 1e-9)
        XCTAssertEqual(StickInput.shape(-1, exponent: 1.6), -1, accuracy: 1e-9)
        let stick = StickInput()
        stick.hold(x: 3, y: -4)                // clamped per axis
        run(stick, .expert, seconds: 1)
        XCTAssertEqual(stick.roll, 1, accuracy: 0.01)
        XCTAssertEqual(stick.pitch, -1, accuracy: 0.01)
    }

    func testFrameRateIndependent() {
        let a = StickInput(), b = StickInput()
        a.hold(x: 0.7, y: 0); b.hold(x: 0.7, y: 0)
        for _ in 0..<12 { a.step(deltaTime: 1.0 / 60, profile: .normal) }
        for _ in 0..<6 { b.step(deltaTime: 1.0 / 30, profile: .normal) }
        XCTAssertEqual(a.roll, b.roll, accuracy: 1e-9)
    }

    func testAutoLevelAfterIdle() {
        let stick = StickInput()
        stick.hold(x: 0, y: 1)
        run(stick, .easy, seconds: 1)
        XCTAssertFalse(stick.shouldAutoLevel(profile: .easy))
        stick.release()
        run(stick, .easy, seconds: 2.5)
        XCTAssertTrue(stick.shouldAutoLevel(profile: .easy))
        XCTAssertFalse(stick.shouldAutoLevel(profile: .expert), "Expert never auto-levels")
    }

    // MARK: - Knob geometry

    func testKnobClampsToBaseAndUpMeansClimb() {
        let offset = JoystickOverlay.knobOffset(translation: CGSize(width: 0, height: -200), verticalOnly: false)
        XCTAssertEqual(offset.height, -JoystickOverlay.radius, accuracy: 1e-6)
        let v = JoystickOverlay.normalized(offset, invertPitch: false)
        XCTAssertEqual(v.y, 1, accuracy: 1e-9, "drag up = climb")
        XCTAssertEqual(JoystickOverlay.normalized(offset, invertPitch: true).y, -1, accuracy: 1e-9)
    }

    func testFullDiagonalIsFullTurnAndClimb() {
        let r = JoystickOverlay.radius
        let rim = CGSize(width: r * 0.7071, height: -r * 0.7071)
        let v = JoystickOverlay.normalized(rim, invertPitch: false)
        XCTAssertEqual(v.x, 1, accuracy: 1e-3)
        XCTAssertEqual(v.y, 1, accuracy: 1e-3)
        let half = JoystickOverlay.normalized(CGSize(width: r / 2, height: 0), invertPitch: false)
        XCTAssertEqual(half.x, 0.5, accuracy: 1e-9, "straight pushes are unchanged")
    }

    func testMixedModeKnobOnlyMovesVertically() {
        let offset = JoystickOverlay.knobOffset(translation: CGSize(width: 50, height: 20), verticalOnly: true)
        XCTAssertEqual(offset.width, 0)
        XCTAssertEqual(offset.height, 20)
    }

    func testTouchZoneSitsOnTheStickSide() {
        let size = CGSize(width: 800, height: 400)
        XCTAssertEqual(JoystickOverlay.touchZone(in: size, onLeft: false).minX, 400)
        XCTAssertEqual(JoystickOverlay.touchZone(in: size, onLeft: true).minX, 0)
        XCTAssertGreaterThan(JoystickOverlay.touchZone(in: size, onLeft: false).minY, 100,
                             "top bar buttons stay reachable")
    }

    // MARK: - Modes

    func testDefaultIsTiltAndLegacyToggleMigrates() {
        XCTAssertEqual(ControlPreferences.mode, .tilt)
        UserDefaults.standard.set(true, forKey: ControlPreferences.legacyTouchKey)
        XCTAssertEqual(ControlPreferences.mode, .joystick)
        ControlPreferences.mode = .mixed
        XCTAssertEqual(ControlPreferences.mode, .mixed)
    }

    func testJoystickModeSkipsCalibrationAndIgnoresSensor() {
        ControlPreferences.mode = .joystick
        let gyro = GyroController(sensitivity: .expert)
        gyro.isAvailable = true
        var done = false
        gyro.beginCalibration { done = true }
        XCTAssertTrue(done)
        gyro.processTilt(ScreenTilt(lateral: 0, lean: 0.5), at: 0)
        gyro.processTilt(ScreenTilt(lateral: 0.4, lean: 0.5), at: 0.1)
        XCTAssertEqual(gyro.rollInput, 0, "sensor ignored in joystick mode")
    }

    func testMixedModeTiltTurnsStickClimbs() {
        ControlPreferences.mode = .mixed
        let vm = FlightViewModel()
        vm.gyroController.isAvailable = true
        vm.refreshControlMode()
        XCTAssertEqual(vm.controlMode, .mixed)
        // Calibrate, then tilt right and tip forward (would dive in tilt mode).
        var t = 0.0
        vm.gyroController.beginCalibration()
        while vm.gyroController.isCalibrating, t < 3 {
            vm.gyroController.processTilt(ScreenTilt(lateral: 0, lean: 0.7), at: t); t += 1.0 / 60
        }
        for _ in 0..<60 {
            vm.gyroController.processTilt(ScreenTilt(lateral: 0.3, lean: 1.0), at: t); t += 1.0 / 60
        }
        vm.stick.hold(x: -1, y: 1)
        var input = vm.controlInputs(deltaTime: 1.0 / 60)
        for _ in 0..<90 { input = vm.controlInputs(deltaTime: 1.0 / 60) }
        XCTAssertGreaterThan(input.roll, 0.3, "tilt still turns (stick x ignored)")
        XCTAssertGreaterThan(input.pitch, 0.9, "stick climbs; the forward tip is ignored")
    }

    func testJoystickModeFliesWithTheStick() {
        ControlPreferences.mode = .joystick
        let vm = FlightViewModel()
        vm.gyroController.isAvailable = true
        vm.refreshControlMode()
        vm.stick.hold(x: 1, y: -1)
        var input = vm.controlInputs(deltaTime: 1.0 / 60)
        for _ in 0..<90 { input = vm.controlInputs(deltaTime: 1.0 / 60) }
        XCTAssertGreaterThan(input.roll, 0.9)
        XCTAssertLessThan(input.pitch, -0.9)
    }

    func testUseFingerOnCalibrationCardSwitchesToJoystick() {
        let vm = FlightViewModel()
        vm.gyroController.isAvailable = true
        vm.refreshControlMode()
        XCTAssertEqual(vm.controlMode, .tilt)
        vm.beginCalibration()
        XCTAssertTrue(vm.isCalibrating)
        vm.setControlMode(.joystick)
        XCTAssertFalse(vm.isCalibrating)
        XCTAssertEqual(vm.controlMode, .joystick)
        XCTAssertEqual(ControlPreferences.mode, .joystick)
    }
}
