import SwiftUI

/// `#friends-modal` (index.php:593-633, ui.js:1993-2124): invite a pilot by
/// call sign, join a game by code, and the invites waiting for you.
struct FriendsModalView: View {
    @Environment(AppState.self) private var app
    @State private var inviteUsername = ""
    @State private var joinCode = ""

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            ModalHeader(icon: NeonIcon.users, title: "FRIENDS", subtitle: "Invite a pilot to an online two player game",
                        onClose: { app.closeModal() })

            // Invite form
            VStack(spacing: 12) {
                field("Friend username") {
                    NeonTextField(placeholder: "Their call sign", text: $inviteUsername)
                        .submitLabel(.next)
                }
                field("Game code") {
                    CodeTextField(placeholder: "e.g. NEBULA", text: $app.inviteCodeField)
                        .submitLabel(.send)
                        .onSubmit { app.sendInvite(username: inviteUsername, code: app.inviteCodeField) }
                }
                Button("SEND INVITE") { app.sendInvite(username: inviteUsername, code: app.inviteCodeField) }
                    .buttonStyle(.neonSmall(.cyan, fullWidth: true))
                if app.friendsInviteOK {
                    FormNotice(message: app.friendsInviteNotice)
                } else {
                    FormError(message: app.friendsInviteNotice)
                }
                LobbyHelp(text: "The code is the one from your lobby (Two Player → Create Game).")
            }

            SectionHead(icon: NeonIcon.globe, text: "JOIN WITH A CODE")
            VStack(spacing: 12) {
                field("Game code") {
                    CodeTextField(placeholder: "Type the code", text: $joinCode)
                        .submitLabel(.join)
                        .onSubmit { app.joinByCode(joinCode) }
                }
                Button("JOIN GAME") { app.joinByCode(joinCode) }
                    .buttonStyle(.neonSmall(.ghostCyan, fullWidth: true))
                FormError(message: app.friendsJoinError)
            }

            SectionHead(icon: NeonIcon.users, text: "INVITES FOR YOU")
            invites
        }
    }

    /// `.invites-list` (renderInvites, ui.js:2043-2092).
    @ViewBuilder
    private var invites: some View {
        if app.pendingInvites.isEmpty {
            LeaderboardEmpty(text: app.session.user.map { "No invites right now. Friends invite you by your call sign: \($0.username)" }
                             ?? "Log in to see your invites.")
        } else {
            VStack(spacing: 6) {
                ForEach(app.pendingInvites) { invite in
                    InviteRow(invite: invite,
                              join: { app.joinByCode(invite.code) },
                              decline: { app.declineInvite(invite) })
                }
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .neonLabel(size: 10, color: NeonColors.slate400)
            content()
        }
    }
}

/// `.invite-row`: who, the code chip, the mode chip, JOIN / NO THANKS.
struct InviteRow: View {
    let invite: APIInvite
    let join: () -> Void
    let decline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(invite.from)
                    .font(NeonFont.sans(14, .semibold))
                    .foregroundStyle(NeonColors.slate200)
                    .lineLimit(1)
                InviteChip(text: invite.code)
                InviteChip(text: LobbyTier(rawValue: invite.mode)?.label ?? invite.mode.uppercased())
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button("JOIN", action: join)
                    .buttonStyle(.neonSmall(.cyan, fullWidth: true))
                Button("NO THANKS", action: decline)
                    .buttonStyle(.neonSmall(.muted, fullWidth: true))
            }
        }
        .padding(12)
        .glassTile(cornerRadius: 12, fill: NeonColors.white(0.05), border: NeonColors.white(0.05))
    }
}

/// `.invite-chip`: a small mono tag for codes and modes.
struct InviteChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(NeonFont.display(10, .bold))
            .tracking(1)
            .foregroundStyle(NeonColors.cyan300)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Capsule().fill(NeonColors.cyan500.opacity(0.12)))
            .overlay(Capsule().stroke(NeonColors.cyan500.opacity(0.3), lineWidth: 1))
    }
}

/// `.code-input`: upper-case letters and digits only, 12 at most.
struct CodeTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        NeonTextField(placeholder: placeholder, text: $text, autocapitalization: .characters)
            .onChange(of: text) { _, value in
                let clean = LobbyService.cleanCode(value)
                if clean != value { text = clean }
            }
    }
}

/// `.lobby-help`.
struct LobbyHelp: View {
    let text: String

    var body: some View {
        Text(text)
            .font(NeonFont.sans(12))
            .foregroundStyle(NeonColors.slate500)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }
}
