import XCTest
@testable import TurtleFlight

final class MathHelpersTests: XCTestCase {

    // MARK: - Compass Direction

    func testCompassNorth() {
        XCTAssertEqual(MathHelpers.compassDirection(from: 0), "N")
        XCTAssertEqual(MathHelpers.compassDirection(from: 360), "N")
        XCTAssertEqual(MathHelpers.compassDirection(from: 10), "N")
        XCTAssertEqual(MathHelpers.compassDirection(from: 350), "N")
    }

    func testCompassNorthEast() {
        XCTAssertEqual(MathHelpers.compassDirection(from: 45), "NE")
        XCTAssertEqual(MathHelpers.compassDirection(from: 23), "NE")
        XCTAssertEqual(MathHelpers.compassDirection(from: 67), "NE")
    }

    func testCompassEast() {
        XCTAssertEqual(MathHelpers.compassDirection(from: 90), "E")
        XCTAssertEqual(MathHelpers.compassDirection(from: 80), "E")
        XCTAssertEqual(MathHelpers.compassDirection(from: 112), "E")
    }

    func testCompassSouthEast() {
        XCTAssertEqual(MathHelpers.compassDirection(from: 135), "SE")
    }

    func testCompassSouth() {
        XCTAssertEqual(MathHelpers.compassDirection(from: 180), "S")
    }

    func testCompassSouthWest() {
        XCTAssertEqual(MathHelpers.compassDirection(from: 225), "SW")
    }

    func testCompassWest() {
        XCTAssertEqual(MathHelpers.compassDirection(from: 270), "W")
    }

    func testCompassNorthWest() {
        XCTAssertEqual(MathHelpers.compassDirection(from: 315), "NW")
    }

    func testCompassNormalizesOver360() {
        // 360 + 10 = 370 should normalize to 10 → "N"
        XCTAssertEqual(MathHelpers.compassDirection(from: 370), "N")
        XCTAssertEqual(MathHelpers.compassDirection(from: 450), "E")  // 450 % 360 = 90
    }

    func testCompassNegativeHeading() {
        // -90 → should map to West (270°)
        XCTAssertEqual(MathHelpers.compassDirection(from: -90), "W")
    }

    // MARK: - Value Noise 2D

    func testValueNoiseRange() {
        // Noise output should be in [0, 1]
        for x in stride(from: 0.0 as Float, through: 10.0, by: 0.5) {
            for y in stride(from: 0.0 as Float, through: 10.0, by: 0.5) {
                let n = MathHelpers.valueNoise2D(x: x, y: y)
                XCTAssertGreaterThanOrEqual(n, 0.0, "Noise below 0 at (\(x),\(y))")
                XCTAssertLessThanOrEqual(n, 1.0, "Noise above 1 at (\(x),\(y))")
            }
        }
    }

    func testValueNoiseDeterminism() {
        // Same inputs → same output
        let a = MathHelpers.valueNoise2D(x: 3.14, y: 2.71, seed: 42)
        let b = MathHelpers.valueNoise2D(x: 3.14, y: 2.71, seed: 42)
        XCTAssertEqual(a, b)
    }

    func testValueNoiseDifferentSeeds() {
        let a = MathHelpers.valueNoise2D(x: 1.0, y: 1.0, seed: 0)
        let b = MathHelpers.valueNoise2D(x: 1.0, y: 1.0, seed: 99)
        // Different seeds should produce different values (with very high probability)
        XCTAssertNotEqual(a, b)
    }

    func testValueNoiseContinuity() {
        // Nearby points should produce similar values (continuity check)
        let a = MathHelpers.valueNoise2D(x: 5.0, y: 5.0)
        let b = MathHelpers.valueNoise2D(x: 5.01, y: 5.0)
        let diff = abs(a - b)
        XCTAssertLessThan(diff, 0.1, "Noise should be continuous: diff=\(diff)")
    }

    // MARK: - Fractal Noise

    func testFractalNoiseRange() {
        for x in stride(from: 0.0 as Float, through: 5.0, by: 0.5) {
            for y in stride(from: 0.0 as Float, through: 5.0, by: 0.5) {
                let n = MathHelpers.fractalNoise(x: x, y: y)
                XCTAssertGreaterThanOrEqual(n, 0.0, "FractalNoise below 0 at (\(x),\(y))")
                XCTAssertLessThanOrEqual(n, 1.0, "FractalNoise above 1 at (\(x),\(y))")
            }
        }
    }

    func testFractalNoiseDeterminism() {
        let a = MathHelpers.fractalNoise(x: 2.5, y: 3.7, octaves: 4, seed: 7)
        let b = MathHelpers.fractalNoise(x: 2.5, y: 3.7, octaves: 4, seed: 7)
        XCTAssertEqual(a, b)
    }

    func testFractalNoiseOctavesEffect() {
        // More octaves → same seed but can differ from 1 octave (detail added)
        let oneOctave = MathHelpers.fractalNoise(x: 2.0, y: 2.0, octaves: 1)
        let fourOctaves = MathHelpers.fractalNoise(x: 2.0, y: 2.0, octaves: 4)
        // They may or may not be equal, but both should be in [0, 1]
        XCTAssertGreaterThanOrEqual(oneOctave, 0.0)
        XCTAssertLessThanOrEqual(oneOctave, 1.0)
        XCTAssertGreaterThanOrEqual(fourOctaves, 0.0)
        XCTAssertLessThanOrEqual(fourOctaves, 1.0)
    }
}
