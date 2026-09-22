import SwiftUI

/// `#settings-modal` (index.php:735-814): touch controls, the three sliders,
/// account and developer sections, legal links, credits and DONE.
struct SettingsModalView: View {
    @Environment(AppState.self) private var app
    @State private var devUsername = ""
    @State private var creditsOpen = false
    @State private var deletePassword = ""

    var body: some View {
        ModalScaffold {
            VStack(spacing: 0) {
                ModalHeader(icon: NeonIcon.sliders, title: "GAME SETTINGS", subtitle: "Flight Control Configuration",
                            onClose: { app.closeSettings() })

                section("Touch Controls") {
                    ControlOptionCard()
                }

                if app.isLeadDeveloper { developerSection }

                if app.session.user != nil { accountSection }

                section("Rocket Speed", value: "\(app.speedPercent)%") {
                    SliderRow(leading: "SLOW", trailing: "FAST",
                              value: Binding(get: { app.speedPercent }, set: { app.setSpeedPercent($0) }),
                              range: 1...300, label: "Rocket speed")
                }
                section("Music", value: AppState.volumeLabel(app.musicPercent)) {
                    SliderRow(leading: "OFF", trailing: "LOUD",
                              value: Binding(get: { app.musicPercent }, set: { app.setMusicPercent($0) }),
                              range: 0...100, label: "Music volume")
                }
                section("Sound Effects", value: AppState.volumeLabel(app.sfxPercent)) {
                    SliderRow(leading: "OFF", trailing: "LOUD",
                              value: Binding(get: { app.sfxPercent }, set: { app.setSfxPercent($0) }),
                              range: 0...100, label: "Sound effects volume")
                }

                creditsSection

                HStack(alignment: .center) {
                    HStack(spacing: 20) {
                        legalLink("Privacy Policy", "https://neon.everosenthal.com/privacy.php")
                        legalLink("Support", "https://neon.everosenthal.com/support.php")
                    }
                    Spacer()
                    Button("DONE") { app.closeSettings() }
                        .buttonStyle(.neonSmall(.cyan))
                }
            }
        }
        .confirmationDialog("Delete your account?", isPresented: confirmShown, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { app.deleteAccountConfirmed() }
            Button("Cancel", role: .cancel) { app.cancelDeleteAccount() }
        } message: {
            Text("Delete your account? Your scores and leaderboard entry will be removed. This cannot be undone.")
        }
        .alert("Confirm your password", isPresented: passwordShown) {
            SecureField("Password", text: $deletePassword)
                .textContentType(.password)
            Button("Delete account", role: .destructive) {
                let password = deletePassword
                deletePassword = ""
                app.performDeleteAccount(password: password)
            }
            Button("Cancel", role: .cancel) {
                deletePassword = ""
                app.cancelDeleteAccount()
            }
        } message: {
            Text("Type your password to delete the account.")
        }
    }

    private var confirmShown: Binding<Bool> {
        Binding(get: { app.deleteAccountStep == .confirm },
                set: { if !$0 && app.deleteAccountStep == .confirm { app.cancelDeleteAccount() } })
    }

    private var passwordShown: Binding<Bool> {
        Binding(get: { app.deleteAccountStep == .password },
                set: { if !$0 && app.deleteAccountStep == .password { app.cancelDeleteAccount() } })
    }

