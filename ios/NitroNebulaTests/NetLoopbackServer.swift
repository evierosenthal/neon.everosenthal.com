import Foundation
import Network
@testable import NeonNebula

/// A one-connection-at-a-time HTTP/1.1 server on 127.0.0.1 for the tests that
/// need URLSession's real HTTP stack (cookie storage and sending happen in
/// CFNetwork's native HTTP layer, which a stub `URLProtocol` bypasses).
nonisolated final class NetLoopbackServer: @unchecked Sendable {
    struct Request: Sendable {
        var method: String
        var path: String
        var headers: [String: String]
        var body: Data

        func header(_ name: String) -> String? {
            headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
    }

    struct Response: Sendable {
        var status = 200
        var headers: [String: String] = ["Content-Type": "application/json; charset=utf-8"]
        var body: String
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "NetLoopbackServer")
    private let state = Locked((requests: [Request](), replies: [Response]()))
    private(set) var port: UInt16 = 0

    init() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        listener = try NWListener(using: params, on: .any)
    }

    var baseURL: URL { URL(string: "http://127.0.0.1:\(port)/api/")! }
    var requests: [Request] { state.withLock { $0.requests } }

    func enqueue(_ response: Response) {
        state.withLock { $0.replies.append(response) }
    }

    func start() async throws {
        listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Locked(false)
            listener.stateUpdateHandler = { [listener] newState in
                switch newState {
                case .ready:
                    if once.withLock({ let was = $0; $0 = true; return !was }) {
                        self.port = listener.port?.rawValue ?? 0
                        continuation.resume()
                    }
                case .failed(let error):
                    if once.withLock({ let was = $0; $0 = true; return !was }) {
                        continuation.resume(throwing: error)
                    }
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    func stop() {
        listener.cancel()
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        var buffer = Data()
        func receive() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [self] data, _, isComplete, error in
                if let data { buffer.append(data) }
                if let request = parse(buffer) {
                    respond(to: request, on: connection)
                } else if isComplete || error != nil {
                    connection.cancel()
                } else {
                    receive()
                }
            }
        }
        receive()
    }

    /// Returns the request once the head and the whole body have arrived.
    private func parse(_ data: Data) -> Request? {
        guard let headEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: data[data.startIndex..<headEnd.lowerBound], as: UTF8.self)
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[String(line[..<colon])] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers.first { $0.key.caseInsensitiveCompare("Content-Length") == .orderedSame }?.value ?? "0") ?? 0
        let body = data[headEnd.upperBound...]
        guard body.count >= length else { return nil }
        return Request(method: String(requestLine[0]), path: String(requestLine[1]), headers: headers, body: Data(body.prefix(length)))
    }

    private func respond(to request: Request, on connection: NWConnection) {
        let reply: Response = state.withLock { s in
            s.requests.append(request)
            return s.replies.isEmpty ? Response(body: "{}") : s.replies.removeFirst()
        }
        let body = Data(reply.body.utf8)
        var head = "HTTP/1.1 \(reply.status) \(reply.status == 200 ? "OK" : "Error")\r\n"
        for (name, value) in reply.headers { head += "\(name): \(value)\r\n" }
        head += "Content-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
