import UIKit
import NeonEngine

// game.js:1655-1964 — drawShips: tilt, spin power, Tailor skins, the six
// exhaust styles, hull, and the shield/speed/magnet rings. Thruster particle
// emission (game.js:1966-1993) lives in the engine's tick, not here.
extension Renderer {

    /// A per-part fill: the flat accent, or a vertical accent gradient over
    /// the part's own y range (skins with `accentGradient`).
    enum ShipFill {
        case solid(RGBA)
        case gradient(stops: [RGBA], y0: CGFloat, y1: CGFloat)
    }

    struct ShipLook {
        /// Glow color; a gradient skin glows with its solid mid-tone.
        var accent: RGBA
        var finFill: ShipFill
        var noseFill: ShipFill
        var stripeFill: ShipFill
        var hullStops: [RGBA]
        var winStops: [RGBA]
        var skinId: String
        var animated: Bool
    }

    static let defaultHullStops: [CSSColor] = ["#94a3b8", "#f1f5f9", "#e2e8f0", "#64748b"]
    static let defaultWindowStops: [CSSColor] = ["#e0f2fe", "#67e8f9", "#0e7490"]

    func shipLook(for p: Player, _ f: RenderFrame) -> ShipLook {
        // Each pilot flies their own Tailor skin (player 2 only has one in
        // local two-player; the CPU wingman keeps stock colors).
        let skin = p.id == .player1 ? f.config.skin : f.config.skin2
        var accent = skin.map { Colors.rgba($0.accent) } ?? Colors.rgba(p.color)
        if let skin, skin.animated {
            accent = RGBA(h: floor((f.simMs / 15).truncatingRemainder(dividingBy: 360)), s: 0.85, l: 0.65)
        }
        // Gradient accents, applied per part (fins / nose / stripe each get the
        // full color run) — exactly how the hangar card's SVG paints them.
        var finFill = ShipFill.solid(accent)
        var noseFill = ShipFill.solid(accent)
        var stripeFill = ShipFill.solid(accent)
        if let skin, let grad = skin.accentGradient, grad.count >= 3 {
            let stops = grad.prefix(3).map { Colors.rgba($0) }
            let R = CGFloat(p.radius)
            finFill = .gradient(stops: stops, y0: R * 0.15, y1: R * 1.05)
            noseFill = .gradient(stops: stops, y0: -R * 1.6, y1: -R * 0.72)
            stripeFill = .gradient(stops: stops, y0: R * 0.45, y1: R * 0.63)
            accent = stops[1] // glows stay a solid mid-tone
        }
        let hullCSS = skin?.hull.flatMap { $0.count == 4 ? $0 : nil } ?? Renderer.defaultHullStops
        let winCSS = skin?.window.flatMap { $0.count == 3 ? $0 : nil } ?? Renderer.defaultWindowStops
        let hullStops = hullCSS.map { Colors.rgba($0) }
        let winStops = winCSS.map { Colors.rgba($0) }
        return ShipLook(accent: accent, finFill: finFill, noseFill: noseFill, stripeFill: stripeFill,
                        hullStops: hullStops, winStops: winStops,
                        skinId: skin?.id ?? "stock:\(p.color.css)", animated: skin?.animated ?? false)
    }

    private func fillPart(_ path: CGPath, with fill: ShipFill, shadow: (blur: CGFloat, color: RGBA)?, _ ctx: CGContext) {
        switch fill {
        case .solid(let c):
            // The caller has already set (or not set) the shadow.
            ctx.setFill(c)
            ctx.fill(path)
        case .gradient(let stops, let y0, let y1):
            ctx.fillLinearGradient(path: path, from: CGPoint(x: 0, y: y0), to: CGPoint(x: 0, y: y1),
                                   stops: [(0, stops[0]), (0.5, stops[1]), (1, stops[2])], shadow: shadow)
        }
    }

