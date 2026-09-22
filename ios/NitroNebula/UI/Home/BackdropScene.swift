import SwiftUI
import NeonEngine

/// The moving parts of the start-screen backdrop (buildStartStars, ui.js
/// L1014-1134): 110 twinkling stars, 7 flares, 8 drifting treats and rocks,
/// 16 dust motes, and the transient shooting stars, comets and rocket
/// flybys. Positions are fractions of the screen; a Canvas draws it all.
@MainActor
final class BackdropScene {
    struct Star { let x, y, size: Double; let color: Color; let delay, duration: Double }
    struct Flare { let x, y, size, delay, duration: Double }
    enum DrifterKind { case donut, blueRock, grayRock }
    struct Drifter { let kind: DrifterKind; let size, x, y, duration: Double }
    struct Dust { let x, duration, delay, opacity: Double }
    struct ShootingStar { let start: TimeInterval; let x, y, angle, dx, dy: Double }
    struct Comet { let start: TimeInterval; let fromLeft: Bool; let top, angle, dx, dy, duration: Double }
    struct Flyby { let start: TimeInterval; let y, duration: Double }

    let stars: [Star]
    let flares: [Flare]
    let drifters: [Drifter]
    let dust: [Dust]
    private(set) var shootingStars: [ShootingStar] = []
    private(set) var comets: [Comet] = []
    private(set) var flybys: [Flyby] = []

    private var lastShoot: TimeInterval = 0
    private var lastComet: TimeInterval = 0
    private var lastFly: TimeInterval = 0
    let epoch = Date()

    init() {
        let palette = ["#ffffff", "#ffffff", "#a5f3fc", "#c7d2fe", "#fde68a"].map { Color(css: $0) }
        stars = (0..<110).map { _ in
            Star(x: .random(in: 0..<1), y: .random(in: 0..<1), size: 1 + .random(in: 0..<1.8),
                 color: palette.randomElement() ?? .white, delay: .random(in: 0..<4), duration: 2.2 + .random(in: 0..<3))
        }
        flares = (0..<7).map { _ in
            Flare(x: .random(in: 0..<1), y: .random(in: 0..<1), size: 14 + .random(in: 0..<16),
                  delay: .random(in: 0..<6), duration: 4 + .random(in: 0..<4))
        }
        drifters = [
            Drifter(kind: .donut, size: 32, x: 0.10, y: 0.16, duration: 26),
            Drifter(kind: .grayRock, size: 46, x: 0.07, y: 0.72, duration: 36),
            Drifter(kind: .blueRock, size: 30, x: 0.87, y: 0.26, duration: 30),
            Drifter(kind: .donut, size: 22, x: 0.86, y: 0.80, duration: 22),
            Drifter(kind: .grayRock, size: 26, x: 0.30, y: 0.08, duration: 40),
            Drifter(kind: .blueRock, size: 18, x: 0.22, y: 0.58, duration: 28),
            Drifter(kind: .grayRock, size: 34, x: 0.93, y: 0.40, duration: 44),
            Drifter(kind: .blueRock, size: 14, x: 0.45, y: 0.90, duration: 24)
        ]
        dust = (0..<16).map { _ in
            Dust(x: .random(in: 0..<1), duration: 45 + .random(in: 0..<45), delay: -.random(in: 0..<60),
                 opacity: 0.25 + .random(in: 0..<0.4))
        }
    }

    /// Spawns the periodic transients and forgets finished ones
    /// (setInterval 2.8s / 21s / 17s in ui.js).
    func advance(to t: TimeInterval, width: Double) {
        if lastShoot == 0 { lastShoot = t; lastComet = t; lastFly = t }
        if t - lastShoot >= 2.8 {
            lastShoot = t
            let angle = 15 + Double.random(in: 0..<30)
            let dir: Double = Bool.random() ? 1 : -1
            let dist = 260 + Double.random(in: 0..<220)
            let rad = angle * .pi / 180
            shootingStars.append(ShootingStar(start: t, x: 0.10 + .random(in: 0..<0.70), y: 0.05 + .random(in: 0..<0.45),
                                              angle: dir == 1 ? angle : 180 - angle,
                                              dx: cos(rad) * dist * dir, dy: sin(rad) * dist))
        }
        if t - lastComet >= 21 {
            lastComet = t
            let fromLeft = Bool.random()
            let angle = 18 + Double.random(in: 0..<20)
            let rad = angle * .pi / 180
            let dist = width * 1.3
            comets.append(Comet(start: t, fromLeft: fromLeft, top: .random(in: 0..<0.30),
                                angle: fromLeft ? angle : 180 - angle,
                                dx: cos(rad) * dist * (fromLeft ? 1 : -1), dy: sin(rad) * dist,
                                duration: 6 + .random(in: 0..<3)))
        }
        if t - lastFly >= 17 {
            lastFly = t
            flybys.append(Flyby(start: t, y: 0.12 + .random(in: 0..<0.65), duration: 5 + .random(in: 0..<3)))
        }
        shootingStars.removeAll { t - $0.start > 1.4 }
        comets.removeAll { t - $0.start > $0.duration + 0.5 }
        flybys.removeAll { t - $0.start > $0.duration + 0.5 }
    }

