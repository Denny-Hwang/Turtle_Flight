import Foundation
import SceneKit

/// Solid parts of a landmark, in the landmark's local space (landmarks
/// are placed with a translation only, never rotated). Each shape is a
/// rough hull of the primitives `LandmarkFactory` draws — close enough
/// that the player bumps off the stone, loose enough that the gaps that
/// look flyable (under an arch, between tower legs, through a rainbow
/// or a wheel) really are.
///
/// A bump is friendly: the character is nudged back out and turned away,
/// with no score and no penalty (landmarks exist only in Free Flight).
enum LandmarkShape: Equatable {
    case sphere(center: SIMD3<Float>, radius: Float)
    /// Vertical cone frustum standing on `base`; a cylinder when both
    /// radii match.
    case cone(base: SIMD3<Float>, bottomRadius: Float, topRadius: Float, height: Float)
    /// Axis-aligned box.
    case box(center: SIMD3<Float>, half: SIMD3<Float>)

    static func cylinder(_ x: Float, _ y: Float, _ z: Float, r: Float, h: Float) -> LandmarkShape {
        .cone(base: SIMD3(x, y, z), bottomRadius: r, topRadius: r, height: h)
    }
    static func cone(_ x: Float, _ y: Float, _ z: Float, bottom: Float, top: Float, h: Float) -> LandmarkShape {
        .cone(base: SIMD3(x, y, z), bottomRadius: bottom, topRadius: top, height: h)
    }
    static func box(_ x: Float, _ y: Float, _ z: Float, _ hx: Float, _ hy: Float, _ hz: Float) -> LandmarkShape {
        .box(center: SIMD3(x, y, z), half: SIMD3(hx, hy, hz))
    }
    static func sphere(_ x: Float, _ y: Float, _ z: Float, r: Float) -> LandmarkShape {
        .sphere(center: SIMD3(x, y, z), radius: r)
    }

    /// Push-out for a point that is within `pad` of the shape: the unit
    /// direction to move along and how far. Nil when clear.
    func contact(_ p: SIMD3<Float>, pad: Float) -> (normal: SIMD3<Float>, depth: Float)? {
        switch self {
        case let .sphere(c, r):
            let d = p - c
            let len = simd_length(d)
            guard len < r + pad else { return nil }
            let n = len > 0.0001 ? d / len : SIMD3<Float>(0, 1, 0)
            return (n, r + pad - len)

        case let .cone(base, rb, rt, h):
            let top = base.y + h
            guard p.y > base.y - pad, p.y < top + pad else { return nil }
            let t = ((p.y - base.y) / h).clamped(to: 0...1)
            let radius = rb + (rt - rb) * t
            let flat = SIMD2<Float>(p.x - base.x, p.z - base.z)
            let dist = simd_length(flat)
            guard dist < radius + pad else { return nil }
            let side = radius + pad - dist
            let up = top + pad - p.y
            if up < side {
                return (SIMD3(0, 1, 0), up)
            }
            let n2 = dist > 0.0001 ? flat / dist : SIMD2<Float>(1, 0)
            return (SIMD3(n2.x, 0, n2.y), side)

        case let .box(c, half):
            let d = p - c
            let ext = half + SIMD3(repeating: pad)
            guard abs(d.x) < ext.x, abs(d.y) < ext.y, abs(d.z) < ext.z else { return nil }
            // Leave through the nearest face.
            let gaps = [ext.x - abs(d.x), ext.y - abs(d.y), ext.z - abs(d.z)]
            let axis = gaps.indices.min { gaps[$0] < gaps[$1] }!
            var n = SIMD3<Float>(0, 0, 0)
            n[axis] = d[axis] >= 0 ? 1 : -1
            return (n, gaps[axis])
        }
    }
}

extension LandmarkKind {

