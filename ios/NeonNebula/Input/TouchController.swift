import UIKit
import NeonEngine

/// How the screen is carved into steering zones.
enum ControlLayout: Equatable, Sendable {
    /// The whole screen steers pilot 1 (solo, CPU wingman, online).
    case single
    /// Left half steers pilot 1, right half pilot 2 (local two-player).
    case split
}

/// What the renderer needs to draw the sticks.
struct JoystickOverlayState: Equatable {
    struct Stick: Equatable {
        var pilot: PilotID
        var anchor: CGPoint
        var knob: CGPoint
        var maxRadius: CGFloat
        /// 1 while held; ramps to 0 over the fade after release.
        var opacity: CGFloat
    }
    var sticks: [Stick] = []

    static let empty = JoystickOverlayState()
}

/// Raw multi-touch → one floating joystick per zone. No gesture
/// recognizers: the first touch that lands in a zone owns that zone's stick
/// (by `ObjectIdentifier(touch)`) until it ends or is cancelled, even if the
/// finger crosses the midline; later touches in an owned zone are ignored.
final class TouchController {
    static let fadeTicks = 10
    static let knobRadius: CGFloat = 22

    var layout: ControlLayout = .single {
        didSet { if layout != oldValue { clearAll() } }
    }
    /// The view's size in points; sets where the midline is in `.split`.
    var zoneSize: CGSize = .zero

    private struct Active {
        let touch: ObjectIdentifier
        var stick: FloatingJoystick
    }

    private struct Fading {
        let pilot: PilotID
        let anchor: CGPoint
        let knob: CGPoint
        let maxRadius: CGFloat
        var remaining: Int
    }

    private var active: [PilotID: Active] = [:]
    private var fading: [Fading] = []

    init(layout: ControlLayout = .single) {
        self.layout = layout
    }

    // MARK: Zones

    func pilot(at point: CGPoint) -> PilotID {
        switch layout {
        case .single: return .player1
        case .split: return point.x < zoneSize.width / 2 ? .player1 : .player2
        }
    }

    // MARK: Touch lifecycle (UIKit-free so tests can drive it)

    func begin(_ id: ObjectIdentifier, at point: CGPoint) {
        let pilot = pilot(at: point)
        guard active[pilot] == nil else { return } // zone already owned
        fading.removeAll { $0.pilot == pilot }
        active[pilot] = Active(touch: id, stick: FloatingJoystick(anchor: point))
    }

    func move(_ id: ObjectIdentifier, to point: CGPoint) {
        for (pilot, entry) in active where entry.touch == id {
            var e = entry
            e.stick.update(touch: point)
            active[pilot] = e
        }
    }

    func end(_ id: ObjectIdentifier) {
        for (pilot, entry) in active where entry.touch == id {
            fading.append(Fading(pilot: pilot, anchor: entry.stick.anchor, knob: entry.stick.knob,
                                 maxRadius: entry.stick.maxRadius, remaining: TouchController.fadeTicks))
            active[pilot] = nil
        }
    }

    /// Drops every stick (pause, layout change, view leaving the window).
    func clearAll() {
        active.removeAll()
        fading.removeAll()
    }

    // MARK: Per-tick

    /// Called once per tick before `engine.tick()`; also advances the fades.
    func sample() -> InputState {
        var s = InputState()
        if let p1 = active[.player1] { s.pilot1 = p1.stick.vector }
        if let p2 = active[.player2] { s.pilot2 = p2.stick.vector }
        for i in fading.indices { fading[i].remaining -= 1 }
        fading.removeAll { $0.remaining <= 0 }
        return s
    }

    var overlayState: JoystickOverlayState {
        var out = JoystickOverlayState()
        for pilot in [PilotID.player1, .player2] {
            if let a = active[pilot] {
                out.sticks.append(.init(pilot: pilot, anchor: a.stick.anchor, knob: a.stick.knob,
                                        maxRadius: a.stick.maxRadius, opacity: 1))
            }
        }
        for f in fading {
            out.sticks.append(.init(pilot: f.pilot, anchor: f.anchor, knob: f.knob, maxRadius: f.maxRadius,
                                    opacity: CGFloat(f.remaining) / CGFloat(TouchController.fadeTicks)))
        }
        return out
    }

    /// Whether `pilot`'s zone is currently owned by a touch.
    func hasStick(for pilot: PilotID) -> Bool {
        active[pilot] != nil
    }

    /// The stick currently owned by `pilot`, if any (tests).
    ///
    /// Written with `guard let` on purpose: with Xcode 26's Swift 6 default
    /// MainActor isolation, the optional-chained form `active[pilot]?.stick`
    /// returned `.some(<uninitialised memory>)` for a missing key (caught by
    /// InputTests). Keep the explicit unwrap.
    func stick(for pilot: PilotID) -> FloatingJoystick? {
        guard let entry = active[pilot] else { return nil }
        return entry.stick
    }

    // MARK: UIKit forwarding

    func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        for t in touches { begin(ObjectIdentifier(t), at: t.location(in: view)) }
    }

    func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        for t in touches { move(ObjectIdentifier(t), to: t.location(in: view)) }
    }

    func touchesEnded(_ touches: Set<UITouch>) {
        for t in touches { end(ObjectIdentifier(t)) }
    }

    func touchesCancelled(_ touches: Set<UITouch>) {
        for t in touches { end(ObjectIdentifier(t)) }
    }
}
