import UIKit
import NeonEngine

// game.js:1291-1433 — drawDonut, drawSundae, drawCollectibles.
extension Renderer {

    /// Body drawn in local coordinates (origin at the collectible centre).
    func drawDonut(_ c: Collectible, _ ctx: CGContext) {
        let R = CGFloat(c.radius) * 1.25
        ctx.canvasShadow(blur: 12, color: c.color)

        // Dough rim, then pink frosting on top
        ctx.fillCircle(0, 0, R, color: "#d9a066")
        ctx.clearShadow()
        ctx.fillCircle(0, 0, R * 0.9, color: "#f472b6")

        // Hole
        ctx.fillCircle(0, 0, R * 0.38, color: "#09090b")

        // Sprinkles on the frosting band
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        for s in c.sprinkles {
            let sx = CGFloat(cos(s.a)) * R * CGFloat(s.d)
            let sy = CGFloat(sin(s.a)) * R * CGFloat(s.d)
            let dx = CGFloat(cos(s.rot)) * 2
            let dy = CGFloat(sin(s.rot)) * 2
            ctx.setStroke(s.color)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: sx - dx, y: sy - dy))
            ctx.addLine(to: CGPoint(x: sx + dx, y: sy + dy))
            ctx.strokePath()
        }
        ctx.setLineCap(.butt)
    }

    // Mini waffle-cone sundae: three scoops, whipped cream with sprinkles,
    // cherry on top and sparkles — a tiny take on the reference art.
    func drawSundae(_ c: Collectible, _ ctx: CGContext) {
        let R = CGFloat(c.radius) * 1.35
        ctx.canvasShadow(blur: 10, color: c.color)

        // Waffle cone
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -R * 0.55, y: R * 0.15))
        ctx.addLine(to: CGPoint(x: R * 0.55, y: R * 0.15))
        ctx.addLine(to: CGPoint(x: 0, y: R * 1.5))
        ctx.closePath()
        ctx.setFill("#e8a33d")
        ctx.fillPath()
        ctx.clearShadow()
        ctx.setStroke("#b45309")
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -R * 0.4, y: R * 0.35))
        ctx.addLine(to: CGPoint(x: R * 0.15, y: R * 1.15))
        ctx.move(to: CGPoint(x: -R * 0.1, y: R * 0.2))
        ctx.addLine(to: CGPoint(x: R * 0.35, y: R * 0.85))
        ctx.move(to: CGPoint(x: R * 0.4, y: R * 0.35))
        ctx.addLine(to: CGPoint(x: -R * 0.15, y: R * 1.15))
        ctx.move(to: CGPoint(x: R * 0.1, y: R * 0.2))
        ctx.addLine(to: CGPoint(x: -R * 0.35, y: R * 0.85))
        ctx.strokePath()

        // Three scoops: lemon, blueberry, strawberry in front
        ctx.fillCircle(-R * 0.42, -R * 0.15, R * 0.42, color: "#fde68a")
        ctx.fillCircle(R * 0.42, -R * 0.15, R * 0.42, color: "#93c5fd")
        ctx.fillCircle(0, -R * 0.05, R * 0.48, color: "#f9a8d4")

        // Whipped cream swirl with sprinkles
        ctx.fillCircle(0, -R * 0.6, R * 0.4, color: "#fff7ed")
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        let sprinkles: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("#ef4444", -0.2, -0.65, 0.6), ("#22c55e", 0.15, -0.5, -0.4),
            ("#3b82f6", 0.02, -0.78, 0.1), ("#f59e0b", -0.12, -0.45, -0.9)
        ]
        for s in sprinkles {
            let dx = cos(s.3) * 1.6, dy = sin(s.3) * 1.6
            ctx.setStroke(s.0)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: s.1 * R - dx, y: s.2 * R - dy))
            ctx.addLine(to: CGPoint(x: s.1 * R + dx, y: s.2 * R + dy))
            ctx.strokePath()
        }
        ctx.setLineCap(.butt)

        // Cherry with stem
        ctx.setStroke("#7c2d12")
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: -R * 1.0))
        ctx.addQuadCurve(to: CGPoint(x: R * 0.2, y: -R * 1.35), control: CGPoint(x: R * 0.12, y: -R * 1.25))
        ctx.strokePath()
        ctx.setFill("#ef4444")
        ctx.canvasShadow(blur: 8, color: CSSColor("#ef4444"))
        ctx.fillCircle(0, -R * 0.98, R * 0.2)
        ctx.clearShadow()

        // Sparkles
        ctx.setStroke("rgba(255, 255, 255, 0.9)")
        ctx.setLineWidth(1)
        for pos in [(0.62, -0.6), (-0.68, 0.25)] {
            let sx = CGFloat(pos.0) * R
            let sy = CGFloat(pos.1) * R
            ctx.beginPath()
            ctx.move(to: CGPoint(x: sx - 3, y: sy))
            ctx.addLine(to: CGPoint(x: sx + 3, y: sy))
            ctx.move(to: CGPoint(x: sx, y: sy - 3))
            ctx.addLine(to: CGPoint(x: sx, y: sy + 3))
            ctx.strokePath()
        }
    }

    func drawCollectibles(_ f: RenderFrame, _ ctx: CGContext) {
        for c in f.state.collectibles {
            let x = CGFloat(c.x), y = CGFloat(c.y)
            if Renderer.useSpriteCache {
                let r = CGFloat(c.radius)
                let half = c.kind == .donut
                    ? r * 1.25 + spritePad(blur: 12)
                    : r * 1.35 * 1.6 + spritePad(blur: 10)
                let sprite = sprites.sprite(key: "c:\(c.id)", tick: f.tickCount, halfExtent: half) { sc in
                    if c.kind == .donut { drawDonut(c, sc) } else { drawSundae(c, sc) }
                }
                if let sprite { ctx.drawSprite(sprite, at: x, y) }
            } else {
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                if c.kind == .donut { drawDonut(c, ctx) } else { drawSundae(c, ctx) }
                ctx.restoreGState()
            }

            // Halo
            ctx.setCanvasAlpha(0.3)
            ctx.strokeCircle(x, y, CGFloat(c.radius) + 6 + CGFloat(sin(f.simMs / 200)) * 2,
                             lineWidth: 1, color: c.color)
            ctx.setCanvasAlpha(1)
        }
    }
}
