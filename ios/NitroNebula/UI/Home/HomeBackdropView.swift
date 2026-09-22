import SwiftUI
import NitroEngine

/// The layered space scene behind the menu (index.php:147-198, styles.css
/// 514-1055): breathing nebula clouds, an aurora sweep, a spiral galaxy, a
/// banded gas giant with an orbiting moon, a ringed planet, the star canvas
/// and a vignette. Layers slide against the parallax offset for depth.
struct HomeBackdropView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let parallax: CGPoint
    let metrics: HomeMetrics
    @State private var scene = BackdropScene()

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let motion = !reduceMotion
            ZStack {
                NebulaClouds(motion: motion)
                    .offset(x: -8 * parallax.x, y: -6 * parallax.y)
                AuroraBand(motion: motion)
                if !metrics.midWidth {
                    GalaxyView(motion: motion)
                        .frame(width: 384, height: 384)
                        .position(x: w * 0.14 + 192, y: h * 0.04 + 192)
                        .offset(x: -10 * parallax.x, y: -8 * parallax.y)
                }
                let giantSize: CGFloat = metrics.midWidth ? 160 : 272
                GasGiantView(motion: motion)
                    .frame(width: giantSize, height: giantSize)
                    .opacity(metrics.midWidth ? 0.5 : 0.72)
                    .position(x: w - (metrics.midWidth ? -w * 0.03 : w * 0.05) - giantSize / 2,
                              y: (metrics.midWidth ? h * 0.03 : h * 0.06) + giantSize / 2)
                    .offset(x: -34 * parallax.x, y: -24 * parallax.y)
                if !metrics.midWidth {
                    RingedPlanetView(motion: motion)
                        .frame(width: 208, height: 192)
                        .opacity(0.7)
                        .position(x: w * 0.06 + 104, y: h - h * 0.08 - 96)
                        .offset(x: -26 * parallax.x, y: -18 * parallax.y)
                }
                TimelineView(.animation(paused: app.anyModalOpen || !motion)) { timeline in
                    let t = timeline.date.timeIntervalSince(scene.epoch)
                    Canvas { ctx, size in
                        if motion { scene.advance(to: t, width: size.width) }
                        scene.draw(in: &ctx, size: size, time: t, skin: GearCatalog.skin(id: app.loadout1.skin), motion: motion)
                    }
                }
                .offset(x: -14 * parallax.x, y: -10 * parallax.y)
                // Vignette pulls the eye toward the panel
                RadialGradient(colors: [.clear, .clear, NeonColors.slate950.opacity(0.55)],
                               center: .center, startRadius: 0, endRadius: max(w, h) * 0.75)
            }
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// `.menu-nebula` `.mn-1…5`: five soft clouds that drift and swell over
/// 26-40s. Radial gradients stand in for the CSS blur.
private struct NebulaClouds: View {
    let motion: Bool
    @State private var drift = false

    private struct Cloud { let color: String; let size: CGFloat; let x, y: CGFloat; let opacity: Double; let period: Double }
    private let clouds: [Cloud] = [
        Cloud(color: "#0e7490", size: 0.45, x: -0.10, y: -0.15, opacity: 0.5, period: 26),
        Cloud(color: "#6d28d9", size: 0.40, x: 0.70, y: 0.80, opacity: 0.5, period: 34),
        Cloud(color: "#be185d", size: 0.30, x: 0.55, y: 0.40, opacity: 0.4, period: 40),
        Cloud(color: "#b45309", size: 0.36, x: 0.72, y: -0.12, opacity: 0.28, period: 38),
        Cloud(color: "#0d9488", size: 0.28, x: 0.18, y: 0.80, opacity: 0.32, period: 30)
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                ForEach(Array(clouds.enumerated()), id: \.offset) { i, c in
                    let d = w * c.size
                    Circle()
                        .fill(RadialGradient(colors: [Color(css: c.color), Color(css: c.color).opacity(0.5), .clear],
                                             center: .center, startRadius: 0, endRadius: d / 2))
                        .frame(width: d, height: d)
                        .opacity(c.opacity)
                        .scaleEffect(drift ? 1.15 : 1)
                        .offset(x: c.x * w + (drift ? 0.06 * w : 0), y: c.y * h - (drift ? 0.04 * h : 0))
                        .animation(motion ? .easeInOut(duration: c.period).repeatForever(autoreverses: true) : nil, value: drift)
                        .accessibilityHidden(true)
                        .id(i)
                }
            }
            .blendMode(.screen)
        }
        .onAppear { if motion { drift = true } }
    }
}

