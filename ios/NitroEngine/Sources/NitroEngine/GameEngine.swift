import Foundation

/// The simulation. A 1:1 port of `createGame()` in www/game.js: the app
/// calls `tick()` exactly 60 times a second and draws whatever `state`,
/// `stars` and `shake` say. All coordinates are top-left origin, y down, in
/// points, exactly like the web canvas.
///
/// Public surface mirrors game.js:2431-2517 (start/stop/setPaused/
/// setSpeedFactor/receive/getScore/getDebugPositions).
public final class GameEngine {
    public weak var delegate: GameEngineDelegate?

    public internal(set) var config = GameConfig()
    public private(set) var worldSize = WorldSize(width: 800, height: 600)
    /// The running round, or nil between rounds. Backed by `s` so the
    /// simulation code never force-unwraps: an optional accessor yielded
    /// through a `_read` coroutine was found to miscompile member reads
    /// across the module boundary (see GameEngine+Internals.swift).
    public internal(set) var state: GameState? {
        get { hasState ? s : nil }
        set {
            if let value = newValue { s = value; hasState = true } else { hasState = false }
        }
    }
    /// Storage for `state`. Simulation files read and mutate `s` directly
    /// (only ever while `hasState` is true, since `update()` returns early
    /// when there is no round).
    var s: GameState = .idle
    var hasState = false
    public internal(set) var stars: [Star] = []
    /// Screen shake magnitude (game.js `shake`), decays x0.9 per tick.
    public internal(set) var shake: Double = 0
    public private(set) var isPaused = false
    public private(set) var isRunning = false
    /// Ticks since `start()`; `simMs` replaces `Date.now()` for fire rate,
    /// wobble, tutorial fade and cosmetic phases so pause and display rate
    /// cannot change behaviour.
    public internal(set) var tickCount = 0
    public var simMs: Double { Double(tickCount) * GameConstants.tickMs }
    /// `mountTime` equivalent: simMs at start (always 0 here).
    public private(set) var mountMs: Double = 0

    /// Steering for this tick, set by the touch controller before `tick()`.
    public var input = InputState()

    var rng: any RandomSource

    // Internal engine bookkeeping (mirrors game.js:146-179). Filled in by the
    // simulation files; declared here so extensions in other files can use them.
    var lastShotTime: Double = 0
    var lastShotTime2: Double = 0
    var remoteInput = PilotInput.zero
    var pendingSnapshot: Snapshot?
    var sentIds: Set<EntityID> = []
    var knownAsteroids: [EntityID: Asteroid] = [:]
    var knownCollectibles: [EntityID: Collectible] = [:]
    var knownPowerUps: [EntityID: PowerUp] = [:]
    var netFrame = 0
    var finalSnapshotSent = false
    var lastInputSentMs: Double = -1000
    var lastInput = PilotInput.zero
    var lastAppliedSeq: UInt32 = 0
    var nextSeq: UInt32 = 0
    var reportedScore: Int? = nil
    var reportedHealth: Int? = nil
    var reportedHit = 0
    var reportedDying = false
    var reportedOver = false
    var idCounter: UInt64 = 0
    /// game.js:170 `controlMode` — which device last steered pilot 1 ('mouse'
    /// after reset; a non-zero pilot1 vector hands control to the keyboard
    /// path, a pointer update hands it back). Only affects solo/CPU steering
    /// with `controlModePreference == .both` and the thruster tilt.
    var controlMode: ControlModePreference = .mouse
    /// game.js:173 `mousePos` — the follow target of the mouse path (screen
    /// centre after reset, then the last `input.pointer`).
    var mousePos = WorldPoint(x: 0, y: 0)
    /// The last pointer seen, so a repeated identical pointer is not treated
    /// as a new mousemove event.
    var lastPointer: WorldPoint? = nil

    public init(rng: any RandomSource = SystemRNG()) {
        self.rng = rng
    }

    // MARK: Public API (game.js:2431-2517)