    /// Fins, hull, nose, stripe, porthole and nozzle in local coordinates.
    func drawShipHull(_ p: Player, look: ShipLook, _ ctx: CGContext) {
        let R = CGFloat(p.radius)
        let white85 = RGBA(r: 1, g: 1, b: 1, a: 0.85)
        let white90 = RGBA(r: 1, g: 1, b: 1, a: 0.9)

        // --- Swept tail fins (tinted per player) ---
        let fins = CGMutablePath()
        fins.move(to: CGPoint(x: -R * 0.6, y: R * 0.15))
        fins.addLine(to: CGPoint(x: -R * 1.15, y: R * 1.05))
        fins.addLine(to: CGPoint(x: -R * 0.55, y: R * 0.95))
        fins.closeSubpath()
        fins.move(to: CGPoint(x: R * 0.6, y: R * 0.15))
        fins.addLine(to: CGPoint(x: R * 1.15, y: R * 1.05))
        fins.addLine(to: CGPoint(x: R * 0.55, y: R * 0.95))
        fins.closeSubpath()
        ctx.canvasShadow(blur: 12, color: look.accent)
        fillPart(fins, with: look.finFill, shadow: (12, look.accent), ctx)
        ctx.setStroke(white85)
        ctx.stroke(fins, lineWidth: 1.2)
        ctx.clearShadow()

        // --- Hull: cylinder with a rounded nose cone ---
        let hull = CGMutablePath()
        hull.move(to: CGPoint(x: -R * 0.62, y: R * 0.95))
        hull.addLine(to: CGPoint(x: -R * 0.62, y: -R * 0.45))
        hull.addQuadCurve(to: CGPoint(x: 0, y: -R * 1.6), control: CGPoint(x: -R * 0.62, y: -R * 1.35))
        hull.addQuadCurve(to: CGPoint(x: R * 0.62, y: -R * 0.45), control: CGPoint(x: R * 0.62, y: -R * 1.35))
        hull.addLine(to: CGPoint(x: R * 0.62, y: R * 0.95))
        hull.closeSubpath()
        ctx.fillLinearGradient(path: hull, from: CGPoint(x: -R * 0.7, y: 0), to: CGPoint(x: R * 0.7, y: 0),
                               stops: [(0, look.hullStops[0]), (0.35, look.hullStops[1]),
                                       (0.65, look.hullStops[2]), (1, look.hullStops[3])],
                               shadow: (14, look.accent))
        ctx.canvasShadow(blur: 14, color: look.accent)
        ctx.setStroke(white90)
        ctx.stroke(hull, lineWidth: 1.3)
        ctx.clearShadow()

        // Nose-cone tip in the player color
        let nose = CGMutablePath()
        nose.move(to: CGPoint(x: -R * 0.58, y: -R * 0.72))
        nose.addQuadCurve(to: CGPoint(x: 0, y: -R * 1.6), control: CGPoint(x: -R * 0.55, y: -R * 1.32))
        nose.addQuadCurve(to: CGPoint(x: R * 0.58, y: -R * 0.72), control: CGPoint(x: R * 0.55, y: -R * 1.32))
        nose.addQuadCurve(to: CGPoint(x: -R * 0.58, y: -R * 0.72), control: CGPoint(x: 0, y: -R * 0.92))
        nose.closeSubpath()
        fillPart(nose, with: look.noseFill, shadow: nil, ctx)

        // Body stripe in the player color
        let stripe = CGPath(rect: CGRect(x: -R * 0.62, y: R * 0.45, width: R * 1.24, height: R * 0.18), transform: nil)
        fillPart(stripe, with: look.stripeFill, shadow: nil, ctx)

        // --- Porthole window ---
        let window = CGPath(ellipseIn: CGRect(x: -R * 0.32, y: -R * 0.22 - R * 0.32, width: R * 0.64, height: R * 0.64), transform: nil)
        ctx.fillRadialGradient(path: window, from: CGPoint(x: -R * 0.1, y: -R * 0.32), r0: R * 0.04,
                               to: CGPoint(x: 0, y: -R * 0.22), r1: R * 0.34,
                               stops: [(0, look.winStops[0]), (0.5, look.winStops[1]), (1, look.winStops[2])])
        ctx.setStroke("#cbd5e1")
        ctx.stroke(window, lineWidth: R * 0.1)
        ctx.setStroke(white90)
        ctx.stroke(window, lineWidth: 1)
        // glint
        ctx.fillCircle(-R * 0.11, -R * 0.33, R * 0.07, color: white85)

        // --- Engine nozzle skirt ---
        let nozzle = CGMutablePath()
        nozzle.move(to: CGPoint(x: -R * 0.45, y: R * 0.95))
        nozzle.addLine(to: CGPoint(x: R * 0.45, y: R * 0.95))
        nozzle.addLine(to: CGPoint(x: R * 0.58, y: R * 1.18))
        nozzle.addLine(to: CGPoint(x: -R * 0.58, y: R * 1.18))
        nozzle.closeSubpath()
        ctx.setFill("#475569")
        ctx.fill(nozzle)
        ctx.setStroke("#94a3b8")
        ctx.stroke(nozzle, lineWidth: 1)
    }

