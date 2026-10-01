import UIKit
import NitroEngine

// The secret cookie quest's drawing (game.js drawCookieDisc,
// traceBittenCookie, drawQuestBoss, drawCookies, drawQuestOverlay). No
// randomness anywhere here. Cookie discs and the jar's body are static per
// radius, so they are rasterised once through the sprite cache; the hit
// flash, hp bar, status line and banners are drawn live.
extension Renderer {

    static let cookieColor: CSSColor = "#d4a373"
    static let cookieGold: CSSColor = "#fbbf24"
    static let cookieCream: CSSColor = "#fde68a"

    // MARK: Cookie disc

    /// A chocolate-chip cookie disc in local coordinates: tan dough with a
    /// soft glow and 6 chips at fixed angles. The caller rotates.
    func drawCookieDiscBody(_ R: CGFloat, _ ctx: CGContext) {
        let path = CGPath(ellipseIn: CGRect(x: -R, y: -R, width: R * 2, height: R * 2), transform: nil)
        ctx.fillRadialGradient(path: path, from: CGPoint(x: -R * 0.3, y: -R * 0.3), r0: R * 0.1,
                               to: .zero, r1: R,
                               stops: [(0, Colors.rgba("#f1c27d")), (0.7, Colors.rgba("#d4a373")), (1, Colors.rgba("#a86f3a"))],
                               shadow: (14, Colors.rgba(Renderer.cookieColor)))
        ctx.setStroke("#8b5a2b")
        ctx.stroke(path, lineWidth: 1.5)
        for i in 0..<6 {
            let a = CGFloat(i) * (.pi / 3) + 0.4
            let d = R * (i % 2 == 1 ? 0.55 : 0.3)
            ctx.fillCircle(cos(a) * d, sin(a) * d, R * 0.16, color: "#3b2314")
        }
    }