    // MARK: Drawing

    /// One frame. `motion == false` freezes the sky (Reduce Motion).
    func draw(in ctx: inout GraphicsContext, size: CGSize, time t: TimeInterval, skin: Skin, motion: Bool) {
        let w = size.width, h = size.height
        // Twinkling stars (star-twinkle: opacity .15→.9, scale .8→1.15)
        for s in stars {
            let v = motion ? wave(t, delay: s.delay, duration: s.duration) : 0.55
            let opacity = 0.15 + 0.75 * v
            let r = s.size * (0.8 + 0.35 * v) / 2
            let rect = CGRect(x: s.x * w - r, y: s.y * h - r, width: 2 * r, height: 2 * r)
            ctx.fill(Path(ellipseIn: rect), with: .color(s.color.opacity(opacity)))
        }
        // Four-point flares (flare-twinkle: opacity .25→1, scale .7→1.15, rotate 0→20deg)
        for f in flares {
            let v = motion ? wave(t, delay: f.delay, duration: f.duration) : 0.6
            let opacity = 0.25 + 0.75 * v
            let scale = 0.7 + 0.45 * v
            let center = CGPoint(x: f.x * w, y: f.y * h)
            var local = ctx
            local.translateBy(x: center.x, y: center.y)
            local.rotate(by: .degrees(20 * v))
            local.scaleBy(x: scale, y: scale)
            let half = f.size / 2
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.45),
                                 .init(color: .white, location: 0.55), .init(color: .clear, location: 1)]),
                startPoint: CGPoint(x: -half, y: 0), endPoint: CGPoint(x: half, y: 0))
            var hLine = Path(); hLine.move(to: CGPoint(x: -half, y: 0)); hLine.addLine(to: CGPoint(x: half, y: 0))
            local.opacity = opacity
            local.stroke(hLine, with: shading, lineWidth: 1.5)
            local.rotate(by: .degrees(90))
            local.stroke(hLine, with: shading, lineWidth: 1.5)
        }
        // Drifting treats and rocks (drift: translate 55,-38 rotate 55deg, alternate)
        for d in drifters {
            let v = motion ? alternate(t, duration: d.duration) : 0.5
            let origin = CGPoint(x: d.x * w + 55 * v, y: d.y * h - 38 * v)
            var local = ctx
            local.translateBy(x: origin.x + d.size / 2, y: origin.y + d.size / 2)
            local.rotate(by: .degrees(55 * v))
            local.opacity = 0.45
            let rect = CGRect(x: -d.size / 2, y: -d.size / 2, width: d.size, height: d.size)
            BackdropSprites.draw(d.kind, in: &local, rect: rect)
        }
        // Sinking stardust (dust-fall: top -2vh → +108vh, linear)
        for m in dust {
            let phase = motion ? (((t - m.delay) / m.duration).truncatingRemainder(dividingBy: 1)) : 0.5
            let y = -0.02 * h + phase * 1.10 * h
            ctx.fill(Path(ellipseIn: CGRect(x: m.x * w - 1, y: y - 1, width: 2, height: 2)),
                     with: .color(Color(css: "#94a3b8").opacity(0.45 * m.opacity)))
        }
        guard motion else { return }
        // Shooting stars (shoot: 1.2s ease-out, 90x2 gradient streak)
        for s in shootingStars {
            let p = min(1, (t - s.start) / 1.2)
            let e = 1 - pow(1 - p, 3)
            var local = ctx
            local.translateBy(x: s.x * w + s.dx * e, y: s.y * h + s.dy * e)
            local.rotate(by: .degrees(s.angle))
            local.opacity = 1 - e
            var line = Path(); line.move(to: .zero); line.addLine(to: CGPoint(x: 90, y: 0))
            local.stroke(line, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.9), Color(css: "#a5f3fc").opacity(0.4), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: 90, y: 0)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        // Comets (comet-fly: ease-in, opacity 0→1→1→0, 260x3 tail + 13px head)
        for c in comets {
            let p = min(1, (t - c.start) / c.duration)
            let e = p * p
            let opacity = p < 0.1 ? p / 0.1 : (p > 0.9 ? (1 - p) / 0.1 : 1)
            let startX = c.fromLeft ? -260.0 : w + 260
            var local = ctx
            local.translateBy(x: startX + c.dx * e, y: c.top * h + c.dy * e)
            local.rotate(by: .degrees(c.angle))
            local.opacity = opacity
            var tail = Path(); tail.move(to: .zero); tail.addLine(to: CGPoint(x: 260, y: 0))
            local.stroke(tail, with: .linearGradient(
                Gradient(stops: [.init(color: .clear, location: 0), .init(color: Color(css: "#818cf8").opacity(0.3), location: 0.4),
                                 .init(color: Color(css: "#a5f3fc").opacity(0.8), location: 0.85), .init(color: .white, location: 1)]),
                startPoint: .zero, endPoint: CGPoint(x: 260, y: 0)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            local.fill(Path(ellipseIn: CGRect(x: 260 - 6.5, y: -6.5, width: 13, height: 13)),
                       with: .radialGradient(Gradient(colors: [.white, Color(css: "#a5f3fc").opacity(0.7), .clear]),
                                             center: CGPoint(x: 260, y: 0), startRadius: 0, endRadius: 6.5))
        }
        // The equipped rocket cruising across (flyby: -70 → 100vw+70, rotated 90deg)
        for f in flybys {
            let p = min(1, (t - f.start) / f.duration)
            let x = -70 + (w + 140) * p
            var local = ctx
            local.translateBy(x: x, y: f.y * h)
            local.rotate(by: .degrees(90))
            GearArt.drawSkin(skin, in: &local, rect: CGRect(x: -23, y: -37, width: 46, height: 74))
        }
    }

    /// 0→1→0 ease-in-out over one period (CSS `infinite` keyframes at 0/50/100%).
    private func wave(_ t: TimeInterval, delay: Double, duration: Double) -> Double {
        let phase = ((t - delay) / duration).truncatingRemainder(dividingBy: 1)
        let p = phase < 0 ? phase + 1 : phase
        return 0.5 - 0.5 * cos(2 * .pi * p)
    }

    /// 0→1 then back, ease-in-out (`alternate` keyframes).
    private func alternate(_ t: TimeInterval, duration: Double) -> Double {
        let phase = (t / (2 * duration)).truncatingRemainder(dividingBy: 1)
        let p = phase < 0.5 ? phase * 2 : 2 - phase * 2
        return 0.5 - 0.5 * cos(.pi * p)
    }
}

