import SwiftUI
import NeonEngine

/// The Tailor card art (ui.js skinSvg/trailSvg/flameSvg, L1650-1732),
/// drawn into a GraphicsContext in the SVGs' 40x64 space so the same code
/// serves the cards, the loadout chips, the home rocket and the flybys.
enum GearArt {
    static let box = CGSize(width: 40, height: 64)

    /// Maps the 40x64 art box into `rect` (aspect fit, centred).
    static func transform(fitting rect: CGRect) -> CGAffineTransform {
        let scale = min(rect.width / box.width, rect.height / box.height)
        let w = box.width * scale, h = box.height * scale
        let dx = rect.minX + (rect.width - w) / 2
        let dy = rect.minY + (rect.height - h) / 2
        return CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
    }

    // MARK: Paths shared by the three previews

    static let nozzle: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 13, y: 4)); p.addLine(to: CGPoint(x: 27, y: 4))
        p.addLine(to: CGPoint(x: 29, y: 10)); p.addLine(to: CGPoint(x: 11, y: 10)); p.closeSubpath()
        return p
    }()

    private static func polygon(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        for (i, pt) in pts.enumerated() {
            if i == 0 { p.move(to: CGPoint(x: pt.0, y: pt.1)) } else { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        }
        p.closeSubpath()
        return p
    }

    private static func color(_ css: CSSColor) -> Color { Color(css) }

    // MARK: skinSvg (ui.js:1712-1732)

    static func drawSkin(_ skin: Skin, in ctx: inout GraphicsContext, rect: CGRect) {
        let t = transform(fitting: rect)
        let hull = skin.hull ?? ["#94a3b8", "#f1f5f9", "#e2e8f0", "#64748b"]
        let win = (skin.window ?? ["#e0f2fe", "#67e8f9", "#0e7490"])[1]
        let gradStops: [CSSColor]? = skin.accentGradient ?? (skin.animated ? ["#f472b6", "#a855f7", "#22d3ee"] : nil)

        func accentShading() -> GraphicsContext.Shading {
            if let stops = gradStops {
                return .linearGradient(Gradient(colors: stops.map(color)),
                                       startPoint: CGPoint(x: 0, y: 0).applying(t),
                                       endPoint: CGPoint(x: 0, y: 64).applying(t))
            }
            return .color(color(skin.accent))
        }

        // Fins
        ctx.fill(polygon([(12, 34), (3, 52), (13, 48)]).applying(t), with: accentShading())
        ctx.fill(polygon([(28, 34), (37, 52), (27, 48)]).applying(t), with: accentShading())
        // Body
        var body = Path()
        body.move(to: CGPoint(x: 12, y: 48)); body.addLine(to: CGPoint(x: 12, y: 22))
        body.addQuadCurve(to: CGPoint(x: 20, y: 4), control: CGPoint(x: 12, y: 6))
        body.addQuadCurve(to: CGPoint(x: 28, y: 22), control: CGPoint(x: 28, y: 6))
        body.addLine(to: CGPoint(x: 28, y: 48)); body.closeSubpath()
        let bodyT = body.applying(t)
        ctx.fill(bodyT, with: .color(color(hull[1])))
        ctx.stroke(bodyT, with: .color(.white), lineWidth: 0.8 * t.a)
        // Nose
        var nose = Path()
        nose.move(to: CGPoint(x: 12.5, y: 18))
        nose.addQuadCurve(to: CGPoint(x: 20, y: 4), control: CGPoint(x: 13, y: 7))
        nose.addQuadCurve(to: CGPoint(x: 27.5, y: 18), control: CGPoint(x: 27, y: 7))
        nose.addQuadCurve(to: CGPoint(x: 12.5, y: 18), control: CGPoint(x: 20, y: 13))
        nose.closeSubpath()
        ctx.fill(nose.applying(t), with: accentShading())
        // Stripe
        ctx.fill(Path(CGRect(x: 12, y: 38, width: 16, height: 3.5)).applying(t), with: accentShading())
        // Window
        let window = Path(ellipseIn: CGRect(x: 20 - 4.6, y: 26 - 4.6, width: 9.2, height: 9.2)).applying(t)
        ctx.fill(window, with: .color(color(win)))
        ctx.stroke(window, with: .color(Color(css: "#cbd5e1")), lineWidth: 1.6 * t.a)
        // Engine + flame
        ctx.fill(polygon([(14, 48), (26, 48), (28, 53), (12, 53)]).applying(t), with: .color(Color(css: "#475569")))
        var flame = Path()
        flame.move(to: CGPoint(x: 16, y: 54))
        flame.addQuadCurve(to: CGPoint(x: 24, y: 54), control: CGPoint(x: 20, y: 63))
        flame.addQuadCurve(to: CGPoint(x: 16, y: 54), control: CGPoint(x: 20, y: 57))
        flame.closeSubpath()
        ctx.fill(flame.applying(t), with: .color(Color(css: "#fb923c")))
    }

    // MARK: trailSvg (ui.js:1692-1710)

    static func drawTrail(_ trail: Trail, in ctx: inout GraphicsContext, rect: CGRect) {
        let t = transform(fitting: rect)
        ctx.fill(nozzle.applying(t), with: .color(Color(css: "#475569")))
        let ys: [CGFloat] = [16, 26, 36, 46, 56]
        let n = trail.colors.count
        for (i, y) in ys.enumerated() {
            let r = 4.5 - CGFloat(i) * 0.6
            let cx: CGFloat = 20 + (i % 2 == 1 ? 2.5 : -2.5)
            let dot = Path(ellipseIn: CGRect(x: cx - r, y: y - r, width: 2 * r, height: 2 * r)).applying(t)
            ctx.fill(dot, with: .color(color(trail.colors[i % n]).opacity(1 - Double(i) * 0.14)))
            if trail.count > 1 {
                let r2 = r * 0.6
                let cx2: CGFloat = 20 + (i % 2 == 1 ? -4 : 4)
                let dot2 = Path(ellipseIn: CGRect(x: cx2 - r2, y: y + 4 - r2, width: 2 * r2, height: 2 * r2)).applying(t)
                ctx.fill(dot2, with: .color(color(trail.colors[(i + 1) % n]).opacity(0.8 - Double(i) * 0.13)))
            }
        }
    }

    // MARK: flameSvg (ui.js:1650-1689)

    static func drawFlame(_ flame: Flame, in ctx: inout GraphicsContext, rect: CGRect) {
        let t = transform(fitting: rect)
        ctx.fill(nozzle.applying(t), with: .color(Color(css: "#475569")))
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)).applying(t)
        }
        switch flame.style {
        case .rings:
            let rc = flame.ringColors ?? ["#fb923c", "#fbbf24", "#fde68a"]
            ctx.stroke(circle(20, 22, 9), with: .color(color(rc[0])), lineWidth: 3 * t.a)
            ctx.stroke(circle(20, 40, 6.5), with: .color(color(rc[1 % rc.count]).opacity(0.75)), lineWidth: 2.5 * t.a)
            ctx.stroke(circle(20, 54, 4), with: .color(color(rc[2 % rc.count]).opacity(0.5)), lineWidth: 2 * t.a)
        case .smoke:
            let sc = flame.smokeColors ?? ["#94a3b8", "#cbd5e1", "#e2e8f0"]
            ctx.fill(circle(20, 20, 9), with: .color(color(sc[0]).opacity(0.9)))
            ctx.fill(circle(14, 36, 7), with: .color(color(sc[1]).opacity(0.65)))
            ctx.fill(circle(26, 50, 5.5), with: .color(color(sc[2]).opacity(0.45)))
        case .stars:
            let stc = color(flame.starColor ?? "#fde047")
            func star(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ o: Double) {
                var p = Path()
                p.move(to: CGPoint(x: x - r, y: y)); p.addLine(to: CGPoint(x: x + r, y: y))
                p.move(to: CGPoint(x: x, y: y - r)); p.addLine(to: CGPoint(x: x, y: y + r))
                ctx.stroke(p.applying(t), with: .color(stc.opacity(o)),
                           style: StrokeStyle(lineWidth: 2.5 * t.a, lineCap: .round))
            }
            star(20, 20, 8, 1); star(14, 38, 6, 0.7); star(26, 52, 4.5, 0.5)
        case .classic, .blue, .jet:
            let cols: [CSSColor]
            if flame.animatedPal {
                cols = ["#f472b6", "#a855f7", "#22d3ee"] // rainbow snapshot for the card
            } else if let pal = flame.pal {
                cols = pal
            } else if flame.style == .blue {
                cols = ["#2563eb", "#60a5fa", "#e0f2fe"]
            } else if flame.style == .jet {
                cols = ["#22d3ee", "#a5f3fc", "#ffffff"]
            } else {
                cols = ["#f97316", "#fbbf24", "#fef9c3"]
            }
            let w: CGFloat = flame.style == .jet ? 6 : 11
            let len: CGFloat = flame.style == .jet ? 60 : 50
            func tongue(_ hw: CGFloat, _ l: CGFloat, _ back: CGFloat) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: 20 - hw, y: 12))
                p.addQuadCurve(to: CGPoint(x: 20 + hw, y: 12), control: CGPoint(x: 20, y: l))
                p.addQuadCurve(to: CGPoint(x: 20 - hw, y: 12), control: CGPoint(x: 20, y: back))
                p.closeSubpath()
                return p.applying(t)
            }
            ctx.fill(tongue(w, len, 22), with: .color(color(cols[0])))
            ctx.fill(tongue(w * 0.62, len * 0.75, 20), with: .color(color(cols[1])))
            ctx.fill(tongue(w * 0.3, len * 0.5, 18), with: .color(color(cols[2])))
        }
    }
}

/// A card-sized preview of one item on any rack.
struct GearPreview: View {
    let tab: TailorTab
    let id: String

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            switch tab {
            case .skins: GearArt.drawSkin(GearCatalog.skin(id: id), in: &ctx, rect: rect)
            case .trails: GearArt.drawTrail(GearCatalog.trail(id: id), in: &ctx, rect: rect)
            case .flames: GearArt.drawFlame(GearCatalog.flame(id: id), in: &ctx, rect: rect)
            }
        }
        .aspectRatio(GearArt.box, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
