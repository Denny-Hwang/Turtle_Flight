import XCTest
@testable import TurtleFlight

/// Landscape tilt mapping + start-of-flight calibration (2026-11-24).
/// On the iPhone the old Euler mapping crossed the axes in landscape:
/// leaning the phone turned, and tilting it left/right did nothing.
final class TiltMappingTests: XCTestCase {

    private func deg(_ d: Double) -> Double { d * .pi / 180 }

    /// Device-frame gravity for a phone held in `orientation` with the
    /// given screen-frame gravity (x right, y up, z out of the screen).
    private func device(_ screen: SIMD3<Double>, _ orientation: UIInterfaceOrientation) -> SIMD3<Double> {
        switch orientation {
        case .landscapeRight: return SIMD3(screen.y, -screen.x, screen.z)   // inverse of (-gy, gx)
        case .landscapeLeft:  return SIMD3(-screen.y, screen.x, screen.z)   // inverse of (gy, -gx)
        default:              return screen
        }
    }

    /// Screen gravity for a phone leaned back by `lean` and with its right
    /// edge lowered by `lateral`.
    private func screen(lateral: Double, lean: Double) -> SIMD3<Double> {
        let x = sin(lateral)
        let rest = cos(lateral)
        return SIMD3(x, -cos(lean) * rest, -sin(lean) * rest)
    }

    // MARK: - Mapping

    func testUprightLandscapeIsLevel() {
        for o in [UIInterfaceOrientation.landscapeRight, .landscapeLeft] {
            let t = TiltMapping.tilt(gravity: device(SIMD3(0, -1, 0), o), orientation: o)
            XCTAssertEqual(t.lateral, 0, accuracy: 1e-9, "\(o.rawValue)")
            XCTAssertEqual(t.lean, 0, accuracy: 1e-9, "\(o.rawValue)")
        }
    }

    func testRightSideDownReadsAsSteerRightInBothLandscapes() {
        for o in [UIInterfaceOrientation.landscapeRight, .landscapeLeft] {
            let g = device(screen(lateral: deg(20), lean: deg(40)), o)
            let t = TiltMapping.tilt(gravity: g, orientation: o)
            XCTAssertEqual(t.lateral, deg(20), accuracy: 1e-6, "\(o.rawValue)")
            XCTAssertEqual(t.lean, deg(40), accuracy: 1e-6, "\(o.rawValue)")
        }
    }

    func testLeaningBackDoesNotSteer() {
        // The old bug: leaning forward/back came out as roll (= turning).
        let o = UIInterfaceOrientation.landscapeRight
        let a = TiltMapping.tilt(gravity: device(screen(lateral: 0, lean: deg(20)), o), orientation: o)
        let b = TiltMapping.tilt(gravity: device(screen(lateral: 0, lean: deg(70)), o), orientation: o)
        let input = TiltMapping.inputs(b, reference: a)
        XCTAssertEqual(input.roll, 0, accuracy: 1e-9)
        XCTAssertEqual(input.pitch, -deg(50), accuracy: 1e-6)
    }

    func testSteeringWorksFlatAndUpright() {
        let o = UIInterfaceOrientation.landscapeLeft
        for lean in [0.0, 45.0, 85.0] {
            let ref = TiltMapping.tilt(gravity: device(screen(lateral: 0, lean: deg(lean)), o), orientation: o)
            let now = TiltMapping.tilt(gravity: device(screen(lateral: deg(-15), lean: deg(lean)), o), orientation: o)
            let input = TiltMapping.inputs(now, reference: ref)
            XCTAssertEqual(input.roll, -deg(15), accuracy: 1e-6, "lean \(lean)")
            XCTAssertEqual(input.pitch, 0, accuracy: 1e-6, "lean \(lean)")
        }
    }

    func testInputsAreRelativeToReference() {
        let ref = ScreenTilt(lateral: deg(5), lean: deg(40))
        let up = TiltMapping.inputs(ScreenTilt(lateral: deg(5), lean: deg(30)), reference: ref)
        XCTAssertEqual(up.pitch, deg(10), accuracy: 1e-9, "standing the phone up climbs")
        let down = TiltMapping.inputs(ScreenTilt(lateral: deg(5), lean: deg(55)), reference: ref)
        XCTAssertEqual(down.pitch, -deg(15), accuracy: 1e-9, "tipping the top away dives")
        let right = TiltMapping.inputs(ScreenTilt(lateral: deg(25), lean: deg(40)), reference: ref)
        XCTAssertEqual(right.roll, deg(20), accuracy: 1e-9)
    }

    func testWrap() {
        XCTAssertEqual(TiltMapping.wrap(deg(350)), -deg(10), accuracy: 1e-9)
        XCTAssertEqual(TiltMapping.wrap(-deg(190)), deg(170), accuracy: 1e-9)
        XCTAssertEqual(TiltMapping.wrap(deg(30)), deg(30), accuracy: 1e-9)
    }

