import Foundation
import GameKit
import UIKit

/// Game Center: the iOS replacement for the web's WebRTC link (net.js
/// `connect()`). The server's lobby pairs two accounts under a game code;
/// both sides then ask Game Center's matchmaker for a two-player match in a
/// player group derived from that code, so only they can meet. The host
/// advertises attributes 0xFFFF0000 and the guest 0x0000FFFF, which GameKit
/// treats as complementary halves, so a host is never paired with a host.
@MainActor
final class GameCenterService: NSObject {
    enum GameCenterError: Error, LocalizedError {
        case notAuthenticated
        case timeout
        case cancelled
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Game Center is not signed in."
            case .timeout: return "Could not link the two screens in time."
            case .cancelled: return "Matchmaking was cancelled."
            case .underlying(let e): return e.localizedDescription
            }
        }
    }

    nonisolated static let hostAttributes: UInt32 = 0xFFFF_0000
    nonisolated static let guestAttributes: UInt32 = 0x0000_FFFF

    private(set) var isAuthenticated = false
    private var authenticating: Task<Bool, Never>?
    private var waiter: MatchWaiter?

    /// `GKLocalPlayer.local.gamePlayerID` once authenticated; what the lobby
    /// relays through `signal` so the peer can be verified.
    var gamePlayerID: String? {
        isAuthenticated ? GKLocalPlayer.local.gamePlayerID : nil
    }

    var displayName: String {
        isAuthenticated ? GKLocalPlayer.local.displayName : ""
    }

    // MARK: - Authentication

    /// Install the authenticate handler, present Game Center's login sheet
    /// if it asks for one, and resolve once with the outcome. Safe to call
    /// repeatedly; concurrent callers share one attempt.
    func authenticate() async -> Bool {
        if GKLocalPlayer.local.isAuthenticated {
            isAuthenticated = true
            GKAccessPoint.shared.isActive = false
            return true
        }
        if let authenticating {
            return await authenticating.value
        }
        let task = Task<Bool, Never> { @MainActor in
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                let once = ResolveOnce(continuation)
                GKLocalPlayer.local.authenticateHandler = { viewController, error in
                    let vc = viewController
                    let resolve: @MainActor () -> Void = {
                        GameCenterService.handleAuthentication(viewController: vc, error: error, once: once)
                    }
                    if Thread.isMainThread {
                        MainActor.assumeIsolated { resolve() }
                    } else {
                        DispatchQueue.main.async { resolve() }
                    }
                }
            }
        }
        authenticating = task
        let ok = await task.value
        authenticating = nil
        isAuthenticated = ok
        GKAccessPoint.shared.isActive = false
        return ok
    }

    private static func handleAuthentication(viewController: UIViewController?, error: Error?, once: ResolveOnce) {
        if let viewController {
            // Game Center wants the player to log in: present its sheet; the
            // handler fires again with the result once it is dismissed.
            if let presenter = topViewController() {
                presenter.present(viewController, animated: true)
            } else {
                once.resolve(false)
            }
            return
        }
        once.resolve(GKLocalPlayer.local.isAuthenticated)
    }

    static func topViewController() -> UIViewController? {
        var top = AppleAuth.keyWindow()?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    // MARK: - Matchmaking

    /// Ask the matchmaker for the other pilot of `code`. Resolves with a
    /// fully connected two-player match (`expectedPlayerCount == 0`),
    /// already through `finishMatchmaking`, and with `delegate` cleared so
    /// `GameKitTransport` can take it over.
    func findMatch(code: String, role: String, timeout: TimeInterval = LobbyService.connectTimeout) async throws -> GKMatch {
        guard isAuthenticated, GKLocalPlayer.local.isAuthenticated else { throw GameCenterError.notAuthenticated }
        cancel()

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.defaultNumberOfPlayers = 2
        request.playerGroup = Int(FNV1a.hash32("neon:" + code))
        request.playerAttributes = role == "host" ? Self.hostAttributes : Self.guestAttributes

        let waiter = MatchWaiter()
        self.waiter = waiter
        let deadline = Task { [waiter] in
            try? await Task.sleep(for: .seconds(timeout))
            if !Task.isCancelled {
                waiter.fail(GameCenterError.timeout)
                GKMatchmaker.shared().cancel()
            }
        }
        defer {
            deadline.cancel()
            if self.waiter === waiter { self.waiter = nil }
        }

        let match: GKMatch
        do {
            match = try await GKMatchmaker.shared().findMatch(for: request)
        } catch {
            if let failure = waiter.failure { throw failure }
            if (error as NSError).domain == GKErrorDomain, (error as NSError).code == GKError.cancelled.rawValue {
                throw GameCenterError.cancelled
            }
            throw GameCenterError.underlying(error)
        }

        match.delegate = waiter
        do {
            try await waiter.waitUntilConnected(match)
        } catch {
            match.delegate = nil
            match.disconnect()
            throw error
        }
        GKMatchmaker.shared().finishMatchmaking(for: match)
        match.delegate = nil
        return match
    }

    /// Abort a `findMatch` in progress (the lobby was left).
    func cancel() {
        guard let waiter else { return }
        self.waiter = nil
        waiter.fail(GameCenterError.cancelled)
        GKMatchmaker.shared().cancel()
    }
}

// MARK: - Helpers

/// Resolves a Bool continuation exactly once (the authenticate handler can
/// fire several times).
nonisolated private final class ResolveOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resolve(_ value: Bool) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(returning: value)
    }
}

/// Watches a freshly found GKMatch until every expected player is connected.
/// GameKit calls the delegate on arbitrary queues, so this is lock-guarded.
nonisolated private final class MatchWaiter: NSObject, GKMatchDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var done = false
    private(set) var failure: Error?

    func waitUntilConnected(_ match: GKMatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            if done {
                let f = failure
                lock.unlock()
                if let f { continuation.resume(throwing: f) } else { continuation.resume() }
                return
            }
            if match.expectedPlayerCount == 0 {
                done = true
                lock.unlock()
                continuation.resume()
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    func succeed() {
        lock.lock()
        guard !done else { lock.unlock(); return }
        done = true
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume()
    }

    func fail(_ error: Error) {
        lock.lock()
        guard !done else { lock.unlock(); return }
        done = true
        failure = error
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(throwing: error)
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        switch state {
        case .connected:
            if match.expectedPlayerCount == 0 { succeed() }
        case .disconnected:
            fail(GameCenterService.GameCenterError.cancelled)
        default:
            break
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        fail(error.map { GameCenterService.GameCenterError.underlying($0) } ?? GameCenterService.GameCenterError.cancelled)
    }

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        // Nothing arrives before the handshake; the transport takes over first.
    }
}

/// FNV-1a, 32-bit: the same player group for the same game code on both
/// phones. (fnv1a32("") == 0x811c9dc5, fnv1a32("a") == 0xe40c292c.)
nonisolated enum FNV1a {
    static let offset32: UInt32 = 0x811C_9DC5
    static let prime32: UInt32 = 0x0100_0193

    static func hash32(_ string: String) -> UInt32 {
        hash32(Array(string.utf8))
    }

    static func hash32(_ bytes: [UInt8]) -> UInt32 {
        var hash = offset32
        for byte in bytes {
            hash ^= UInt32(byte)
            hash = hash &* prime32
        }
        return hash
    }
}
