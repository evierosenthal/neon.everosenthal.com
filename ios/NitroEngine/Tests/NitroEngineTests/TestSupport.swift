import Foundation
import XCTest
@testable import NeonEngine

/// Returns a scripted sequence of "Math.random()" values, then keeps
/// returning `fallback`. Counts calls so tests can pin the number of draws.
struct ScriptedRNG: RandomSource {
    var values: [Double]
    var fallback: Double
    var calls = 0
    init(_ values: [Double], fallback: Double = 0.5) { self.values = values; self.fallback = fallback }
    mutating func next() -> Double {
        calls += 1
        if !values.isEmpty { return values.removeFirst() }
        return fallback
    }
}

/// Always the same value; `calls` counts the draws.
struct ConstantRNG: RandomSource {
    var value: Double
    var calls = 0
    init(_ value: Double) { self.value = value }
    mutating func next() -> Double { calls += 1; return value }
}

final class RecordingDelegate: GameEngineDelegate {
    var scores: [Int] = []
    var healths: [Int] = []
    var difficulties: [Double] = []
    var deaths = 0
    var hits = 0
    var gameOverScore: Int? = nil
    var sent: [NetMessage] = []
    var onSend: ((NetMessage) -> Void)? = nil

    func engine(_ engine: GameEngine, gameOverWithScore score: Int) { gameOverScore = score }
    func engine(_ engine: GameEngine, scoreDidChange score: Int) { scores.append(score) }
    func engine(_ engine: GameEngine, healthDidChange health: Int) { healths.append(health) }
    func engine(_ engine: GameEngine, difficultyDidChange difficulty: Double) { difficulties.append(difficulty) }
    func engineDidStartDeath(_ engine: GameEngine) { deaths += 1 }
    func engineDidTakeHit(_ engine: GameEngine) { hits += 1 }
    func engine(_ engine: GameEngine, send message: NetMessage) { sent.append(message); onSend?(message) }
}

let testWorld = WorldSize(width: 800, height: 600)

/// A started engine with a recording delegate attached (kept alive by the
/// returned tuple; the engine's delegate is weak).
func makeEngine(_ configure: (inout GameConfig) -> Void = { _ in }, rng: any RandomSource = SeededRNG(seed: 1),
                world: WorldSize = testWorld) -> (GameEngine, RecordingDelegate) {
    var config = GameConfig()
    configure(&config)
    let engine = GameEngine(rng: rng)
    let delegate = RecordingDelegate()
    engine.delegate = delegate
    engine.start(config, worldSize: world)
    return (engine, delegate)
}

extension GameEngine {
    /// The engine's RNG call count when it is one of the counting test sources.
    var rngCalls: Int {
        if let r = rng as? ScriptedRNG { return r.calls }
        if let r = rng as? ConstantRNG { return r.calls }
        return -1
    }

    /// Empties every spawned list so a test controls the field exactly.
    func clearField() {
        state!.asteroids = []
        state!.collectibles = []
        state!.powerUps = []
        state!.projectiles = []
        state!.particles = []
        state!.floatingTexts = []
    }

    func addAsteroid(x: Double, y: Double, vx: Double = 0, vy: Double = 0, radius: Double = 20) -> Asteroid {
        let a = Asteroid(id: "a\(state!.asteroids.count)", x: x, y: y, vx: vx, vy: vy, radius: radius,
                         color: "hsl(215, 15%, 70%)", style: .rocky, tint: .gray,
                         vertices: [1, 1, 1, 1, 1, 1, 1, 1], craters: [], speckles: [], rotation: 0, spinSpeed: 0)
        state!.asteroids.append(a)
        return a
    }

    func addCollectible(x: Double, y: Double, vx: Double = 0, vy: Double = 0) {
        state!.collectibles.append(Collectible(id: "c\(state!.collectibles.count)", x: x, y: y, vx: vx, vy: vy,
                                               color: "#fde68a", kind: .sundae, sprinkles: []))
    }

    func addPowerUp(x: Double, y: Double, _ type: PowerUpType) {
        state!.powerUps.append(PowerUp(id: "u\(state!.powerUps.count)", x: x, y: y, vx: 0, vy: 0,
                                       life: 1200, maxLife: 1200, subType: type))
    }
}

/// The deterministic steering script shared by the golden run and the
/// oracle parity test: ten headings, 37 frames each, offset per pilot.
enum InputScript {
    static let headings: [(dx: Double, dy: Double)] = [
        (1, 0), (0, -1), (-1, 0), (0, 1), (1, -1), (0, 0), (-1, 1), (1, 1), (0, 0), (-1, -1)
    ]
    static func pilot(_ frame: Int, pilot: Int) -> PilotInput {
        let idx = (frame / 37 + pilot * 3) % headings.count
        let h = headings[idx]
        return PilotInput(dx: h.dx, dy: h.dy)
    }
}
