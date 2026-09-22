import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// What Sign in with Apple hands back, ready for `AuthService.appleSignIn`.
nonisolated struct AppleCredentialPayload: Sendable {
    /// The JWT apple.php verifies against Apple's JWKS.
    var identityToken: String
    /// One-time code the server may swap for a refresh token (used later to
    /// revoke the grant on account deletion).
    var authorizationCode: String?
    /// The raw nonce; the request carried its SHA-256, and the token's
    /// `nonce` claim must match `hash('sha256', rawNonce)` on the server.
    var rawNonce: String
    /// Only present the first time the user authorizes the app.
    var fullName: (given: String?, family: String?)?
    /// Only present the first time, too (the server reads it from the token).
    var email: String?
    /// Apple's stable user identifier (the token's `sub`).
    var userID: String
}

/// Sign in with Apple (iOS only; the web has no Apple button). One
/// `ASAuthorizationController` flow at a time; the same flow serves both
/// `signIn()` and `reauthorize()` (account deletion wants a fresh
/// authorization code, which only a new authorization produces).
@MainActor
final class AppleAuth: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    enum AppleAuthError: Error, LocalizedError {
        case cancelled
        case inProgress
        /// Apple returned a credential without an identity token.
        case invalidResponse
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Sign in with Apple was cancelled."
            case .inProgress: return "Sign in with Apple is already in progress."
            case .invalidResponse: return "Apple did not return an identity token."
            case .underlying(let e): return e.localizedDescription
            }
        }
    }

    private var continuation: CheckedContinuation<AppleCredentialPayload, Error>?
    private var controller: ASAuthorizationController?
    private var currentNonce: String?

    var isInProgress: Bool { continuation != nil }

    /// Present the Apple sheet and return the credential.
    func signIn() async throws -> AppleCredentialPayload {
        try await authorize()
    }

    /// Same flow, run again for a fresh `authorizationCode` (delete-account.php).
    func reauthorize() async throws -> AppleCredentialPayload {
        try await authorize()
    }

    /// Cancel a flow in progress (e.g. the view went away).
    func cancel() {
        guard let continuation else { return }
        self.continuation = nil
        controller = nil
        currentNonce = nil
        continuation.resume(throwing: AppleAuthError.cancelled)
    }

    private func authorize() async throws -> AppleCredentialPayload {
        guard continuation == nil else { throw AppleAuthError.inProgress }
        let nonce = Self.randomNonce()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256Hex(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let continuation else { return }
        self.continuation = nil
        self.controller = nil
        let nonce = currentNonce ?? ""
        currentNonce = nil
        do {
            continuation.resume(returning: try Self.payload(from: authorization, rawNonce: nonce))
        } catch {
            continuation.resume(throwing: error)
        }
    }

    /// Unpack an Apple ID credential (ours or the SwiftUI button's) into the
    /// payload apple.php wants.
    nonisolated static func payload(from authorization: ASAuthorization, rawNonce: String) throws -> AppleCredentialPayload {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8), !token.isEmpty else {
            throw AppleAuthError.invalidResponse
        }
        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        var fullName: (given: String?, family: String?)?
        if let name = credential.fullName, name.givenName != nil || name.familyName != nil {
            fullName = (given: name.givenName, family: name.familyName)
        }
        return AppleCredentialPayload(
            identityToken: token,
            authorizationCode: code,
            rawNonce: rawNonce,
            fullName: fullName,
            email: credential.email,
            userID: credential.user
        )
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        self.controller = nil
        currentNonce = nil
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            continuation.resume(throwing: AppleAuthError.cancelled)
        } else {
            continuation.resume(throwing: AppleAuthError.underlying(error))
        }
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        Self.keyWindow() ?? ASPresentationAnchor()
    }

    static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    // MARK: - Nonce helpers

    /// Lower-case hex SHA-256, the form apple.php compares with `hash('sha256', $nonce)`.
    nonisolated static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// A random URL-safe nonce (32 chars by default).
    nonisolated static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }
}
