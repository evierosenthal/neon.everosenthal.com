import SwiftUI

/// `#leaderboard-modal` (index.php:516-556, ui.js:1875-1912): ONE PLAYER
/// and TWO PLAYER boards, each with its tier tabs, both opening on the tier
/// just played.
struct LeaderboardModalView: View {
    @Environment(AppState.self) private var app

    private static let tabs = Tier.allCases.map { NeonTabBar<Tier>.Item(value: $0, title: $0.label) }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(icon: NeonIcon.trophy, title: "GALACTIC LEADERBOARD", subtitle: "Top 10 Commanders",
                        onClose: { app.closeModal() })

            SectionHead(icon: NeonIcon.user, text: "ONE PLAYER", first: true)
            NeonTabBar(items: Self.tabs, selection: app.leaderboardTab) { app.leaderboardTab = $0 }
                .padding(.bottom, 12)
            board(mode: app.leaderboardTab.soloMode, offlineText: "COMMS OFFLINE — leaderboard unavailable.",
                  emptyText: nil)

            SectionHead(icon: NeonIcon.users, text: "TWO PLAYER")
            NeonTabBar(items: Self.tabs, selection: app.leaderboard2pTab) { app.leaderboard2pTab = $0 }
                .padding(.bottom, 12)
            board(mode: app.leaderboard2pTab.duoMode, offlineText: "COMMS OFFLINE.",
                  emptyText: "No two-player scores on \(app.leaderboard2pTab.label) yet — grab a co-pilot!")

            if app.leaderboardFailed {
                Button("RETRY") { app.loadLeaderboards() }
                    .buttonStyle(.neonSmall(.muted))
                    .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private func board(mode: GameMode, offlineText: String, emptyText: String?) -> some View {
        if app.leaderboardFailed {
            LeaderboardEmpty(text: offlineText)
        } else if let boards = app.leaderboards {
            LeaderboardList(rows: boards[mode] ?? [], emptyText: emptyText, me: app.session.user?.username)
        } else {
            LeaderboardEmpty(text: "Contacting command…")
        }
    }
}

/// `.lb-list` (buildLeaderboardList, ui.js:1413-1440): rank, call sign,
/// score; the signed-in pilot's row lights up (`.lb-me`).
struct LeaderboardList: View {
    let rows: [APILeaderboardRow]
    var emptyText: String? = nil
    var me: String? = nil
    var compact = false

    var body: some View {
        if rows.isEmpty {
            LeaderboardEmpty(text: emptyText ?? "No scores transmitted yet — be the first commander on the board.")
        } else {
            VStack(spacing: compact ? 4 : 6) {
                ForEach(rows.prefix(10)) { row in
                    LeaderboardRowView(row: row, isMe: me != nil && me == row.username, compact: compact)
                }
            }
        }
    }
}

struct LeaderboardRowView: View {
    let row: APILeaderboardRow
    let isMe: Bool
    var compact = false

    var body: some View {
        HStack(spacing: 14) {
            Text("#\(row.rank)")
                .font(NeonFont.display(compact ? 12 : 14, .black))
                .foregroundStyle(isMe ? NeonColors.cyan400 : NeonColors.slate500)
                .frame(width: 36, alignment: .leading)
            Text(row.username)
                .font(NeonFont.sans(compact ? 13 : 14, .semibold))
                .foregroundStyle(isMe ? .white : NeonColors.slate200)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(NumberFormat.integer(row.score))
                .font(NeonFont.display(compact ? 12 : 14, .bold))
                .foregroundStyle(NeonColors.cyan400)
                .monospacedDigit()
        }
        .padding(.vertical, compact ? 6 : 9)
        .padding(.horizontal, 14)
        .glassTile(cornerRadius: 12,
                   fill: isMe ? NeonColors.cyan500.opacity(0.15) : NeonColors.white(0.05),
                   border: isMe ? NeonColors.cyan400.opacity(0.6) : NeonColors.white(0.05))
        .accessibilityElement(children: .combine)
    }
}

/// `.lb-empty`.
struct LeaderboardEmpty: View {
    let text: String

    var body: some View {
        Text(text)
            .font(NeonFont.sans(13))
            .foregroundStyle(NeonColors.slate500)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
    }
}

extension AppState {
    /// GET leaderboard.php (openLeaderboard, ui.js:1895-1912). The previous
    /// boards stay while a refresh is in flight.
    func loadLeaderboards() {
        leaderboardFailed = false
        Task {
            do {
                let boards = try await auth.leaderboards()
                var byMode: [GameMode: [APILeaderboardRow]] = [:]
                for (key, rows) in boards {
                    if let mode = GameMode(rawValue: key) { byMode[mode] = rows }
                }
                leaderboards = byMode
                leaderboardFailed = false
            } catch {
                leaderboardFailed = true
                if (error as? APIError)?.isUnauthorized == true { sessionExpired() }
            }
        }
    }
}