    private func section<Content: View>(_ title: String, value: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsLabel(title: title, value: value)
            content()
        }
        .padding(.bottom, 32)
    }

    private var accountSection: some View {
        section("Account") {
            HStack(spacing: 8) {
                Button { app.logout() } label: {
                    HStack(spacing: 8) { Icon(NeonIcon.logout, size: 16); Text("LOG OUT") }
                }
                .buttonStyle(.neonSmall(.muted, fullWidth: true))
                Button { app.deleteAccountTapped() } label: {
                    HStack(spacing: 8) { Icon(NeonIcon.trash, size: 16); Text("DELETE ACCOUNT…") }
                }
                .buttonStyle(.neonSmall(.ghostRose, fullWidth: true))
                .disabled(app.deleteAccountStep == .working)
            }
            if app.deleteAccountStep == .working {
                HStack(spacing: 8) {
                    ProgressView().tint(NeonColors.rose400)
                    Text("Deleting your account…")
                        .font(NeonFont.sans(12))
                        .foregroundStyle(NeonColors.slate400)
                }
            }
        }
    }

    private var developerSection: some View {
        section("Developer Accounts") {
            HStack(spacing: 8) {
                NeonTextField(placeholder: "Pilot username", text: $devUsername)
                Button("MAKE DEV") { app.setRole(username: devUsername, role: "developer") }
                    .buttonStyle(.neonSmall(.cyan))
                Button("REMOVE") { app.setRole(username: devUsername, role: "normal") }
                    .buttonStyle(.neonSmall(.muted))
            }
            Button("RUN DB MIGRATIONS") { app.runMigrations() }
                .buttonStyle(.neonSmall(.ghostCyan, fullWidth: true))
            if app.devConsoleIsError {
                FormError(message: app.devConsoleMessage)
            } else {
                FormNotice(message: app.devConsoleMessage)
            }
        }
    }

    private var creditsSection: some View {
        DisclosureGroup(isExpanded: $creditsOpen) {
            VStack(alignment: .leading, spacing: 8) {
                credit("Orbitron and Inter typefaces — SIL Open Font License 1.1.")
                credit("\"You Win Sequence 3\" by floraphonic (Pixabay #183950) — new high score fanfare.")
                credit("\"Spacecraft crashing\" by freesound_community (Pixabay #88048) — the crash.")
                credit("\"Cinematic designed sci-fi whoosh spectral glide\" by Rescopic Sound (Pixabay #228310) — asteroid hits.")
                credit("Home and gameplay music — original loops composed for Nitro Nebula.")
                credit("Google Sign-In for iOS — Apache License 2.0.")
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Icon(NeonIcon.info, size: 16)
                Text("About & Credits")
            }
            .font(NeonFont.sans(12, .bold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(NeonColors.slate300)
        }
        .tint(NeonColors.slate400)
        .padding(.bottom, 24)
    }

    private func credit(_ text: String) -> some View {
        Text(text)
            .font(NeonFont.sans(12))
            .foregroundStyle(NeonColors.slate400)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func legalLink(_ title: String, _ url: String) -> some View {
        Link(title, destination: URL(string: url)!)
            .font(NeonFont.sans(11))
            .foregroundStyle(NeonColors.slate500)
            .underline()
    }
}

/// `.control-option.selected` (ui.js:238-268, 1288-1317): the single
/// Floating Joystick card. Persisted as `keyboard`, the web's key for the
/// path the joystick drives.
struct ControlOptionCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Icon(NeonIcon.joystick, size: 20)
                .foregroundStyle(NeonColors.slate950)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NeonColors.cyan500))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Floating Joystick")
                        .font(NeonFont.sans(14, .bold))
                        .foregroundStyle(.white)
                    Text("Recommended")
                        .font(NeonFont.sans(9, .black))
                        .textCase(.uppercase)
                        .foregroundStyle(NeonColors.cyan300)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(NeonColors.cyan500.opacity(0.2)))
                        .overlay(Capsule().stroke(NeonColors.cyan500.opacity(0.3), lineWidth: 1))
                }
                Text("Touch anywhere and drag to steer; the stick appears under your thumb")
                    .font(NeonFont.sans(12))
                    .foregroundStyle(NeonColors.slate400)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Icon(NeonIcon.check, size: 16, weight: .bold)
                .foregroundStyle(NeonColors.slate950)
                .frame(width: 24, height: 24)
                .background(Circle().fill(NeonColors.cyan400))
        }
        .padding(16)
        .glassTile(cornerRadius: 16, fill: NeonColors.cyan500.opacity(0.15), border: NeonColors.cyan400)
        .shadow(color: Color(css: "#083344").opacity(0.4), radius: 8, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isSelected)
    }
}
