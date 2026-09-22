import UIKit
import NeonEngine

// game.js:1470-1502 — drawProjectiles, drawParticles.
extension Renderer {

    func drawProjectiles(_ f: RenderFrame, _ ctx: CGContext) {
        guard !f.state.projectiles.isEmpty else { return }
        ctx.saveGState()
        ctx.setLineCap(.round)
        for p in f.state.projectiles {
            let angle = atan2(p.vy, p.vx)
            let length = 18.0
            let path = CGMutablePath()
            path.move(to: CGPoint(x: p.x, y: p.y))
            path.addLine(to: CGPoint(x: p.x - cos(angle) * length, y: p.y - sin(angle) * length))

            ctx.setStroke(p.color)
            ctx.stroke(path, lineWidth: 3.5)

            // Draw pristine inner core
            ctx.setStroke("#ffffff")
            ctx.stroke(path, lineWidth: 1.2)
        }
        ctx.restoreGState()
    }

    func drawParticles(_ f: RenderFrame, _ ctx: CGContext) {
        for p in f.state.particles {
            let alpha = p.maxLife > 0
                ? max(0, p.life / p.maxLife)
                : max(0, (p.life != 0 ? p.life : 1) / 25)
            ctx.setCanvasAlpha(CGFloat(alpha))
            ctx.fillCircle(CGFloat(p.x), CGFloat(p.y), CGFloat(p.radius), color: p.color)
        }
        ctx.setCanvasAlpha(1)
    }
}
