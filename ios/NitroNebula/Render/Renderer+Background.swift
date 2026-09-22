import UIKit
import NeonEngine

// game.js:1270-1289 — drawStars, drawAtmosphere.
extension Renderer {

    func drawStars(_ f: RenderFrame, _ ctx: CGContext) {
        ctx.setFill(Colors.white)
        for s in f.stars {
            ctx.fillCircle(CGFloat(s.x), CGFloat(s.y), CGFloat(s.s))
        }
    }

    func drawAtmosphere(_ f: RenderFrame, _ ctx: CGContext, size: CGSize) {
        if f.state.shipsDestroyed { return }
        let p = f.state.player
        let c = CGPoint(x: p.x, y: p.y)
        ctx.fillRadialGradient(
            path: CGPath(rect: CGRect(origin: .zero, size: size), transform: nil),
            from: c, r0: 0, to: c, r1: 400,
            stops: [
                (0, RGBA(r: 0, g: 1, b: 1, a: 0.08)),
                (1, RGBA(r: 0, g: 0, b: 0, a: 0)) // 'transparent' → same hue at alpha 0 (shim)
            ]
        )
    }
}
