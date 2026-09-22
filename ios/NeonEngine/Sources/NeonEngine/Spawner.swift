import Foundation

// Entity factories (game.js:183-411) and updateSpawns (game.js:798-832).
//
// Every `Math.random()` maps to exactly one `random()` here, in the same
// order the JavaScript evaluates them. In a JS object literal the properties
// evaluate top to bottom, so `id: randomId()` burns its random before the
// later `radius`/`color`/`rotation` fields; locals declared before the
// literal (angle, speed, life...) come first.
extension GameEngine {

    /// game.js:183-199
    func createParticle(x: Double, y: Double, color: CSSColor, isThruster: Bool = false) -> Particle {
        let angle = random() * Double.pi * 2
        let speed = isThruster ? (random() * 2 + 1) : (random() * 3 + 1)
        let life = isThruster ? (8 + random() * 8) : (20 + random() * 10)
        let id = randomId()
        let radius = isThruster ? (random() * 2 + 1) : (random() * 2.5 + 1)
        return Particle(id: id, x: x, y: y,
                        vx: cos(angle) * speed, vy: sin(angle) * speed,
                        radius: radius, color: color, life: life, maxLife: life)
    }

    /// game.js:201-228
    func createCollectible(width: Double, height: Double) -> Collectible {
        let kind: CollectibleKind = random() < 0.5 ? .sundae : .donut
        var sprinkles: [Sprinkle] = []
        if kind == .donut {
            let sprinkleColors: [CSSColor] = ["#fef08a", "#86efac", "#93c5fd", "#fca5a5", "#f0abfc"]
            for i in 0..<7 {
                let a = random() * Double.pi * 2
                let d = 0.55 + random() * 0.35
                let rot = random() * Double.pi
                sprinkles.append(Sprinkle(a: a, d: d, rot: rot, color: sprinkleColors[i % sprinkleColors.count]))
            }
        }
        let id = randomId()
        let x = random() * width
        let y = random() * height
        let vx = (random() - 0.5) * 1
        let vy = (random() - 0.5) * 1
        return Collectible(id: id, x: x, y: y, vx: vx, vy: vy,
                           color: kind == .donut ? "#f472b6" : "#fde68a",
                           kind: kind, sprinkles: sprinkles)
    }

    /// game.js:230-243
    func createProjectile(x: Double, y: Double, angle: Double, color: CSSColor? = nil) -> Projectile {
        let speed = 10.0
        let id = randomId()
        return Projectile(id: id, x: x, y: y,
                          vx: cos(angle) * speed, vy: sin(angle) * speed,
                          color: color ?? "#00ffff")
    }

    /// game.js:245-272. Magnet is rare (~6%) and only from Medium up.
    func createPowerUp(width: Double, height: Double, difficulty: Double) -> PowerUp {
        let isMediumOrHigher = difficulty >= 0.6
        let rand = random()
        let type: PowerUpType
        if isMediumOrHigher && rand < 0.06 {
            type = .magnet
        } else {
            let others: [PowerUpType] = [.shield, .speed, .weapon]
            type = others[jsRandomIndex(&rng, others.count)]
        }
        let id = randomId()
        let x = random() * width
        let y = random() * height
        let vx = (random() - 0.5) * 2
        let vy = (random() - 0.5) * 2
        return PowerUp(id: id, x: x, y: y, vx: vx, vy: vy, life: 1200, maxLife: 1200, subType: type)
    }

    /// game.js:274-285
    func addFloatingText(x: Double, y: Double, text: String, color: CSSColor? = nil, scale: Double = 1.0) {
        let id = randomId()
        s.floatingTexts.append(FloatingText(id: id, x: x, y: y, text: text, color: color ?? "#ffffff", scale: scale))
    }