    /// Rocket exhaust (behind the body); the fire style is Tailor gear.
    func drawExhaust(_ p: Player, flame flameDef: Flame?, _ f: RenderFrame, _ ctx: CGContext) {
        let R = CGFloat(p.radius)
        let fStyle = flameDef?.style ?? .classic
        let flick = CGFloat(0.8 + 0.35 * abs(sin(f.simMs / 47 + p.x)) + random() * 0.15)

        switch fStyle {
        case .rings:
            // Expanding exhaust rings instead of a flame
            let ringCols = flameDef?.ringColors ?? ["#fb923c", "#fbbf24", "#fde68a"]
            ctx.setLineWidth(3)
            for ri in 0..<3 {
                ctx.circlePath(0, R * (1.4 + CGFloat(ri) * 0.5 * flick), R * (0.3 - CGFloat(ri) * 0.06))
                ctx.setStroke(ringCols[ri % ringCols.count])
                ctx.setCanvasAlpha(1 - CGFloat(ri) * 0.28)
                ctx.canvasShadow(blur: 12, color: ringCols[0])
                ctx.strokePath()
            }
            ctx.setCanvasAlpha(1)
            ctx.clearShadow()

        case .smoke:
            // Chuffing smoke puffs
            let cols = flameDef?.smokeColors ?? ["#94a3b8", "#cbd5e1", "#e2e8f0"]
            for si in 0..<3 {
                let cx = CGFloat(sin(f.simMs / 150 + Double(si) * 2)) * R * 0.15
                ctx.setCanvasAlpha(0.75 - CGFloat(si) * 0.22)
                ctx.fillCircle(cx, R * (1.32 + CGFloat(si) * 0.45), R * (0.28 + CGFloat(si) * 0.05) * flick,
                               color: cols[si % cols.count])
            }
            ctx.setCanvasAlpha(1)

        case .stars:
            // Twinkling star sparks
            let sa = f.simMs / 250
            let starCol = flameDef?.starColor ?? "#fde047"
            for ti in 0..<3 {
                let sr = R * (0.24 - CGFloat(ti) * 0.04) * flick
                ctx.saveGState()
                ctx.translateBy(x: CGFloat(sin(sa + Double(ti) * 2)) * R * 0.14, y: R * (1.38 + CGFloat(ti) * 0.5))
                ctx.rotate(by: CGFloat(sa + Double(ti)))
                ctx.setStroke(starCol)
                ctx.setLineWidth(2)
                ctx.canvasShadow(blur: 10, color: starCol)
                ctx.setCanvasAlpha(1 - CGFloat(ti) * 0.25)
                ctx.beginPath()
                ctx.move(to: CGPoint(x: -sr, y: 0))
                ctx.addLine(to: CGPoint(x: sr, y: 0))
                ctx.move(to: CGPoint(x: 0, y: -sr))
                ctx.addLine(to: CGPoint(x: 0, y: sr))
                ctx.strokePath()
                ctx.restoreGState()
            }
            ctx.setCanvasAlpha(1)
            ctx.clearShadow()

        case .classic, .blue, .jet:
            // Layered flame tongues: classic orange, blue, the narrow jet, or
            // any custom palette (pal/glow) the equipped fire specifies.
            var pal: [RGBA]
            var glow: RGBA
            var wMul: CGFloat = 1, lMul: CGFloat = 1
            switch fStyle {
            case .blue:
                pal = [Colors.rgba("rgba(37, 99, 235, 0.85)"), Colors.rgba("rgba(96, 165, 250, 0.95)"), Colors.rgba("rgba(224, 242, 254, 0.95)")]
                glow = Colors.rgba("#60a5fa")
            case .jet:
                pal = [Colors.rgba("rgba(34, 211, 238, 0.85)"), Colors.rgba("rgba(165, 243, 252, 0.95)"), Colors.rgba("rgba(255, 255, 255, 0.95)")]
                glow = Colors.rgba("#22d3ee"); wMul = 0.55; lMul = 1.6
            default:
                pal = [Colors.rgba("rgba(249, 115, 22, 0.85)"), Colors.rgba("rgba(251, 191, 36, 0.95)"), Colors.rgba("rgba(224, 242, 254, 0.95)")]
                glow = Colors.rgba("#fb923c")
            }
            if let flameDef, flameDef.animatedPal {
                let fh = floor((f.simMs / 12).truncatingRemainder(dividingBy: 360))
                pal = [RGBA(h: fh, s: 0.9, l: 0.55, a: 0.85),
                       RGBA(h: (fh + 45).truncatingRemainder(dividingBy: 360), s: 0.9, l: 0.65, a: 0.95),
                       RGBA(r: 1, g: 1, b: 1, a: 0.95)]
                glow = RGBA(h: fh, s: 0.9, l: 0.6)
            } else if let flameDef, let custom = flameDef.pal, custom.count >= 3 {
                pal = custom.prefix(3).map { Colors.rgba($0) }
                glow = Colors.rgba(flameDef.glow ?? "#fb923c")
            }
            if let flameDef, flameDef.style == .jet, flameDef.pal != nil {
                wMul = 0.55; lMul = 1.6
            }
            let flameLen = R * 1.0 * flick * lMul
            let base = R * 1.1

            ctx.beginPath()
            ctx.move(to: CGPoint(x: -R * 0.34 * wMul, y: base))
            ctx.addQuadCurve(to: CGPoint(x: 0, y: base + flameLen), control: CGPoint(x: -R * 0.28 * wMul, y: base + flameLen * 0.7))
            ctx.addQuadCurve(to: CGPoint(x: R * 0.34 * wMul, y: base), control: CGPoint(x: R * 0.28 * wMul, y: base + flameLen * 0.7))
            ctx.closePath()
            ctx.setFill(pal[0])
            ctx.canvasShadow(blur: 18, color: glow)
            ctx.fillPath()
            ctx.clearShadow()

            ctx.beginPath()
            ctx.move(to: CGPoint(x: -R * 0.22 * wMul, y: base))
            ctx.addQuadCurve(to: CGPoint(x: 0, y: base + flameLen * 0.68), control: CGPoint(x: -R * 0.18 * wMul, y: base + flameLen * 0.5))
            ctx.addQuadCurve(to: CGPoint(x: R * 0.22 * wMul, y: base), control: CGPoint(x: R * 0.18 * wMul, y: base + flameLen * 0.5))
            ctx.closePath()
            ctx.setFill(pal[1])
            ctx.fillPath()

            ctx.beginPath()
            ctx.move(to: CGPoint(x: -R * 0.11 * wMul, y: base))
            ctx.addQuadCurve(to: CGPoint(x: 0, y: base + flameLen * 0.4), control: CGPoint(x: -R * 0.09 * wMul, y: base + flameLen * 0.3))
            ctx.addQuadCurve(to: CGPoint(x: R * 0.11 * wMul, y: base), control: CGPoint(x: R * 0.09 * wMul, y: base + flameLen * 0.3))
            ctx.closePath()
            ctx.setFill(pal[2])
            ctx.fillPath()
        }
    }

