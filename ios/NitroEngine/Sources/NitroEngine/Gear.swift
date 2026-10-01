import Foundation

// Rocket skins, thruster trails and fire styles (ui.js:67-226). The ids and
// prices are shared with the web and the server, so they must match exactly.
// The catalog itself lives in GearCatalog.swift.

public struct Skin: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let price: Int
    public let accent: CSSColor
    /// Four gradient stops for a custom hull (nil = default hull colors).
    public var hull: [CSSColor]? = nil
    /// Three gradient stops for a custom window.
    public var window: [CSSColor]? = nil
    /// Multi-stop accent (fins/stripe) instead of the flat accent color.
    public var accentGradient: [CSSColor]? = nil
    /// Galaxy Prism: hull hue cycles over time.
    public var animated: Bool = false
    /// Secret skins (ui.js:132-140): earned only by finishing the cookie
    /// quest — never purchasable and never free for developers.
    public var secret: Bool = false

    public init(id: String, name: String, price: Int, accent: CSSColor,
                hull: [CSSColor]? = nil, window: [CSSColor]? = nil,
                accentGradient: [CSSColor]? = nil, animated: Bool = false, secret: Bool = false) {
        self.id = id; self.name = name; self.price = price; self.accent = accent
        self.hull = hull; self.window = window; self.accentGradient = accentGradient
        self.animated = animated; self.secret = secret
    }

    // Codable by hand so `secret` is only written when true: the JSON of
    // every pre-existing skin (and what the parity test hands game.js) is
    // byte-for-byte what the synthesized conformance produced before.
    enum CodingKeys: String, CodingKey {
        case id, name, price, accent, hull, window, accentGradient, animated, secret
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        price = try c.decode(Int.self, forKey: .price)
        accent = try c.decode(CSSColor.self, forKey: .accent)
        hull = try c.decodeIfPresent([CSSColor].self, forKey: .hull)
        window = try c.decodeIfPresent([CSSColor].self, forKey: .window)
        accentGradient = try c.decodeIfPresent([CSSColor].self, forKey: .accentGradient)
        animated = try c.decodeIfPresent(Bool.self, forKey: .animated) ?? false
        secret = try c.decodeIfPresent(Bool.self, forKey: .secret) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(price, forKey: .price)
        try c.encode(accent, forKey: .accent)
        try c.encodeIfPresent(hull, forKey: .hull)
        try c.encodeIfPresent(window, forKey: .window)
        try c.encodeIfPresent(accentGradient, forKey: .accentGradient)
        try c.encode(animated, forKey: .animated)
        if secret { try c.encode(secret, forKey: .secret) }
    }
}

public struct Trail: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let price: Int
    public let colors: [CSSColor]
    /// Particles emitted per tick (1, 2 or 3). 'count: 2' trails burn denser.
    public var count: Int = 1
    /// Rainbow Ribbon: colors cycle over time.
    public var animated: Bool = false

    public init(id: String, name: String, price: Int, colors: [CSSColor], count: Int = 1, animated: Bool = false) {
        self.id = id; self.name = name; self.price = price; self.colors = colors
        self.count = count; self.animated = animated
    }
}

public enum FlameStyle: String, Codable, Sendable, CaseIterable {
    case classic, blue, jet, smoke, rings, stars
}

/// Gameplay powers carried by some fires (active whenever equipped).
public enum FlamePower: String, Codable, Sendable, CaseIterable {
    case slow      // Snail Smoke: speed x0.65
    case fast      // Turbo Torch, Comet Fire: speed x1.35
    case tiny      // Pocket Rocket: hull radius x0.7
    case giant     // Mega Burner: hull radius x1.45
    case armor     // Iron Forge: damage x0.6 (rounded)
    case fragile   // Eggshell Flame: damage x2
    case mirror    // Mirror Flame: steering reversed
    case wobble    // Wobble Smoke: ship sways
    case bouncy    // Bouncy Blast: walls bounce (-0.85)
    case spin      // Ring Burner, Cyclone Jet: always spinning
    case magnet    // Magnet Muzzle: treat magnet always on
    case lucky     // Star Fire: 2x coins
    case jackpot   // Money Storm: 3x coins
}

public struct Flame: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let price: Int
    public let style: FlameStyle
    public let power: FlamePower?
    public let powerLabel: String
    /// Three-color palette for classic/jet fires (rgba strings).
    public var pal: [CSSColor]? = nil
    public var glow: CSSColor? = nil
    public var ringColors: [CSSColor]? = nil
    public var smokeColors: [CSSColor]? = nil
    public var starColor: CSSColor? = nil
    /// Rainbow Fire: palette hue cycles over time.
    public var animatedPal: Bool = false

    public init(id: String, name: String, price: Int, style: FlameStyle, power: FlamePower?,
                powerLabel: String, pal: [CSSColor]? = nil, glow: CSSColor? = nil,
                ringColors: [CSSColor]? = nil, smokeColors: [CSSColor]? = nil,
                starColor: CSSColor? = nil, animatedPal: Bool = false) {
        self.id = id; self.name = name; self.price = price; self.style = style
        self.power = power; self.powerLabel = powerLabel; self.pal = pal; self.glow = glow
        self.ringColors = ringColors; self.smokeColors = smokeColors
        self.starColor = starColor; self.animatedPal = animatedPal
    }
}

/// One pilot's equipped gear.
public struct Loadout: Hashable, Codable, Sendable {
    public var skin: Skin
    public var trail: Trail
    public var flame: Flame

    public init(skin: Skin, trail: Trail, flame: Flame) {
        self.skin = skin; self.trail = trail; self.flame = flame
    }
}
