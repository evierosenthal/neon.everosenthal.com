import UIKit

/// Pre-rasterised bodies. Everything blur-heavy that does not change from
/// frame to frame (asteroid bodies, donuts, sundaes, orbs, ship hulls) is
/// drawn once into a bitmap at the view's scale and blitted afterwards;
/// the live parts (exhaust, rings, particles, text) are drawn on top.
///
/// Entries are keyed by entity id. A sweep every `sweepInterval` ticks drops
/// whatever has not been drawn recently (the id left the state).
final class SpriteCache {
    struct Sprite {
        let image: CGImage
        /// Size in points; the sprite's local origin is its centre.
        let size: CGSize
    }

    private struct Entry {
        var sprite: Sprite
        var variant: Int
        var lastUsed: Int
    }

    static let sweepInterval = 300
    /// Entries unused for this many ticks are evicted at sweep time. Power-up
    /// orbs blink (skip frames) for up to 10 ticks, so this is well above that.
    static let staleAfter = 60

    private var entries: [String: Entry] = [:]
    private var lastSweep = 0

    /// Device scale the bitmaps are rendered at. Changing it flushes.
    var scale: CGFloat = 1 {
        didSet { if scale != oldValue { removeAll() } }
    }

    var count: Int { entries.count }

    /// Returns the cached sprite for `key`, re-rendering when `variant` (for
    /// animated sprites) or the size changed. `halfExtent` is the padding
    /// radius around the entity's local origin, in points; `render` draws in
    /// local coordinates with the origin at the centre.
    func sprite(key: String, variant: Int = 0, tick: Int, halfExtent: CGFloat,
                render: (CGContext) -> Void) -> Sprite? {
        let side = ceil(halfExtent * 2)
        if var e = entries[key], e.variant == variant, e.sprite.size.width == side {
            e.lastUsed = tick
            entries[key] = e
            return e.sprite
        }
        guard side > 0, side.isFinite else { return nil }
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { rc in
            let ctx = rc.cgContext
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            render(ctx)
        }
        guard let cg = image.cgImage else { return nil }
        let sprite = Sprite(image: cg, size: size)
        entries[key] = Entry(sprite: sprite, variant: variant, lastUsed: tick)
        return sprite
    }

    /// Call once per frame; evicts stale entries every 300 ticks.
    func sweep(tick: Int) {
        guard tick - lastSweep >= SpriteCache.sweepInterval || tick < lastSweep else { return }
        lastSweep = tick
        let cutoff = tick - SpriteCache.staleAfter
        entries = entries.filter { $0.value.lastUsed >= cutoff }
    }

    func removeAll() {
        entries.removeAll()
        lastSweep = 0
    }
}
