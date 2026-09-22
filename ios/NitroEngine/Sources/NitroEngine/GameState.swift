import Foundation

/// `state.activeEffects` — remaining frames per effect (game.js:471-476).
public struct ActiveEffects: Hashable, Codable, Sendable {
    public var shield = 0
    public var speedBoost = 0
    public var weaponUpgrade = 0
    public var magnet = 0
    public init() {}
    public init(shield: Int, speedBoost: Int, weaponUpgrade: Int, magnet: Int) {
        self.shield = shield; self.speedBoost = speedBoost
        self.weaponUpgrade = weaponUpgrade; self.magnet = magnet
    }
}

/// `state` in game.js (L453-477).
public struct GameState: Hashable, Codable, Sendable {
    public var player: Player
    public var player2: Player?
    public var asteroids: [Asteroid] = []
    public var particles: [Particle] = []
    public var collectibles: [Collectible] = []
    public var projectiles: [Projectile] = []
    public var powerUps: [PowerUp] = []
    public var floatingTexts: [FloatingText] = []
    public var score = 0
    public var health = 100
    public var isGameOver = false
    public var dying = false
    public var deathTimer = 0
    public var shipsDestroyed = false
    public var hitCount = 0
    public var difficulty: Double
    public var activeEffects = ActiveEffects()

    public init(player: Player, player2: Player?, difficulty: Double) {
        self.player = player
        self.player2 = player2
        self.difficulty = difficulty
    }

    /// Placeholder used between rounds (never simulated or drawn).
    public static let idle = GameState(player: Player(id: .player1, x: 0, y: 0, color: "#00ffff"),
                                       player2: nil, difficulty: 1)
}
