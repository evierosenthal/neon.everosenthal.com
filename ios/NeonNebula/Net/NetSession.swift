import Foundation
import NeonEngine

/// The app-facing face of an online round: the port of net.js's `Session`
/// (`.send(obj)`, `.close()`, `.onMessage`, `.onClose(reason)`), over any
/// `NetTransport` (a `GameKitTransport` in the app, a `LoopbackTransport`
/// in tests).
///
/// Adds a snapshot watchdog: the host streams snapshots at 20 Hz, so once
/// `expectingSnapshots` is on (the guest has launched), five seconds without
/// one means the link is dead even if GameKit has not said so yet.
@MainActor
final class NetSession {
    nonisolated static let defaultSnapshotTimeout: TimeInterval = 5

    private(set) var transport: NetTransport?
    private(set) var isOpen = false

    /// Every message from the other side, in order.
    var onMessage: ((NetMessage) -> Void)?
    /// Called once when the link ends for any reason other than `close()`.
    /// The reason reads like net.js's: "disconnected", "snapshot timeout".
    var onClosed: ((String) -> Void)?

    /// Guest side: turn on after launching; the watchdog then runs.
    var expectingSnapshots = false {
        didSet { expectingSnapshots ? restartWatchdog() : stopWatchdog() }
    }

    /// Seconds without a snapshot before the watchdog closes the session.
    let snapshotTimeout: TimeInterval
    private var watchdog: Task<Void, Never>?
    private(set) var lastSnapshotAt: Date?
    private let now: () -> Date

    init(transport: NetTransport? = nil,
         snapshotTimeout: TimeInterval = NetSession.defaultSnapshotTimeout,
         now: @escaping () -> Date = Date.init) {
        self.snapshotTimeout = snapshotTimeout
        self.now = now
        if let transport { attach(transport) }
    }

    /// Take over a transport; its callbacks route into this session.
    func attach(_ transport: NetTransport) {
        detach()
        self.transport = transport
        isOpen = true
        transport.onReceive = { [weak self] message in
            self?.receive(message)
        }
        if let reporting = transport as? DisconnectReporting {
            reporting.onDisconnect = { [weak self] in
                self?.ended(reason: "disconnected")
            }
        }
    }

    @discardableResult
    func send(_ message: NetMessage) -> Bool {
        guard isOpen, let transport else { return false }
        return transport.send(message)
    }

    /// End the round quietly (no `onClosed`).
    func close() {
        guard isOpen else { return }
        isOpen = false
        stopWatchdog()
        detach()
    }

    // MARK: - Internals

    private func receive(_ message: NetMessage) {
        guard isOpen else { return }
        if case .snapshot = message {
            lastSnapshotAt = now()
            if expectingSnapshots { restartWatchdog() }
        }
        onMessage?(message)
    }

    private func ended(reason: String) {
        guard isOpen else { return }
        isOpen = false
        stopWatchdog()
        detach()
        onClosed?(reason)
    }

    private func detach() {
        if let transport {
            transport.onReceive = nil
            (transport as? DisconnectReporting)?.onDisconnect = nil
            transport.close()
        }
        transport = nil
    }

    private func restartWatchdog() {
        stopWatchdog()
        guard isOpen, expectingSnapshots else { return }
        let timeout = snapshotTimeout
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled, let self else { return }
            self.watchdogFired()
        }
    }

    private func stopWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }

    private func watchdogFired() {
        guard isOpen, expectingSnapshots else { return }
        if let last = lastSnapshotAt, now().timeIntervalSince(last) < snapshotTimeout {
            restartWatchdog()
            return
        }
        ended(reason: "snapshot timeout")
    }
}
