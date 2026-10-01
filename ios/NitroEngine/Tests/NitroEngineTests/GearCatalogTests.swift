import XCTest
@testable import NitroEngine

final class GearCatalogTests: XCTestCase {
    func testCounts() {
        XCTAssertEqual(GearCatalog.skins.count, 27)
        XCTAssertEqual(GearCatalog.trails.count, 25)
        XCTAssertEqual(GearCatalog.flames.count, 24)
    }

    func testFirstEntriesAreFree() {
        XCTAssertEqual(GearCatalog.skins[0].id, "cyan")
        XCTAssertEqual(GearCatalog.skins[0].price, 0)
        XCTAssertEqual(GearCatalog.trails[0].id, "classic")
        XCTAssertEqual(GearCatalog.trails[0].price, 0)
        XCTAssertEqual(GearCatalog.flames[0].id, "classic")
        XCTAssertEqual(GearCatalog.flames[0].price, 0)
    }

    func testIdOrder() {
        XCTAssertEqual(GearCatalog.skins.map(\.id), [
            "cyan", "rose", "emerald", "ice", "candy", "toxic", "gold", "magma", "amethyst", "void", "stealth",
            "lime", "bubblegum", "oceanwave", "grape", "sunset", "cherrybomb", "copper", "cottoncandy",
            "midnightgold", "emeraldroyale", "dragonfire", "aurora", "galaxy",
            "cookie", "chocochip", "goldencookie"
        ])
        XCTAssertEqual(GearCatalog.trails.map(\.id), [
            "classic", "rosepetal", "bubble", "lemon", "mint", "ember", "lavender", "goldrush", "sky", "frost",
            "venom", "ocean", "cherry", "magma", "sludge", "ghost", "velvet", "confetti", "pulse", "stardust",
            "solarwind", "firework", "aurorawake", "comet", "rainbow"
        ])
        XCTAssertEqual(GearCatalog.flames.map(\.id), [
            "classic", "greenfire", "bluefire", "violetburn", "pinkflare", "snail", "neonrings", "eggshell",
            "whitenova", "rings", "wobblesmoke", "voidfire", "mirrorflame", "cyclonejet", "pocketrocket",
            "megaburner", "turbo", "bouncyblast", "magnetmuzzle", "ironforge", "starfire", "cometfire",
            "rainbowfire", "moneystorm"
        ])
    }

    func testIdsAreUnique() {
        XCTAssertEqual(Set(GearCatalog.skins.map(\.id)).count, 27)
        XCTAssertEqual(Set(GearCatalog.trails.map(\.id)).count, 25)
        XCTAssertEqual(Set(GearCatalog.flames.map(\.id)).count, 24)
    }

    func testPaletteShapes() {
        for f in GearCatalog.flames {
            if let pal = f.pal { XCTAssertEqual(pal.count, 3, f.id) }
            if let rings = f.ringColors { XCTAssertEqual(rings.count, 3, f.id) }
            if let smoke = f.smokeColors { XCTAssertEqual(smoke.count, 3, f.id) }
        }
        for s in GearCatalog.skins {
            if let hull = s.hull { XCTAssertEqual(hull.count, 4, s.id) }
            if let win = s.window { XCTAssertEqual(win.count, 3, s.id) }
            if let g = s.accentGradient { XCTAssertEqual(g.count, 3, s.id) }
        }
        for t in GearCatalog.trails {
            XCTAssertFalse(t.colors.isEmpty, t.id)
            XCTAssertTrue((1...3).contains(t.count), t.id)
        }
    }

    func testPowersUsed() {
        let powers = Set(GearCatalog.flames.compactMap(\.power))
        XCTAssertEqual(powers, [.slow, .fast, .tiny, .giant, .armor, .fragile, .mirror, .wobble, .bouncy, .spin, .magnet, .lucky, .jackpot])
        XCTAssertEqual(GearCatalog.flames.filter { $0.power == .fast }.map(\.id), ["turbo", "cometfire"])
        XCTAssertEqual(GearCatalog.flames.filter { $0.power == .spin }.map(\.id), ["rings", "cyclonejet"])
        XCTAssertEqual(GearCatalog.flames.filter { $0.power == nil }.count, 9)
    }