/// `.menu-aurora`: a wide translucent gradient band that sweeps side to side.
private struct AuroraBand: View {
    let motion: Bool
    @State private var sweep = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(css: "#2dd4bf").opacity(0.4), location: 0.18),
                .init(color: Color(css: "#a855f7").opacity(0.34), location: 0.42),
                .init(color: Color(css: "#f472b6").opacity(0.28), location: 0.64),
                .init(color: Color(css: "#22d3ee").opacity(0.24), location: 0.80),
                .init(color: .clear, location: 0.95)
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: w * 1.4, height: h * 0.65)
            .rotationEffect(.degrees(sweep ? 4 : -6))
            .blur(radius: 40)
            .opacity(sweep ? 0.45 : 0.4)
            .position(x: w * 0.5 + (sweep ? 0.07 : -0.07) * w, y: -h * 0.35 + h * 0.325)
            .blendMode(.screen)
            .animation(motion ? .easeInOut(duration: 26).repeatForever(autoreverses: true) : nil, value: sweep)
        }
        .onAppear { if motion { sweep = true } }
    }
}

/// `.menu-galaxy`: a faint conic spiral with a bright core, turning once
/// every 140 seconds.
private struct GalaxyView: View {
    let motion: Bool
    @State private var spin = false

    var body: some View {
        ZStack {
            AngularGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(css: "#a5b4fc").opacity(0.5), location: 0.12),
                .init(color: .clear, location: 0.26),
                .init(color: .clear, location: 0.48),
                .init(color: Color(css: "#67e8f9").opacity(0.45), location: 0.60),
                .init(color: .clear, location: 0.76),
                .init(color: Color(css: "#f472b6").opacity(0.3), location: 0.88),
                .init(color: .clear, location: 1)
            ], center: .center)
            .blur(radius: 12)
            .mask(RadialGradient(stops: [.init(color: .black, location: 0.2), .init(color: .black.opacity(0.5), location: 0.42),
                                         .init(color: .clear, location: 0.66)], center: .center, startRadius: 0, endRadius: 192))
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(motion ? .linear(duration: 140).repeatForever(autoreverses: false) : nil, value: spin)
            RadialGradient(colors: [.white, Color(css: "#c7d2fe").opacity(0.7), .clear], center: .center, startRadius: 0, endRadius: 45)
                .frame(width: 122, height: 122)
        }
        .opacity(0.5)
        .onAppear { if motion { spin = true } }
    }
}

/// `.menu-giant` (index.php:158-180): the banded gas giant and its moon.
private struct GasGiantView: View {
    let motion: Bool
    @State private var float = false