    /// game.js:287-306
    func createShockwaveRing(x: Double, y: Double, color: CSSColor, count: Int = 8) {
        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * Double.pi * 2
            let speed = 3.0
            let life = 18 + random() * 10
            let id = randomId()
            s.particles.append(Particle(id: id, x: x, y: y,
                                        vx: cos(angle) * speed, vy: sin(angle) * speed,
                                        radius: 2.5, color: color, life: life, maxLife: life))
        }
    }

    /// game.js:308-398
    func createAsteroid(width: Double, height: Double, difficulty: Double) -> Asteroid {
        let side = jsRandomIndex(&rng, 4)
        var x = 0.0
        var y = 0.0
        if side == 0 { x = random() * width; y = -50 }
        else if side == 1 { x = width + 50; y = random() * height }
        else if side == 2 { x = random() * width; y = height + 50 }
        else { x = -50; y = random() * height }

        let targetX = width / 2 + (random() - 0.5) * width
        let targetY = height / 2 + (random() - 0.5) * height
        let angle = atan2(targetY - y, targetX - x) + (random() - 0.5) * 0.2
        let superHardSpeedBoost = difficulty >= 4.0 ? 2.5 : 1.0
        let mediumSpeedBoost = (difficulty >= 0.6 && difficulty < 1.2) ? 1.2 : 1.0
        let speed = (random() * 2.5 + 2.0) * difficulty * superHardSpeedBoost * mediumSpeedBoost

        let styles: [AsteroidStyle] = [.rocky, .faceted, .blobby]
        let style = styles[jsRandomIndex(&rng, 3)]
        let tint: AsteroidTint = style == .rocky ? .gray : (style == .faceted ? .blue : .darkblue)

        let vertexCount: Int
        let roundness: Double
        let spread: Double
        if style == .blobby {
            vertexCount = 10 + jsRandomIndex(&rng, 3); roundness = 0.92; spread = 0.14
        } else if style == .faceted {
            vertexCount = 9 + jsRandomIndex(&rng, 4); roundness = 0.78; spread = 0.38
        } else {
            vertexCount = 8 + jsRandomIndex(&rng, 5); roundness = 0.85; spread = 0.3
        }
        var vertices: [Double] = []
        for _ in 0..<vertexCount {
            vertices.append(roundness + random() * spread)
        }

        let craterCount: Int
        let craterBase: Double
        let craterVar: Double
        if style == .blobby { craterCount = 3; craterBase = 0.16; craterVar = 0.14 }
        else if style == .faceted { craterCount = 4 + jsRandomIndex(&rng, 3); craterBase = 0.08; craterVar = 0.1 }
        else { craterCount = 2 + jsRandomIndex(&rng, 2); craterBase = 0.12; craterVar = 0.12 }
        var craters: [Crater] = []
        for _ in 0..<craterCount {
            let rx = (random() - 0.5) * (style == .blobby ? 0.8 : 0.5)
            let ry = (random() - 0.5) * (style == .blobby ? 0.8 : 0.5)
            let r = craterBase + random() * craterVar
            let rot = random() * Double.pi * 2
            craters.append(Crater(rx: rx, ry: ry, r: r, rot: rot))
        }

        var speckles: [Speckle] = []
        if style == .rocky {
            for _ in 0..<5 {
                let rx = (random() - 0.5) * 1.1
                let ry = (random() - 0.5) * 1.1
                let r = 0.02 + random() * 0.04
                speckles.append(Speckle(rx: rx, ry: ry, r: r))
            }
        }

        // Object literal (game.js:379-397): id, then radius, color, rotation, spinSpeed.
        let id = randomId()
        let radius = GameConstants.asteroidMinRadius + random() * (GameConstants.asteroidMaxRadius - GameConstants.asteroidMinRadius)
        let color: CSSColor
        if tint == .gray {
            color = CSSColor("hsl(215, 15%, " + jsNumberString(65 + random() * 10) + "%)")
        } else {
            color = CSSColor("hsl(" + jsNumberString(218 + random() * 12) + ", 80%, " + (tint == .darkblue ? "55" : "65") + "%)")
        }
        let rotation = random() * Double.pi * 2
        let spinSpeed = (random() - 0.5) * 0.03
        return Asteroid(id: id, x: x, y: y, vx: cos(angle) * speed, vy: sin(angle) * speed,
                        radius: radius, color: color, style: style, tint: tint,
                        vertices: vertices, craters: craters, speckles: speckles,
                        rotation: rotation, spinSpeed: spinSpeed)
    }

    /// game.js:400-411 (no randoms).
    func createPlayer(id: PilotID, x: Double, y: Double, color: CSSColor) -> Player {
        Player(id: id, x: x, y: y, color: color)
    }

    // MARK: updateSpawns (game.js:798-832)

    func updateSpawns() {
        let w = worldSize.width, h = worldSize.height
        // The medium-tier band gets a small density boost.
        let mediumSpawnBoost = (s.difficulty >= 0.6 && s.difficulty < 1.2) ? 1.45 : 1.0
        var spawnChance = GameConstants.spawnRate * pow(s.difficulty, 2) * mediumSpawnBoost
        while spawnChance > 0 {
            if random() < min(1, spawnChance) {
                let a = createAsteroid(width: w, height: h, difficulty: s.difficulty)
                s.asteroids.append(a)
            }
            spawnChance -= 1
        }

        // Spawn collectibles
        if s.collectibles.count < 12 && random() < 0.02 / s.difficulty.squareRoot() {
            let c = createCollectible(width: w, height: h)
            s.collectibles.append(c)
        }

        // Spawn power-ups (Easy gets most, Medium slightly less, Hard less than Medium)
        var powerUpChance = 0.010
        var maxPowerUps = 3
        if s.difficulty >= 5.0 {
            powerUpChance = 0.001; maxPowerUps = 2
        } else if s.difficulty >= 1.0 {
            powerUpChance = 0.0028; maxPowerUps = 2
        } else if s.difficulty >= 0.6 {
            powerUpChance = 0.0045; maxPowerUps = 2
        }

        if s.powerUps.count < maxPowerUps && random() < powerUpChance {
            let u = createPowerUp(width: w, height: h, difficulty: s.difficulty)
            s.powerUps.append(u)
        }
    }
}