    /// Shield / force field / magnet aura, in local coordinates.
    func drawEffectRings(_ p: Player, _ f: RenderFrame, _ ctx: CGContext) {
        let fx = f.state.activeEffects
        let r = CGFloat(p.radius)

        // Shield Effect
        if fx.shield > 0 {
            let a = CGFloat(min(1, Double(fx.shield) / 100))
            ctx.setCanvasAlpha(a)
            ctx.setCanvasLineDash([10, 5], offset: CGFloat(f.simMs / 10))
            ctx.strokeCircle(0, 0, r * 2, lineWidth: 3, color: CSSColor("#a855f7"))
            ctx.clearLineDash()
            ctx.setCanvasAlpha(1)

            ctx.setCanvasAlpha(0.2 * a)
            ctx.strokeCircle(0, 0, r * 2 + 5, lineWidth: 1, color: CSSColor("#a855f7"))
            ctx.setCanvasAlpha(1)
        }

        // Force Field Effect
        if fx.speedBoost > 0 {
            let pulse = CGFloat(sin(f.simMs / 100) * 0.2 + 0.8)
            let a = CGFloat(min(1, Double(fx.speedBoost) / 100))
            ctx.setCanvasAlpha(0.6 * a)
            ctx.strokeCircle(0, 0, r * 2.2, lineWidth: 2 * pulse, color: CSSColor("#22c55e"))
            ctx.setCanvasAlpha(0.1 * a)
            ctx.fillCircle(0, 0, r * 2.2, color: CSSColor("#22c55e"))
            ctx.setCanvasAlpha(1)
        }

        // Magnet Aura Effect
        if fx.magnet > 0 {
            ctx.setCanvasAlpha(0.8 * CGFloat(min(1, Double(fx.magnet) / 60)))
            ctx.setCanvasLineDash([4, 4], offset: CGFloat(-f.simMs / 25))
            ctx.strokeCircle(0, 0, r * 2.5, lineWidth: 2, color: CSSColor("#c084fc"))
            ctx.clearLineDash()
            ctx.setCanvasAlpha(1)
        }
    }