    /// `start(options)`: resets everything and begins ticking.
    public func start(_ config: GameConfig, worldSize: WorldSize) {
        self.config = config
        self.config.speedFactor = max(0.01, min(3, config.speedFactor))
        self.worldSize = worldSize
        resetNet()
        tickCount = 0
        mountMs = 0
        reset()
        isPaused = false
        isRunning = true
    }

    public func stop() {
        isRunning = false
        state = nil
    }

    /// The view size changed (rotation between the two landscapes keeps the
    /// same size, so this is rare). Mirrors resizeCanvas(): the world simply
    /// becomes the new size; clamps apply on the next tick.
    public func resize(worldSize: WorldSize) {
        self.worldSize = worldSize
    }

    /// Clears input to avoid stuck thrust (game.js:2468-2472).
    public func setPaused(_ paused: Bool) {
        isPaused = paused
        input = InputState()
    }

    public func setControlModePreference(_ mode: ControlModePreference) {
        config.controlModePreference = mode
    }

    /// Clamped 0.01...3 (game.js:2478-2480).
    public func setSpeedFactor(_ factor: Double) {
        config.speedFactor = max(0.01, min(3, factor.isFinite ? factor : 1))
    }

    /// Score of the round in progress (used when a connection drops).
    public var score: Int { state?.score ?? 0 }

    /// Online: hand a message from the other side to the engine. Host takes
    /// steering; guest takes snapshots (game.js:2484-2494).
    public func receive(_ message: NetMessage) {
        guard let role = config.online else { return }
        switch (role, message) {
        case (.host, .input(let dx, let dy)):
            remoteInput = PilotInput(dx: max(-1, min(1, dx)), dy: max(-1, min(1, dy)))
        case (.guest, .snapshot(let snap)):
            if snap.seq > lastAppliedSeq || snap.seq == 0 { pendingSnapshot = snap }
        default:
            break
        }
    }

    /// One simulation step (game.js `loop()`: update + online send). Drawing
    /// is the caller's job.
    public func tick() {
        guard isRunning else { return }
        update()
        if config.online != nil, state != nil {
            if config.online == .host { maybeSendSnapshot() }
            else if !(state?.isGameOver ?? true) { maybeSendInput() }
        }
        if !isPaused { tickCount += 1 }
    }

    /// Read-only ship telemetry (debug/testing), game.js:2502-2516.
    public struct DebugPositions: Equatable, Sendable {
        public var p1: (x: Double, y: Double, vx: Double, vy: Double)?
        public var p2: (x: Double, y: Double, vx: Double, vy: Double)?
        public static func == (l: DebugPositions, r: DebugPositions) -> Bool {
            func eq(_ a: (x: Double, y: Double, vx: Double, vy: Double)?, _ b: (x: Double, y: Double, vx: Double, vy: Double)?) -> Bool {
                switch (a, b) {
                case (nil, nil): return true
                case let (a?, b?): return a.x == b.x && a.y == b.y && a.vx == b.vx && a.vy == b.vy
                default: return false
                }
            }
            return eq(l.p1, r.p1) && eq(l.p2, r.p2)
        }
    }

    public var debugPositions: DebugPositions? {
        guard let s = state else { return nil }
        func pack(_ p: Player) -> (x: Double, y: Double, vx: Double, vy: Double) {
            (jsRound(p.x * 10) / 10, jsRound(p.y * 10) / 10, jsRound(p.vx * 100) / 100, jsRound(p.vy * 100) / 100)
        }
        return DebugPositions(p1: pack(s.player), p2: s.player2.map(pack))
    }

    // MARK: Internals filled in by the simulation extension files.
    // (GameEngine+Reset.swift, +Update.swift, +Physics.swift, +CPUPilot.swift,
    //  +Weapons.swift, +Difficulty.swift, +Spawns.swift, +Collisions.swift,
    //  +Death.swift, +Thrusters.swift, Online/GameEngine+Net.swift)

    /// `randomId()` (game.js:116-118) burns one Math.random() call; the value
    /// itself is a counter so ids stay short and unique.
    func randomId() -> EntityID {
        _ = rng.next()
        idCounter += 1
        return String(idCounter, radix: 36)
    }

    func random() -> Double { rng.next() }
}
