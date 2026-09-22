import SwiftUI

/// `#lobby-modal` (index.php:636-688, ui.js:2126-2281): the setup phase
/// (mode, code, OPEN LOBBY) and the wait phase (code card, the two pilot
/// rows, LEAVE / INVITE A FRIEND / START), plus the connecting spinner.
struct LobbyModalView: View {
    @Environment(AppState.self) private var app

    private static let modes = LobbyTier.allCases.map { NeonTabBar<LobbyTier>.Item(value: $0, title: $0.label + " MODE") }

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            ModalHeader(icon: NeonIcon.globe, title: "ONLINE GAME", subtitle: app.lobbySubtitle,
                        onClose: { app.leaveLobby(notifyServer: true, message: nil) })

            switch app.lobbyPhase {
            case .setup:
                setup
            case .wait, .connecting:
                wait
            }
        }
    }

    // MARK: Setup (index.php:649-667)

    private var setup: some View {
        @Bindable var app = app
        return VStack(spacing: 0) {
            SettingsLabel(title: "Mode")
                .padding(.bottom, 12)
            NeonTabBar(items: Self.modes, selection: app.lobbyModeChoice, fontSize: 10) { app.lobbyModeChoice = $0 }
                .padding(.bottom, 28)

            SettingsLabel(title: "Game code")
                .padding(.bottom, 12)
            HStack(spacing: 8) {
                CodeTextField(placeholder: "CODE", text: $app.lobbyCodeField)
                Button("NEW CODE") { app.shuffleLobbyCode() }
                    .buttonStyle(.neonSmall(.muted))
                    .fixedSize()
            }
            .padding(.bottom, 10)
            LobbyHelp(text: "Your friend types this code on their Friends page, or you invite them from there.")
                .padding(.bottom, 16)

            FormError(message: app.lobbySetupMessage)
                .padding(.bottom, app.lobbySetupMessage == nil ? 0 : 16)

            HStack {
                Spacer()
                Button("OPEN LOBBY") { app.createLobby() }
                    .buttonStyle(.neonSmall(.cyan))
                    .disabled(app.lobbyBusy)
                    .opacity(app.lobbyBusy ? 0.6 : 1)
            }
        }
    }

    // MARK: Wait / connecting (index.php:670-687)

    private var wait: some View {
        let online = app.online
        let game = online?.game
        let me = app.session.user?.username ?? ""
        let isHost = online?.isHost ?? false
        let connecting = app.lobbyPhase == .connecting
        return VStack(spacing: 0) {
            LobbyCodeCard(code: online?.code ?? "", mode: (online?.mode.label ?? "") + " MODE")
                .padding(.bottom, 16)

            VStack(spacing: 6) {
                PlayerRow(label: "PILOT 1", name: game?.host ?? me, isYou: (game?.host ?? me) == me,
                          isOnline: game?.hostOnline ?? true, waiting: false)
                PlayerRow(label: "PILOT 2", name: game?.guest ?? "", isYou: game?.guest == me,
                          isOnline: game?.guestOnline ?? false, waiting: game?.guest == nil)
            }
            .padding(.bottom, 16)

            if connecting {
                HStack(spacing: 10) {
                    ProgressView().tint(NeonColors.cyan400)
                    Text(app.lobbyStatusText)
                }
                .font(NeonFont.sans(12))
                .foregroundStyle(NeonColors.slate300)
                .padding(.bottom, 16)
            } else {
                LobbyHelp(text: app.lobbyStatusText)
                    .padding(.bottom, 16)
            }

            FormError(message: app.lobbyMessage)
                .padding(.bottom, app.lobbyMessage == nil ? 0 : 16)

            if connecting {
                Button("CANCEL") { app.leaveLobby(notifyServer: true, message: nil) }
                    .buttonStyle(.neonSmall(.muted, fullWidth: true))
            } else {
                // LEAVE · INVITE A FRIEND · START (flex 1 / 1 / 2 on the web):
                // the first two share one half, START takes the other.
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button { app.leaveLobby(notifyServer: true, message: nil) } label: { rowLabel("LEAVE") }
                            .buttonStyle(.neonSmall(.muted, fullWidth: true))
                        if isHost {
                            Button { app.inviteFromLobby() } label: { rowLabel("INVITE A FRIEND") }
                                .buttonStyle(.neonSmall(.ghostCyan, fullWidth: true))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if isHost {
                        Button { app.hostStart() } label: { rowLabel("START") }
                            .buttonStyle(.neonSmall(.cyan, fullWidth: true))
                            .frame(maxWidth: .infinity)
                            .disabled(!app.lobbyReady || app.lobbyBusy)
                            .opacity(app.lobbyReady && !app.lobbyBusy ? 1 : 0.45)
                    }
                }
            }
        }
    }
}

private func rowLabel(_ text: String) -> some View {
    Text(text).lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, -12)
}

/// `.lobby-code-card`: GAME CODE, the code and the mode chip.
struct LobbyCodeCard: View {
    let code: String
    let mode: String

    var body: some View {
        VStack(spacing: 6) {
            Text("GAME CODE")
                .neonLabel(size: 10, color: NeonColors.slate400)
            Text(code)
                .font(NeonFont.display(30, .black))
                .tracking(6)
                .foregroundStyle(NeonColors.cyan400)
                .neonGlow(NeonColors.cyan400.opacity(0.6), radius: 14)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            InviteChip(text: mode)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassTile(cornerRadius: 16, fill: NeonColors.cyan500.opacity(0.08), border: NeonColors.cyan500.opacity(0.25))
    }
}

/// `.player-row` (playerRow, ui.js:2174-2189) with its online dot.
struct PlayerRow: View {
    let label: String
    let name: String
    let isYou: Bool
    let isOnline: Bool
    let waiting: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(label)
                .font(NeonFont.display(11, .black))
                .tracking(1)
                .foregroundStyle(NeonColors.slate500)
                .frame(width: 64, alignment: .leading)
            Text(waiting ? "Waiting for a friend to join…" : name + (isYou ? " (you)" : ""))
                .font(NeonFont.sans(14, waiting ? .regular : .semibold))
                .italic(waiting)
                .foregroundStyle(waiting ? NeonColors.slate500 : NeonColors.slate200)
                .lineLimit(1)
            Spacer(minLength: 8)
            Circle()
                .fill(isOnline ? NeonColors.emerald400 : NeonColors.slate500.opacity(0.5))
                .frame(width: 10, height: 10)
                .shadow(color: isOnline ? NeonColors.emerald400.opacity(0.8) : .clear, radius: 4)
                .accessibilityLabel(isOnline ? "online" : "offline")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .glassTile(cornerRadius: 12, fill: NeonColors.white(0.05), border: NeonColors.white(0.05))
    }
}
