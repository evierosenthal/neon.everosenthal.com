import Foundation

/// The Tailor's three racks, transcribed from www/ui.js (SKINS L67-126,
/// TRAILS L132-160, FLAMES L167-226) in the same order with every id, price
/// and color string verbatim. The ids and prices are shared with the server.
public enum GearCatalog {

    // MARK: Rocket skins (ui.js:67-126)

    public static let skins: [Skin] = [
        Skin(id: "cyan", name: "Neon Classic", price: 0, accent: "#22d3ee"),
        Skin(id: "rose", name: "Rose Racer", price: 500, accent: "#fb7185"),
        Skin(id: "emerald", name: "Emerald Comet", price: 500, accent: "#34d399"),
        Skin(id: "ice", name: "Ice Crystal", price: 800, accent: "#7dd3fc",
             hull: ["#93c5fd", "#f8fafc", "#e0f2fe", "#60a5fa"],
             window: ["#f0f9ff", "#bae6fd", "#1d4ed8"]),
        Skin(id: "candy", name: "Candy Sundae", price: 1000, accent: "#f472b6",
             hull: ["#d9a066", "#fff7ed", "#fde68a", "#b45309"],
             window: ["#fdf2f8", "#f9a8d4", "#9d174d"]),
        Skin(id: "toxic", name: "Toxic Venom", price: 1200, accent: "#a3e635",
             hull: ["#14532d", "#86efac", "#4ade80", "#052e16"],
             window: ["#f7fee7", "#bef264", "#3f6212"]),
        Skin(id: "gold", name: "Solar Flare", price: 1500, accent: "#fbbf24",
             hull: ["#b45309", "#fef9c3", "#fde68a", "#a16207"]),
        Skin(id: "magma", name: "Magma Core", price: 1800, accent: "#f97316",
             hull: ["#7f1d1d", "#fca5a5", "#ef4444", "#450a0a"],
             window: ["#fff7ed", "#fdba74", "#7c2d12"]),
        Skin(id: "amethyst", name: "Royal Amethyst", price: 2400, accent: "#fbbf24",
             hull: ["#4c1d95", "#c4b5fd", "#8b5cf6", "#2e1065"],
             window: ["#fefce8", "#fde047", "#713f12"]),
        Skin(id: "void", name: "Void Shadow", price: 3000, accent: "#c084fc",
             hull: ["#1e293b", "#64748b", "#475569", "#0f172a"],
             window: ["#f5d0fe", "#e879f9", "#701a75"]),
        Skin(id: "stealth", name: "Stealth Ops", price: 4000, accent: "#64748b",
             hull: ["#0f172a", "#334155", "#1e293b", "#020617"],
             window: ["#fecaca", "#ef4444", "#450a0a"]),
        Skin(id: "lime", name: "Lime Zest", price: 600, accent: "#a3e635"),
        Skin(id: "bubblegum", name: "Bubblegum", price: 700, accent: "#f472b6",
             hull: ["#f9a8d4", "#fdf2f8", "#fce7f3", "#ec4899"],
             window: ["#eff6ff", "#93c5fd", "#1e40af"]),
        Skin(id: "oceanwave", name: "Ocean Wave", price: 900, accent: "#0ea5e9",
             accentGradient: ["#22d3ee", "#0ea5e9", "#1e40af"]),
        Skin(id: "grape", name: "Neon Grape", price: 1000, accent: "#a855f7",
             hull: ["#6d28d9", "#ede9fe", "#c4b5fd", "#4c1d95"]),
        Skin(id: "sunset", name: "Sunset Cruiser", price: 1100, accent: "#fb923c",
             accentGradient: ["#fbbf24", "#fb923c", "#ec4899"]),
        Skin(id: "cherrybomb", name: "Cherry Bomb", price: 1300, accent: "#fecdd3",
             hull: ["#991b1b", "#fca5a5", "#ef4444", "#7f1d1d"],
             window: ["#fff1f2", "#fda4af", "#881337"]),
        Skin(id: "copper", name: "Copper Punk", price: 1600, accent: "#22d3ee",
             hull: ["#92400e", "#fdba74", "#ea580c", "#7c2d12"],
             window: ["#ecfeff", "#67e8f9", "#155e75"]),
        Skin(id: "cottoncandy", name: "Cotton Candy", price: 1800, accent: "#f9a8d4",
             hull: ["#bfdbfe", "#fdf2f8", "#fce7f3", "#93c5fd"],
             accentGradient: ["#f9a8d4", "#e9d5ff", "#93c5fd"]),
        Skin(id: "midnightgold", name: "Midnight Gold", price: 2000, accent: "#fbbf24",
             hull: ["#0f172a", "#475569", "#1e293b", "#020617"],
             window: ["#fefce8", "#fde047", "#713f12"]),
        Skin(id: "emeraldroyale", name: "Emerald Royale", price: 2600, accent: "#fbbf24",
             hull: ["#065f46", "#a7f3d0", "#34d399", "#064e3b"],
             window: ["#fefce8", "#fde047", "#713f12"]),
        Skin(id: "dragonfire", name: "Dragonfire", price: 3600, accent: "#ef4444",
             hull: ["#1c1917", "#57534e", "#292524", "#0c0a09"],
             window: ["#fff7ed", "#fdba74", "#7c2d12"],
             accentGradient: ["#fde047", "#f97316", "#dc2626"]),
        Skin(id: "aurora", name: "Aurora Prism", price: 5000, accent: "#a855f7",
             accentGradient: ["#f472b6", "#a855f7", "#22d3ee"]),
        Skin(id: "galaxy", name: "Galaxy Prism", price: 6000, accent: "#22d3ee", animated: true)
    ]