    /// Tilt from horizontal speed (keyboard/joystick path); the web's mouse
    /// path tilts toward the pointer, kept for a follow-finger scheme.
    func shipTilt(_ p: Player, _ f: RenderFrame) -> Double {
        let c = f.config
        let tilt: Double
        if let pointer = f.input.pointer, !c.isLocalMultiplayer, !c.isCPUMultiplayer, c.online == nil,
           p.id != .player2, c.controlModePreference != .keyboard {
            tilt = (pointer.x - p.x) * 0.01
        } else {
            tilt = p.vx * 0.04
        }
        return max(-0.45, min(0.45, tilt))
    }

    func drawShips(_ f: RenderFrame, _ ctx: CGContext) {
        let s = f.state
        if s.shipsDestroyed { return }
        let live = !f.isPaused && !s.isGameOver && !s.dying

        for p in [s.player, s.player2].compactMap({ $0 }) {
            let tilt = shipTilt(p, f)

            ctx.saveGState()
            ctx.translateBy(x: CGFloat(p.x), y: CGFloat(p.y))
            // The Ring Burner's power: the ship pinwheels nonstop (visual only)
            let ownFlame = p.id == .player1 ? f.config.flame : f.config.flame2
            let flameSpin = (ownFlame?.power == .spin && live)
                ? (f.simMs / 200).truncatingRemainder(dividingBy: Double.pi * 2) : 0
            ctx.rotate(by: CGFloat(tilt + flameSpin))

            let look = shipLook(for: p, f)

            if live {
                drawExhaust(p, flame: ownFlame, f, ctx)
            }

            if Renderer.useSpriteCache {
                let R = CGFloat(p.radius)
                let key = "ship:\(p.id.rawValue):\(look.skinId):\(p.radius)"
                let variant = look.animated ? f.tickCount / 2 : 0
                let sprite = sprites.sprite(key: key, variant: variant, tick: f.tickCount,
                                            halfExtent: R * 1.6 + spritePad(blur: 14)) { sc in
                    drawShipHull(p, look: look, sc)
                }
                if let sprite { ctx.drawSpriteAtOrigin(sprite) }
            } else {
                drawShipHull(p, look: look, ctx)
            }

            drawEffectRings(p, f, ctx)
            ctx.restoreGState()
        }
    }
}
