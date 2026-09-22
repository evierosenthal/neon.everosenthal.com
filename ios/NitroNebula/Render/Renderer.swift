import UIKit
import NitroEngine

/// Everything the draw pass needs, snapshotted from the engine once per
/// frame. Tests build one directly (the engine's `state` is read-only from
/// outside the package).
struct RenderFrame {
    var state: GameState
    var stars: [Star]
    var shake: Double
    /// `Date.now()` replacement for every cosmetic phase.
    var simMs: Double
    var mountMs: Double
    var tickCount: Int
    var config: GameConfig
    var isPaused: Bool
    var input: InputState

    init(state: GameState, stars: [Star], shake: Double, simMs: Double, mountMs: Double = 0,
         tickCount: Int, config: GameConfig, isPaused: Bool = false, input: InputState = InputState()) {
        self.state = state; self.stars = stars; self.shake = shake; self.simMs = simMs
        self.mountMs = mountMs; self.tickCount = tickCount; self.config = config
        self.isPaused = isPaused; self.input = input
    }

    /// nil while the engine has no round (`state == null` on the web: draw() bails).
    init?(engine: GameEngine) {
        guard let state = engine.state else { return nil }
        self.init(state: state, stars: engine.stars, shake: engine.shake, simMs: engine.simMs,
                  mountMs: engine.mountMs, tickCount: engine.tickCount, config: engine.config,
                  isPaused: engine.isPaused, input: engine.input)
    }
}

/// Core Graphics port of `draw()` (game.js:2179-2202). One instance per
/// GameView; holds the sprite cache and the cosmetic RNG.
final class Renderer {
    /// Multiplier on every `shadowBlur` so the CG glow can be tuned against
    /// the canvas look without touching the ported numbers.
    static var glowScale: CGFloat = 1.0
    /// Rasterise static bodies once (see SpriteCache). Off = draw everything
    /// live, for A/B comparison.
    static var useSpriteCache = true
    /// `.game-canvas { background: #09090b }` (styles.css:125) — the canvas is
    /// cleared to transparent each frame over this. The donut hole is painted
    /// with the same value (game.js:1310).
    static let backgroundCSS: CSSColor = "#09090b"
    static let backgroundColor = RGBA(r: 9.0 / 255, g: 9.0 / 255, b: 11.0 / 255, a: 1)

    let sprites = SpriteCache()
    let overlayRenderer = JoystickOverlayRenderer()

    /// Device scale for the sprite bitmaps (the view's contentScaleFactor).
    var scale: CGFloat = 1 {
        didSet { sprites.scale = scale }
    }

    /// The web uses Math.random() for shake jitter and flame flicker. Those
    /// must not touch the engine's RNG (its sequence mirrors the JS
    /// simulation), so cosmetics draw from here.
    private var cosmeticRNG = SystemRandomNumberGenerator()

    init() {}

    func random() -> Double { Double.random(in: 0..<1, using: &cosmeticRNG) }

    /// `draw()`: clear, shake, then the layers in the web's order, then the
    /// joystick overlay outside the shake transform.
    func draw(engine: GameEngine, in ctx: CGContext, size: CGSize, safeInsets: UIEdgeInsets,
              overlay: JoystickOverlayState) {
        if let frame = RenderFrame(engine: engine) {
            draw(frame: frame, in: ctx, size: size, safeInsets: safeInsets, overlay: overlay)
        } else {
            fillBackground(ctx, size: size)
            overlayRenderer.draw(overlay, in: ctx)
        }
    }

    func draw(frame f: RenderFrame, in ctx: CGContext, size: CGSize, safeInsets: UIEdgeInsets,
              overlay: JoystickOverlayState) {
        fillBackground(ctx, size: size)

        ctx.saveGState()
        if f.shake > 1 {
            ctx.translateBy(x: CGFloat((random() - 0.5) * f.shake), y: CGFloat((random() - 0.5) * f.shake))
        }

        drawStars(f, ctx)
        drawAtmosphere(f, ctx, size: size)
        drawCollectibles(f, ctx)
        drawPowerUps(f, ctx)
        drawProjectiles(f, ctx)
        drawParticles(f, ctx)
        drawAsteroids(f, ctx)
        drawShips(f, ctx)
        drawFloatingTexts(f, ctx)
        drawEffectsHud(f, ctx, size: size, safeInsets: safeInsets)
        drawTutorial(f, ctx, size: size)

        ctx.restoreGState()

        overlayRenderer.draw(overlay, in: ctx)

        sprites.sweep(tick: f.tickCount)
    }

    private func fillBackground(_ ctx: CGContext, size: CGSize) {
        ctx.setFill(Renderer.backgroundColor)
        ctx.fill(CGRect(origin: .zero, size: size))
    }

    /// Padding a sprite needs around a shape so a canvas `shadowBlur` of
    /// `blur` is not clipped (the blur spreads roughly twice its radius).
    func spritePad(blur: CGFloat) -> CGFloat {
        blur * Renderer.glowScale * 2 + 2
    }
}
