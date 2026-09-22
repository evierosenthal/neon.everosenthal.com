import Foundation

/// A canvas color string, kept verbatim (the renderer parses it). game.js
/// and ui.js pass colors around as CSS strings: '#rrggbb', 'rgba(r, g, b, a)',
/// 'hsl(h, s%, l%)' and 'hsla(...)'. Keeping the string form means every
/// literal ports unchanged and the online codec sends exactly what the web sends.
public struct CSSColor: Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public var css: String

    public init(_ css: String) { self.css = css }
    public init(stringLiteral value: String) { self.css = value }
    public var description: String { css }

    public init(from decoder: Decoder) throws {
        css = try decoder.singleValueContainer().decode(String.self)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(css)
    }

    /// Parsed components in 0...1. Unparseable strings decode as opaque white
    /// so a typo is visible rather than invisible.
    public var rgba: RGBA { RGBA(css: css) ?? RGBA(r: 1, g: 1, b: 1, a: 1) }
}

public struct RGBA: Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public func withAlpha(_ alpha: Double) -> RGBA {
        RGBA(r: r, g: g, b: b, a: alpha)
    }

    public init?(css raw: String) {
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if s == "transparent" { self.init(r: 0, g: 0, b: 0, a: 0); return }
        if s == "white" { self.init(r: 1, g: 1, b: 1); return }
        if s == "black" { self.init(r: 0, g: 0, b: 0); return }
        if s.hasPrefix("#") {
            let hex = String(s.dropFirst())
            func byte(_ i: Int) -> Double? {
                let start = hex.index(hex.startIndex, offsetBy: i)
                let end = hex.index(start, offsetBy: 2)
                guard end <= hex.endIndex, let v = UInt8(hex[start..<end], radix: 16) else { return nil }
                return Double(v) / 255
            }
            func nibble(_ i: Int) -> Double? {
                let idx = hex.index(hex.startIndex, offsetBy: i)
                guard idx < hex.endIndex, let v = UInt8(String(hex[idx]), radix: 16) else { return nil }
                return Double(v * 17) / 255
            }
            switch hex.count {
            case 6:
                guard let r = byte(0), let g = byte(2), let b = byte(4) else { return nil }
                self.init(r: r, g: g, b: b)
            case 8:
                guard let r = byte(0), let g = byte(2), let b = byte(4), let a = byte(6) else { return nil }
                self.init(r: r, g: g, b: b, a: a)
            case 3:
                guard let r = nibble(0), let g = nibble(1), let b = nibble(2) else { return nil }
                self.init(r: r, g: g, b: b)
            default:
                return nil
            }
            return
        }
        guard let open = s.firstIndex(of: "("), let close = s.lastIndex(of: ")") else { return nil }
        let fn = String(s[s.startIndex..<open])
        let parts = s[s.index(after: open)..<close]
            .replacingOccurrences(of: "/", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        func num(_ str: String) -> Double? {
            if str.hasSuffix("%") { return Double(str.dropLast()).map { $0 / 100 } }
            return Double(str)
        }
        switch fn {
        case "rgb", "rgba":
            guard parts.count >= 3, let r = num(parts[0]), let g = num(parts[1]), let b = num(parts[2]) else { return nil }
            let a = parts.count > 3 ? (num(parts[3]) ?? 1) : 1
            let scale: (String, Double) -> Double = { str, v in str.hasSuffix("%") ? v : v / 255 }
            self.init(r: scale(parts[0], r), g: scale(parts[1], g), b: scale(parts[2], b), a: a)
        case "hsl", "hsla":
            guard parts.count >= 3, let h = Double(parts[0].replacingOccurrences(of: "deg", with: "")),
                  let sat = num(parts[1]), let light = num(parts[2]) else { return nil }
            let a = parts.count > 3 ? (num(parts[3]) ?? 1) : 1
            let (r, g, b) = RGBA.hslToRGB(h: h, s: sat, l: light)
            self.init(r: r, g: g, b: b, a: a)
        default:
            return nil
        }
    }

    /// CSS HSL → RGB (h in degrees, s and l in 0...1).
    public static func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
        let hue = ((h.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 360
        if s == 0 { return (l, l, l) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 0.5 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        return (channel(hue + 1.0 / 3), channel(hue), channel(hue - 1.0 / 3))
    }
}
