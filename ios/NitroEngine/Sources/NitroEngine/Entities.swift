import Foundation

// Entity shapes from the factories in www/game.js L183-411. Kept as plain
// value types with the same field names so the port and the online codec
// can be diffed against the JavaScript.

public typealias EntityID = String

public struct WorldSize: Hashable, Codable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}

public enum PilotID: String, Codable, Sendable {
    case player1, player2
}

public struct Player: Hashable, Codable, Sendable {
    public var id: PilotID
    public var x: Double
    public var y: Double
    public var vx: Double = 0
    public var vy: Double = 0
    public var radius: Double = GameConstants.playerRadius
    public var color: CSSColor

    public init(id: PilotID, x: Double, y: Double, color: CSSColor) {
        self.id = id; self.x = x; self.y = y; self.color = color
    }
}

public struct Particle: Hashable, Codable, Sendable {
    public var id: EntityID
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var radius: Double
    public var color: CSSColor
    /// Fractional on the web (`8 + Math.random() * 8`), compared `<= 0`.
    public var life: Double
    public var maxLife: Double

    public init(id: EntityID, x: Double, y: Double, vx: Double, vy: Double, radius: Double,
                color: CSSColor, life: Double, maxLife: Double) {
        self.id = id; self.x = x; self.y = y; self.vx = vx; self.vy = vy
        self.radius = radius; self.color = color; self.life = life; self.maxLife = maxLife
    }
}

public enum CollectibleKind: String, Codable, Sendable {
    case sundae, donut
}

public struct Sprinkle: Hashable, Codable, Sendable {
    public var a: Double     // angle
    public var d: Double     // distance factor 0.55...0.9
    public var rot: Double
    public var color: CSSColor
    public init(a: Double, d: Double, rot: Double, color: CSSColor) {
        self.a = a; self.d = d; self.rot = rot; self.color = color
    }
}

public struct Collectible: Hashable, Codable, Sendable {
    public var id: EntityID
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var radius: Double = 9
    /// Halo/particle tint: donut '#f472b6', sundae '#fde68a'.
    public var color: CSSColor
    public var kind: CollectibleKind
    public var sprinkles: [Sprinkle]

    public init(id: EntityID, x: Double, y: Double, vx: Double, vy: Double,
                color: CSSColor, kind: CollectibleKind, sprinkles: [Sprinkle]) {
        self.id = id; self.x = x; self.y = y; self.vx = vx; self.vy = vy
        self.color = color; self.kind = kind; self.sprinkles = sprinkles
    }
}

public struct Projectile: Hashable, Codable, Sendable {
    public var id: EntityID
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var radius: Double = 4
    public var color: CSSColor
    public var life: Int = 100

    public init(id: EntityID, x: Double, y: Double, vx: Double, vy: Double, color: CSSColor) {
        self.id = id; self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.color = color
    }
}

public enum PowerUpType: String, Codable, Sendable, CaseIterable {
    case shield, speed, weapon, magnet

    /// Orb colors (game.js:257).
    public var color: CSSColor {
        switch self {
        case .shield: return "#a855f7"
        case .speed: return "#22c55e"
        case .weapon: return "#ef4444"
        case .magnet: return "#c084fc"
        }
    }
}

public struct PowerUp: Hashable, Codable, Sendable {
    public var id: EntityID
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var radius: Double = 12
    public var color: CSSColor
    public var life: Int
    public var maxLife: Int
    public var subType: PowerUpType

    public init(id: EntityID, x: Double, y: Double, vx: Double, vy: Double,
                life: Int, maxLife: Int, subType: PowerUpType) {
        self.id = id; self.x = x; self.y = y; self.vx = vx; self.vy = vy
        self.life = life; self.maxLife = maxLife; self.subType = subType
        self.color = subType.color
    }
}

public struct FloatingText: Hashable, Codable, Sendable {
    public var id: EntityID
    public var x: Double
    public var y: Double
    public var text: String
    public var color: CSSColor
    public var alpha: Double = 1
    public var life: Int = 60
    public var scale: Double = 1

    public init(id: EntityID, x: Double, y: Double, text: String, color: CSSColor, scale: Double = 1) {
        self.id = id; self.x = x; self.y = y; self.text = text; self.color = color; self.scale = scale
    }
}

/// `burnt` is the cookie quest's charred cookie / crumb (game.js
/// createBurntCookie / createCrumb): a regular asteroid for every rule except
/// the off-screen +10, drawn by drawBurntCookie.
public enum AsteroidStyle: String, Codable, Sendable, CaseIterable {
    case rocky, faceted, blobby, burnt
}

/// Palette key (game.js:18-121). rocky = gray, faceted = blue, blobby = darkblue;
/// purple and pink exist in the palette table but are never spawned; burnt is
/// the cookie quest's dark-chocolate palette.
public enum AsteroidTint: String, Codable, Sendable, CaseIterable {
    case purple, pink, gray, blue, darkblue, burnt
}

public struct Crater: Hashable, Codable, Sendable {
    public var rx: Double
    public var ry: Double
    public var r: Double
    public var rot: Double
    public init(rx: Double, ry: Double, r: Double, rot: Double) {
        self.rx = rx; self.ry = ry; self.r = r; self.rot = rot
    }
}

public struct Speckle: Hashable, Codable, Sendable {
    public var rx: Double
    public var ry: Double
    public var r: Double
    public init(rx: Double, ry: Double, r: Double) { self.rx = rx; self.ry = ry; self.r = r }
}

public struct Asteroid: Hashable, Codable, Sendable {
    public var id: EntityID
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var radius: Double
    /// Debris/shockwave tint ('hsl(...)' string, game.js:386-388).
    public var color: CSSColor
    public var style: AsteroidStyle
    public var tint: AsteroidTint
    /// Radius multipliers per vertex (roundness + random * spread).
    public var vertices: [Double]
    public var craters: [Crater]
    public var speckles: [Speckle]
    public var rotation: Double
    public var spinSpeed: Double

