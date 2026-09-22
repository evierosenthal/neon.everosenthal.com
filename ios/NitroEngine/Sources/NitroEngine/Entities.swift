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

public enum AsteroidStyle: String, Codable, Sendable, CaseIterable {
    case rocky, faceted, blobby
}

/// Palette key (game.js:18-104). rocky = gray, faceted = blue, blobby = darkblue;
/// purple and pink exist in the palette table but are never spawned.
public enum AsteroidTint: String, Codable, Sendable, CaseIterable {
    case purple, pink, gray, blue, darkblue
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