    func testSpotValues() {
        XCTAssertEqual(GearCatalog.skin(id: "galaxy").animated, true)
        XCTAssertEqual(GearCatalog.skin(id: "galaxy").price, 6000)
        XCTAssertEqual(GearCatalog.trail(id: "rainbow").animated, true)
        XCTAssertEqual(GearCatalog.trail(id: "comet").count, 3)
        XCTAssertEqual(GearCatalog.flame(id: "moneystorm").starColor, "#4ade80")
        XCTAssertEqual(GearCatalog.flame(id: "rainbowfire").animatedPal, true)
        XCTAssertEqual(GearCatalog.flame(id: "voidfire").pal?[0], "rgba(15, 23, 42, 0.9)")
        XCTAssertEqual(GearCatalog.flame(id: "starfire").powerLabel, "POWER: 2× COINS")
        XCTAssertEqual(GearCatalog.skin(id: "cottoncandy").hull?[0], "#bfdbfe")
    }

    /// ui.js:132-140 — the cookie quest's three secret skins: free, secret,
    /// last on the rack, with the web's exact colors.
    func testSecretSkins() throws {
        XCTAssertEqual(GearCatalog.secretSkinIDs, ["cookie", "chocochip", "goldencookie"])
        XCTAssertEqual(GearCatalog.skins.filter(\.secret).map(\.id), GearCatalog.secretSkinIDs)
        for id in GearCatalog.secretSkinIDs {
            let s = GearCatalog.skin(id: id)
            XCTAssertEqual(s.price, 0, id)
            XCTAssertTrue(s.secret, id)
        }
        XCTAssertEqual(GearCatalog.skin(id: "cookie").name, "Cookie Crumb")
        XCTAssertEqual(GearCatalog.skin(id: "cookie").accent, "#d4a373")
        XCTAssertEqual(GearCatalog.skin(id: "cookie").hull, ["#8b5a2b", "#f5deb3", "#deb887", "#5c3a1e"])
        XCTAssertEqual(GearCatalog.skin(id: "cookie").window, ["#fff8e7", "#f4c27a", "#6b3e0f"])
        XCTAssertEqual(GearCatalog.skin(id: "chocochip").name, "Choco Chip")
        XCTAssertEqual(GearCatalog.skin(id: "chocochip").accent, "#a0522d")
        XCTAssertEqual(GearCatalog.skin(id: "chocochip").hull, ["#3b2314", "#a0522d", "#7b4a24", "#1f1008"])
        XCTAssertEqual(GearCatalog.skin(id: "chocochip").window, ["#fde68a", "#f59e0b", "#78350f"])
        XCTAssertEqual(GearCatalog.skin(id: "goldencookie").name, "Golden Cookie")
        XCTAssertEqual(GearCatalog.skin(id: "goldencookie").accent, "#fbbf24")
        XCTAssertEqual(GearCatalog.skin(id: "goldencookie").accentGradient, ["#fde68a", "#fbbf24", "#b45309"])
        XCTAssertEqual(GearCatalog.skin(id: "goldencookie").hull, ["#b45309", "#fef3c7", "#fcd34d", "#92400e"])
        XCTAssertEqual(GearCatalog.skin(id: "goldencookie").window, ["#fffbeb", "#fde68a", "#78350f"])

        // JSON: `secret` only appears on secret skins, so the encoding of the
        // other 24 is unchanged (the parity test hands it to game.js).
        let galaxy = String(data: try JSONEncoder().encode(GearCatalog.skin(id: "galaxy")), encoding: .utf8)!
        XCTAssertFalse(galaxy.contains("secret"))
        XCTAssertTrue(galaxy.contains("\"animated\":true"))
        let cookie = String(data: try JSONEncoder().encode(GearCatalog.skin(id: "cookie")), encoding: .utf8)!
        XCTAssertTrue(cookie.contains("\"secret\":true"))
        let decoded = try JSONDecoder().decode(Skin.self, from: Data(galaxy.utf8))
        XCTAssertEqual(decoded, GearCatalog.skin(id: "galaxy"))
        XCTAssertEqual(try JSONDecoder().decode(Skin.self, from: Data(cookie.utf8)), GearCatalog.skin(id: "cookie"))
    }

    func testLookupFallsBackToFirstEntry() {
        XCTAssertEqual(GearCatalog.skin(id: "nope").id, "cyan")
        XCTAssertEqual(GearCatalog.trail(id: "nope").id, "classic")
        XCTAssertEqual(GearCatalog.flame(id: "nope").id, "classic")
        XCTAssertEqual(GearCatalog.flame(id: "turbo").id, "turbo")
        XCTAssertEqual(GearCatalog.defaultLoadout.skin.id, "cyan")
        XCTAssertEqual(GearCatalog.defaultLoadout.trail.id, "classic")
        XCTAssertEqual(GearCatalog.defaultLoadout.flame.id, "classic")
    }
}
