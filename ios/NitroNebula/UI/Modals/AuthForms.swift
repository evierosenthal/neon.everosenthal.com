import AuthenticationServices
import SwiftUI

// The sign-in building blocks shared by the auth modal (index.php:85-133)
// and the celebration screen's inline forms (index.php:445-490): the social
// buttons, the OR divider and the three password forms. Each form owns its
// fields and shows the server's message verbatim (setFormError, ui.js:1408).

/// Sign in with Apple, then Google, then the `OR` rule.
struct SocialSignInButtons: View {
    @Environment(AppState.self) private var app
    @State private var nonce = ""
    @State private var error: String? = nil
    @State private var busy = false

    var body: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.continue) { request in
                nonce = AppleAuth.randomNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleAuth.sha256Hex(nonce)
            } onCompletion: { result in
                let raw = nonce
                run { try await app.completeAppleSignIn(result, rawNonce: raw) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(busy || app.session.offline)

            GoogleSignInButton(enabled: app.google.isConfigured && !app.session.offline && !busy) {
                run { try await app.signInWithGoogle() }
            }
            if !app.google.isConfigured {
                Text("Google sign-in is not configured for this build")
                    .font(NeonFont.sans(11))
                    .foregroundStyle(NeonColors.slate500)
            }
            FormError(message: error)
            AuthDivider()
        }
    }

    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do { try await work() } catch let failure as AuthFailure { error = failure.message } catch { self.error = error.localizedDescription }
        }
    }
}

/// The web's GSI "Continue with Google" pill: white, with the G mark.
struct GoogleSignInButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("G")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(css: "#4285F4"), Color(css: "#34A853"), Color(css: "#FBBC05"), Color(css: "#EA4335")],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Continue with Google")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(css: "#1f1f1f"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(css: "#747775"), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel("Continue with Google")
    }
}

/// `.auth-divider`: a rule with OR in the middle.
struct AuthDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(NeonColors.white(0.1)).frame(height: 1)
            Text("OR")
                .font(NeonFont.sans(10, .bold))
                .tracking(2)
                .foregroundStyle(NeonColors.slate500)
            Rectangle().fill(NeonColors.white(0.1)).frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

/// `#am-login-form` / `#newhigh-login-form`.
struct LoginForm: View {
    @Environment(AppState.self) private var app
    var submitLabel = "LOG IN"
    @State private var user = ""
    @State private var password = ""
    @State private var error: String? = nil
    @State private var busy = false

    var body: some View {
        VStack(spacing: 12) {
            NeonTextField(placeholder: "Username or email", text: $user, keyboard: .emailAddress, contentType: .username)
                .submitLabel(.next)
            NeonTextField(placeholder: "Password", text: $password, secure: true, contentType: .password)
                .submitLabel(.go)
                .onSubmit(submit)
            FormError(message: error)
            Button(submitLabel, action: submit)
                .buttonStyle(.neonSmall(.cyan, fullWidth: true))
                .disabled(busy || app.session.offline)
                .opacity(app.session.offline ? 0.5 : 1)
        }
    }

    private func submit() {
        guard !busy, !app.session.offline else { return }
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do { try await app.login(usernameOrEmail: user, password: password) } catch let failure as AuthFailure { error = failure.message } catch { self.error = error.localizedDescription }
        }
    }
}

/// `#am-register-form` / `#newhigh-register-form`.
struct RegisterForm: View {
    @Environment(AppState.self) private var app
    var submitLabel = "CREATE ACCOUNT"
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String? = nil
    @State private var busy = false

    var body: some View {
        VStack(spacing: 12) {
            NeonTextField(placeholder: "Call sign (username)", text: $username, contentType: .username)
                .submitLabel(.next)
            NeonTextField(placeholder: "Email", text: $email, keyboard: .emailAddress, contentType: .emailAddress)
                .submitLabel(.next)
            NeonTextField(placeholder: "Password (8+ characters)", text: $password, secure: true, contentType: .newPassword)
                .submitLabel(.go)
                .onSubmit(submit)
            FormError(message: error)
            Button(submitLabel, action: submit)
                .buttonStyle(.neonSmall(.cyan, fullWidth: true))
                .disabled(busy || app.session.offline)
                .opacity(app.session.offline ? 0.5 : 1)
        }
    }

    private func submit() {
        guard !busy, !app.session.offline else { return }
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do { try await app.register(username: username, email: email, password: password) } catch let failure as AuthFailure { error = failure.message } catch { self.error = error.localizedDescription }
        }
    }
}

/// `#am-forgot-form` / `#newhigh-forgot-form`.
struct ForgotForm: View {
    @Environment(AppState.self) private var app
    @State private var email = ""
    @State private var error: String? = nil
    @State private var sent: String? = nil
    @State private var busy = false

    var body: some View {
        VStack(spacing: 12) {
            NeonTextField(placeholder: "Email", text: $email, keyboard: .emailAddress, contentType: .emailAddress)
                .submitLabel(.send)
                .onSubmit(submit)
            FormError(message: error)
            FormNotice(message: sent)
            Button("SEND RESET LINK", action: submit)
                .buttonStyle(.neonSmall(.cyan, fullWidth: true))
                .disabled(busy || app.session.offline)
                .opacity(app.session.offline ? 0.5 : 1)
        }
    }

    private func submit() {
        guard !busy, !app.session.offline else { return }
        error = nil
        sent = nil
        busy = true
        Task {
            defer { busy = false }
            do { sent = try await app.requestReset(email: email) } catch let failure as AuthFailure { error = failure.message } catch { self.error = error.localizedDescription }
        }
    }
}

/// "COMMS OFFLINE" when session.php could not be reached.
struct OfflineNotice: View {
    var body: some View {
        Text("COMMS OFFLINE — the server cannot be reached right now.")
            .font(NeonFont.display(11, .bold))
            .tracking(1)
            .foregroundStyle(NeonColors.rose400)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(10)
            .glassTile(cornerRadius: 12, fill: NeonColors.rose500.opacity(0.1), border: NeonColors.rose500.opacity(0.3))
    }
}

/// `.legal-links`: Privacy policy · Support.
struct LegalLinks: View {
    var body: some View {
        HStack(spacing: 16) {
            link("Privacy policy", "https://neon.everosenthal.com/privacy.php")
            link("Support", "https://neon.everosenthal.com/support.php")
        }
        .frame(maxWidth: .infinity)
    }

    private func link(_ title: String, _ url: String) -> some View {
        Link(title, destination: URL(string: url)!)
            .font(NeonFont.sans(11))
            .foregroundStyle(NeonColors.slate500)
            .underline()
    }
}
