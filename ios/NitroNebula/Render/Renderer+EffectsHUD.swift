import UIKit
import NitroEngine

// game.js:2012-2080 — drawEffectsHud: one chip per active effect along the
// bottom edge. The chips start `safeInsets.left` further in and sit above
// the bottom inset so the home indicator never covers them.
extension Renderer {

    struct EffectChip {
        let name: String
        let id: String
        let color: CSSColor
        let value: Int
        let max: Int
    }

    static func activeChips(_ fx: ActiveEffects) -> [EffectChip] {
        [
            EffectChip(name: "SHIELD", id: "S", color: "#a855f7", value: fx.shield, max: 1000),
            EffectChip(name: "SPEED", id: "V", color: "#22c55e", value: fx.speedBoost, max: 1000),
            EffectChip(name: "WEAPON", id: "W", color: "#ef4444", value: fx.weaponUpgrade, max: 2000),
            EffectChip(name: "MAGNET", id: "M", color: "#c084fc", value: fx.magnet, max: 600)
        ].filter { $0.value > 0 }
    }

    func drawEffectsHud(_ f: RenderFrame, _ ctx: CGContext, size: CGSize, safeInsets: UIEdgeInsets) {
        let chips = Renderer.activeChips(f.state.activeEffects)
        for (i, eff) in chips.enumerated() {
            let x = 50 + safeInsets.left + CGFloat(i) * 140
            let y = size.height - 40 - safeInsets.bottom

            ctx.saveGState()
            // The web sets the shadow once and everything in the chip carries it.
            ctx.canvasShadow(blur: 10, color: eff.color)

            let card = ctx.roundedRectPath(x - 20, y - 15, 125, 30, 8)
            ctx.setFill("rgba(9, 12, 28, 0.75)")
            ctx.fill(card)
            ctx.setStroke("rgba(255, 255, 255, 0.15)")
            ctx.stroke(card, lineWidth: 1)

            // Arc meter
            ctx.strokeCircle(x, y, 10, lineWidth: 2.5, color: CSSColor("rgba(255, 255, 255, 0.08)"))

            let frac = CGFloat(eff.value) / CGFloat(eff.max)
            ctx.beginPath()
            ctx.canvasArc(x, y, 10, -.pi / 2, -.pi / 2 + .pi * 2 * frac)
            ctx.setStroke(eff.color)
            ctx.setLineWidth(2.5)
            ctx.strokePath()

            // Arc center character
            ctx.fillText(eff.id, x: x, y: y, font: Fonts.sans(9, weight: .black), color: Colors.white,
                         align: .center, baseline: .middle)

            // Label Text Next To It
            ctx.fillText(eff.name, x: x + 18, y: y - 5, font: Fonts.mono(9, bold: true), color: eff.color,
                         align: .left, baseline: .middle)

            // Remaining Countdown seconds
            ctx.setCanvasAlpha(0.6)
            let seconds = Int(jsRound(Double(eff.value) / 60))
            ctx.fillText("\(seconds)s left", x: x + 18, y: y + 5, font: Fonts.mono(8), color: Colors.white,
                         align: .left, baseline: .middle)

            ctx.restoreGState()
        }
    }
}
