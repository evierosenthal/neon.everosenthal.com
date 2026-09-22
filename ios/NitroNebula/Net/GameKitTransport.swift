import Foundation
import GameKit
import NeonEngine

/// A transport that can also say when the other side went away (the engine's
/// `NetTransport` only carries messages). `NetSession` uses it for `onClosed`.
protocol DisconnectReporting: AnyObject {
    var onDisconnect: (() -> Void)? { get set }
}

/// `NetTransport` over a connected `GKMatch`: the iOS counterpart of the
/// WebRTC data channel in net.js. Every message goes reliable (ordered), as
/// the snapshot design sends each new entity's full record exactly once and
/// the deltas after it must not overtake it.
///
/// GameKit invokes the delegate on arbitrary queues; the class is therefore
/// nonisolated and lock-free by design (the only mutable state is the open
/// flag and the callbacks, which are set from the main actor before use), and
/// every callback is delivered on the main queue in arrival order.
nonisolated final class GameKitTransport: NSObject, NetTransport, DisconnectReporting, GKMatchDelegate, @unchecked Sendable {
    let match: GKMatch

    /// Called on the main actor for every decoded message, in arrival order.
    var onReceive: ((NetMessage) -> Void)?
    /// Called on the main actor once when the peer drops or the match fails.
    var onDisconnect: (() -> Void)?

    private let state = Locked(State())

    private struct State {
        var isOpen = true
        var disconnectReported = false
    }

    init(match: GKMatch) {
        self.match = match
        super.init()
        match.delegate = self
    }

    var isOpen: Bool { state.withLock { $0.isOpen } }

    /// The other pilot's `gamePlayerID`, to compare with the one the lobby
    /// relayed through `signal` ({type:'gc', gamePlayerID}).
    var peerPlayerID: String? {
        match.players.first?.gamePlayerID
    }

    var peerDisplayName: String? {
        match.players.first?.displayName
    }

    // MARK: - NetTransport

    @discardableResult
    func send(_ message: NetMessage) -> Bool {
        guard isOpen else { return false }
        do {
            let data = try WireCodec.encode(message)
            try match.sendData(toAllPlayers: data, with: .reliable)
            return true
        } catch {
            return false
        }
    }

    func close() {
        let wasOpen = state.withLock { s -> Bool in
            let was = s.isOpen
            s.isOpen = false
            s.disconnectReported = true // a close we asked for is not a drop
            return was
        }
        guard wasOpen else { return }
        match.delegate = nil
        match.disconnect()
    }

    // MARK: - Inbound (factored so tests can drive it without a GKMatch)

    /// Decode `data` and hand the message to `onReceive` on the main queue.
    /// Undecodable data is dropped. Returns the decoded message (for tests).
    @discardableResult
    func deliver(_ data: Data) -> NetMessage? {
        guard isOpen, let message = try? WireCodec.decode(data) else { return nil }
        DispatchQueue.main.async { [self] in
            guard isOpen else { return }
            onReceive?(message)
        }
        return message
    }

    /// Mark the link dead and report it once, on the main queue.
    func reportDisconnect() {
        let first = state.withLock { s -> Bool in
            let first = !s.disconnectReported
            s.disconnectReported = true
            s.isOpen = false
            return first
        }
        guard first else { return }
        DispatchQueue.main.async { [self] in
            onDisconnect?()
        }
    }

    // MARK: - GKMatchDelegate

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        deliver(data)
    }

    func match(_ match: GKMatch, didReceive data: Data, forRecipient recipient: GKPlayer, fromRemotePlayer player: GKPlayer) {
        deliver(data)
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        if state == .disconnected { reportDisconnect() }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        reportDisconnect()
    }

    func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
        false
    }
}

/// A tiny lock box (iOS 17 has no `Mutex`).
nonisolated final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
