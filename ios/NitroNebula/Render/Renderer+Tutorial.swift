import UIKit
import NeonEngine

// game.js:2082-2177 — drawTutorial. Same card, same fade (4.5 s hold, 1.5 s
// fade, gone at 6 s of simulation time); the copy is rewritten for touch.
extension Renderer {

    static let tutorialWidth: CGFloat = 480
    static let tutorialHeight: CGFloat = 135

    /// 0 when the card is gone; the web's `alpha` otherwise.
    static func tutorialAlpha(elapsedMs: Double) -> Double {
        if elapsedMs >= 6000 { return 0 }
        let alpha = elapsedMs < 4500 ? 0.9 : max(0, 0.9 - (elapsedMs - 4500) / 1500)
        return alpha
    }

    func drawTutorial(_ f: RenderFrame, _ ctx: CGContext, size: CGSize) {
        let elapsed = f.simMs - f.mountMs
        let alpha = Renderer.tutorialAlpha(elapsedMs: elapsed)
        if alpha <= 0 { return }

        ctx.saveGState()

        let w = Renderer.tutorialWidth
        let h = Renderer.tutorialHeight
        let x = size.width / 2 - w / 2
        let y = size.height / 2 - h / 2 - 80
        let cx = size.width / 2

        let card = ctx.roundedRectPath(x, y, w, h, 20)
        ctx.setFill(RGBA(r: 15.0 / 255, g: 23.0 / 255, b: 42.0 / 255, a: alpha * 0.9))
        ctx.fill(card)
        ctx.setStroke(RGBA(r: 99.0 / 255, g: 102.0 / 255, b: 241.0 / 255, a: alpha * 0.55))
        ctx.stroke(card, lineWidth: 1.5)

        ctx.fillText("MISSION CONTROL PROTOCOLS", x: cx, y: y + 25, font: Fonts.sans(14, weight: .bold),
                     color: RGBA(r: 1, g: 1, b: 1, a: alpha), align: .center)

        ctx.setStroke(RGBA(r: 1, g: 1, b: 1, a: alpha * 0.15))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x + 30, y: y + 36))
        ctx.addLine(to: CGPoint(x: x + w - 30, y: y + 36))
        ctx.strokePath()

        let cyan = RGBA(r: 0, g: 1, b: 1, a: alpha)
        let pink = RGBA(r: 251.0 / 255, g: 113.0 / 255, b: 133.0 / 255, a: alpha)
        let body = RGBA(r: 226.0 / 255, g: 232.0 / 255, b: 240.0 / 255, a: alpha * 0.9)
        let heading = Fonts.mono(12, bold: true)
        let line = Fonts.mono(11, bold: true)

        if f.config.isLocalMultiplayer {
            // Pilot 1 (Cyan)
            ctx.fillText("PILOT 1 (CYAN SHIP)", x: x + 35, y: y + 58, font: heading, color: cyan)
            ctx.fillText("Move: DRAG ON THE LEFT HALF", x: x + 35, y: y + 78, font: line, color: body)
            ctx.fillText("Weapons: GRAB 'W' ORB TO SHOOT", x: x + 35, y: y + 96, font: line, color: body)

            // Pilot 2 (Pink)
            ctx.fillText("PILOT 2 (PINK SHIP)", x: x + 255, y: y + 58, font: heading, color: pink)
            ctx.fillText("Move: DRAG ON THE RIGHT HALF", x: x + 255, y: y + 78, font: line, color: body)
            ctx.fillText("Weapons: GRAB 'W' ORB TO SHOOT", x: x + 255, y: y + 96, font: line, color: body)
        } else if f.config.isCPUMultiplayer {
            // Pilot 1 (Cyan)
            ctx.fillText("PILOT 1 (CYAN SHIP)", x: x + 35, y: y + 58, font: heading, color: cyan)
            ctx.fillText("Controls: DRAG ANYWHERE TO FLY", x: x + 35, y: y + 78, font: line, color: body)
            ctx.fillText("Weapons: GRAB 'W' ORB TO AUTO-FIRE", x: x + 35, y: y + 96, font: line, color: body)

            // CPU Co-pilot (Pink)
            ctx.fillText("NEURAL CO-PILOT (AI)", x: x + 255, y: y + 58, font: heading, color: pink)
            ctx.fillText("Strategy: DODGE & ASSIST", x: x + 255, y: y + 78, font: line, color: body)
            ctx.fillText("System: AUTONOMOUS", x: x + 255, y: y + 96, font: line, color: body)
        } else if let role = f.config.online {
            // Online squadron: this device steers its own ship
            let me = role == .host ? "PILOT 1 (CYAN SHIP)" : "PILOT 2 (PINK SHIP)"
            ctx.fillText(me, x: x + 35, y: y + 58, font: heading, color: role == .host ? cyan : pink)
            ctx.fillText("Controls: DRAG ANYWHERE TO FLY", x: x + 35, y: y + 78, font: line, color: body)
            ctx.fillText("Weapons: GRAB 'W' ORB TO AUTO-FIRE", x: x + 35, y: y + 96, font: line, color: body)

            ctx.fillText("ONLINE SQUADRON", x: x + 255, y: y + 58, font: heading, color: role == .host ? pink : cyan)
            ctx.fillText(role == .host ? "Wingmate: REMOTE PILOT 2" : "Wingmate: REMOTE PILOT 1",
                         x: x + 255, y: y + 78, font: line, color: body)
            ctx.fillText("Link: SYNCED", x: x + 255, y: y + 96, font: line, color: body)
        } else {
            // Single player help
            ctx.fillText("SINGLE PILOT STATUS: READY", x: cx, y: y + 58, font: heading, color: cyan, align: .center)
            ctx.fillText("Drag anywhere to fly \u{00B7} lift your finger to coast", x: cx, y: y + 78,
                         font: line, color: body, align: .center)
            ctx.fillText("Auto-fire once you grab the red W orb", x: cx, y: y + 96,
                         font: line, color: body, align: .center)
        }

        ctx.fillText("THE STICK APPEARS WHEREVER YOU TOUCH", x: cx, y: y + h - 14,
                     font: Fonts.mono(9, bold: true, italic: true),
                     color: RGBA(r: 99.0 / 255, g: 102.0 / 255, b: 241.0 / 255, a: alpha * 0.95), align: .center)

        ctx.restoreGState()
    }
}
