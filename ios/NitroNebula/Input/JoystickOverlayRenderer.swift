import UIKit
import NitroEngine

/// Draws the floating sticks: a faint base ring at the anchor and a knob in
/// the pilot's accent. Called by Renderer after the tutorial, outside the
/// shake transform, so the stick stays under the finger.
final class JoystickOverlayRenderer {
    static let ringStrokeAlpha: CGFloat = 0.25
    static let ringLineWidth: CGFloat = 1.5
    static let knobAlpha: CGFloat = 0.6

    static func accent(for pilot: PilotID) -> RGBA {
        switch pilot {
        case .player1: return Colors.rgba("#00ffff")
        case .player2: return Colors.rgba("#fb7185")
        }
    }

    init() {}

    func draw(_ state: JoystickOverlayState, in ctx: CGContext) {
        guard !state.sticks.isEmpty else { return }
        ctx.saveGState()
        ctx.clearShadow()
        for s in state.sticks {
            let fade = max(0, min(1, s.opacity))
            if fade <= 0 { continue }
            ctx.strokeCircle(s.anchor.x, s.anchor.y, s.maxRadius, lineWidth: JoystickOverlayRenderer.ringLineWidth,
                             color: RGBA(r: 1, g: 1, b: 1, a: Double(JoystickOverlayRenderer.ringStrokeAlpha * fade)))
            let accent = JoystickOverlayRenderer.accent(for: s.pilot)
            ctx.fillCircle(s.knob.x, s.knob.y, TouchController.knobRadius,
                           color: accent.withAlpha(Double(JoystickOverlayRenderer.knobAlpha * fade)))
        }
        ctx.restoreGState()
    }
}