/// The donut and rock sprites (ui.js:1043-1051) in a 40x40 box.
enum BackdropSprites {
    static func draw(_ kind: BackdropScene.DrifterKind, in ctx: inout GraphicsContext, rect: CGRect) {
        let s = rect.width / 40
        let t = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: s, y: s)
        func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
            var p = Path()
            for (i, pt) in pts.enumerated() {
                let point = CGPoint(x: pt.0, y: pt.1)
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()
            return p.applying(t)
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)).applying(t)
        }
        switch kind {
        case .donut:
            ctx.fill(circle(20, 20, 16), with: .color(Color(css: "#d9a066")))
            ctx.fill(circle(20, 20, 14), with: .color(Color(css: "#f472b6")))
            ctx.fill(circle(20, 20, 6), with: .color(Color(css: "#0b0716")))
            ctx.fill(circle(13, 14, 1.5), with: .color(Color(css: "#fef08a")))
            ctx.fill(circle(27, 15, 1.5), with: .color(Color(css: "#86efac")))
            ctx.fill(circle(25, 26, 1.5), with: .color(Color(css: "#93c5fd")))
            ctx.fill(circle(14, 25, 1.5), with: .color(Color(css: "#fca5a5")))
        case .blueRock:
            let body = poly([(8, 14), (20, 4), (34, 12), (36, 26), (24, 37), (9, 32)])
            ctx.fill(body, with: .color(Color(css: "#2563eb")))
            ctx.stroke(body, with: .color(Color(css: "#1e3a8a")), lineWidth: 2 * s)
            ctx.fill(poly([(14, 18), (20, 14), (26, 19), (23, 25), (15, 24)]), with: .color(Color(css: "#172554")))
        case .grayRock:
            let body = poly([(6, 16), (16, 5), (31, 8), (36, 22), (27, 35), (10, 33)])
            ctx.fill(body, with: .color(Color(css: "#94a3b8")))
            ctx.stroke(body, with: .color(Color(css: "#475569")), lineWidth: 2 * s)
            ctx.fill(circle(18, 18, 4), with: .color(Color(css: "#334155").opacity(0.7)))
            ctx.fill(circle(27, 26, 3), with: .color(Color(css: "#334155").opacity(0.7)))
        }
    }
}
