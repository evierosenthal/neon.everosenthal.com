import UIKit
import NeonEngine

// game.js:1504-1653 — traceAsteroidPath and the three body styles.
extension Renderer {

    /// The asteroid's outline in local (translated/rotated) coordinates.
    static func asteroidPath(_ a: Asteroid) -> CGPath {
        let path = CGMutablePath()
        let steps = a.vertices.count
        guard steps > 0 else { return path }
        for i in 0..<steps {
            let angle = (Double(i) / Double(steps)) * Double.pi * 2
            let r = a.radius * a.vertices[i]
            let pt = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    // Shaded cratered rock — mini of the photo reference.
    func drawRockyAsteroid(_ a: Asteroid, path: CGPath, _ ctx: CGContext) {
        let R = CGFloat(a.radius)
        let P = AsteroidPalette.palette(for: a.tint)
        ctx.fillLinearGradient(path: path, from: CGPoint(x: -R, y: -R), to: CGPoint(x: R, y: R),
                               stops: [(0, Colors.rgba(P.gradient[0])),
                                       (0.45, Colors.rgba(P.gradient[1])),
                                       (1, Colors.rgba(P.gradient[2]))],
                               shadow: (10, Colors.rgba(P.glow)))

        ctx.saveGState()
        ctx.clip(to: path)
        for crater in a.craters {
            let cx = CGFloat(crater.rx) * R
            let cy = CGFloat(crater.ry) * R
            let cr = CGFloat(crater.r) * R
            ctx.fillCircle(cx, cy, cr, color: P.craterFill)
            // sunlit rim on the lower-right of each crater
            ctx.beginPath()
            ctx.canvasArc(cx, cy, cr, .pi * 0.1, .pi * 0.9)
            ctx.setStroke(P.craterRim)
            ctx.setLineWidth(1.2)
            ctx.strokePath()
        }
        for dot in a.speckles {
            ctx.fillCircle(CGFloat(dot.rx) * R, CGFloat(dot.ry) * R, CGFloat(dot.r) * R + 0.6, color: P.speckle)
        }
        ctx.restoreGState()
    }

    // Chunky cel-shaded rock with angular potholes — mini of the low-poly art.
    func drawFacetedAsteroid(_ a: Asteroid, path: CGPath, _ ctx: CGContext) {
        let R = CGFloat(a.radius)
        let P = AsteroidPalette.palette(for: a.tint)
        ctx.setFill(P.base)
        ctx.fill(path)
        ctx.setStroke(P.outline)
        ctx.stroke(path, lineWidth: 2.5)

        ctx.saveGState()
        ctx.clip(to: path)
        // Two flat facet highlights toward the light
        ctx.setFill(P.facet)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -R, y: -R))
        ctx.addLine(to: CGPoint(x: R * 0.25, y: -R * 0.55))
        ctx.addLine(to: CGPoint(x: -R * 0.3, y: R * 0.15))
        ctx.closePath()
        ctx.fillPath()
        ctx.setFill(P.facetSoft)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: R * 0.1, y: -R))
        ctx.addLine(to: CGPoint(x: R * 0.8, y: -R * 0.3))
        ctx.addLine(to: CGPoint(x: R * 0.25, y: -R * 0.1))
        ctx.closePath()
        ctx.fillPath()

        // Angular hexagon potholes
        ctx.setFill(P.hole)
        for crater in a.craters {
            let cx = CGFloat(crater.rx) * R
            let cy = CGFloat(crater.ry) * R
            let cr = CGFloat(crater.r) * R * 1.2
            ctx.beginPath()
            for i in 0..<6 {
                let ha = CGFloat(crater.rot) + (CGFloat(i) / 6) * .pi * 2
                let pt = CGPoint(x: cx + cos(ha) * cr, y: cy + sin(ha) * cr)
                if i == 0 { ctx.move(to: pt) } else { ctx.addLine(to: pt) }
            }
            ctx.closePath()
            ctx.fillPath()
        }
        ctx.restoreGState()
    }

    // Smooth round rock with big rimmed craters — mini of the round cartoon art.
    func drawBlobbyAsteroid(_ a: Asteroid, path: CGPath, _ ctx: CGContext) {
        let R = CGFloat(a.radius)
        let P = AsteroidPalette.palette(for: a.tint)
        ctx.setFill(P.blobBase)
        ctx.canvasShadow(blur: 8, color: P.glow)
        ctx.fill(path)
        ctx.clearShadow()
        ctx.setStroke(P.blobOutline)
        ctx.stroke(path, lineWidth: 1.5)

        ctx.saveGState()
        ctx.clip(to: path)
        // Lit side
        ctx.fillCircle(-R * 0.35, -R * 0.35, R * 1.05, color: P.lit)

        // Big organic craters with light rims
        for crater in a.craters {
            let cx = CGFloat(crater.rx) * R
            let cy = CGFloat(crater.ry) * R
            let cr = CGFloat(crater.r) * R
            ctx.ellipsePath(cx, cy, cr * 1.35, cr * 0.95, rotation: CGFloat(crater.rot))
            ctx.setFill(P.blobCrater)
            ctx.fillPath()
            ctx.ellipsePath(cx, cy, cr * 1.35, cr * 0.95, rotation: CGFloat(crater.rot))
            ctx.setStroke(P.blobRim)
            ctx.setLineWidth(1.5)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// Body in local unrotated coordinates.
    func drawAsteroidBody(_ a: Asteroid, _ ctx: CGContext) {
        let path = Renderer.asteroidPath(a)
        switch a.style {
        case .faceted: drawFacetedAsteroid(a, path: path, ctx)
        case .blobby: drawBlobbyAsteroid(a, path: path, ctx)
        case .rocky: drawRockyAsteroid(a, path: path, ctx)
        }
    }

    func drawAsteroids(_ f: RenderFrame, _ ctx: CGContext) {
        for a in f.state.asteroids {
            let x = CGFloat(a.x), y = CGFloat(a.y), rot = CGFloat(a.rotation)
            if Renderer.useSpriteCache {
                let maxV = CGFloat(a.vertices.max() ?? 1)
                let half = CGFloat(a.radius) * maxV + 2.5 + spritePad(blur: 10)
                let sprite = sprites.sprite(key: "a:\(a.id)", tick: f.tickCount, halfExtent: half) { sc in
                    drawAsteroidBody(a, sc)
                }
                if let sprite { ctx.drawSprite(sprite, at: x, y, rotation: rot) }
            } else {
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: rot)
                drawAsteroidBody(a, ctx)
                ctx.restoreGState()
            }
        }
    }
}
