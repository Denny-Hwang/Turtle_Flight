import Foundation
import SwiftUI
import SceneKit

// MARK: - Double Extensions
extension Double {
    /// Degrees to radians
    var rad: Double {
        self * .pi / 180.0
    }

    /// Radians to degrees
    var deg: Double {
        self * 180.0 / .pi
    }

    /// Clamp value to range
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    /// Sign of value: -1, 0, or 1
    var sign: Double {
        if self > 0 { return 1.0 }
        if self < 0 { return -1.0 }
        return 0.0
    }
}

// MARK: - Float Extensions
extension Float {
    var rad: Float {
        self * .pi / 180.0
    }

    var deg: Float {
        self * 180.0 / .pi
    }

    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }

    /// Linear interpolation
    static func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
        a + (b - a) * t.clamped(to: 0...1)
    }
}

// MARK: - SCNVector3 Extensions
extension SCNVector3 {
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    var length: Float {
        sqrt(x * x + y * y + z * z)
    }

    var normalized: SCNVector3 {
        let len = length
        guard len > 0 else { return self }
        return SCNVector3(x / len, y / len, z / len)
    }

    static func lerp(_ a: SCNVector3, _ b: SCNVector3, t: Float) -> SCNVector3 {
        SCNVector3(
            Float.lerp(a.x, b.x, t: t),
            Float.lerp(a.y, b.y, t: t),
            Float.lerp(a.z, b.z, t: t)
        )
    }
}

// MARK: - Color from Hex
extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - TimeInterval Formatting
extension TimeInterval {
    var mmss: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
