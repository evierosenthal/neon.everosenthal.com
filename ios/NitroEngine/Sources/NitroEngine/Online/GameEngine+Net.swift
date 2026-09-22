import Foundation

// game.js:156-166 (resetNet) and 2208-2361: host -> guest snapshots and
// guest -> host steering.
extension GameEngine {

    /// game.js:156-166
    func resetNet() {
        remoteInput = .zero
        pendingSnapshot = nil
        sentIds = []
        knownAsteroids = [:]
        knownCollectibles = [:]
        knownPowerUps = [:]
        netFrame = 0
        finalSnapshotSent = false
        // The web sets lastInputSent = 0 and compares against Date.now(), so
        // its first frame always sends. simMs starts at 0 here, so start far
        // enough back that tick 0 sends too.
        lastInputSentMs = -1000
        lastInput = .zero
        lastAppliedSeq = 0
        nextSeq = 0
        reportedScore = nil
        reportedHealth = nil
        reportedHit = 0
        reportedDying = false
        reportedOver = false
    }

    // MARK: Host

    /// `r1()` game.js:2210 — one decimal.
    static func r1(_ v: Double) -> Double { jsRound(v * 10) / 10 }

    /// game.js:2212-2214
    static func packPlayer(_ p: Player) -> Snapshot.PackedPlayer {
        Snapshot.PackedPlayer(x: r1(p.x), y: r1(p.y), vx: r1(p.vx), vy: r1(p.vy), radius: r1(p.radius))
    }

    /// game.js:2216-2264. Asteroids, treats and orbs travel in full once
    /// (shape, colours...) and as id + position afterwards.
    func buildSnapshot() -> Snapshot {
        nextSeq &+= 1
        var snap = Snapshot(
            world: worldSize,
            score: Int(jsRound(Double(s.score))),
            health: GameEngine.r1(Double(s.health)),
            difficulty: s.difficulty,
            dying: s.dying,
            gameOver: s.isGameOver,
            shipsDestroyed: s.shipsDestroyed,
            shake: GameEngine.r1(shake),
            hitCount: s.hitCount,
            effects: s.activeEffects,
            p: GameEngine.packPlayer(s.player),
            p2: s.player2.map(GameEngine.packPlayer))
        snap.seq = nextSeq
        for a in s.asteroids {
            if !sentIds.contains(a.id) { sentIds.insert(a.id); snap.an.append(a) }
            snap.a.append(Snapshot.AsteroidRow(id: a.id, x: GameEngine.r1(a.x), y: GameEngine.r1(a.y),
                                               rotation: jsRound(a.rotation * 1000) / 1000))
        }
        for c in s.collectibles {
            if !sentIds.contains(c.id) { sentIds.insert(c.id); snap.cn.append(c) }
            snap.c.append(Snapshot.CollectibleRow(id: c.id, x: GameEngine.r1(c.x), y: GameEngine.r1(c.y)))
        }
        for u in s.powerUps {
            if !sentIds.contains(u.id) { sentIds.insert(u.id); snap.un.append(u) }
            snap.u.append(Snapshot.PowerUpRow(id: u.id, x: GameEngine.r1(u.x), y: GameEngine.r1(u.y), life: u.life))
        }
        for j in s.projectiles {
            snap.j.append(Snapshot.ProjectileRow(x: GameEngine.r1(j.x), y: GameEngine.r1(j.y), radius: j.radius, color: j.color))
        }
        let particles = s.particles.count > 60 ? Array(s.particles.suffix(60)) : s.particles
        for pt in particles {
            snap.pt.append(Snapshot.ParticleRow(x: GameEngine.r1(pt.x), y: GameEngine.r1(pt.y), radius: GameEngine.r1(pt.radius),
                                                color: pt.color, life: Int(jsRound(pt.life)), maxLife: Int(jsRound(pt.maxLife))))
        }
        for ft in s.floatingTexts {
            snap.ft.append(Snapshot.TextRow(x: GameEngine.r1(ft.x), y: GameEngine.r1(ft.y), text: ft.text, color: ft.color,
                                            alpha: GameEngine.r1(ft.alpha), scale: ft.scale))
        }
        // Forget ids that are gone so the "already sent" set stays small.
        if netFrame % 300 == 0 {
            var live: Set<EntityID> = []
            for a in s.asteroids { live.insert(a.id) }
            for c in s.collectibles { live.insert(c.id) }
            for u in s.powerUps { live.insert(u.id) }
            sentIds = live
        }
        return snap
    }

    /// game.js:2266-2275: every 3rd frame, plus one final word on game over.
    func maybeSendSnapshot() {
        netFrame += 1
        if s.isGameOver {
            if finalSnapshotSent { return }
            finalSnapshotSent = true
        } else if netFrame % 3 != 0 {
            return // 20 snapshots a second is plenty
        }
        delegate?.engine(self, send: .snapshot(buildSnapshot()))
    }

    // MARK: Guest

    /// game.js:2277-2279
    static func unpackPlayer(_ p: inout Player, _ row: Snapshot.PackedPlayer) {
        p.x = row.x; p.y = row.y; p.vx = row.vx; p.vy = row.vy; p.radius = row.radius
    }

