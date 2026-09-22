import Foundation

/// The HTTP layer under every api/*.php call: the port of `request()` and
/// `post()` in www/auth.js (auth.js:29-56).
///
/// One persistent cookie jar (the PHP session cookie `neon_sid`, 30 days,
/// HttpOnly) and one CSRF token, which the server rotates on every login and
/// logout; any response carrying a `csrf` field replaces the stored one.
/// GETs send no CSRF header, POSTs always do (`X-CSRF-Token`). No `Origin`
/// header is ever set: _bootstrap.php only checks Origin when it is present,
/// and a native app has none.
///
/// This is a real actor (not main-actor bound) so the app can fire lobby polls
/// and score submissions without touching the render loop's thread.
actor APIClient {
    static let defaultBaseURL = URL(string: "https://neon.everosenthal.com/api/")!

    /// submit-score.php refuses a second score inside this window
    /// (SCORE_MIN_INTERVAL_SEC in www/config.php).
    nonisolated static let scoreMinIntervalSec: TimeInterval = 10

    /// The api/ directory every path is resolved against (trailing slash).
    nonisolated let baseURL: URL
    nonisolated let session: URLSession

    /// The current CSRF token (from session.php, rotated by login/logout).
    private(set) var csrf: String?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    /// - Parameters:
    ///   - baseURL: where api/ lives; override for a `php -S localhost:8000` server.
    ///   - session: defaults to `makeSession()` (shared cookie jar). Tests pass
    ///     a session with a private cookie jar and a stub `URLProtocol`.
    init(baseURL: URL = APIClient.defaultBaseURL, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.session = session ?? APIClient.makeSession()
    }

    /// The URLSession every client shares: persistent cookies, no HTTP cache
    /// (session state and CSRF tokens must never be served stale), app
    /// User-Agent, 15 s per request / 30 s per resource.
    ///
    /// `ephemeral: true` gives the session its own in-memory cookie jar
    /// (`session.configuration.httpCookieStorage`) instead of the shared one;
    /// tests use it so they never touch the real login cookie.
    nonisolated static func makeSession(cookieStorage: HTTPCookieStorage = .shared,
                                        protocolClasses: [AnyClass]? = nil,
                                        ephemeral: Bool = false) -> URLSession {
        let config = ephemeral ? URLSessionConfiguration.ephemeral : URLSessionConfiguration.default
        if !ephemeral { config.httpCookieStorage = cookieStorage }
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept": "application/json",
        ]
        if let protocolClasses { config.protocolClasses = protocolClasses }
        return URLSession(configuration: config)
    }

    /// `NitroNebula-iOS/<CFBundleShortVersionString> (<CFBundleVersion>)`
    nonisolated static var userAgent: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        return "NitroNebula-iOS/\(short) (\(build))"
    }

    // MARK: - Requests

    /// GET `path?query`. No CSRF header (auth.js:95-97).
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var request = URLRequest(url: url(for: path, query: query))
        request.httpMethod = "GET"
        return try await perform(request)
    }

    /// POST a JSON body with the CSRF token (auth.js:46-56). The body is
    /// `{}` when `body` is nil, as the web sends for logout / run-migrations.
    func post<T: Decodable & Sendable>(_ path: String, body: some Encodable & Sendable) async throws -> T {
        var request = URLRequest(url: url(for: path, query: [:]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(csrf ?? "", forHTTPHeaderField: "X-CSRF-Token")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    /// POST `{}`.
    func post<T: Decodable & Sendable>(_ path: String) async throws -> T {
        try await post(path, body: EmptyBody())
    }

    /// Replace the CSRF token (normally done automatically from responses).
    func setCSRF(_ token: String?) {
        csrf = token
    }

    // MARK: - Internals

    nonisolated func url(for path: String, query: [String: String]) -> URL {
        let url = baseURL.appendingPathComponent(path)
        guard !query.isEmpty, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        comps.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
        return comps.url ?? url
    }

    private func perform<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // fetch() rejected: the web flips state.offline (auth.js:116-120).
            throw APIError.offline(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let headers = (response as? HTTPURLResponse)?.allHeaderFields ?? [:]
        let (value, token): (T, String?) = try Self.map(data: data, status: status, headers: headers, decoder: decoder)
        if let token { csrf = token }
        return value
    }

    /// The status/body → value-or-APIError rules of auth.js:29-44, plus the
    /// `csrf` field a response may carry. Factored so tests can drive them
    /// without a socket.
    nonisolated static func map<T: Decodable>(data: Data, status: Int, headers: [AnyHashable: Any],
                                              decoder: JSONDecoder) throws -> (T, csrf: String?) {
        if (200..<300).contains(status) {
            let token = (try? decoder.decode(CSRFCarrier.self, from: data))?.csrf.flatMap { $0.isEmpty ? nil : $0 }
            do {
                return (try decoder.decode(T.self, from: data), token)
            } catch {
                throw APIError.serverError(status: status)
            }
        }
        // Non-2xx: `{error, message}` from json_error(), else server_error.
        guard let body = try? decoder.decode(APIError.Body.self, from: data) else {
            throw APIError.serverError(status: status)
        }
        var error = APIError(code: body.error ?? "server_error",
                             message: body.message ?? "Request failed",
                             status: status)
        if status == 429 || error.code == "rate_limited" {
            error.code = "rate_limited"
            error.retryAfter = retryAfter(from: headers) ?? scoreMinIntervalSec
        }
        throw error
    }

    nonisolated private static func retryAfter(from headers: [AnyHashable: Any]) -> TimeInterval? {
        for (key, value) in headers {
            guard let name = key as? String, name.caseInsensitiveCompare("Retry-After") == .orderedSame else { continue }
            if let text = value as? String, let seconds = TimeInterval(text.trimmingCharacters(in: .whitespaces)) {
                return seconds
            }
        }
        return nil
    }

    nonisolated private struct CSRFCarrier: Decodable {
        var csrf: String?
    }
}

/// `{}`: the body of logout.php / run-migrations.php posts.
nonisolated struct EmptyBody: Encodable, Sendable {
    init() {}
    func encode(to encoder: Encoder) throws {
        _ = encoder.container(keyedBy: CodingKeys.self)
    }
    private enum CodingKeys: CodingKey {}
}
