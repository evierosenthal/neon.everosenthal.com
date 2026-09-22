import CoreGraphics
import NeonEngine

/// One floating stick: the anchor is where the finger landed and never
/// drifts; the knob follows the finger, clamped to `maxRadius` for display.
/// The steering vector is the knob's direction scaled by a 0→1 ramp that
/// starts past the dead zone and reaches 1 at full deflection, so a fully
/// deflected stick equals holding a key on the web.
struct FloatingJoystick: Equatable {
    var anchor: CGPoint
    private(set) var knob: CGPoint
    var maxRadius: CGFloat
    var deadZone: CGFloat

    init(anchor: CGPoint, maxRadius: CGFloat = 60, deadZone: CGFloat = 8) {
        self.anchor = anchor
        self.knob = anchor
        self.maxRadius = maxRadius
        self.deadZone = deadZone
    }

    /// Move the finger; the knob is clamped to the ring.
    mutating func update(touch: CGPoint) {
        let dx = touch.x - anchor.x
        let dy = touch.y - anchor.y
        let d = (dx * dx + dy * dy).squareRoot()
        if d > maxRadius, d > 0 {
            knob = CGPoint(x: anchor.x + dx / d * maxRadius, y: anchor.y + dy / d * maxRadius)
        } else {
            knob = touch
        }
    }

    /// Distance from the anchor to the knob (0...maxRadius).
    var deflection: CGFloat {
        let dx = knob.x - anchor.x
        let dy = knob.y - anchor.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Unit direction × ramp(deadZone → maxRadius).
    var vector: PilotInput {
        let d = deflection
        guard d > deadZone, maxRadius > deadZone else { return .zero }
        let m = min(1, (d - deadZone) / (maxRadius - deadZone))
        let ux = (knob.x - anchor.x) / d
        let uy = (knob.y - anchor.y) / d
        return PilotInput(dx: Double(ux * m), dy: Double(uy * m))
    }
}
