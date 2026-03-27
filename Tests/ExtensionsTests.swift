import XCTest
import SceneKit
@testable import TurtleFlight

/// Tests for Extensions.swift utilities
final class ExtensionsTests: XCTestCase {

    // MARK: - Double Extensions

    func testDoubleRadConversion() {
        XCTAssertEqual(0.0.rad, 0.0, accuracy: 0.0001)
        XCTAssertEqual(180.0.rad, Double.pi, accuracy: 0.0001)
        XCTAssertEqual(90.0.rad, Double.pi / 2, accuracy: 0.0001)
        XCTAssertEqual(360.0.rad, 2 * Double.pi, accuracy: 0.0001)
    }

    func testDoubleDegConversion() {
        XCTAssertEqual(Double.pi.deg, 180.0, accuracy: 0.0001)
        XCTAssertEqual((Double.pi / 2).deg, 90.0, accuracy: 0.0001)
        XCTAssertEqual(0.0.deg, 0.0, accuracy: 0.0001)
    }

    func testDoubleRadDegRoundTrip() {
        let angles: [Double] = [0, 30, 45, 90, 135, 180, 270, 360]
        for angle in angles {
            XCTAssertEqual(angle.rad.deg, angle, accuracy: 0.001,
                           "Round trip failed for \(angle)°")
        }
    }

    func testDoubleClamped() {
        XCTAssertEqual(1.5.clamped(to: 0...1), 1.0)
        XCTAssertEqual((-0.5).clamped(to: 0...1), 0.0)
        XCTAssertEqual(0.5.clamped(to: 0...1), 0.5)
    }

    func testDoubleSign() {
        XCTAssertEqual((5.0).sign, 1.0)
        XCTAssertEqual((-3.0).sign, -1.0)
        XCTAssertEqual((0.0).sign, 0.0)
    }

    // MARK: - Float Extensions

    func testFloatRadConversion() {
        XCTAssertEqual(Float(180.0).rad, Float.pi, accuracy: 0.0001)
        XCTAssertEqual(Float(0.0).rad, 0, accuracy: 0.0001)
    }

    func testFloatDegConversion() {
        XCTAssertEqual(Float.pi.deg, 180.0, accuracy: 0.001)
    }

    func testFloatClamped() {
        XCTAssertEqual(Float(1.5).clamped(to: 0...1), 1.0)
        XCTAssertEqual(Float(-0.5).clamped(to: 0...1), 0.0)
        XCTAssertEqual(Float(0.5).clamped(to: 0...1), 0.5)
    }

    func testFloatLerp() {
        XCTAssertEqual(Float.lerp(0, 10, t: 0.5), 5.0, accuracy: 0.001)
        XCTAssertEqual(Float.lerp(0, 10, t: 0), 0.0, accuracy: 0.001)
        XCTAssertEqual(Float.lerp(0, 10, t: 1), 10.0, accuracy: 0.001)
    }

    func testFloatLerpClampsT() {
        // t > 1 should be clamped to 1
        XCTAssertEqual(Float.lerp(0, 10, t: 2.0), 10.0, accuracy: 0.001)
        // t < 0 should be clamped to 0
        XCTAssertEqual(Float.lerp(0, 10, t: -1.0), 0.0, accuracy: 0.001)
    }

    // MARK: - SCNVector3 Extensions

    func testSCNVector3Addition() {
        let a = SCNVector3(1, 2, 3)
        let b = SCNVector3(4, 5, 6)
        let result = a + b
        XCTAssertEqual(result.x, 5)
        XCTAssertEqual(result.y, 7)
        XCTAssertEqual(result.z, 9)
    }

    func testSCNVector3Subtraction() {
        let a = SCNVector3(5, 7, 9)
        let b = SCNVector3(1, 2, 3)
        let result = a - b
        XCTAssertEqual(result.x, 4)
        XCTAssertEqual(result.y, 5)
        XCTAssertEqual(result.z, 6)
    }

    func testSCNVector3ScalarMultiply() {
        let v = SCNVector3(1, 2, 3)
        let result = v * 2
        XCTAssertEqual(result.x, 2)
        XCTAssertEqual(result.y, 4)
        XCTAssertEqual(result.z, 6)
    }

    func testSCNVector3Length() {
        let v = SCNVector3(3, 4, 0)
        XCTAssertEqual(v.length, 5.0, accuracy: 0.001)  // 3-4-5 triangle
    }

    func testSCNVector3LengthZero() {
        let v = SCNVector3(0, 0, 0)
        XCTAssertEqual(v.length, 0.0)
    }

    func testSCNVector3Normalized() {
        let v = SCNVector3(3, 4, 0)
        let n = v.normalized
        XCTAssertEqual(n.length, 1.0, accuracy: 0.001)
    }

    func testSCNVector3NormalizedDirection() {
        let v = SCNVector3(0, 0, -5)
        let n = v.normalized
        XCTAssertEqual(n.z, -1.0, accuracy: 0.001)
        XCTAssertEqual(n.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(n.y, 0.0, accuracy: 0.001)
    }

    func testSCNVector3NormalizedZeroVector() {
        // Zero vector normalized should return zero vector (no crash)
        let v = SCNVector3(0, 0, 0)
        let n = v.normalized
        XCTAssertEqual(n.length, 0)
    }

    func testSCNVector3Lerp() {
        let a = SCNVector3(0, 0, 0)
        let b = SCNVector3(10, 10, 10)
        let mid = SCNVector3.lerp(a, b, t: 0.5)
        XCTAssertEqual(mid.x, 5, accuracy: 0.001)
        XCTAssertEqual(mid.y, 5, accuracy: 0.001)
        XCTAssertEqual(mid.z, 5, accuracy: 0.001)
    }

    func testSCNVector3LerpAtZero() {
        let a = SCNVector3(1, 2, 3)
        let b = SCNVector3(10, 20, 30)
        let result = SCNVector3.lerp(a, b, t: 0)
        XCTAssertEqual(result.x, a.x, accuracy: 0.001)
    }

    func testSCNVector3LerpAtOne() {
        let a = SCNVector3(1, 2, 3)
        let b = SCNVector3(10, 20, 30)
        let result = SCNVector3.lerp(a, b, t: 1)
        XCTAssertEqual(result.x, b.x, accuracy: 0.001)
    }

    // MARK: - TimeInterval Formatting

    func testMMSSFormatting() {
        XCTAssertEqual(TimeInterval(65).mmss, "01:05")
        XCTAssertEqual(TimeInterval(0).mmss, "00:00")
        XCTAssertEqual(TimeInterval(60).mmss, "01:00")
        XCTAssertEqual(TimeInterval(3661).mmss, "61:01")
    }

    func testMMSSFormattingFor3Stars() {
        // Typical game scenario: 45 seconds
        XCTAssertEqual(TimeInterval(45).mmss, "00:45")
    }
}