    // MARK: - Calibrator

    func testCalibratorWaitsForStillnessThenAverages() {
        var c = TiltCalibrator()
        var found: ScreenTilt?
        var t = 0.0
        // Half a second of wobble, then still at lean 40°.
        while t < 0.5 {
            _ = c.add(ScreenTilt(lateral: deg(10 * sin(t * 20)), lean: deg(40)), at: t)
            t += 1.0 / 60
        }
        while found == nil, t < 3 {
            found = c.add(ScreenTilt(lateral: deg(2), lean: deg(40)), at: t)
            t += 1.0 / 60
        }
        let neutral = try! XCTUnwrap(found)
        XCTAssertEqual(neutral.lateral, deg(2), accuracy: deg(0.5))
        XCTAssertEqual(neutral.lean, deg(40), accuracy: 1e-6)
        XCTAssertGreaterThan(t, 0.5 + TiltCalibrator.steadyDuration * 0.9, "needs a still window first")
        XCTAssertLessThan(t, 0.5 + TiltCalibrator.steadyDuration + 0.1)
    }

    func testCalibratorGivesUpWaitingAfterTimeout() {
        var c = TiltCalibrator()
        var found: ScreenTilt?
        var t = 0.0
        while found == nil, t < 5 {
            found = c.add(ScreenTilt(lateral: deg(10 * sin(t * 20)), lean: deg(30)), at: t)
            t += 1.0 / 60
        }
        XCTAssertNotNil(found)
        XCTAssertEqual(t, TiltCalibrator.timeout, accuracy: 0.05)
        XCTAssertEqual(found!.lean, deg(30), accuracy: 1e-6)
    }

    // MARK: - GyroController pipeline

    func testControllerCalibratesThenSteersAndClimbs() {
        let gyro = GyroController(sensitivity: .expert)
        gyro.isAvailable = true            // pretend the sensor is there
        var calibrated = false
        gyro.beginCalibration { calibrated = true }
        XCTAssertTrue(gyro.isCalibrating)

        var t = 0.0
        let neutral = ScreenTilt(lateral: deg(3), lean: deg(45))
        while !calibrated, t < 3 {
            gyro.processTilt(neutral, at: t)
            XCTAssertEqual(gyro.rollInput, 0)
            t += 1.0 / 60
        }
        XCTAssertTrue(calibrated)
        XCTAssertFalse(gyro.isCalibrating)
        XCTAssertLessThan(t, 1, "a still phone calibrates in well under a second")

        // Held at the neutral pose: no input.
        for _ in 0..<30 { gyro.processTilt(neutral, at: t); t += 1.0 / 60 }
        XCTAssertEqual(gyro.rollInput, 0, accuracy: 1e-9)
        XCTAssertEqual(gyro.pitchInput, 0, accuracy: 1e-9)

        // Right side down → turn right; no climb.
        for _ in 0..<60 { gyro.processTilt(ScreenTilt(lateral: deg(23), lean: deg(45)), at: t); t += 1.0 / 60 }
        XCTAssertGreaterThan(gyro.rollInput, 0.3)
        XCTAssertEqual(gyro.pitchInput, 0, accuracy: 1e-9)

        // Stand the phone up → climb; no turn.
        for _ in 0..<60 { gyro.processTilt(ScreenTilt(lateral: deg(3), lean: deg(25)), at: t); t += 1.0 / 60 }
        XCTAssertGreaterThan(gyro.pitchInput, 0.3)
        XCTAssertEqual(gyro.rollInput, 0, accuracy: 0.01)
    }

    func testStartNowUsesCurrentPose() {
        let gyro = GyroController(sensitivity: .expert)
        gyro.isAvailable = true
        gyro.beginCalibration()
        // Wobbling, so it would not finish on its own yet.
        gyro.processTilt(ScreenTilt(lateral: deg(0), lean: deg(50)), at: 0)
        gyro.processTilt(ScreenTilt(lateral: deg(8), lean: deg(50)), at: 0.02)
        XCTAssertTrue(gyro.isCalibrating)
        gyro.finishCalibrationNow()
        XCTAssertFalse(gyro.isCalibrating)
    }

    func testNoSensorCalibratesImmediately() {
        let gyro = GyroController(sensitivity: .easy)   // isAvailable false until start()
        var calibrated = false
        gyro.beginCalibration { calibrated = true }
        XCTAssertTrue(calibrated)
        XCTAssertFalse(gyro.isCalibrating)
    }

    // MARK: - Flight freezes while calibrating

    func testFlightWaitsWhileCalibrating() {
        let vm = FlightViewModel()
        vm.isFlying = true
        vm.isCalibrating = true
        vm.update(deltaTime: 0.016)
        XCTAssertEqual(vm.flightEngine.state.flightTime, 0, "world holds still until neutral is set")

        // Simulator / no sensor: calibration completes at once.
        vm.beginCalibration()
        XCTAssertFalse(vm.isCalibrating)
    }
}
