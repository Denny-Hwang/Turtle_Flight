import Foundation
import CoreGraphics
import simd

/// Where the target ring is, seen from the character. Drives the
/// screen-edge guide that appears when the ring is out of view
/// (owner 2026-11-26: "when I drift away I can't tell where the ring is").
struct RingGuide: Equatable, Sendable {
    /// Radians relative to the heading. 0 = straight ahead, + = right,
    /// ±π = directly behind.
    var bearing: Double
    /// Radians above (+) or below (−) the character's horizon.
    var elevation: Double
    /// Metres to the ring centre.
    var distance: Float

    static func make(bearing: Double, dx: Float, dy: Float, dz: Float) -> RingGuide {
        let flat = (dx * dx + dz * dz).squareRoot()
        return RingGuide(bearing: bearing,
                         elevation: Double(atan2(dy, max(flat, 0.001))),
                         distance: (flat * flat + dy * dy).squareRoot())
    }

    /// Seen from the chase camera (15 m behind, 5 m above the character),
    /// which is what decides whether the ring is on screen. Measuring
    /// from the character overstated the angle up close: a ring 110 m
    /// ahead and a little above read as off-screen while plainly in view.
    /// `distance` stays the character's distance to the ring.
    static func fromCamera(ringDelta d: SIMD3<Float>, heading: Float) -> RingGuide {
        let h = heading * .pi / 180
        let forward = SIMD2<Float>(sin(h), -cos(h))
        let cam = SIMD3<Float>(d.x + forward.x * cameraBack, d.y - cameraUp, d.z + forward.y * cameraBack)
        let flat = (cam.x * cam.x + cam.z * cam.z).squareRoot()
        var bearing = Double(atan2(cam.x, -cam.z) - h)
        while bearing > .pi { bearing -= 2 * .pi }
        while bearing < -.pi { bearing += 2 * .pi }
        return RingGuide(bearing: bearing,
                         elevation: Double(atan2(cam.y, max(flat, 0.001))),
                         distance: simd_length(d))
    }

    static let cameraBack = Constants.Camera.followDistance
    static let cameraUp = Constants.Camera.followHeight

    // The chase camera sits 15 m behind and 5 m above the character and
    // looks at it, so it points ~18° down; the view is 70° tall and, in
    // landscape, ~113° wide. A far point at elevation e appears at
    // e + 18° from the screen centre.
    static let cameraPitchDown = atan(Double(Constants.Camera.followHeight / Constants.Camera.followDistance))
    static let halfVerticalFOV = 35.0 * .pi / 180
    static let halfHorizontalFOV = 56.0 * .pi / 180

    /// Hide the guide this close: the ring fills the view anyway.
    static let nearDistance: Float = 40

    var isBehind: Bool { abs(bearing) > .pi / 2 }

    /// The ring is comfortably inside the view (with a margin so the guide
    /// doesn't flicker at the edge).
    var isOnScreen: Bool {
        let margin = 0.88
        guard !isBehind else { return false }
        let up = elevation + Self.cameraPitchDown
        return abs(bearing) < Self.halfHorizontalFOV * margin
            && abs(up) < Self.halfVerticalFOV * margin
    }

    var showsGuide: Bool { distance > Self.nearDistance && !isOnScreen }

    /// Point on the screen's edge (normalised: x, y in −1…1, y down) in
    /// the ring's direction. Behind the player it sits low on the side to
    /// turn toward.
    var edgePoint: CGPoint {
        var x: Double
        var y: Double
        if isBehind {
            x = bearing > 0 ? 1 : -1
            y = 0.55
        } else {
            let limit = 80.0 * .pi / 180
            x = tan(bearing.clamped(to: -limit...limit)) / tan(Self.halfHorizontalFOV)
            let up = (elevation + Self.cameraPitchDown).clamped(to: -limit...limit)
            y = -tan(up) / tan(Self.halfVerticalFOV)
        }
        let scale = max(abs(x), abs(y), 0.0001)
        return CGPoint(x: x / scale, y: y / scale)
    }

    /// Display granularity for HUD publishing (avoid republishing for
    /// sub-degree / sub-10 m changes).
    var displayKey: [Int] {
        [Int(bearing * 30), Int(elevation * 30), Int(distance / 10), showsGuide ? 1 : 0]
    }
}
