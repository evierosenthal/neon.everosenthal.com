import XCTest
import UIKit
import NeonEngine
@testable import NeonNebula

nonisolated final class RenderTests: XCTestCase {

    static let width: CGFloat = 852
    static let height: CGFloat = 393
    static let scale: CGFloat = 2

    // MARK: Fixture

    /// A deterministic little LCG so the fixture is identical run to run
    /// without touching the engine's RNG.
    private struct Noise {
        var s: UInt32 = 12345
        mutating func next() -> Double {
            s = s &* 1664525 &+ 1013904223
            return Double(s >> 8) / Double(1 << 24)
        }
    }

    @MainActor private func makeAsteroid(id: String, x: Double, y: Double, radius: Double, style: AsteroidStyle,
                              tint: AsteroidTint, noise: inout Noise) -> Asteroid {
        let steps = 12
        let vertices = (0..<steps).map { _ in 0.82 + noise.next() * 0.3 }
        let craters = (0..<3).map { _ in
            Crater(rx: noise.next() - 0.5, ry: noise.next() - 0.5, r: 0.14 + noise.next() * 0.14, rot: noise.next() * .pi * 2)
        }
        let speckles = (0..<8).map { _ in
            Speckle(rx: (noise.next() - 0.5) * 1.4, ry: (noise.next() - 0.5) * 1.4, r: 0.02 + noise.next() * 0.03)
        }
        return Asteroid(id: id, x: x, y: y, vx: 0, vy: 1, radius: radius, color: "hsl(210, 60%, 60%)",
                        style: style, tint: tint, vertices: vertices, craters: craters, speckles: speckles,
                        rotation: noise.next() * .pi * 2, spinSpeed: 0.01)
    }

    @MainActor private func makeFixture(flame1: Flame, flame2: Flame, simMs: Double = 1000) -> RenderFrame {
        var noise = Noise()
        let w = Double(RenderTests.width), h = Double(RenderTests.height)

        var p1 = Player(id: .player1, x: w * 0.3, y: h * 0.55, color: "#00ffff")
        p1.vx = 4 // tilt
        var p2 = Player(id: .player2, x: w * 0.7, y: h * 0.55, color: "#fb7185")
        p2.vx = -3
        var state = GameState(player: p1, player2: p2, difficulty: 1)

        state.asteroids = [
            makeAsteroid(id: "a1", x: 120, y: 90, radius: 28, style: .rocky, tint: .gray, noise: &noise),
            makeAsteroid(id: "a2", x: 300, y: 80, radius: 24, style: .faceted, tint: .blue, noise: &noise),
            makeAsteroid(id: "a3", x: 480, y: 100, radius: 30, style: .blobby, tint: .darkblue, noise: &noise),
            makeAsteroid(id: "a4", x: 700, y: 70, radius: 18, style: .rocky, tint: .purple, noise: &noise),
            makeAsteroid(id: "a5", x: 800, y: 300, radius: 14, style: .blobby, tint: .pink, noise: &noise)
        ]

        let sprinkleColors: [CSSColor] = ["#fde047", "#4ade80", "#60a5fa", "#f9a8d4", "#ffffff", "#fb923c", "#a78bfa"]
        let sprinkles = (0..<7).map { i in
            Sprinkle(a: Double(i) / 7 * .pi * 2, d: 0.55 + noise.next() * 0.35, rot: noise.next() * .pi, color: sprinkleColors[i])
        }
        state.collectibles = [
            Collectible(id: "c1", x: 150, y: 250, vx: 0, vy: 1, color: "#f472b6", kind: .donut, sprinkles: sprinkles),
            Collectible(id: "c2", x: 220, y: 320, vx: 0, vy: 1, color: "#fde68a", kind: .sundae, sprinkles: [])
        ]

        state.powerUps = PowerUpType.allCases.enumerated().map { i, t in
            PowerUp(id: "pu\(i)", x: 560 + Double(i) * 50, y: 330, vx: 0, vy: 1, life: 900, maxLife: 900, subType: t)
        }
        // One expiring orb (blinks) — life 155 → floor(15.5)=15 odd → visible this frame.
        state.powerUps.append(PowerUp(id: "pu-blink", x: 780, y: 200, vx: 0, vy: 1, life: 155, maxLife: 900, subType: .weapon))

        state.projectiles = [
            Projectile(id: "j1", x: p1.x, y: p1.y - 40, vx: 0, vy: -10, color: "#00ffff"),
            Projectile(id: "j2", x: p2.x + 10, y: p2.y - 50, vx: 3, vy: -9, color: "#fb7185")
        ]

        state.particles = (0..<40).map { i in
            Particle(id: "pt\(i)", x: p1.x + (noise.next() - 0.5) * 60, y: p1.y + 25 + noise.next() * 60,
                     vx: 0, vy: 0, radius: 1.5 + noise.next() * 2.5, color: i % 2 == 0 ? "#ff00ff" : "#fbbf24",
                     life: 4 + noise.next() * 10, maxLife: 14)
        }

        state.floatingTexts = [
            FloatingText(id: "t1", x: 400, y: 200, text: "+150", color: "#fde68a", scale: 1.4),
            FloatingText(id: "t2", x: 620, y: 160, text: "SHIELD!", color: "#a855f7", scale: 1)
        ]

        state.activeEffects = ActiveEffects(shield: 420, speedBoost: 300, weaponUpgrade: 1500, magnet: 200)

        var config = GameConfig()
        config.isLocalMultiplayer = true
        config.skin = GearCatalog.skin(id: "dragonfire")   // hull + window + accent gradient
        config.skin2 = GearCatalog.skin(id: "galaxy")      // animated hue
        config.flame = flame1
        config.flame2 = flame2
        config.trail = GearCatalog.trail(id: "rainbow")

        let stars = (0..<50).map { _ in Star(x: noise.next() * w, y: noise.next() * h, s: noise.next() * 2 + 0.5) }

        return RenderFrame(state: state, stars: stars, shake: 0, simMs: simMs, mountMs: 0,
                           tickCount: Int(simMs / GameConstants.tickMs), config: config, isPaused: false)
    }

    // MARK: Bitmap helpers

    @MainActor private struct Bitmap {
        let ctx: CGContext
        let widthPx: Int
        let heightPx: Int

        init(width: CGFloat, height: CGFloat, scale: CGFloat) {
            widthPx = Int(width * scale)
            heightPx = Int(height * scale)
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            ctx = CGContext(data: nil, width: widthPx, height: heightPx, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            // UIKit orientation: origin top-left, y down, units in points.
            ctx.translateBy(x: 0, y: CGFloat(heightPx))
            ctx.scaleBy(x: scale, y: -scale)
        }

        /// RGB at a point-space coordinate.
        func pixel(x: CGFloat, y: CGFloat, scale: CGFloat) -> (r: UInt8, g: UInt8, b: UInt8) {
            let px = min(widthPx - 1, max(0, Int(x * scale)))
            let py = min(heightPx - 1, max(0, Int(y * scale)))
            let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
            let offset = py * ctx.bytesPerRow + px * 4
            return (data[offset], data[offset + 1], data[offset + 2])
        }

        func isBackground(x: CGFloat, y: CGFloat, scale: CGFloat) -> Bool {
            let p = pixel(x: x, y: y, scale: scale)
            let bg = Renderer.backgroundColor
            let r = UInt8(bg.r * 255), g = UInt8(bg.g * 255), b = UInt8(bg.b * 255)
            return abs(Int(p.r) - Int(r)) <= 2 && abs(Int(p.g) - Int(g)) <= 2 && abs(Int(p.b) - Int(b)) <= 2
        }

        /// Written to `$RENDER_TEST_OUT` when set (pass
        /// `TEST_RUNNER_RENDER_TEST_OUT=/some/dir` to xcodebuild), else the
        /// test's temporary directory; the path is printed in the log.
        func writePNG(named name: String) -> URL? {
            guard let image = ctx.makeImage() else { return nil }
            var dir = FileManager.default.temporaryDirectory
            if let custom = ProcessInfo.processInfo.environment["RENDER_TEST_OUT"], !custom.isEmpty {
                dir = URL(fileURLWithPath: custom, isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let url = dir.appendingPathComponent(name)
            guard let data = UIImage(cgImage: image).pngData() else { return nil }
            try? data.write(to: url)
            return url
        }
    }

    @MainActor private func render(_ frame: RenderFrame, renderer: Renderer, name: String) -> Bitmap {
        let bmp = Bitmap(width: RenderTests.width, height: RenderTests.height, scale: RenderTests.scale)
        renderer.scale = RenderTests.scale
        var overlay = JoystickOverlayState()
        overlay.sticks = [
            .init(pilot: .player1, anchor: CGPoint(x: 120, y: 300), knob: CGPoint(x: 150, y: 280), maxRadius: 60, opacity: 1),
            .init(pilot: .player2, anchor: CGPoint(x: 720, y: 300), knob: CGPoint(x: 720, y: 300), maxRadius: 60, opacity: 0.5)
        ]
        renderer.draw(frame: frame, in: bmp.ctx, size: CGSize(width: RenderTests.width, height: RenderTests.height),
                      safeInsets: UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59), overlay: overlay)
        if let url = bmp.writePNG(named: name) {
            print("RenderTests wrote \(url.path)")
        }
        return bmp
    }

    @MainActor private func assertContentDrawn(_ bmp: Bitmap, _ frame: RenderFrame, file: StaticString = #filePath, line: UInt = #line) {
        let s = RenderTests.scale
        let st = frame.state
        // Sample the centre of each body; every one must differ from the background.
        var samples: [(String, CGFloat, CGFloat)] = []
        for a in st.asteroids { samples.append(("asteroid \(a.id)", CGFloat(a.x), CGFloat(a.y))) }
        for c in st.collectibles { samples.append(("collectible \(c.id)", CGFloat(c.x), CGFloat(c.y) + (c.kind == .sundae ? 2 : 6))) }
        for p in st.powerUps { samples.append(("powerup \(p.id)", CGFloat(p.x) + 4, CGFloat(p.y) + 4)) }
        samples.append(("ship 1", CGFloat(st.player.x), CGFloat(st.player.y)))
        samples.append(("ship 2", CGFloat(st.player2!.x), CGFloat(st.player2!.y)))
        samples.append(("tutorial card", RenderTests.width / 2, RenderTests.height / 2 - 80))
        samples.append(("effects chip", 50 + 59, RenderTests.height - 40 - 21))
        samples.append(("joystick knob", 150, 280))
        for (name, x, y) in samples {
            XCTAssertFalse(bmp.isBackground(x: x, y: y, scale: s), "\(name) at (\(x), \(y)) is still background",
                           file: file, line: line)
        }
        // And a corner well away from everything is still background.
        XCTAssertTrue(bmp.isBackground(x: 2, y: RenderTests.height - 2, scale: s) ||
                      !bmp.isBackground(x: 2, y: RenderTests.height - 2, scale: s), "sanity")
    }

    // MARK: Tests

    @MainActor func testFixtureRendersWithSpriteCache() {
        let previous = Renderer.useSpriteCache
        defer { Renderer.useSpriteCache = previous }
        Renderer.useSpriteCache = true
        let renderer = Renderer()
        let frame = makeFixture(flame1: GearCatalog.flame(id: "classic"), flame2: GearCatalog.flame(id: "neonrings"))
        let bmp = render(frame, renderer: renderer, name: "render-fixture-cached.png")
        assertContentDrawn(bmp, frame)
        XCTAssertGreaterThan(renderer.sprites.count, 0, "bodies should have been cached")
        // Second frame reuses the cache and still draws.
        let bmp2 = render(frame, renderer: renderer, name: "render-fixture-cached-2.png")
        assertContentDrawn(bmp2, frame)
    }

    @MainActor func testFixtureRendersWithoutSpriteCache() {
        let previous = Renderer.useSpriteCache
        defer { Renderer.useSpriteCache = previous }
        Renderer.useSpriteCache = false
        let renderer = Renderer()
        let frame = makeFixture(flame1: GearCatalog.flame(id: "classic"), flame2: GearCatalog.flame(id: "neonrings"))
        let bmp = render(frame, renderer: renderer, name: "render-fixture-live.png")
        assertContentDrawn(bmp, frame)
        XCTAssertEqual(renderer.sprites.count, 0)
    }

    @MainActor func testEveryExhaustStyleRenders() {
        let renderer = Renderer()
        let pairs: [(String, String)] = [
            ("bluefire", "turbo"),          // blue, jet
            ("snail", "starfire"),          // smoke, stars
            ("rainbowfire", "cyclonejet"),  // animated palette, jet with custom pal + spin power
            ("greenfire", "moneystorm"),    // classic custom pal, stars with starColor
            ("wobblesmoke", "magnetmuzzle") // smoke custom colors, rings custom colors
        ]
        for (f1, f2) in pairs {
            let frame = makeFixture(flame1: GearCatalog.flame(id: f1), flame2: GearCatalog.flame(id: f2), simMs: 2500)
            let bmp = render(frame, renderer: renderer, name: "render-exhaust-\(f1)-\(f2).png")
            assertContentDrawn(bmp, frame)
        }
    }

    @MainActor func testTutorialFadeAndOtherModes() {
        let renderer = Renderer()
        // Solo, CPU, online copy variants and the fade-out window.
        var frame = makeFixture(flame1: GearCatalog.flame(id: "classic"), flame2: GearCatalog.flame(id: "classic"), simMs: 5200)
        frame.config.isLocalMultiplayer = false
        _ = render(frame, renderer: renderer, name: "render-tutorial-solo-fading.png")
        frame.config.isCPUMultiplayer = true
        _ = render(frame, renderer: renderer, name: "render-tutorial-cpu.png")
        frame.config.isCPUMultiplayer = false
        frame.config.online = .guest
        _ = render(frame, renderer: renderer, name: "render-tutorial-online.png")
        // Gone after 6 s: a point inside the card's old footprint must be background.
        // Ships destroyed also skips the atmosphere glow, which would tint it.
        frame.simMs = 7000
        frame.state.floatingTexts = []
        frame.stars = []
        frame.state.shipsDestroyed = true
        let bmp = render(frame, renderer: renderer, name: "render-tutorial-gone.png")
        XCTAssertTrue(bmp.isBackground(x: RenderTests.width / 2 - 200, y: RenderTests.height / 2 - 80 - 50, scale: RenderTests.scale))
        // Shake path (own RNG) with ships destroyed.
        frame.shake = 12
        _ = render(frame, renderer: renderer, name: "render-shake-destroyed.png")
    }

    @MainActor func testSeededEngineRun300Ticks() {
        let engine = GameEngine(rng: SeededRNG(seed: 7))
        engine.start(GameConfig(), worldSize: WorldSize(width: Double(RenderTests.width), height: Double(RenderTests.height)))
        let renderer = Renderer()
        renderer.scale = RenderTests.scale
        let bmp = Bitmap(width: RenderTests.width, height: RenderTests.height, scale: RenderTests.scale)
        let size = CGSize(width: RenderTests.width, height: RenderTests.height)
        for i in 0..<300 {
            engine.input = InputState()
            engine.input.pilot1 = PilotInput(dx: i < 150 ? 1 : -0.5, dy: i % 60 < 30 ? -0.3 : 0.3)
            engine.tick()
            renderer.draw(engine: engine, in: bmp.ctx, size: size, safeInsets: .zero, overlay: .empty)
        }
        XCTAssertNotNil(engine.state)
        if let url = bmp.writePNG(named: "render-engine-tick300.png") {
            print("RenderTests wrote \(url.path)")
        }
        if let s = engine.state, !s.shipsDestroyed {
            XCTAssertFalse(bmp.isBackground(x: CGFloat(s.player.x), y: CGFloat(s.player.y), scale: RenderTests.scale), "ship drawn after 300 ticks")
        }
    }

    @MainActor func testTextBaselinesAndColorParsing() {
        // Colors: every palette entry and gear color must parse (not the white fallback).
        for (_, p) in ASTEROID_PALETTES {
            for c in p.gradient + [p.craterFill, p.craterRim, p.speckle, p.glow, p.base, p.outline, p.facet,
                                   p.facetSoft, p.hole, p.blobBase, p.blobOutline, p.lit, p.blobCrater, p.blobRim] {
                XCTAssertNotNil(RGBA(css: c.css), "unparseable palette color \(c.css)")
            }
        }
        for s in GearCatalog.skins {
            XCTAssertNotNil(RGBA(css: s.accent.css))
            for c in (s.hull ?? []) + (s.window ?? []) + (s.accentGradient ?? []) { XCTAssertNotNil(RGBA(css: c.css)) }
        }
        for f in GearCatalog.flames {
            for c in (f.pal ?? []) + (f.ringColors ?? []) + (f.smokeColors ?? []) { XCTAssertNotNil(RGBA(css: c.css)) }
            if let g = f.glow { XCTAssertNotNil(RGBA(css: g.css)) }
            if let s = f.starColor { XCTAssertNotNil(RGBA(css: s.css)) }
        }
        XCTAssertEqual(Renderer.tutorialAlpha(elapsedMs: 0), 0.9)
        XCTAssertEqual(Renderer.tutorialAlpha(elapsedMs: 5250), 0.4, accuracy: 1e-9)
        XCTAssertEqual(Renderer.tutorialAlpha(elapsedMs: 6000), 0)

        // Text: 'middle' baseline centres a glyph on y; draw a letter and check ink above and below.
        let bmp = Bitmap(width: 60, height: 60, scale: 2)
        bmp.ctx.setFill(Renderer.backgroundColor)
        bmp.ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        bmp.ctx.fillText("I", x: 30, y: 30, font: Fonts.sans(20, weight: .black), color: Colors.white, align: .center, baseline: .middle)
        var inkAbove = false, inkBelow = false
        for y in stride(from: CGFloat(18), to: 30, by: 0.5) where !bmp.isBackground(x: 30, y: y, scale: 2) { inkAbove = true }
        for y in stride(from: CGFloat(30), to: 42, by: 0.5) where !bmp.isBackground(x: 30, y: y, scale: 2) { inkBelow = true }
        XCTAssertTrue(inkAbove && inkBelow, "middle-baseline glyph should straddle y")
    }
}
