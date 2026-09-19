import Foundation

/// Deterministic 64-bit pseudo-random generator (SplitMix64).
///
/// `SystemRandomNumberGenerator` is fine for cosmetic jitter but useless
/// for anything that has to reproduce: a Daily Run course that every
/// player must see identically, a ghost replay that has to line up with
/// the same star field, a unit test that pins ring positions. This
/// generator produces the same sequence for the same seed on every
/// device and every Swift version, and it satisfies
/// `RandomNumberGenerator` so it plugs straight into
/// `Float.random(in:using:)`, `shuffle(using:)`, etc.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// Convenience for signed seeds (e.g. `Int` hashes of a date string).
    init(seed: Int) {
        self.init(seed: UInt64(bitPattern: Int64(seed)))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform float in [0, 1).
    mutating func nextUnit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }

    /// Uniform float in `range`.
    mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextUnit()
    }

    /// Uniform integer in `range`.
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    /// Stable, platform-independent hash of a string (FNV-1a 64).
    /// `String.hashValue` is randomised per process, so it can't seed
    /// anything that must reproduce tomorrow.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