    // MARK: Thruster trails (ui.js:132-160)

    public static let trails: [Trail] = [
        Trail(id: "classic", name: "Classic Ion", price: 0, colors: ["#ff00ff"]),
        Trail(id: "rosepetal", name: "Rose Petal", price: 500, colors: ["#fda4af", "#fb7185", "#ffe4e6"]),
        Trail(id: "bubble", name: "Bubble Pop", price: 500, colors: ["#f9a8d4", "#fdf2f8", "#f472b6"]),
        Trail(id: "lemon", name: "Electric Lemon", price: 600, colors: ["#fde047", "#facc15", "#fef9c3"]),
        Trail(id: "mint", name: "Mint Breeze", price: 600, colors: ["#a7f3d0", "#6ee7b7", "#ecfdf5"]),
        Trail(id: "ember", name: "Ember Burn", price: 600, colors: ["#f97316", "#fbbf24", "#ef4444"]),
        Trail(id: "lavender", name: "Lavender Mist", price: 700, colors: ["#c4b5fd", "#a78bfa", "#ede9fe"]),
        Trail(id: "goldrush", name: "Gold Rush", price: 700, colors: ["#fbbf24", "#fde68a", "#b45309"]),
        Trail(id: "sky", name: "Sky Stream", price: 700, colors: ["#93c5fd", "#dbeafe", "#60a5fa"]),
        Trail(id: "frost", name: "Frost Wake", price: 800, colors: ["#7dd3fc", "#e0f2fe", "#38bdf8"]),
        Trail(id: "venom", name: "Venom Stream", price: 800, colors: ["#a3e635", "#4ade80"]),
        Trail(id: "ocean", name: "Ocean Spray", price: 900, colors: ["#22d3ee", "#0ea5e9", "#a5f3fc"]),
        Trail(id: "cherry", name: "Cherry Fizz", price: 1000, colors: ["#ef4444", "#fb7185", "#fecdd3"]),
        Trail(id: "magma", name: "Magma Drip", price: 1100, colors: ["#dc2626", "#f97316", "#7c2d12"]),
        Trail(id: "sludge", name: "Toxic Sludge", price: 1100, colors: ["#65a30d", "#a3e635", "#365314"]),
        Trail(id: "ghost", name: "Ghost Flame", price: 1200, colors: ["#f8fafc", "#cbd5e1", "#e2e8f0"]),
        Trail(id: "velvet", name: "Royal Velvet", price: 1300, colors: ["#7c3aed", "#a855f7", "#ddd6fe"]),
        Trail(id: "confetti", name: "Cosmic Confetti", price: 1400, colors: ["#f472b6", "#4ade80", "#60a5fa", "#fbbf24"]),
        Trail(id: "pulse", name: "Neon Pulse", price: 1500, colors: ["#22d3ee", "#f0fdff"], count: 2),
        Trail(id: "stardust", name: "Stardust", price: 1600, colors: ["#fef9c3", "#fde68a", "#ffffff"], count: 2),
        Trail(id: "solarwind", name: "Solar Wind", price: 1800, colors: ["#fb923c", "#fff7ed", "#fdba74"], count: 2),
        Trail(id: "firework", name: "Firework Fizz", price: 1900,
              colors: ["#f472b6", "#fbbf24", "#4ade80", "#60a5fa", "#ffffff"], count: 2),
        Trail(id: "aurorawake", name: "Aurora Wake", price: 2200, colors: ["#4ade80", "#22d3ee", "#a78bfa"], count: 2),
        Trail(id: "comet", name: "Comet Tail", price: 2500, colors: ["#e0f2fe", "#7dd3fc", "#ffffff"], count: 3),
        Trail(id: "rainbow", name: "Rainbow Ribbon", price: 3000,
              colors: ["#f472b6", "#a855f7", "#22d3ee", "#4ade80", "#fbbf24"], count: 2, animated: true)
    ]

