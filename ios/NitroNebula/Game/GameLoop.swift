import QuartzCore

/// CADisplayLink-driven fixed-step loop: the engine ticks at exactly 60 Hz
/// (`GameConstants.ticksPerSecond`) however the display behaves, and the
/// view redraws only on frames where at least one tick ran.
final class GameLoop {
    static let step: CFTimeInterval = 1.0 / 60.0
    /// A stall longer than this (background, debugger) is dropped instead of
    /// replayed as a burst of ticks.
    static let maxFrameDelta: CFTimeInterval = 0.25

    private let tick: () -> Void
    private let render: () -> Void
    private var link: CADisplayLink?
    private var last: CFTimeInterval?
    private var accumulator: CFTimeInterval = 0

    var isRunning: Bool { link != nil }

    init(tick: @escaping () -> Void, render: @escaping () -> Void) {
        self.tick = tick
        self.render = render
    }

    /// Starts (or restarts) the link. `last` is reset so resuming after a
    /// pause does not catch up on the paused time.
    func start() {
        guard link == nil else { return }
        let proxy = LinkProxy(loop: self)
        let l = CADisplayLink(target: proxy, selector: #selector(LinkProxy.frame(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        l.add(to: .main, forMode: .common)
        link = l
        last = nil
        accumulator = 0
    }

    /// Invalidates the link. Pause = stop.
    func stop() {
        link?.invalidate()
        link = nil
        last = nil
        accumulator = 0
    }

    fileprivate func frame(_ link: CADisplayLink) {
        let now = link.targetTimestamp
        let prev = last ?? link.timestamp
        last = now
        accumulator += min(max(0, now - prev), GameLoop.maxFrameDelta)
        var ticked = false
        while accumulator >= GameLoop.step {
            accumulator -= GameLoop.step
            tick()
            ticked = true
        }
        if ticked { render() }
    }

    /// CADisplayLink retains its target; this weak hop keeps the loop (and
    /// the view that owns it) collectable without an explicit teardown.
    private final class LinkProxy: NSObject {
        weak var loop: GameLoop?
        init(loop: GameLoop) { self.loop = loop }

        @objc func frame(_ link: CADisplayLink) {
            if let loop { loop.frame(link) } else { link.invalidate() }
        }
    }
}