    public init(id: EntityID, x: Double, y: Double, vx: Double, vy: Double, radius: Double,
                color: CSSColor, style: AsteroidStyle, tint: AsteroidTint, vertices: [Double],
                craters: [Crater], speckles: [Speckle], rotation: Double, spinSpeed: Double) {
        self.id = id; self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.radius = radius
        self.color = color; self.style = style; self.tint = tint; self.vertices = vertices
        self.craters = craters; self.speckles = speckles; self.rotation = rotation
        self.spinSpeed = spinSpeed
    }
}

public struct Star: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    /// Size; also the scroll speed factor (y += s * 0.5 per tick).
    public var s: Double
    public init(x: Double, y: Double, s: Double) { self.x = x; self.y = y; self.s = s }
}

// MARK: Secret cookie quest (game.js:124-146, 464-565, 1312-1395)

/// The lone cookie that drifts across a Hard run (createDriftingCookie,
/// game.js:467-484). Caught -> the quest starts.
public struct DriftingCookie: Hashable, Codable, Sendable {
    public var id: EntityID = "secret_cookie"
    public var x: Double
    public var y: Double
    /// +2.4 from the left edge, -2.4 from the right; vy is the wobble.
    public var vx: Double
    /// Donut-sized (a donut body draws at 9 * 1.25).
    public var radius: Double = 11
    /// Phase of the vertical wobble (y += sin(frame / 25 + wobble) * 0.7).
    public var wobble: Double
    public var rotation: Double = 0
    public var spin: Double = 0.01

    public init(id: EntityID = "secret_cookie", x: Double, y: Double, vx: Double, radius: Double = 11,
                wobble: Double, rotation: Double = 0, spin: Double = 0.01) {
        self.id = id; self.x = x; self.y = y; self.vx = vx; self.radius = radius
        self.wobble = wobble; self.rotation = rotation; self.spin = spin
    }
}

/// A cookie raining down in quest levels 1 and 2 (createQuestCookie,
/// game.js:488-506). Drawn like the drifting cookie, at radius 13.
public struct QuestCookie: Hashable, Codable, Sendable {
    public var id: EntityID
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var radius: Double = 13
    public var rotation: Double
    public var spin: Double

    public init(id: EntityID, x: Double, y: Double, vx: Double, vy: Double, radius: Double = 13,
                rotation: Double, spin: Double) {
        self.id = id; self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.radius = radius
        self.rotation = rotation; self.spin = spin
    }
}

/// The Giant Cookie of level 3 (beginQuestPlay, game.js:1360-1372): a
/// bitten cookie that bounces around the world, fires crumb rings and
/// shows an hp bar (hp / maxHp).
public struct QuestBoss: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var radius: Double = 58
    public var hp: Int
    public var maxHp: Int
    public var rotation: Double = 0
    /// Frames of white flash left after a projectile hit (8 on a hit).
    public var hitFlash: Int = 0
    /// Ship-bump immunity frames left (45 after a bump).
    public var contactCooldown: Int = 0

    public init(x: Double, y: Double, vx: Double, vy: Double, radius: Double = 58, hp: Int, maxHp: Int,
                rotation: Double = 0, hitFlash: Int = 0, contactCooldown: Int = 0) {
        self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.radius = radius
        self.hp = hp; self.maxHp = maxHp; self.rotation = rotation
        self.hitFlash = hitFlash; self.contactCooldown = contactCooldown
    }
}

/// `quest.phase` (game.js:1340). `intro`, `won`, `failed` and `complete` are
/// banner phases (phaseTimer counts down); `play` is the timed level.
public enum QuestPhase: String, Codable, Sendable, CaseIterable {
    case intro, play, won, complete, failed
}

/// `state.quest` (startQuest, game.js:1338-1347): the running cookie quest.
public struct QuestState: Hashable, Codable, Sendable {
    /// 1...3
    public var level: Int
    public var phase: QuestPhase
    /// Frames left in a banner phase (120; 180 for `complete`).
    public var phaseTimer: Int
    /// Play frames elapsed in this level (the clock shows duration - timer).
    public var timer: Int
    /// Cookies to collect this level (QuestLevelDef.goal).
    public var goal: Int
    public var collected: Int
    /// The raining quest cookies.
    public var cookies: [QuestCookie]
    /// The Giant Cookie (level 3 play phase only).
    public var boss: QuestBoss?

    public init(level: Int, phase: QuestPhase, phaseTimer: Int, timer: Int, goal: Int, collected: Int,
                cookies: [QuestCookie], boss: QuestBoss?) {
        self.level = level; self.phase = phase; self.phaseTimer = phaseTimer; self.timer = timer
        self.goal = goal; self.collected = collected; self.cookies = cookies; self.boss = boss
    }
}

/// One row of QUEST_LEVELS (game.js:131-138). Durations are frames at 60
/// fps; `rain` / `burnt` are per-frame spawn chances during the play phase.
public struct QuestLevelDef: Hashable, Codable, Sendable {
    public let name: String
    public let duration: Int
    public let goal: Int
    public let rain: Double
    public let burnt: Double
    /// Keep the normal asteroid spawns running during this level.
    public let asteroids: Bool
    public let hint: String

    public init(name: String, duration: Int, goal: Int, rain: Double, burnt: Double, asteroids: Bool = false, hint: String) {
        self.name = name; self.duration = duration; self.goal = goal
        self.rain = rain; self.burnt = burnt; self.hint = hint
        self.asteroids = asteroids
    }
}