    /// Rough solid hull. Empty for the ones that are meant to be flown
    /// through or are flat on the ground (rainbow gate, oasis, village).
    var colliders: [LandmarkShape] {
        switch self {
        case .floatingCastle:
            var shapes: [LandmarkShape] = [
                .cone(0, -60, 0, bottom: 8, top: 70, h: 60),
                .cylinder(0, 0, 0, r: 72, h: 8),
                .box(0, 28, 0, 30, 20, 30),
                .box(0, 52, 0, 34, 5, 34),          // battlements
                .cylinder(0, 30, 0, r: 14, h: 80),
                .cone(0, 110, 0, bottom: 18, top: 0, h: 36)
            ]
            for (x, z) in [(-34, -34), (34, -34), (-34, 34), (34, 34)] as [(Float, Float)] {
                shapes.append(.cylinder(x, 8, z, r: 10, h: 90))
            }
            return shapes
        case .rainbowGate, .palmOasis, .hanokVillage:
            return []
        case .windmillHill:
            return [.sphere(0, -55, 0, r: 90),
                    .cone(0, 30, 0, bottom: 20, top: 12, h: 80),
                    .cone(0, 110, 0, bottom: 17, top: 0, h: 22)]
        case .greatPyramids:
            let pyramids: [(Float, Float, Float)] = [(0, 0, 220), (-190, 110, 150), (170, 140, 110)]
            return pyramids.map { x, z, w in
                LandmarkShape.cone(x, 0, z, bottom: w * 0.5, top: 0, h: w * 0.64)
            }
        case .sandGuardian:
            return [.box(0, 17, 0, 30, 17, 75), .sphere(0, 62, 62, r: 30),
                    .box(-22, 7, 100, 13, 7, 35), .box(22, 7, 100, 13, 7, 35)]
        case .sunObelisk:
            return [.box(0, 6, 0, 35, 6, 35), .cone(0, 12, 0, bottom: 15, top: 9, h: 170),
                    .cone(0, 182, 0, bottom: 10, top: 0, h: 22)]
        case .ironLaceTower:
            // Legs stay separate so the arch between them is flyable.
            var shapes: [LandmarkShape] = [
                .box(0, 88, 0, 43, 4, 43),
                .cone(0, 92, 0, bottom: 34, top: 16, h: 80),
                .cone(0, 173, 0, bottom: 16, top: 5, h: 110),
                .sphere(0, 296, 0, r: 7)
            ]
            for (x, z) in [(-38, -38), (38, -38), (-38, 38), (38, 38)] as [(Float, Float)] {
                shapes.append(.cylinder(x * 1.1, 0, z * 1.1, r: 9, h: 86))
            }
            return shapes
        case .grandArch:
            return [.box(-46, 55, 0, 19, 55, 22), .box(46, 55, 0, 19, 55, 22),
                    .box(0, 135, 0, 70, 21, 25),
                    .cylinder(0, 152, 0, r: 9, h: 38)]   // statue
        case .riverBridge:
            var shapes: [LandmarkShape] = [.box(0, 34, 0, 17, 3, 170)]
            for z: Float in [-90, 90] {
                shapes.append(.box(-17, 60, z, 4, 60, 5))
                shapes.append(.box(17, 60, z, 4, 60, 5))
                shapes.append(.box(0, 116, z, 23, 4, 5))
            }
            return shapes
        case .skyWheel:
            // Only the stand: the wheel itself is a hoop to thread.
            return [.cylinder(-26, 0, 0, r: 6, h: 124), .cylinder(26, 0, 0, r: 6, h: 124)]
        case .hilltopTower:
            return [.cone(0, 0, 0, bottom: 150, top: 40, h: 110),
                    .cylinder(0, 110, 0, r: 26, h: 14),
                    .cylinder(0, 124, 0, r: 8, h: 130),
                    .cylinder(0, 232, 0, r: 20, h: 26),
                    .cone(0, 258, 0, bottom: 12, top: 2, h: 26)]
        case .palaceGate:
            return [.box(0, 22, 0, 95, 22, 30), .box(0, 64, 0, 94, 20, 39), .box(0, 98, 0, 72, 20, 39),
                    .cylinder(-85, 0, 44, r: 8, h: 30), .cylinder(85, 0, 44, r: 8, h: 30)]   // guardians
        case .moonBridge:
            return [.box(0, 30, 0, 15, 3, 165)]
        case .greatFalls:
            // The water sheets in front are left open: flying through a
            // waterfall is the point.
            return [.box(0, 95, -45, 130, 95, 45), .box(0, 196, -45, 140, 10, 55)]
        case .canyonArch:
            return [.box(-95, 85, 0, 30, 85, 35), .box(95, 85, 0, 30, 85, 35),
                    .box(0, 180, 0, 130, 23, 33),
                    .cone(-20, 203, 0, bottom: 9, top: 0, h: 38),   // pine on the span
                    .cone(-170, 0, 60, bottom: 24, top: 14, h: 90),
                    .cone(180, 0, -50, bottom: 24, top: 14, h: 120),
                    .cone(-200, 0, -70, bottom: 24, top: 14, h: 60)]
        case .auroraPeak:
            return [.cone(0, 0, 0, bottom: 150, top: 0, h: 300),
                    .cone(-150, 0, 40, bottom: 90, top: 0, h: 170),
                    .cone(140, 0, -60, bottom: 90, top: 0, h: 200)]
        case .giantTree:
            return [.cone(0, 0, 0, bottom: 44, top: 22, h: 200),
                    .sphere(0, 250, 0, r: 88),
                    .sphere(-70, 220, 20, r: 60), .sphere(72, 226, -16, r: 62),
                    .sphere(10, 230, 76, r: 56), .sphere(-16, 232, -74, r: 56)]
        case .ringPlanet:
            return [.sphere(0, 0, 0, r: 110), .sphere(230, 60, 40, r: 20)]
        case .spaceStation:
            return [.box(0, 0, 0, 65, 22, 22), .sphere(0, 0, 0, r: 34),
                    .box(-110, 0, 0, 40, 2, 22), .box(110, 0, 0, 40, 2, 22)]
        case .moonBase:
            return [.sphere(0, 6, 0, r: 54), .sphere(-90, 6, 40, r: 34), .sphere(86, 6, -34, r: 38),
                    .cylinder(40, 15, 80, r: 9, h: 114)]
        case .shipwreck:
            return [.box(0, 32, 0, 42, 34, 104), .box(70, 9, 60, 13, 9, 10)]
        case .seaVolcano:
            return [.cone(0, 0, 0, bottom: 170, top: 34, h: 220)]
        case .shellPalace:
            var shapes: [LandmarkShape] = [.cylinder(0, -24, 0, r: 80, h: 60), .sphere(0, 54, 0, r: 26)]
            for i in 0..<6 {
                let a = Float(i) * .pi / 3
                shapes.append(.cylinder(cos(a) * 112, 0, sin(a) * 112, r: 16, h: 135))
            }
            return shapes
        }
    }

