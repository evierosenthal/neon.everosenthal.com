import SwiftUI

/// `#menu-two-player` (index.php:302-377): the duo's own home screen with a
/// loadout row per pilot.
struct TwoPlayerMenuView: View {
    @Environment(AppState.self) private var app
    @Environment(\.homeMetrics) private var m
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            BackToMainButton()
                .padding(.bottom, 24)
            MenuTitle(text: "TWO PLAYER", size: m.titleSmallSize,
                      rule: [NeonColors.indigo500, Color(css: "#a855f7")])
                .padding(.bottom, 8)
            MenuSubtitle(text: "Co-op on one screen", trackingEm: 0.25)
                .padding(.bottom, m.shortScreen ? 24 : 40)

            StatTile {
                CountUpText(value: app.duoBest)
                    .foregroundStyle(NeonColors.cyan400)
                    .neonGlow(NeonColors.cyan400.opacity(0.4), radius: 10)
                StatLabel(text: "Duo Best")
            }
            .frame(maxWidth: 224)
            .padding(.bottom, 28)

            LoadoutRowLabel(text: "Pilot 1 · left stick", color: NeonColors.cyan400)
            LoadoutRow(pilot: 1)
                .padding(.bottom, 16)
            LoadoutRowLabel(text: "Pilot 2 · right stick", color: NeonColors.rose400)
            LoadoutRow(pilot: 2)
                .padding(.bottom, 24)

            VStack(spacing: m.stackGap) {
                DifficultyButtons(mode: .local)

                Button { app.openLobby() } label: {
                    MenuButtonLabel(icon: NeonIcon.globe, text: "CREATE GAME · PLAY ONLINE")
                }
                .buttonStyle(.neonMenu(.ghostCyan))

                HStack(spacing: 12) {
                    Button { app.openTailor(tab: app.tailorTab, pilot: 1) } label: {
                        MenuButtonLabel(icon: NeonIcon.tailor, text: "PILOT 1 TAILOR")
                    }
                    .buttonStyle(.neonMenu(.ghostIndigo))
                    Button { app.openTailor(tab: app.tailorTab, pilot: 2) } label: {
                        MenuButtonLabel(icon: NeonIcon.tailor, text: "PILOT 2 TAILOR")
                    }
                    .buttonStyle(.neonMenu(.ghostRose))
                }
            }

            if let last = app.lastMission, last.mode == .local, GCKeyboardPresence.hasKeyboard {
                HomeHint(mission: last)
                    .padding(.top, 24)
            }
        }
        .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
    }
}

/// `#menu-cpu` (index.php:380-393).
struct CPUMenuView: View {
    @Environment(\.homeMetrics) private var m
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            BackToMainButton()
                .padding(.bottom, 24)
            MenuTitle(text: "CPU CO-PILOT MODE", size: min(m.titleSmallSize, 34),
                      rule: [NeonColors.rose500, Color(css: "#f59e0b")])
                .padding(.bottom, 8)
            MenuSubtitle(text: "Select AI Companion Difficulty", trackingEm: 0.25)
                .padding(.bottom, m.shortScreen ? 24 : 40)
            DifficultyButtons(mode: .cpu)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
    }
}

import GameController

/// Whether a hardware keyboard is attached (the Enter hint only makes
/// sense then; on the web the hint hides under `hover: none`).
enum GCKeyboardPresence {
    static var hasKeyboard: Bool { GCKeyboard.coalesced != nil }
}
