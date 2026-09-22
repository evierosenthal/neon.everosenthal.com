import Foundation

/// A two-way link to the other pilot. The app provides a GameKit-backed one;
/// tests use `LoopbackTransport` to wire two engines together in-process.
public protocol NetTransport: AnyObject {
    /// Deliver a message to the other side. Returns false if the link is gone.
    @discardableResult
    func send(_ message: NetMessage) -> Bool
    /// Called for every message from the other side (on the caller's thread).
    var onReceive: ((NetMessage) -> Void)? { get set }
    func close()
}

/// In-process pair of transports for tests: what one sends, the other receives.
public final class LoopbackTransport: NetTransport {
    public var onReceive: ((NetMessage) -> Void)?
    public private(set) var isOpen = true
    weak var peer: LoopbackTransport?
    /// Messages queued until `flush()` (so tests control ordering/timing).
    public private(set) var outbox: [NetMessage] = []
    public var sentCount = 0

    public init() {}

    public static func pair() -> (LoopbackTransport, LoopbackTransport) {
        let a = LoopbackTransport(), b = LoopbackTransport()
        a.peer = b; b.peer = a
        return (a, b)
    }

    @discardableResult
    public func send(_ message: NetMessage) -> Bool {
        guard isOpen, peer?.isOpen == true else { return false }
        outbox.append(message)
        sentCount += 1
        return true
    }

    /// Deliver queued messages to the peer, in order.
    public func flush() {
        let pending = outbox
        outbox.removeAll()
        for m in pending { peer?.onReceive?(m) }
    }

    public func close() {
        isOpen = false
        outbox.removeAll()
    }
}