    func drawCookieDisc(x: CGFloat, y: CGFloat, radius: CGFloat, rotation: CGFloat, tick: Int, _ ctx: CGContext) {
        if Renderer.useSpriteCache {
            let half = radius + 1 + spritePad(blur: 14)
            let key = "cookie:\(Int((radius * 10).rounded()))"
            if let sprite = sprites.sprite(key: key, tick: tick, halfExtent: half, render: { sc in drawCookieDiscBody(radius, sc) }) {
                ctx.drawSprite(sprite, at: x, y, rotation: rotation)
                return
            }
        }
        ctx.saveGState()
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: rotation)
        drawCookieDiscBody(radius, ctx)
        ctx.restoreGState()
    }

    // MARK: The Giant Cookie

    /// Outline of a cookie with a bite out of its upper right, as one path:
    /// the disc's arc around to the bite, then the bite circle's inner arc
    /// back to the start.
    static func bittenCookiePath(_ R: CGFloat) -> CGPath {
        let tau = CGFloat.pi * 2
        let theta: CGFloat = -.pi / 4 // bite direction
        let d = R * 0.92              // bite circle centre distance
        let r = R * 0.42              // bite circle radius
        let cx = cos(theta) * d
        let cy = sin(theta) * d
        let alpha = acos((R * R + d * d - r * r) / (2 * R * d))
        let a1 = theta + alpha
        let a2 = theta - alpha
        let p1 = CGPoint(x: cos(a1) * R, y: sin(a1) * R)
        let p2 = CGPoint(x: cos(a2) * R, y: sin(a2) * R)
        let path = CGMutablePath()
        // canvas arc(0,0,R,a1,a2+2π): increasing angle = clockwise: false in CG's flipped space
        path.addArc(center: .zero, radius: R, startAngle: a1, endAngle: a2 + tau, clockwise: false)
        let b2 = atan2(p2.y - cy, p2.x - cx)
        let b1 = atan2(p1.y - cy, p1.x - cx)
        let mid = theta + .pi
        let forward = ((mid - b2 + tau * 2).truncatingRemainder(dividingBy: tau)) < ((b1 - b2 + tau * 2).truncatingRemainder(dividingBy: tau))
        // JS: ctx.arc(cx, cy, r, b2, b1, !forward) — anticlockwise flag; CG's
        // `clockwise` in this flipped context means decreasing angle.
        path.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: b2, endAngle: b1, clockwise: !forward)
        path.closeSubpath()
        return path
    }

    /// The jar's body (bitten cookie, chips) in local coordinates.
    func drawQuestBossBody(_ R: CGFloat, _ ctx: CGContext) {
        let path = Renderer.bittenCookiePath(R)
        ctx.fillRadialGradient(path: path, from: CGPoint(x: -R * 0.3, y: -R * 0.3), r0: R * 0.1,
                               to: .zero, r1: R,
                               stops: [(0, Colors.rgba("#f1c27d")), (0.7, Colors.rgba("#d4a373")), (1, Colors.rgba("#a86f3a"))],
                               shadow: (28, Colors.rgba(Renderer.cookieColor)))
        ctx.setStroke("#8b5a2b")
        ctx.stroke(path, lineWidth: 3)
        ctx.saveGState()
        ctx.clip(to: path)
        let chips: [(CGFloat, CGFloat)] = [(-0.45, -0.35), (0.1, -0.55), (-0.6, 0.2), (0, 0.05), (0.5, 0.3), (-0.25, 0.6), (0.3, 0.65)]
        for (i, c) in chips.enumerated() {
            ctx.fillCircle(c.0 * R, c.1 * R, R * (0.11 + 0.02 * CGFloat(i % 3)), color: "#3b2314")
        }
        ctx.restoreGState()
    }

    /// The Giant Cookie: a big bitten cookie with chips, a white flash while
    /// hitFlash > 0 and an hp bar above it.
    func drawQuestBoss(_ b: QuestBoss, tick: Int, _ ctx: CGContext) {
        let R = CGFloat(b.radius)
        let x = CGFloat(b.x), y = CGFloat(b.y), rot = CGFloat(b.rotation)
        var drawn = false
        if Renderer.useSpriteCache {
            let half = R + 2 + spritePad(blur: 28)
            if let sprite = sprites.sprite(key: "boss:\(Int(R))", tick: tick, halfExtent: half, render: { sc in drawQuestBossBody(R, sc) }) {
                ctx.drawSprite(sprite, at: x, y, rotation: rot)
                drawn = true
            }
        }
        ctx.saveGState()
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: rot)
        if !drawn { drawQuestBossBody(R, ctx) }
        if b.hitFlash > 0 {
            ctx.saveGState()
            ctx.clip(to: Renderer.bittenCookiePath(R))
            ctx.setFill(RGBA(r: 1, g: 1, b: 1, a: 0.7 * Double(b.hitFlash) / 8))
            ctx.fill(CGRect(x: -R, y: -R, width: R * 2, height: R * 2))
            ctx.restoreGState()
        }
        ctx.restoreGState()

        // HP bar above the jar: dark track, gold fill
        let w: CGFloat = 110
        let h: CGFloat = 7
        let bx = x - w / 2
        let by = y - R - 22
        ctx.saveGState()
        ctx.setFill("rgba(9, 12, 28, 0.8)")
        ctx.fill(ctx.roundedRectPath(bx - 1, by - 1, w + 2, h + 2, 4))
        ctx.setFill(Renderer.cookieGold)
        ctx.canvasShadow(blur: 8, color: Renderer.cookieGold)
        let frac = max(0, CGFloat(b.hp) / CGFloat(max(1, b.maxHp)))
        ctx.fill(ctx.roundedRectPath(bx, by, w * frac, h, 3))
        ctx.restoreGState()
    }

    // MARK: Layers

    /// Drifting cookie, raining quest cookies and the boss — after the
    /// asteroids and before the ships.
    func drawCookies(_ f: RenderFrame, _ ctx: CGContext) {
        if let c = f.state.cookie {
            drawCookieDisc(x: CGFloat(c.x), y: CGFloat(c.y), radius: CGFloat(c.radius), rotation: CGFloat(c.rotation),
                           tick: f.tickCount, ctx)
        }
        guard let q = f.state.quest else { return }
        for c in q.cookies {
            drawCookieDisc(x: CGFloat(c.x), y: CGFloat(c.y), radius: CGFloat(c.radius), rotation: CGFloat(c.rotation),
                           tick: f.tickCount, ctx)
        }
        if let b = q.boss { drawQuestBoss(b, tick: f.tickCount, ctx) }
    }

    static func formatClock(frames: Int) -> String {
        let secs = max(0, Int(ceil(Double(frames) / 60)))
        let m = secs / 60
        let s = secs % 60
        return "\(m):" + (s < 10 ? "0" : "") + "\(s)"
    }

    /// Quest status line under the HUD bar plus the phase banners (drawn
    /// last, after the tutorial card). The status line is inset below the
    /// safe area like the effect chips are.
    func drawQuestOverlay(_ f: RenderFrame, _ ctx: CGContext, size: CGSize, safeInsets: UIEdgeInsets) {
        guard let q = f.state.quest else { return }
        let def = GameConstants.questLevels[q.level - 1]
        let cx = size.width / 2
        ctx.saveGState()

        let progress: String
        if q.level == 3 {
            let dealt = q.boss.map { $0.maxHp - $0.hp } ?? GameConstants.questBossHP
            progress = "GIANT COOKIE \(dealt)/\(GameConstants.questBossHP)"
        } else {
            progress = "\(q.collected)/\(q.goal) COOKIES"
        }
        ctx.canvasShadow(blur: 10, color: Renderer.cookieGold)
        ctx.fillText("SECRET LEVEL \(q.level)/3 · \(def.name) · \(progress) · \(Renderer.formatClock(frames: def.duration - q.timer))",
                     x: cx, y: 120 + safeInsets.top, font: Fonts.mono(12), color: Renderer.cookieCream,
                     align: .center, baseline: .middle)

        var title: String? = nil
        var sub: String? = nil
        var total = 0
        switch q.phase {
        case .intro:
            title = "SECRET LEVEL \(q.level)"
            sub = "\(def.name) · \(def.hint)"
            total = 120
        case .won:
            title = "LEVEL CLEARED!"
            total = 120
        case .failed:
            title = "TIME'S UP"
            sub = "BACK TO THE NEBULA"
            total = 120
        case .complete:
            title = "COOKIE QUEST COMPLETE!"
            sub = "+1000 COINS · 3 SECRET SKINS UNLOCKED"
            total = 180
        case .play:
            break
        }
        if let title {
            // fade in over the first 15 frames, out over the last 20
            let t = CGFloat(total), pt = CGFloat(q.phaseTimer)
            let alpha = max(0, min(1, min((t - pt) / 15, pt / 20)))
            ctx.setCanvasAlpha(alpha)
            ctx.canvasShadow(blur: 24, color: Renderer.cookieGold)
            ctx.fillText(title, x: cx, y: size.height / 2 - 30, font: Fonts.sans(34, weight: .black),
                         color: Renderer.cookieGold, align: .center, baseline: .middle)
            if let sub {
                ctx.canvasShadow(blur: 10, color: Renderer.cookieGold)
                ctx.fillText(sub, x: cx, y: size.height / 2 + 10, font: Fonts.mono(14, bold: true),
                             color: Renderer.cookieCream, align: .center, baseline: .middle)
            }
        }
        ctx.restoreGState()
    }
}
