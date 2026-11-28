// Benchmark example (benchmark/PLAN.md B3) — NOT part of the app target.
//
// Jolt's lesson for a game our size: you do not need a physics engine,
// but fast bodies need *continuous* collision ("LinearCast" motion
// quality, CastShape), not just a test at the end of the frame.
//
// Today `LandmarkCollider` checks the player's end-of-frame point with
// `playerPad` = 6 m. At the energy cap (380) with boost ×2 the player
// moves ~12.7 m per frame at 60 fps and ~25 m at 30 fps, so a thin tower
// leg can be skipped. This walks the frame's segment in steps of half
// the pad and returns the first contact, reusing the existing
// `contact(_:pad:)` shape test unchanged.

import simd

enum SweptContact {
    typealias Contact = (normal: SIMD3<Float>, depth: Float)

    /// First contact along `from → to`, or nil.
    /// - Parameters:
    ///   - pad: the same pad the point test uses.
    ///   - contact: the point test (e.g. `{ shape.contact($0, pad: $1) }`).
    /// - Returns: `t` in (0, 1] along the segment, and the contact there.
    static func first(from: SIMD3<Float>, to: SIMD3<Float>, pad: Float,
                      contact: (SIMD3<Float>, Float) -> Contact?) -> (t: Float, hit: Contact)? {
        let length = simd_distance(from, to)
        // Short moves (the usual case) cost exactly one point test.
        let steps = max(1, Int((length / (pad * 0.5)).rounded(.up)))
        for i in 1...steps {
            let t = Float(i) / Float(steps)
            if let hit = contact(simd_mix(from, to, SIMD3(repeating: t)), pad) {
                return (t, hit)
            }
        }
        return nil
    }
}

// Test sketch for B3-1 (reproduce first, then fix):
//
//   // A 2 m-radius leg at the origin; the player crosses it in one 25 m step.
//   let leg = LandmarkShape.cylinder(0, 0, 0, r: 2, h: 100)
//   let a = SIMD3<Float>(-12.5, 50, 0), b = SIMD3<Float>(12.5, 50, 0)
//   XCTAssertNil(leg.contact(b, pad: 6))                                   // end-point test misses
//   XCTAssertNotNil(SweptContact.first(from: a, to: b, pad: 6) { leg.contact($0, pad: $1) })
