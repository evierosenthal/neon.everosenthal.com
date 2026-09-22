import UIKit
import CoreText
import NeonEngine

// A thin Canvas-2D-flavoured layer over CGContext so the ported draw code
// reads like www/game.js. Every context handed to these helpers is in UIKit
// orientation (top-left origin, y down, 1 unit = 1 point), exactly like the
// web canvas at 1 CSS px per canvas px.

// MARK: - Color cache

/// CSS strings are parsed once and remembered; the same literal ('#a855f7',
/// 'rgba(255, 255, 255, 0.85)') is asked for thousands of times per second.
enum Colors {
    private static var rgbaCache: [String: RGBA] = [:]
    private static var cgCache: [String: CGColor] = [:]

    static func rgba(_ css: CSSColor) -> RGBA {
        if let c = rgbaCache[css.css] { return c }
        let c = css.rgba
        rgbaCache[css.css] = c
        return c
    }

    static func rgba(_ css: String) -> RGBA { rgba(CSSColor(css)) }

    static func cg(_ css: CSSColor) -> CGColor {
        if let c = cgCache[css.css] { return c }
        let c = rgba(css).cgColor
        cgCache[css.css] = c
        return c
    }

    static func cg(_ css: String) -> CGColor { cg(CSSColor(css)) }

    static let white = RGBA(r: 1, g: 1, b: 1, a: 1)
}

extension RGBA {
    var cgColor: CGColor {
        CGColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    /// CSS `hsl(h, s%, l%)` built directly (the animated skins/fires build a
    /// new string every frame on the web; here we skip the string).
    init(h: Double, s: Double, l: Double, a: Double = 1) {
        let (r, g, b) = RGBA.hslToRGB(h: h, s: s, l: l)
        self.init(r: r, g: g, b: b, a: a)
    }
}

// MARK: - Fonts

enum Fonts {
    private static var cache: [String: UIFont] = [:]

    /// `'900 14px sans-serif'` → system font, weight black.
    static func sans(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let key = "sans|\(size)|\(weight.rawValue)"
        if let f = cache[key] { return f }
        let f = UIFont.systemFont(ofSize: size, weight: weight)
        cache[key] = f
        return f
    }

    /// `'bold 9px monospace'` → Menlo-Bold 9 (Menlo has no 900/600 cuts, so
    /// every bold-ish weight maps to Bold).
    static func mono(_ size: CGFloat, bold: Bool = false, italic: Bool = false) -> UIFont {
        let name: String
        switch (bold, italic) {
        case (true, true): name = "Menlo-BoldItalic"
        case (true, false): name = "Menlo-Bold"
        case (false, true): name = "Menlo-Italic"
        case (false, false): name = "Menlo-Regular"
        }
        let key = "\(name)|\(size)"
        if let f = cache[key] { return f }
        let f = UIFont(name: name, size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        cache[key] = f
        return f
    }
}

enum TextAlign { case left, center, right }
enum TextBaseline { case top, middle, alphabetic, bottom }

private enum TextLines {
    private struct Key: Hashable { let text: String; let font: String; let size: CGFloat }
    private static var cache: [Key: (line: CTLine, width: CGFloat)] = [:]

    static func line(_ text: String, font: UIFont) -> (line: CTLine, width: CGFloat) {
        let key = Key(text: text, font: font.fontName, size: font.pointSize)
        if let l = cache[key] { return l }
        if cache.count > 512 { cache.removeAll(keepingCapacity: true) }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        cache[key] = (line, width)
        return (line, width)
    }
}

// MARK: - Canvas shim

extension CGContext {

    // Shadows (`ctx.shadowBlur = N; ctx.shadowColor = c`).

    func canvasShadow(blur: CGFloat, color: RGBA) {
        setShadow(offset: .zero, blur: blur * Renderer.glowScale, color: color.cgColor)
    }

    func canvasShadow(blur: CGFloat, color: CSSColor) {
        setShadow(offset: .zero, blur: blur * Renderer.glowScale, color: Colors.cg(color))
    }

    /// `ctx.shadowBlur = 0`.
    func clearShadow() {
        setShadow(offset: .zero, blur: 0, color: nil)
    }

    // Colors.

    func setFill(_ c: RGBA) {
        setFillColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }

    func setFill(_ c: CSSColor) { setFill(Colors.rgba(c)) }
    func setFill(_ css: String) { setFill(Colors.rgba(css)) }

