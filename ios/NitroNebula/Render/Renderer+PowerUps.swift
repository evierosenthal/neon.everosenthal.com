import UIKit
import NitroEngine

// game.js:1435-1468 — drawPowerUps.
extension Renderer {

    static func powerUpLabel(_ t: PowerUpType) -> String {
        switch t {
        case .shield: return "S"
        case .speed: return "V"
        case .magnet: return "M"
        case .weapon: return "W"
        }
    }

    /// Orb body + icon letter in local coordinates.
    func drawPowerUpBody(_ pu: PowerUp, _ ctx: CGContext) {
        let r = CGFloat(pu.radius)
        ctx.setFill(pu.color)
        ctx.canvasShadow(blur: 15, color: pu.color)
        ctx.fillCircle(0, 0, r)
        ctx.clearShadow()

        // Icon letter
        ctx.fillText(Renderer.powerUpLabel(pu.subType), x: 0, y: 0,
                     font: Fonts.sans(10, weight: .bold), color: Colors.white,
                     align: .center, baseline: .middle)
    }

    func drawPowerUps(_ f: RenderFrame, _ ctx: CGContext) {
        for pu in f.state.powerUps {
            // Blinking effect when expiring
            if pu.life < 300 && (pu.life / 10) % 2 == 0 { continue }

            let x = CGFloat(pu.x), y = CGFloat(pu.y), r = CGFloat(pu.radius)
            if Renderer.useSpriteCache {
                let sprite = sprites.sprite(key: "pu:\(pu.id)", tick: f.tickCount,
                                            halfExtent: r + spritePad(blur: 15)) { sc in
                    drawPowerUpBody(pu, sc)
                }
                if let sprite { ctx.drawSprite(sprite, at: x, y) }
            } else {
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                drawPowerUpBody(pu, ctx)
                ctx.restoreGState()
            }

            // Rotating ring
            ctx.setCanvasLineDash([5, 5], offset: CGFloat(-f.simMs / 20))
            ctx.strokeCircle(x, y, r + 3, lineWidth: 2, color: pu.color)
            ctx.clearLineDash()
        }
    }
}
