import Foundation
import GameKit
import NitroEngine

/// A live link to the other pilot: the transport the round runs over and,
/// when the matchmaker knows it, the peer's Game Center player id so the app
/// can check it is the account the lobby paired us with.
struct OnlineLink {
    let transport: any NetTransport
    let peerPlayerID: String?
}

/// What `AppState+Online` needs from Game Center — the port of net.js's
/// `connect(code, role)`. `GameCenterService` is the real one; tests plug in
/// a loopback fake so no GameKit session is required.
@MainActor
protocol OnlineMatchmaking: AnyObject {
    /// Sign the local player in (presenting Game Center's sheet if needed).
    /// False means online play is unavailable.
    func authenticate() async -> Bool
    /// The local player's `gamePlayerID` once authenticated.
    var gamePlayerID: String? { get }
    /// Find the other pilot of `code` and return a connected link.
    func connect(code: String, role: OnlineRoleName) async throws -> OnlineLink
    /// Abort a `connect` in progress.
    func cancel()
}

extension GameCenterService: OnlineMatchmaking {
    func connect(code: String, role: OnlineRoleName) async throws -> OnlineLink {
        let match = try await findMatch(code: code, role: role.rawValue)
        let transport = GameKitTransport(match: match)
        return OnlineLink(transport: transport, peerPlayerID: transport.peerPlayerID)
    }
}
