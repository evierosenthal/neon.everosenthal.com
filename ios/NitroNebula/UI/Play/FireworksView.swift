import SwiftUI

/// Celebration fireworks behind the new-high-score panel (ui.js:1466-1576):
/// a rocket launches every 45 frames and bursts into 40-70 sparks with
/// drag 0.985 and gravity 0.045. Runs at the web's 60 frames a second on a
/// TimelineView + Canvas; each spark drags a short glowing tail in place of
/// the web's frame-fade trick.
struct FireworksView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sim = FireworksSim()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas(rendersAsynchronously: false) { ctx, size in
                sim.step(to: timeline.date, size: size)
                sim.draw(in: &ctx)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
final class FireworksSim {
    struct Rocket { var x, y, vx, vy, targetY: Double; let color: Color }
    struct Spark { var x, y, vx, vy, life: Double; let decay: Double; let color: Color; var px, py: Double }

    private static let colors = ["#22d3ee", "#34d399", "#fbbf24", "#f43f5e", "#818cf8", "#c084fc"].map { Color(css: $0) }
    private var rockets: [Rocket] = []
    private var sparks: [Spark] = []
    private var frame = 0
    private var lastDate: Date? = nil
    private var size = CGSize.zero

    /// Advances whole 60Hz frames (at most 3 per draw to survive hitches).
    func step(to date: Date, size: CGSize) {
        if self.size != size {
            self.size = size
            if lastDate == nil { launch() }
        }
        guard let last = lastDate else { lastDate = date; return }
        let frames = min(3, Int(date.timeIntervalSince(last) * 60))
        if frames <= 0 { return }
        lastDate = date
        for _ in 0..<frames { tick() }
    }

    private func launch() {
        guard size.height > 0 else { return }
        rockets.append(Rocket(x: size.width * (0.1 + .random(in: 0..<0.8)), y: size.height,
                              vx: (.random(in: 0..<1) - 0.5) * 1.2,
                              vy: -(size.height * (0.009 + .random(in: 0..<0.004))),
                              targetY: size.height * (0.15 + .random(in: 0..<0.35)),
                              color: Self.colors.randomElement() ?? .white))
    }

    private func explode(_ r: Rocket) {
        let count = 40 + Int.random(in: 0..<30)
        for i in 0..<count {
            let angle = (Double.pi * 2 * Double(i)) / Double(count) + .random(in: 0..<0.2)
            let speed = 1.5 + Double.random(in: 0..<3.5)
            sparks.append(Spark(x: r.x, y: r.y, vx: cos(angle) * speed, vy: sin(angle) * speed, life: 1,
                                decay: 0.008 + .random(in: 0..<0.012), color: r.color, px: r.x, py: r.y))
        }
    }

    private func tick() {
        frame += 1
        if frame % 45 == 0 || (rockets.isEmpty && sparks.count < 30) { launch() }
        for i in stride(from: rockets.count - 1, through: 0, by: -1) {
            rockets[i].x += rockets[i].vx
            rockets[i].y += rockets[i].vy
            rockets[i].vy += 0.03
            if rockets[i].y <= rockets[i].targetY || rockets[i].vy >= 0 {
                explode(rockets[i])
                rockets.remove(at: i)
            }
        }
        for j in stride(from: sparks.count - 1, through: 0, by: -1) {
            sparks[j].px = sparks[j].x
            sparks[j].py = sparks[j].y
            sparks[j].x += sparks[j].vx
            sparks[j].y += sparks[j].vy
            sparks[j].vx *= 0.985
            sparks[j].vy = sparks[j].vy * 0.985 + 0.045 // drag + gravity
            sparks[j].life -= sparks[j].decay
            if sparks[j].life <= 0 { sparks.remove(at: j) }
        }
    }

    func draw(in ctx: inout GraphicsContext) {
        ctx.blendMode = .plusLighter
        for r in rockets {
            ctx.fill(Path(CGRect(x: r.x - 1.5, y: r.y - 1.5, width: 3, height: 3)), with: .color(r.color))
        }
        for s in sparks {
            var tail = Path()
            tail.move(to: CGPoint(x: s.px - (s.x - s.px) * 3, y: s.py - (s.y - s.py) * 3))
            tail.addLine(to: CGPoint(x: s.x, y: s.y))
            ctx.stroke(tail, with: .color(s.color.opacity(s.life * 0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ctx.fill(Path(CGRect(x: s.x - 1.5, y: s.y - 1.5, width: 3, height: 3)), with: .color(s.color.opacity(s.life)))
        }
    }
}
