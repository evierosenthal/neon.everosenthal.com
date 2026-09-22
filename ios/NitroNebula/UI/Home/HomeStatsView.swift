import SwiftUI

/// `.home-stats` (index.php:224-238): best score, coins and the pilot tile
/// with its rank progress bar.
struct HomeStatsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let standing = app.rankStanding
        HStack(spacing: 12) {
            StatTile {
                CountUpText(value: app.bestOverall)
                    .foregroundStyle(NeonColors.cyan400)
                    .neonGlow(NeonColors.cyan400.opacity(0.4), radius: 10)
                StatLabel(text: "Best Score")
            }
            StatTile {
                CountUpText(value: app.coins)
                    .foregroundStyle(NeonColors.amber400)
                    .neonGlow(NeonColors.amber400.opacity(0.4), radius: 10)
                StatLabel(text: "Coins")
            }
            StatTile {
                Text(app.session.user?.username ?? "GUEST")
                    .font(NeonFont.display(18, .black))
                    .foregroundStyle(NeonColors.indigo300)
                    .neonGlow(NeonColors.indigo400.opacity(0.4), radius: 10)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                StatLabel(text: standing.name, color: NeonColors.indigo300)
                RankTrack(progress: standing.progress)
            }
            .accessibilityHint(standing.tooltip(best: app.bestOverall))
        }
        .padding(.horizontal, 8)
    }
}

/// `.home-stat`.
struct StatTile<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 4) { content }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .glassTile(cornerRadius: 16, fill: NeonColors.white(0.04), border: NeonColors.white(0.07))
    }
}

struct StatLabel: View {
    let text: String
    var color: Color = NeonColors.slate500

    var body: some View {
        Text(text)
            .neonLabel(size: 10, color: color, trackingEm: 0.1, weight: .black)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// `.rank-track` / `.rank-fill`.
struct RankTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(NeonColors.white(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [NeonColors.indigo400, NeonColors.cyan400], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress)
                    .shadow(color: NeonColors.cyan400.opacity(0.5), radius: 3)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 24)
        .padding(.top, 3)
        .animation(.easeInOut(duration: 0.6), value: progress)
    }
}

/// animateStat (ui.js:860-876): rolls the number toward its new value over
/// 600ms with a cubic ease-out instead of snapping.
struct CountUpText: View {
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var from = 0
    @State private var to = 0
    @State private var startedAt: Date? = nil

    var body: some View {
        TimelineView(.animation(paused: startedAt == nil)) { timeline in
            let shown = current(at: timeline.date)
            Text(NumberFormat.integer(shown))
                .font(NeonFont.display(18, .black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .monospacedDigit()
        }
        .onAppear { animate(to: value) }
        .onChange(of: value) { _, new in animate(to: new) }
    }

    private func current(at date: Date) -> Int {
        guard let startedAt else { return to }
        let t = min(1, date.timeIntervalSince(startedAt) / 0.6)
        let eased = 1 - pow(1 - t, 3)
        if t >= 1 { DispatchQueue.main.async { self.startedAt = nil } }
        return Int((Double(from) + Double(to - from) * eased).rounded())
    }

    private func animate(to target: Int) {
        if reduceMotion || target == to {
            from = target; to = target; startedAt = nil
            return
        }
        from = startedAt == nil ? to : current(at: Date())
        to = target
        startedAt = Date()
    }
}
