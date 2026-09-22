import Foundation

// game.js:448-517 reset()
extension GameEngine {
    func reset() {
        let hasPlayer2 = config.hasPlayer2
        let w = worldSize.width
        let h = worldSize.height

        var st = GameState(
            player: createPlayer(id: .player1, x: w / (hasPlayer2 ? 3 : 2), y: h / 2, color: "#00ffff"),
            player2: hasPlayer2 ? createPlayer(id: .player2, x: (w / 3) * 2, y: h / 2, color: "#fb7185") : nil,
            difficulty: config.initialDifficulty)

        mousePos = WorldPoint(x: w / 2, y: h / 2)
        lastPointer = nil

        // Fire powers that resize the hull (visuals and collisions both follow radius)
        if config.flame?.power == .tiny { st.player.radius *= 0.7 }
        if config.flame?.power == .giant { st.player.radius *= 1.45 }
        if st.player2 != nil && config.flame2?.power == .tiny { st.player2!.radius *= 0.7 }
        if st.player2 != nil && config.flame2?.power == .giant { st.player2!.radius *= 1.45 }

        // Initial 'W' weapon orb so the player can shoot right away (L488-500).
        // Its id is the literal 'initial_weapon' (no randomId call).
        let vx = (random() - 0.5) * 1.5
        let vy = (random() - 0.5) * 1.5
        var orb = PowerUp(id: "initial_weapon", x: w / 2, y: h / 3, vx: vx, vy: vy,
                          life: 1800, maxLife: 1800, subType: .weapon)
        orb.color = "#ef4444"
        st.powerUps.append(orb)

        state = st

        stars = []
        for _ in 0..<GameConstants.starCount {
            let x = random() * w
            let y = random() * h
            let sz = random() * 2 + 0.5
            stars.append(Star(x: x, y: y, s: sz))
        }

        // keysPressed = {} on the web; `input` belongs to the app here and is
        // left alone (setPaused clears it, like the web).
        controlMode = .mouse
        lastShotTime = 0
        lastShotTime2 = 0
        shake = 0
        // mountTime = Date.now() -> simMs at start, which `start()` set to 0.
    }
}