    /// game.js:2281-2291, per entity type (the JS keeps one id -> entity map).
    /// A row whose full record hasn't arrived yet is skipped.
    private func rebuildList<E, Row>(_ rows: [Row], _ fullList: [E], _ known: inout [EntityID: E],
                                     id: (E) -> EntityID, rowID: (Row) -> EntityID,
                                     apply: (inout E, Row) -> Void) -> [E] {
        for e in fullList { known[id(e)] = e }
        var out: [E] = []
        for row in rows {
            guard var e = known[rowID(row)] else { continue }
            apply(&e, row)
            known[rowID(row)] = e
            out.append(e)
        }
        return out
    }

    /// game.js:2293-2332
    func applySnapshot(_ snap: Snapshot) {
        lastAppliedSeq = snap.seq
        let health = Int(jsRound(snap.health))
        s.score = snap.score
        s.health = health
        s.difficulty = snap.difficulty
        s.dying = snap.dying
        s.isGameOver = snap.gameOver
        s.shipsDestroyed = snap.shipsDestroyed
        shake = snap.shake
        s.activeEffects = snap.effects
        GameEngine.unpackPlayer(&s.player, snap.p)
        if let p2 = snap.p2 {
            if s.player2 == nil { s.player2 = createPlayer(id: .player2, x: p2.x, y: p2.y, color: "#fb7185") }
            GameEngine.unpackPlayer(&s.player2!, p2)
        }
        s.asteroids = rebuildList(snap.a, snap.an, &knownAsteroids, id: { $0.id }, rowID: { $0.id }) { a, row in
            a.x = row.x; a.y = row.y; a.rotation = row.rotation
        }
        s.collectibles = rebuildList(snap.c, snap.cn, &knownCollectibles, id: { $0.id }, rowID: { $0.id }) { c, row in
            c.x = row.x; c.y = row.y
        }
        s.powerUps = rebuildList(snap.u, snap.un, &knownPowerUps, id: { $0.id }, rowID: { $0.id }) { u, row in
            u.x = row.x; u.y = row.y; u.life = row.life
        }
        s.projectiles = snap.j.map { row in
            var p = Projectile(id: "", x: row.x, y: row.y, vx: 0, vy: 0, color: row.color)
            p.radius = row.radius
            return p
        }
        s.particles = snap.pt.map { row in
            Particle(id: "", x: row.x, y: row.y, vx: 0, vy: 0, radius: row.radius, color: row.color,
                     life: Double(row.life), maxLife: Double(row.maxLife))
        }
        s.floatingTexts = snap.ft.map { row in
            var t = FloatingText(id: "", x: row.x, y: row.y, text: row.text, color: row.color, scale: row.scale)
            t.alpha = row.alpha
            return t
        }
        // `if (netFrame++ % 300 === 0)`: tests the value before incrementing.
        let frame = netFrame
        netFrame += 1
        if frame % 300 == 0 {
            knownAsteroids = Dictionary(uniqueKeysWithValues: s.asteroids.map { ($0.id, $0) })
            knownCollectibles = Dictionary(uniqueKeysWithValues: s.collectibles.map { ($0.id, $0) })
            knownPowerUps = Dictionary(uniqueKeysWithValues: s.powerUps.map { ($0.id, $0) })
        }

        // Mirror the host's callbacks so the HUD, sounds and game-over flow match.
        if snap.score != reportedScore { reportedScore = snap.score; delegate?.engine(self, scoreDidChange: snap.score) }
        if health != reportedHealth { reportedHealth = health; delegate?.engine(self, healthDidChange: health) }
        if snap.hitCount > reportedHit { reportedHit = snap.hitCount; delegate?.engineDidTakeHit(self) }
        if s.dying && !reportedDying { reportedDying = true; delegate?.engineDidStartDeath(self) }
        delegate?.engine(self, difficultyDidChange: snap.difficulty)
        if s.isGameOver && !reportedOver { reportedOver = true; delegate?.engine(self, gameOverWithScore: s.score) }
    }

    /// game.js:2334-2361: the guest's steering as a unit vector, sent when it
    /// changes or every 250 ms (simMs) as a keep-alive.
    func maybeSendInput() {
        var dx = 0.0
        var dy = 0.0
        let pref = config.controlModePreference
        let keyboardDrives = pref == .keyboard || (pref == .both && controlMode == .keyboard)
        let mouseDrives = pref == .mouse || (pref == .both && controlMode == .mouse)
        if keyboardDrives {
            dx = input.pilot1.dx
            dy = input.pilot1.dy
            let len = (dx * dx + dy * dy).squareRoot()
            if len > 1 { dx /= len; dy /= len }
        } else if mouseDrives, input.pointer != nil, let p2 = s.player2 {
            let ddx = mousePos.x - p2.x
            let ddy = mousePos.y - p2.y
            let dist = (ddx * ddx + ddy * ddy).squareRoot()
            if dist > 14 { dx = ddx / dist; dy = ddy / dist }
        }
        dx = jsRound(dx * 100) / 100
        dy = jsRound(dy * 100) / 100
        let now = simMs
        if dx != lastInput.dx || dy != lastInput.dy || now - lastInputSentMs > 250 {
            lastInput = PilotInput(dx: dx, dy: dy)
            lastInputSentMs = now
            delegate?.engine(self, send: .input(dx: dx, dy: dy))
        }
    }
}
