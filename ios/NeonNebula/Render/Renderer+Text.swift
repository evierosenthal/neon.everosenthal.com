import UIKit
import NeonEngine

// game.js:1998-2010 — drawFloatingTexts.
extension Renderer {

    func drawFloatingTexts(_ f: RenderFrame, _ ctx: CGContext) {
        for ft in f.state.floatingTexts {
            ctx.saveGState()
            ctx.setCanvasAlpha(CGFloat(ft.alpha))
            let size = CGFloat(jsRound(14 * ft.scale))
            ctx.canvasShadow(blur: 10, color: ft.color)
            ctx.fillText(ft.text, x: CGFloat(ft.x), y: CGFloat(ft.y),
                         font: Fonts.sans(max(1, size), weight: .black), color: ft.color,
                         align: .center, baseline: .alphabetic)
            ctx.restoreGState()
        }
    }
}
