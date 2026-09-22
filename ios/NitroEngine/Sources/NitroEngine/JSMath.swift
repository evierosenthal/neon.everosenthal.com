import Foundation

// JavaScript number semantics the port must keep, plus the random source.

/// `Math.round`: JS rounds half toward +infinity (round(-2.5) == -2), Swift's
/// `.rounded()` rounds half away from zero (-3). Velocities go negative, so
/// the r1() snapshot rounding in game.js:2206 sees both.
@inlinable public func jsRound(_ x: Double) -> Double {
    return (x + 0.5).rounded(.down)
}

/// `Math.sign`: 0 for 0 (Swift has no direct equivalent for Double).
@inlinable public func jsSign(_ x: Double) -> Double {
    if x > 0 { return 1 }
    if x < 0 { return -1 }
    return 0
}

/// `Math.floor(Math.random() * n)` — an index in 0..<n.
@inlinable public func jsRandomIndex(_ rng: inout some RandomSource, _ n: Int) -> Int {
    return Int((rng.next() * Double(n)).rounded(.down))
}

/// Source of `Math.random()` values in [0, 1). Every random call in game.js
/// goes through one of these, in the same order, so a seeded source lets a
/// run be reproduced (and compared against the JS oracle in the tests).
public protocol RandomSource {
    mutating func next() -> Double
}

/// Production source.
public struct SystemRNG: RandomSource {
    public init() {}
    public mutating func next() -> Double { Double.random(in: 0..<1) }
}

/// xorshift128+ with a splitmix64 seed expansion. The same algorithm is
/// implemented in JavaScript by the oracle harness (Tests/.../Oracle) so both
/// sides consume an identical sequence. Output is the top 53 bits as a
/// double in [0, 1), exactly like V8's Math.random construction.
public struct SeededRNG: RandomSource, Equatable {
    public private(set) var s0: UInt64
    public private(set) var s1: UInt64

    public init(seed: UInt64) {
        var x = seed
        func splitmix() -> UInt64 {
            x &+= 0x9E37_79B9_7F4A_7C15
            var z = x
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        s0 = splitmix()
        s1 = splitmix()
        if s0 == 0 && s1 == 0 { s1 = 1 }
    }

    public mutating func nextUInt64() -> UInt64 {
        var a = s0
        let b = s1
        s0 = b
        a ^= a << 23
        a ^= a >> 17
        a ^= b ^ (b >> 26)
        s1 = a
        return a &+ b
    }

    public mutating func next() -> Double {
        // 53 random bits / 2^53
        return Double(nextUInt64() >> 11) * (1.0 / 9007199254740992.0)
    }
}