    var body: some View {
        TimelineView(.animation(paused: !motion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let theta = motion ? (t / 26).truncatingRemainder(dividingBy: 1) * 2 * Double.pi : 0
            GeometryReader { geo in
                let s = geo.size.width / 200
                let orbitR = geo.size.width * 0.62
                let moon = CGPoint(x: geo.size.width / 2 + orbitR * CGFloat(cos(theta - .pi / 2)),
                                   y: geo.size.height / 2 + orbitR * 0.375 * CGFloat(sin(theta - .pi / 2)))
                let moonBehind = sin(theta - .pi / 2) < 0
                ZStack {
                    if moonBehind { Moon().position(moon) }
                    Canvas { ctx, size in
                        let t = CGAffineTransform(scaleX: s, y: s)
                        let disc = Path(ellipseIn: CGRect(x: 14, y: 14, width: 172, height: 172)).applying(t)
                        ctx.fill(disc, with: .radialGradient(
                            Gradient(stops: [.init(color: Color(css: "#fde68a"), location: 0), .init(color: Color(css: "#f59e0b"), location: 0.45),
                                             .init(color: Color(css: "#9a3412"), location: 0.8), .init(color: Color(css: "#431407"), location: 1)]),
                            center: CGPoint(x: 64 * s, y: 56 * s), startRadius: 0, endRadius: 160 * s))
                        var bands = ctx
                        bands.clip(to: disc)
                        func band(_ y0: CGFloat, _ c0: CGFloat, _ y1: CGFloat, _ c1: CGFloat, _ color: Color) {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y0))
                            p.addQuadCurve(to: CGPoint(x: 200, y: y0), control: CGPoint(x: 100, y: c0))
                            p.addLine(to: CGPoint(x: 200, y: y1))
                            p.addQuadCurve(to: CGPoint(x: 0, y: y1), control: CGPoint(x: 100, y: c1))
                            p.closeSubpath()
                            bands.fill(p.applying(t), with: .color(color))
                        }
                        band(52, 40, 62, 74, .white.opacity(0.14))
                        band(84, 96, 98, 110, Color(css: "#431407").opacity(0.35))
                        band(120, 108, 126, 138, .white.opacity(0.1))
                        band(146, 158, 160, 172, Color(css: "#431407").opacity(0.4))
                        bands.fill(Path(ellipseIn: CGRect(x: 110, y: 103, width: 36, height: 18)).applying(t),
                                   with: .color(Color(css: "#fecaca").opacity(0.45)))
                        ctx.stroke(disc, with: .color(.white.opacity(0.12)), lineWidth: 1.5 * s)
                    }
                    if !moonBehind { Moon().position(moon) }
                }
            }
        }
        .shadow(color: Color(css: "#f59e0b").opacity(0.28), radius: 20)
        .offset(y: float ? -18 : 0)
        .rotationEffect(.degrees(float ? 3 : -3))
        .animation(motion ? .easeInOut(duration: 22).repeatForever(autoreverses: true) : nil, value: float)
        .onAppear { if motion { float = true } }
    }

    private struct Moon: View {
        var body: some View {
            Circle()
                .fill(RadialGradient(colors: [Color(css: "#f8fafc"), Color(css: "#94a3b8"), Color(css: "#334155")],
                                     center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: 10))
                .frame(width: 17.6, height: 17.6)
                .shadow(color: Color(css: "#e2e8f0").opacity(0.5), radius: 5)
        }
    }
}

/// `.menu-planet` (index.php:181-196): the distant ringed planet.
private struct RingedPlanetView: View {
    let motion: Bool
    @State private var float = false

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 130
            let t = CGAffineTransform(scaleX: s, y: s)
            let disc = Path(ellipseIn: CGRect(x: 32, y: 27, width: 66, height: 66)).applying(t)
            ctx.fill(disc, with: .radialGradient(
                Gradient(stops: [.init(color: Color(css: "#a5b4fc"), location: 0), .init(color: Color(css: "#6366f1"), location: 0.55),
                                 .init(color: Color(css: "#312e81"), location: 1)]),
                center: CGPoint(x: 55 * s, y: 46 * s), startRadius: 0, endRadius: 56 * s))
            var arc1 = Path(); arc1.move(to: CGPoint(x: 34, y: 50)); arc1.addQuadCurve(to: CGPoint(x: 96, y: 50), control: CGPoint(x: 65, y: 40))
            ctx.stroke(arc1.applying(t), with: .color(.white.opacity(0.16)), lineWidth: 4 * s)
            var arc2 = Path(); arc2.move(to: CGPoint(x: 33, y: 66)); arc2.addQuadCurve(to: CGPoint(x: 97, y: 66), control: CGPoint(x: 65, y: 76))
            ctx.stroke(arc2.applying(t), with: .color(NeonColors.slate950.opacity(0.25)), lineWidth: 5 * s)
            let tilt = CGAffineTransform(translationX: 65, y: 63).rotated(by: -16 * .pi / 180).translatedBy(x: -65, y: -63)
            let ring1 = Path(ellipseIn: CGRect(x: 8, y: 50, width: 114, height: 26)).applying(tilt).applying(t)
            ctx.stroke(ring1, with: .color(NeonColors.cyan400.opacity(0.45)), lineWidth: 2.5 * s)
            let ring2 = Path(ellipseIn: CGRect(x: 17, y: 53, width: 96, height: 20)).applying(tilt).applying(t)
            ctx.stroke(ring2, with: .color(Color(css: "#a5f3fc").opacity(0.3)), lineWidth: 1 * s)
        }
        .shadow(color: NeonColors.indigo400.opacity(0.35), radius: 11)
        .offset(y: float ? -14 : 0)
        .rotationEffect(.degrees(float ? 2 : -2))
        .animation(motion ? .easeInOut(duration: 16).repeatForever(autoreverses: true) : nil, value: float)
        .onAppear { if motion { float = true } }
    }
}