    /// Horizontal reach of the hull from the landmark's origin, for a
    /// cheap reject before testing shapes.
    var colliderReach: Float { 320 }
}

extension LandmarkField {
    /// Radius of the character for bump tests (the billboard is drawn
    /// bigger, but a generous hit box feels unfair at speed).
    static let playerPad: Float = 6

    /// Deepest contact between the player and any loaded landmark, in
    /// world space. Nil when the player is clear of everything.
    func contact(at position: SCNVector3) -> (normal: SIMD3<Float>, depth: Float)? {
        Self.contact(at: position, placements: placements)
    }

    static func contact(at position: SCNVector3, placements: [Placement]) -> (normal: SIMD3<Float>, depth: Float)? {
        let p = SIMD3<Float>(position.x, position.y, position.z)
        var best: (normal: SIMD3<Float>, depth: Float)?
        for placement in placements {
            let origin = SIMD3<Float>(placement.position.x, placement.position.y, placement.position.z)
            let local = p - origin
            let reach = placement.kind.colliderReach
            guard abs(local.x) < reach, abs(local.z) < reach else { continue }
            for shape in placement.kind.colliders {
                if let hit = shape.contact(local, pad: playerPad), hit.depth > (best?.depth ?? 0) {
                    best = hit
                }
            }
        }
        return best
    }
}