    func setStroke(_ c: RGBA) {
        setStrokeColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }

    func setStroke(_ c: CSSColor) { setStroke(Colors.rgba(c)) }
    func setStroke(_ css: String) { setStroke(Colors.rgba(css)) }

    /// `ctx.globalAlpha = a`.
    func setCanvasAlpha(_ a: CGFloat) { setAlpha(a) }

    // Paths.

    /// `ctx.arc(cx, cy, r, 0, Math.PI * 2)` on a fresh path.
    func circlePath(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        beginPath()
        addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    /// `ctx.arc(cx, cy, r, start, end)` with the canvas default direction
    /// (increasing angle, which is clockwise on screen with y down). CG's
    /// `clockwise: false` walks the angle upwards, so it is the same thing.
    func canvasArc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ start: CGFloat, _ end: CGFloat) {
        addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: start, endAngle: end, clockwise: false)
    }

    /// `ctx.ellipse(cx, cy, rx, ry, rotation, 0, 2π)` on a fresh path.
    func ellipsePath(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, rotation: CGFloat) {
        var t = CGAffineTransform(translationX: cx, y: cy).rotated(by: rotation)
        let p = CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: &t)
        beginPath()
        addPath(p)
    }

    func fillCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        circlePath(cx, cy, r)
        fillPath()
    }

    func fillCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, color: RGBA) {
        setFill(color)
        fillCircle(cx, cy, r)
    }

    func fillCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, color: CSSColor) {
        fillCircle(cx, cy, r, color: Colors.rgba(color))
    }

    func strokeCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, lineWidth: CGFloat, color: RGBA) {
        setStroke(color)
        setLineWidth(lineWidth)
        circlePath(cx, cy, r)
        strokePath()
    }

    func strokeCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, lineWidth: CGFloat, color: CSSColor) {
        strokeCircle(cx, cy, r, lineWidth: lineWidth, color: Colors.rgba(color))
    }

    /// Canvas keeps the path after fill()/stroke(); CG consumes it. These
    /// re-add a stored path so "fill then stroke the same shape" ports 1:1.
    func fill(_ path: CGPath) {
        beginPath()
        addPath(path)
        fillPath()
    }

    func stroke(_ path: CGPath, lineWidth: CGFloat) {
        setLineWidth(lineWidth)
        beginPath()
        addPath(path)
        strokePath()
    }

    func clip(to path: CGPath) {
        beginPath()
        addPath(path)
        clip()
    }

    /// `ctx.roundRect(x, y, w, h, r)`.
    func roundedRectPath(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        let rr = min(r, w / 2, h / 2)
        return CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: rr, cornerHeight: rr, transform: nil)
    }

    // Dashes.

    /// `ctx.setLineDash(segments); ctx.lineDashOffset = offset`. The offset is
    /// wrapped to the pattern length so a large `simMs`-derived phase stays
    /// precise.
    func setCanvasLineDash(_ segments: [CGFloat], offset: CGFloat = 0) {
        let period = segments.reduce(0, +)
        var phase = offset
        if period > 0 {
            phase = offset.truncatingRemainder(dividingBy: period)
            if phase < 0 { phase += period }
        }
        setLineDash(phase: phase, lengths: segments)
    }

    /// `ctx.setLineDash([])`.
    func clearLineDash() {
        setLineDash(phase: 0, lengths: [])
    }

    // Gradients.

    /// Canvas `'transparent'` is rgba(0,0,0,0); blending toward black gives a
    /// dark fringe, so a fully transparent stop borrows its neighbour's RGB
    /// (game.js:1286 is the only place the web relies on this).
    private static func fixTransparentStops(_ stops: [(Double, RGBA)]) -> [(Double, RGBA)] {
        var out = stops
        for i in out.indices where out[i].1.a == 0 && out[i].1.r == 0 && out[i].1.g == 0 && out[i].1.b == 0 {
            let neighbour = i > 0 ? out[i - 1].1 : (i + 1 < out.count ? out[i + 1].1 : out[i].1)
            out[i].1 = neighbour.withAlpha(0)
        }
        return out
    }

    private static func makeGradient(_ stops: [(Double, RGBA)]) -> CGGradient? {
        let fixed = fixTransparentStops(stops)
        let colors = fixed.map { $0.1.cgColor } as CFArray
        let locations = fixed.map { CGFloat($0.0) }
        return CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: locations)
    }

    private static let extendBothWays: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]

    /// `ctx.fillStyle = createLinearGradient(...); ctx.fill()` for `path`.
    /// A canvas gradient pads with its end colors past both ends, hence both
    /// extend options. When `shadow` is given the whole shape casts one
    /// shadow (canvas shadows apply to gradient fills too); that needs a
    /// transparency layer because CG gradients do not cast shadows by
    /// themselves.
    func fillLinearGradient(path: CGPath, from: CGPoint, to: CGPoint, stops: [(Double, RGBA)],
                            shadow: (blur: CGFloat, color: RGBA)? = nil) {
        guard let g = CGContext.makeGradient(stops) else { return }
        saveGState()
        if let s = shadow {
            canvasShadow(blur: s.blur, color: s.color)
            beginTransparencyLayer(auxiliaryInfo: nil)
        }
        clip(to: path)
        drawLinearGradient(g, start: from, end: to, options: CGContext.extendBothWays)
        if shadow != nil { endTransparencyLayer() }
        restoreGState()
    }

    /// `ctx.fillStyle = createRadialGradient(x0, y0, r0, x1, y1, r1); ctx.fill()`.
    /// Inside the start circle the canvas paints the first color, outside the
    /// end circle the last, which is what the two extend options do.
    func fillRadialGradient(path: CGPath, from: CGPoint, r0: CGFloat, to: CGPoint, r1: CGFloat,
                            stops: [(Double, RGBA)], shadow: (blur: CGFloat, color: RGBA)? = nil) {
        guard let g = CGContext.makeGradient(stops) else { return }
        saveGState()
        if let s = shadow {
            canvasShadow(blur: s.blur, color: s.color)
            beginTransparencyLayer(auxiliaryInfo: nil)
        }
        clip(to: path)
        drawRadialGradient(g, startCenter: from, startRadius: r0, endCenter: to, endRadius: r1, options: CGContext.extendBothWays)
        if shadow != nil { endTransparencyLayer() }
        restoreGState()
    }

    // Text.

    /// `ctx.font = ...; ctx.textAlign; ctx.textBaseline; ctx.fillText(text, x, y)`.
    /// Drawn with Core Text so the baseline lands exactly where the canvas
    /// puts it: `alphabetic` means y is the baseline; `middle` centres the
    /// em box (ascender..descender), like browsers do; `top`/`bottom` are the
    /// em box edges. The text matrix is flipped because the context is.
    func fillText(_ text: String, x: CGFloat, y: CGFloat, font: UIFont, color: RGBA,
                  align: TextAlign = .left, baseline: TextBaseline = .alphabetic) {
        let (line, width) = TextLines.line(text, font: font)
        var px = x
        switch align {
        case .left: break
        case .center: px -= width / 2
        case .right: px -= width
        }
        var baselineY = y
        switch baseline {
        case .alphabetic: break
        case .top: baselineY = y + font.ascender
        case .middle: baselineY = y + (font.ascender + font.descender) / 2
        case .bottom: baselineY = y + font.descender
        }
        saveGState()
        setFill(color)
        textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        textPosition = CGPoint(x: px, y: baselineY)
        CTLineDraw(line, self)
        restoreGState()
    }

    func fillText(_ text: String, x: CGFloat, y: CGFloat, font: UIFont, color: CSSColor,
                  align: TextAlign = .left, baseline: TextBaseline = .alphabetic) {
        fillText(text, x: x, y: y, font: font, color: Colors.rgba(color), align: align, baseline: baseline)
    }

    // Sprites.

    /// Draws a pre-rasterised sprite whose local origin is its centre, at the
    /// current origin (the caller has already translated/rotated). The extra
    /// y flip undoes the context's flip so the bitmap comes out upright.
    func drawSpriteAtOrigin(_ sprite: SpriteCache.Sprite) {
        saveGState()
        scaleBy(x: 1, y: -1)
        interpolationQuality = .high
        draw(sprite.image, in: CGRect(x: -sprite.size.width / 2, y: -sprite.size.height / 2,
                                      width: sprite.size.width, height: sprite.size.height))
        restoreGState()
    }

    func drawSprite(_ sprite: SpriteCache.Sprite, at x: CGFloat, _ y: CGFloat, rotation: CGFloat = 0) {
        saveGState()
        translateBy(x: x, y: y)
        if rotation != 0 { rotate(by: rotation) }
        drawSpriteAtOrigin(sprite)
        restoreGState()
    }
}
