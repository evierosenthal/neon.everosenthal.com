import AuthenticationServices
import Foundation
import UIKit

// Session bootstrap and the sign-in flows (auth.js:105-121, ui.js:2560-2600,
// 2630-2700). The auth modal and the celebration screen share these: the
// views own their text fields and show whatever `APIError.message` the
// server sent, verbatim, exactly like the web's `setFormError`.

extension AppState {
    // MARK: Bootstrap (ui.js:2560-2570)

    /// GET session.php on launch and whenever the app returns from the
    /// background. Never throws: offline just means local celebrations.
    func bootstrapSession() async {
        #if DEBUG
        if debugStagedSession { return }
        #endif
        let data = await auth.bootstrap()
        didBootstrap = true
        session.user = data.user
        session.csrf = data.csrf
        session.offline = data.isOffline
        session.googleClientId = data.googleClientId
        enforceOwnedGear()
        if let user = data.user {
            store.hasAccount = true
            hasAccount = true
            syncServerBests(user)
            refreshInbox()
            startInboxPolling(LobbyService.inboxPollIdle)
        } else {
            stopInboxPolling()
        }
    }

    /// `auth.onAuthChange` with a user (ui.js:2572-2586): remember that an
    /// account exists, close the login modal, merge the server bests and
    /// submit the record the celebration screen is holding.
    func applySignedIn(_ user: APIUser?) {
        session.user = user
        session.offline = false
        guard let user else { return }
        store.hasAccount = true
        hasAccount = true
        if modal == .auth { modal = nil }
        enforceOwnedGear()
        syncServerBests(user)
        if phase == .newHigh && pendingScore != nil {
            submitPendingScore()
        } else if phase == .newHigh {
            newHighPhase = .none
        }
        refreshInbox()
        startInboxPolling(LobbyService.inboxPollIdle)
    }

    /// The server said `unauthorized`: the cookie died. Drop the user and
    /// ask session.php again.
    func sessionExpired() {
        session.user = nil
        pendingInvites = []
        stopInboxPolling()
        if phase == .newHigh && pendingScore != nil { newHighPhase = .offer }
        Task { await bootstrapSession() }
    }

    /// Route any failed call through here: `unauthorized` resets the
    /// session; the message is what the caller shows.
    @discardableResult
    func noteError(_ error: Error) -> String {
        if let api = error as? APIError {
            if api.isUnauthorized { sessionExpired() }
            return api.message
        }
        return error.localizedDescription
    }

    // MARK: Password accounts (ui.js:2645-2663, 2665-2697)

    /// login.php; social-only accounts get their `use_google` / `use_apple`
    /// message back verbatim (loginErrorText, ui.js:1403-1406).
    func login(usernameOrEmail: String, password: String) async throws {
        do {
            let user = try await auth.login(usernameOrEmail: usernameOrEmail.trimmingCharacters(in: .whitespaces), password: password)
            applySignedIn(user)
        } catch {
            throw AuthFailure(message: (error as? APIError)?.message ?? "Login failed.")
        }
    }

    func register(username: String, email: String, password: String) async throws {
        do {
            let user = try await auth.register(username: username.trimmingCharacters(in: .whitespaces),
                                               email: email.trimmingCharacters(in: .whitespaces), password: password)
            applySignedIn(user)
        } catch {
            throw AuthFailure(message: noteError(error))
        }
    }

    /// request-reset.php: returns the server's confirmation line.
    func requestReset(email: String) async throws -> String {
        do {
            let data = try await auth.requestReset(email: email.trimmingCharacters(in: .whitespaces))
            return data.message ?? "If that email has an account, a reset link is on its way."
        } catch {
            throw AuthFailure(message: noteError(error))
        }
    }

    /// reset-password.php (the emailed token).
    func resetPassword(token: String, newPassword: String) async throws {
        do {
            let user = try await auth.resetPassword(token: token, newPassword: newPassword)
            applySignedIn(user)
            modal = nil
        } catch {
            throw AuthFailure(message: noteError(error))
        }
    }

    // MARK: Social sign-in

    /// The Google button: the SDK's sheet, then google.php.
    func signInWithGoogle() async throws {
        guard google.isConfigured else { throw AuthFailure(message: GoogleAuth.GoogleAuthError.notConfigured.localizedDescription) }
        guard let presenter = GameCenterService.topViewController() else {
            throw AuthFailure(message: "Google sign-in could not open.")
        }
        do {
            let token = try await google.signIn(presenting: presenter)
            let user = try await auth.googleSignIn(idToken: token)
            applySignedIn(user)
        } catch GoogleAuth.GoogleAuthError.cancelled {
            return
        } catch {
            throw AuthFailure(message: noteError(error))
        }
    }

    /// The Sign in with Apple button's result → apple.php.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>, rawNonce: String) async throws {
        switch result {
        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled { return }
            throw AuthFailure(message: error.localizedDescription)
        case .success(let authorization):
            let payload: AppleCredentialPayload
            do {
                payload = try AppleAuth.payload(from: authorization, rawNonce: rawNonce)
            } catch {
                throw AuthFailure(message: error.localizedDescription)
            }
            do {
                let user = try await auth.appleSignIn(identityToken: payload.identityToken,
                                                      authorizationCode: payload.authorizationCode,
                                                      nonce: payload.rawNonce, fullName: payload.fullName)
                applySignedIn(user)
            } catch {
                throw AuthFailure(message: noteError(error))
            }
        }
    }
}

/// What a sign-in form shows under its fields.
struct AuthFailure: Error, Sendable, Hashable {
    var message: String
}
