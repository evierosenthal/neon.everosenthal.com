import GameController
import SwiftUI

/// `#menu-main` (index.php:217-299).
struct MainMenuView: View {
    @Environment(AppState.self) private var app
    @Environment(\.homeMetrics) private var m
    @State private var hasKeyboard = false

    var body: some View {
        VStack(spacing: 0) {
            MenuTitle(text: "NITRO\nNEBULA", size: m.titleSize,
                      rule: [NeonColors.cyan500, NeonColors.indigo600], glow: true)
                .padding(.bottom, 24)
            MenuSubtitle(text: "Galactic Tactical System // 4.0")
                .padding(.bottom, m.subtitleBottom)

            HomeStatsView()
                .padding(.bottom, 28)

            LoadoutRow(pilot: 1)
                .padding(.bottom, 24)

            VStack(spacing: m.stackGap) {
                DifficultyButtons(mode: .single)

                HStack(spacing: 12) {
                    Button { app.menuMode = .twoPlayer } label: {
                        MenuButtonLabel(icon: NeonIcon.users, text: "TWO PLAYER")
                    }
                    .buttonStyle(.neonMenu(.ghostIndigo))
                    Button { app.menuMode = .cpu } label: {
                        MenuButtonLabel(icon: NeonIcon.zap, text: "CPU CO-PILOT")
                    }
                    .buttonStyle(.neonMenu(.ghostRose))
                }

                HStack(spacing: 12) {
                    Button { app.openModal(.leaderboard) } label: {
                        MenuButtonLabel(icon: NeonIcon.trophy, text: "HIGH SCORES")
                    }
                    .buttonStyle(.neonMenu(.ghostCyan))
                    Button { app.openTailor(tab: app.tailorTab, pilot: 1) } label: {
                        MenuButtonLabel(icon: NeonIcon.tailor, text: "TAILOR")
                    }
                    .buttonStyle(.neonMenu(.ghostIndigo))
                    .overlay(alignment: .topTrailing) {
                        if app.showTailorBadge { CornerBadge(text: "NEW") }
                    }
                }

                Button { app.openFriends() } label: {
                    MenuButtonLabel(icon: NeonIcon.users, text: "FRIENDS & INVITES")
                }
                .buttonStyle(.neonMenu(.ghostCyan))
                .overlay(alignment: .topTrailing) {
                    if app.session.user != nil && !app.pendingInvites.isEmpty {
                        CornerBadge(text: String(app.pendingInvites.count))
                    }
                }
            }

            if hasKeyboard {
                HomeHint(mission: app.lastMission, fallback: "Pick a difficulty to launch")
                    .padding(.top, 24)
            }
        }
        .onAppear { hasKeyboard = GCKeyboard.coalesced != nil }
    }
}

/// Icon + caption inside the ghost menu buttons.
struct MenuButtonLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Icon(icon, size: 20)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

/// `.btn-badge`: the pulsing amber pill on the Tailor / Friends buttons.
struct CornerBadge: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Text(text)
            .font(NeonFont.display(8, .black))
            .tracking(1)
            .foregroundStyle(Color(css: "#1c1917"))
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(Capsule().fill(NeonColors.amber400))
            .shadow(color: NeonColors.amber400.opacity(0.7), radius: 5)
            .scaleEffect(pulse ? 1.12 : 1)
            .padding(.top, 5)
            .padding(.trailing, 6)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

/// `.home-hint`: "ENTER replay MEDIUM" for hardware keyboards.
struct HomeHint: View {
    let mission: LastMission?
    var fallback: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let mission {
                Text("ENTER")
                    .font(NeonFont.display(9, .bold))
                    .tracking(0.9)
                    .foregroundStyle(NeonColors.cyan400)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .glassTile(cornerRadius: 6, fill: NeonColors.cyan400.opacity(0.08), border: NeonColors.cyan400.opacity(0.3))
                Text("replay " + mission.label)
            } else if let fallback {
                Text(fallback)
            }
        }
        .font(NeonFont.sans(11))
        .tracking(1.3)
        .textCase(.uppercase)
        .foregroundStyle(NeonColors.slate500)
    }
}
