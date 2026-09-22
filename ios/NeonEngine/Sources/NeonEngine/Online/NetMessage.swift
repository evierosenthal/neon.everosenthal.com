import Foundation

// Wire messages between host and guest (game.js:2206-2357 and the lobby
// handshake in ui.js:2299-2359). Field names mirror the JSON keys the web
// sends so the two codecs can be compared; the iOS transport (GameKit)
// encodes them with WireCodec instead of JSON.

public enum NetMessage: Equatable, Sendable {
    /// Handshake: both sides announce their pilot and equipped gear.
    case hello(Hello)
    /// Host -> guest: launch the round.
    case go
    /// Guest -> host: launched, start simulating.
    case ready
    /// Either side is leaving.
    case bye
    /// Guest -> host: steering unit vector ({t:'in', x, y}).
    case input(dx: Double, dy: Double)
    /// Host -> guest: world snapshot ({t:'s', ...}).
    case snapshot(Snapshot)

    public struct Hello: Equatable, Codable, Sendable {
        public var name: String
        public var skin: String
        public var trail: String
        public var flame: String
        public init(name: String, skin: String, trail: String, flame: String) {
            self.name = name; self.skin = skin; self.trail = trail; self.flame = flame
        }
    }
}

/// `buildSnapshot()` (game.js:2212-2260). Positions are rounded to 0.1 by r1().
/// Adds `seq` (ordering guard) and the host's world size (so a guest with a
/// different screen can letterbox), which the web does not send.
public struct Snapshot: Equatable, Codable, Sendable {
    public var seq: UInt32 = 0
    public var world: WorldSize
    public var score: Int                     // sc
    public var health: Double                 // h
    public var difficulty: Double             // d
    public var dying: Bool                    // dy
    public var gameOver: Bool                 // go
    public var shipsDestroyed: Bool           // sd
    public var shake: Double                  // sh
    public var hitCount: Int                  // hc
    public var effects: ActiveEffects         // fx
    public var p: PackedPlayer                // p
    public var p2: PackedPlayer?              // p2
    public var a: [AsteroidRow] = []          // [id, x, y, rotation]
    public var an: [Asteroid] = []            // new asteroids in full
    public var c: [CollectibleRow] = []       // [id, x, y]
    public var cn: [Collectible] = []
    public var u: [PowerUpRow] = []           // [id, x, y, life]
    public var un: [PowerUp] = []
    public var j: [ProjectileRow] = []        // [x, y, radius, color]
    public var pt: [ParticleRow] = []         // [x, y, radius, color, life, maxLife]
    public var ft: [TextRow] = []             // [x, y, text, color, alpha, scale]

    public init(world: WorldSize, score: Int, health: Double, difficulty: Double, dying: Bool,
                gameOver: Bool, shipsDestroyed: Bool, shake: Double, hitCount: Int,
                effects: ActiveEffects, p: PackedPlayer, p2: PackedPlayer?) {
        self.world = world; self.score = score; self.health = health; self.difficulty = difficulty
        self.dying = dying; self.gameOver = gameOver; self.shipsDestroyed = shipsDestroyed
        self.shake = shake; self.hitCount = hitCount; self.effects = effects; self.p = p; self.p2 = p2
    }

    public struct PackedPlayer: Equatable, Codable, Sendable {
        public var x, y, vx, vy, radius: Double
        public init(x: Double, y: Double, vx: Double, vy: Double, radius: Double) {
            self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.radius = radius
        }
    }
    public struct AsteroidRow: Equatable, Codable, Sendable {
        public var id: EntityID; public var x, y, rotation: Double
        public init(id: EntityID, x: Double, y: Double, rotation: Double) {
            self.id = id; self.x = x; self.y = y; self.rotation = rotation
        }
    }
    public struct CollectibleRow: Equatable, Codable, Sendable {
        public var id: EntityID; public var x, y: Double
        public init(id: EntityID, x: Double, y: Double) { self.id = id; self.x = x; self.y = y }
    }
    public struct PowerUpRow: Equatable, Codable, Sendable {
        public var id: EntityID; public var x, y: Double; public var life: Int
        public init(id: EntityID, x: Double, y: Double, life: Int) {
            self.id = id; self.x = x; self.y = y; self.life = life
        }
    }
    public struct ProjectileRow: Equatable, Codable, Sendable {
        public var x, y, radius: Double; public var color: CSSColor
        public init(x: Double, y: Double, radius: Double, color: CSSColor) {
            self.x = x; self.y = y; self.radius = radius; self.color = color
        }
    }
    public struct ParticleRow: Equatable, Codable, Sendable {
        public var x, y, radius: Double; public var color: CSSColor; public var life, maxLife: Int
        public init(x: Double, y: Double, radius: Double, color: CSSColor, life: Int, maxLife: Int) {
            self.x = x; self.y = y; self.radius = radius; self.color = color; self.life = life; self.maxLife = maxLife
        }
    }
    public struct TextRow: Equatable, Codable, Sendable {
        public var x, y: Double; public var text: String; public var color: CSSColor
        public var alpha, scale: Double
        public init(x: Double, y: Double, text: String, color: CSSColor, alpha: Double, scale: Double) {
            self.x = x; self.y = y; self.text = text; self.color = color; self.alpha = alpha; self.scale = scale
        }
    }
}
