import SwiftUI

/// `#auth-modal` (index.php:85-133, ui.js:812-848): PILOT LOGIN / JOIN THE
/// FLEET with the social buttons, one of the three password forms and the
/// links that switch between them.
struct AuthModalView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(icon: NeonIcon.user,
                        title: app.authPhase == .register ? "JOIN THE FLEET" : "PILOT LOGIN",
                        subtitle: "Save your scores on the leaderboard",
                        onClose: { app.closeModal() })

            VStack(spacing: 16) {
                if app.session.offline { OfflineNotice() }
                SocialSignInButtons()
                switch app.authPhase {
                case .login: LoginForm().id("login")
                case .register: RegisterForm().id("register")
                case .forgot: ForgotForm().id("forgot")
                }
                links
            }
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)

            LegalLinks()
                .padding(.top, 24)
        }
    }

    /// `.auth-links` (ui.js:822-831): which switches show per phase.
    private var links: some View {
        HStack(spacing: 20) {
            if app.authPhase == .login {
                Button("Create account") { app.authPhase = .register }
                Button("Forgot password?") { app.authPhase = .forgot }
            } else {
                Button("Back to log in") { app.authPhase = .login }
            }
        }
        .buttonStyle(LinkButtonStyle())
        .padding(.top, 4)
    }
}

/// `#reset-modal` (index.php:691-713): choose a new password for the token
/// from the emailed link.
struct ResetPasswordModalView: View {
    @Environment(AppState.self) private var app
    @State private var token = ""
    @State private var password = ""
    @State private var error: String? = nil
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(icon: NeonIcon.lock, title: "RESET PASSWORD", subtitle: "Choose a new password",
                        onClose: { app.closeModal() })
            VStack(spacing: 12) {
                NeonTextField(placeholder: "Reset token from the email", text: $token)
                NeonTextField(placeholder: "New password (8+ characters)", text: $password, secure: true, contentType: .newPassword)
                    .submitLabel(.go)
                    .onSubmit(submit)
                FormError(message: error)
                Button("SAVE PASSWORD", action: submit)
                    .buttonStyle(.neonSmall(.cyan, fullWidth: true))
                    .disabled(busy)
            }
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)
        }
    }

    private func submit() {
        guard !busy else { return }
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do { try await app.resetPassword(token: token.trimmingCharacters(in: .whitespaces), newPassword: password) } catch let failure as AuthFailure { error = failure.message } catch { self.error = error.localizedDescription }
        }
    }
}
