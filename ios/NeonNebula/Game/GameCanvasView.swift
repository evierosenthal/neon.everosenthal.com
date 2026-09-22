import SwiftUI
import NeonEngine

/// SwiftUI host for `GameView`. The engine is owned by the caller; this view
/// ticks it at 60 Hz, feeds it joystick input and draws it. Give it the
/// full screen (`.ignoresSafeArea()`): the renderer reads the safe-area
/// insets itself for the effect chips.
struct GameCanvasView: UIViewRepresentable {
    let engine: GameEngine
    var controlLayout: ControlLayout
    var isPaused: Bool
    var onTick: () -> Void

    init(engine: GameEngine, controlLayout: ControlLayout, isPaused: Bool, onTick: @escaping () -> Void) {
        self.engine = engine
        self.controlLayout = controlLayout
        self.isPaused = isPaused
        self.onTick = onTick
    }

    func makeUIView(context: Context) -> GameView {
        let view = GameView(engine: engine)
        view.controlLayout = controlLayout
        view.onTick = onTick
        view.setPaused(isPaused)
        return view
    }

    func updateUIView(_ view: GameView, context: Context) {
        view.onTick = onTick
        if view.controlLayout != controlLayout {
            view.controlLayout = controlLayout
        }
        if view.isPausedLoop != isPaused {
            view.setPaused(isPaused)
        }
    }
}
