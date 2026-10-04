import Foundation

// Port of the module-level constants in www/game.js (L12-15, L105).
public enum GameConstants {
    public static let playerRadius: Double = 15
    public static let asteroidMinRadius: Double = 10
    public static let asteroidMaxRadius: Double = 30
    /// Base spawn rate; scaled by difficulty squared.
    public static let spawnRate: Double = 0.03
    public static let starCount = 50

    /// Simulation tick rate. game.js runs one `update()` per
    /// requestAnimationFrame at 60 Hz; every duration in the engine is a
    /// frame count, so the tick rate is part of the game's definition.
    public static let ticksPerSecond: Double = 60
    public static let tickMs: Double = 1000.0 / 60.0

    // MARK: Secret cookie quest (game.js:124-146)

    /// QUEST_LEVELS: the three secret levels, indexed by `quest.level - 1`.
    public static let questLevels: [QuestLevelDef] = [
        QuestLevelDef(name: "COOKIE CRUMBS", duration: 1800, goal: 10, rain: 0.045, burnt: 0, asteroids: 0.65,
                      hint: "COLLECT 10 COOKIES · MIND THE ASTEROIDS"),
        QuestLevelDef(name: "CRUMB STORM", duration: 2100, goal: 15, rain: 0.04, burnt: 0.02,
                      hint: "COLLECT 15 COOKIES · DODGE THE BURNT ONES"),
        QuestLevelDef(name: "THE COOKIE JAR", duration: 2700, goal: 1, rain: 0, burnt: 0.012,
                      hint: "CRACK THE COOKIE JAR · DON'T TOUCH THE SUNS")
    ]
    /// QUEST_BOSS_HP
    public static let questBossHP = 50
    /// QUEST_SUN_COUNT / QUEST_SUN_RADIUS / QUEST_SUN_ARM_FRAMES: level 3's
    /// lethal little suns and their harmless warm-up.
    /// QUEST_WEAPON_RESUPPLY: level 3 re-supplies a W orb this often while unarmed.
    public static let questWeaponResupply = 450
    public static let questSunCount = 3
    public static let questSunRadius = 14.0
    public static let questSunArmFrames = 90
    public static let sunColor: CSSColor = "#fbbf24"
    /// QUEST_HUNTER_SPEED / QUEST_HUNTER_ACCEL: the hunting sun's chase.
    public static let questHunterSpeed = 2.8
    public static let questHunterAccel = 0.1
    /// QUEST_BOSS_FIRE_INTERVAL: play frames between crumb rings.
    public static let questBossFireInterval = 150
    /// QUEST_BOSS_CONTACT_COOLDOWN: frames a ship is immune after bumping the boss.
    public static let questBossContactCooldown = 45
    /// COOKIE_COLOR: cookie dough tan (rings, boss debris, death explosion).
    public static let cookieColor: CSSColor = "#d4a373"
    /// COOKIE_GOLD: quest floating texts, hp bar and banners.
    public static let cookieGold: CSSColor = "#fbbf24"
    /// Burnt cookie / crumb body color (`asteroid.color` for debris).
    public static let burntCookieColor: CSSColor = "#3b2314"
    /// CRUMB_VERTICES: a crumb's outline (no randoms): ten near-round vertices.
    public static let crumbVertices: [Double] = [1, 0.96, 1.02, 0.95, 1, 0.97, 1.03, 0.96, 1, 0.98]
}
