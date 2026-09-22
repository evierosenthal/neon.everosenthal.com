import UIKit
import NitroEngine

/// The canvas. Owns the display-link loop, the touch controller and the
/// renderer; the engine is owned by the app and shared with the HUD.
///
/// World size = `bounds.size` in points (the web's canvas = viewport), so
/// the engine is resized from `layoutSubviews`. Start the engine after the
/// view has laid out (or with the size you know it will get) so the ships
/// spawn in the right place.
final class GameView: UIView {
    let engine: GameEngine
    let renderer = Renderer()
    let touchController = TouchController()

    /// Fired on the main thread after every engine tick (coalesce HUD
    /// updates here rather than observing the engine).
    var onTick: (() -> Void)?

    /// Pause state of the loop (the link is stopped while paused).
    private(set) var isPausedLoop = false

    private var loop: GameLoop!
    private var lastWorldSize: CGSize = .zero

    init(engine: GameEngine) {
        self.engine = engine
        super.init(frame: .zero)
        isOpaque = true
        isMultipleTouchEnabled = true
        contentMode = .redraw
        backgroundColor = UIColor(red: CGFloat(Renderer.backgroundColor.r), green: CGFloat(Renderer.backgroundColor.g),
                                  blue: CGFloat(Renderer.backgroundColor.b), alpha: 1)
        loop = GameLoop(
            tick: { [weak self] in self?.tickOnce() },
            render: { [weak self] in self?.setNeedsDisplay() }
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Configuration

    var controlLayout: ControlLayout {
        get { touchController.layout }
        set { touchController.layout = newValue }
    }

    /// Current world size handed to the engine (points).
    var worldSize: WorldSize {
        WorldSize(width: Double(bounds.width), height: Double(bounds.height))
    }

    /// Pausing stops the display link, drops every stick and clears the
    /// engine's input (no stuck thrust). Resuming restarts the link fresh.
    func setPaused(_ paused: Bool) {
        isPausedLoop = paused
        engine.setPaused(paused)
        if paused { touchController.clearAll() }
        updateLoop()
        setNeedsDisplay()
    }

    private func updateLoop() {
        let shouldRun = window != nil && !isPausedLoop
        if shouldRun { loop.start() } else { loop.stop() }
    }

    // MARK: UIView

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            contentScaleFactor = window.screen.scale
            renderer.scale = contentScaleFactor
        } else {
            touchController.clearAll()
        }
        updateLoop()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.size
        touchController.zoneSize = size
        if size != lastWorldSize, size.width > 0, size.height > 0 {
            lastWorldSize = size
            engine.resize(worldSize: WorldSize(width: Double(size.width), height: Double(size.height)))
            setNeedsDisplay()
        }
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        renderer.scale = contentScaleFactor
        renderer.draw(engine: engine, in: ctx, size: bounds.size, safeInsets: safeAreaInsets,
                      overlay: touchController.overlayState)
    }

    // MARK: Loop

    private func tickOnce() {
        engine.input = touchController.sample()
        engine.tick()
        onTick?()
    }

    // MARK: Touches (raw, no gesture recognizers)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchController.touchesBegan(touches, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchController.touchesMoved(touches, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchController.touchesEnded(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchController.touchesCancelled(touches)
    }
}