    // MARK: Fire styles (ui.js:167-226)

    public static let flames: [Flame] = [
        Flame(id: "classic", name: "Classic Fire", price: 0, style: .classic, power: nil,
              powerLabel: "NO POWER"),
        Flame(id: "greenfire", name: "Green Inferno", price: 500, style: .classic, power: nil,
              powerLabel: "NO POWER",
              pal: ["rgba(22, 163, 74, 0.85)", "rgba(74, 222, 128, 0.95)", "rgba(240, 253, 244, 0.95)"], glow: "#4ade80"),
        Flame(id: "bluefire", name: "Blue Blaze", price: 600, style: .blue, power: nil,
              powerLabel: "NO POWER"),
        Flame(id: "violetburn", name: "Violet Burn", price: 700, style: .classic, power: nil,
              powerLabel: "NO POWER",
              pal: ["rgba(126, 34, 206, 0.85)", "rgba(192, 132, 252, 0.95)", "rgba(250, 245, 255, 0.95)"], glow: "#c084fc"),
        Flame(id: "pinkflare", name: "Pink Flare", price: 700, style: .classic, power: nil,
              powerLabel: "NO POWER",
              pal: ["rgba(219, 39, 119, 0.85)", "rgba(244, 114, 182, 0.95)", "rgba(253, 242, 248, 0.95)"], glow: "#f472b6"),
        Flame(id: "snail", name: "Snail Smoke", price: 800, style: .smoke, power: .slow,
              powerLabel: "POWER: SLOW-MO SHIP"),
        Flame(id: "neonrings", name: "Neon Rings", price: 900, style: .rings, power: nil,
              powerLabel: "NO POWER", ringColors: ["#22d3ee", "#67e8f9", "#a5f3fc"]),
        Flame(id: "eggshell", name: "Eggshell Flame", price: 900, style: .classic, power: .fragile,
              powerLabel: "POWER: DOUBLE DAMAGE",
              pal: ["rgba(250, 240, 200, 0.85)", "rgba(254, 249, 195, 0.95)", "rgba(255, 255, 255, 0.95)"], glow: "#fef9c3"),
        Flame(id: "whitenova", name: "White Nova", price: 1000, style: .classic, power: nil,
              powerLabel: "NO POWER",
              pal: ["rgba(203, 213, 225, 0.85)", "rgba(241, 245, 249, 0.95)", "rgba(255, 255, 255, 0.98)"], glow: "#f8fafc"),
        Flame(id: "rings", name: "Ring Burner", price: 1200, style: .rings, power: .spin,
              powerLabel: "POWER: ALWAYS SPINNING"),
        Flame(id: "wobblesmoke", name: "Wobble Smoke", price: 1200, style: .smoke, power: .wobble,
              powerLabel: "POWER: WOBBLY FLIGHT", smokeColors: ["#a855f7", "#c4b5fd", "#ede9fe"]),
        Flame(id: "voidfire", name: "Void Fire", price: 1300, style: .classic, power: nil,
              powerLabel: "NO POWER",
              pal: ["rgba(15, 23, 42, 0.9)", "rgba(88, 28, 135, 0.95)", "rgba(192, 132, 252, 0.95)"], glow: "#581c87"),
        Flame(id: "mirrorflame", name: "Mirror Flame", price: 1500, style: .classic, power: .mirror,
              powerLabel: "POWER: REVERSED KEYS",
              pal: ["rgba(13, 148, 136, 0.85)", "rgba(45, 212, 191, 0.95)", "rgba(240, 253, 250, 0.95)"], glow: "#2dd4bf"),
        Flame(id: "cyclonejet", name: "Cyclone Jet", price: 1600, style: .jet, power: .spin,
              powerLabel: "POWER: ALWAYS SPINNING",
              pal: ["rgba(22, 163, 74, 0.85)", "rgba(134, 239, 172, 0.95)", "rgba(255, 255, 255, 0.95)"], glow: "#4ade80"),
        Flame(id: "pocketrocket", name: "Pocket Rocket", price: 1600, style: .jet, power: .tiny,
              powerLabel: "POWER: TINY SHIP",
              pal: ["rgba(219, 39, 119, 0.85)", "rgba(249, 168, 212, 0.95)", "rgba(255, 255, 255, 0.95)"], glow: "#f472b6"),
        Flame(id: "megaburner", name: "Mega Burner", price: 1700, style: .smoke, power: .giant,
              powerLabel: "POWER: GIANT SHIP", smokeColors: ["#44403c", "#78716c", "#a8a29e"]),
        Flame(id: "turbo", name: "Turbo Torch", price: 1800, style: .jet, power: .fast,
              powerLabel: "POWER: EXTRA SPEED"),
        Flame(id: "bouncyblast", name: "Bouncy Blast", price: 1900, style: .rings, power: .bouncy,
              powerLabel: "POWER: BOUNCY WALLS", ringColors: ["#4ade80", "#86efac", "#bbf7d0"]),
        Flame(id: "magnetmuzzle", name: "Magnet Muzzle", price: 2000, style: .rings, power: .magnet,
              powerLabel: "POWER: TREAT MAGNET", ringColors: ["#c084fc", "#a855f7", "#ddd6fe"]),
        Flame(id: "ironforge", name: "Iron Forge", price: 2200, style: .smoke, power: .armor,
              powerLabel: "POWER: EXTRA ARMOR", smokeColors: ["#b91c1c", "#f87171", "#fecaca"]),
        Flame(id: "starfire", name: "Star Fire", price: 2400, style: .stars, power: .lucky,
              powerLabel: "POWER: 2× COINS"),
        Flame(id: "cometfire", name: "Comet Fire", price: 2800, style: .jet, power: .fast,
              powerLabel: "POWER: EXTRA SPEED",
              pal: ["rgba(224, 242, 254, 0.9)", "rgba(125, 211, 252, 0.95)", "rgba(255, 255, 255, 0.98)"], glow: "#e0f2fe"),
        Flame(id: "rainbowfire", name: "Rainbow Fire", price: 3600, style: .classic, power: nil,
              powerLabel: "NO POWER", animatedPal: true),
        Flame(id: "moneystorm", name: "Money Storm", price: 5000, style: .stars, power: .jackpot,
              powerLabel: "POWER: 3× COINS", starColor: "#4ade80")
    ]

    // MARK: Lookups (ui.js:1604-1609 getSkin and its getTrail/getFlame twins):
    // an unknown id falls back to the first (free) entry.

    public static func skin(id: String) -> Skin {
        skins.first { $0.id == id } ?? skins[0]
    }

    public static func trail(id: String) -> Trail {
        trails.first { $0.id == id } ?? trails[0]
    }

    public static func flame(id: String) -> Flame {
        flames.first { $0.id == id } ?? flames[0]
    }

    /// The stock loadout every pilot starts with (cyan / classic / classic).
    public static var defaultLoadout: Loadout {
        Loadout(skin: skins[0], trail: trails[0], flame: flames[0])
    }
}
