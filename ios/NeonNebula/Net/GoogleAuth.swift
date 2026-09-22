import Foundation
import GoogleSignIn
import UIKit

/// Google Sign-In on iOS. The web loads accounts.google.com/gsi/client and
/// posts the button's credential (auth.js:63-87); here the GoogleSignIn SDK
/// produces the same kind of ID token, which `AuthService.googleSignIn(idToken:)`
/// posts to google.php. The server accepts tokens whose audience is either the
/// web client or the iOS client (`GOOGLE_ALLOWED_CLIENT_IDS`).
///
/// Configuration comes from Info.plist (`GIDClientID`, `GIDServerClientID`,
/// and the reversed-client-id URL scheme). The SDK reads those keys itself;
/// `configureIfNeeded()` sets them explicitly as a belt-and-braces.
@MainActor
final class GoogleAuth {
    enum GoogleAuthError: Error, LocalizedError {
        /// The user dismissed the Google sheet.
        case cancelled
        /// Info.plist has no usable `GIDClientID` (still the REPLACE_WITH placeholder).
        case notConfigured
        /// Sign-in succeeded but returned no ID token.
        case noIDToken
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Google sign-in was cancelled."
            case .notConfigured: return "Google sign-in is not configured for this build."
            case .noIDToken: return "Google did not return an ID token."
            case .underlying(let e): return e.localizedDescription
            }
        }
    }

    init() {
        configureIfNeeded()
    }

    /// True once a real client ID is available. The SDK reads `GIDClientID`
    /// from Info.plist by itself, so the placeholder must be ruled out here.
    var isConfigured: Bool {
        Self.clientID != nil && GIDSignIn.sharedInstance.configuration != nil
    }

    /// The `GIDClientID` from Info.plist, if it is a real client ID.
    nonisolated static var clientID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !id.isEmpty, !id.contains("REPLACE_WITH") else { return nil }
        return id
    }

    nonisolated static var serverClientID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String,
              !id.isEmpty, !id.contains("REPLACE_WITH") else { return nil }
        return id
    }

    private func configureIfNeeded() {
        guard GIDSignIn.sharedInstance.configuration == nil, let clientID = Self.clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID, serverClientID: Self.serverClientID)
    }

    /// Interactive sign-in; returns the ID token to post to google.php.
    func signIn(presenting viewController: UIViewController) async throws -> String {
        configureIfNeeded()
        guard isConfigured else { throw GoogleAuthError.notConfigured }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            guard let token = result.user.idToken?.tokenString, !token.isEmpty else {
                throw GoogleAuthError.noIDToken
            }
            return token
        } catch let error as GoogleAuthError {
            throw error
        } catch {
            if (error as NSError).domain == kGIDSignInErrorDomain,
               (error as NSError).code == GIDSignInError.canceled.rawValue {
                throw GoogleAuthError.cancelled
            }
            throw GoogleAuthError.underlying(error)
        }
    }

    /// Feed `.onOpenURL` (the OAuth redirect on the reversed-client-id scheme).
    @discardableResult
    func handle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    /// Silent restore at launch; returns a fresh ID token or nil. The server
    /// session cookie is what actually keeps the player logged in, so this
    /// is only needed to re-login after the cookie expired.
    func restorePreviousSignIn() async -> String? {
        configureIfNeeded()
        guard isConfigured, GIDSignIn.sharedInstance.hasPreviousSignIn() else { return nil }
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            return user.idToken?.tokenString
        } catch {
            return nil
        }
    }

    /// Forget the Google user locally (after logout.php).
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    /// Revoke the app's grant and sign out: call alongside delete-account.php.
    func disconnect() async throws {
        guard GIDSignIn.sharedInstance.currentUser != nil || GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }
        do {
            try await GIDSignIn.sharedInstance.disconnect()
        } catch {
            throw GoogleAuthError.underlying(error)
        }
    }
}
