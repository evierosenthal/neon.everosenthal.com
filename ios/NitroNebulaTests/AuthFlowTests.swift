import Foundation
import NitroEngine
import XCTest
@testable import NitroNebula

nonisolated final class AuthFlowTests: XCTestCase {
    private let server = FakeServer()

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        server.install()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    @MainActor func testBootstrapLoggedInMergesBestsAndSetsHasAccount() async {
        server.set { k in
            k.loggedIn = true
            k.userJSON = """
            {"id":7,"username":"eve","role":"developer","provider":"password","hasPassword":true,
             "bestScores":{"easy":10,"medium":900,"hard":0,"super":0,"2p_easy":0,"2p_medium":0,"2p_hard":0,"2p_super":0}}
            """
        }
        let (app, _, defaults) = AppStateFixtures.makeApp(suite: "AuthFlow.bootstrap")
        app.highScores[.medium] = 300
        app.highScores[.easy] = 50
        XCTAssertFalse(app.hasAccount)

        await app.bootstrapSession()
        XCTAssertEqual(app.session.user?.username, "eve")
        XCTAssertEqual(app.session.csrf, "tok")
        XCTAssertFalse(app.session.offline)
        XCTAssertTrue(app.isDeveloper)
        XCTAssertTrue(app.hasAccount)
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_has_account"), "1")
        // Server bests only ever raise the local records.
        XCTAssertEqual(app.highScores[.medium], 900)
        XCTAssertEqual(app.highScores[.easy], 50)
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_highscore_medium"), "900")
        XCTAssertNotNil(app.inboxPollTask)
        app.stopInboxPolling()
    }

    @MainActor func testBootstrapOfflineMarksSessionOffline() async {
        StubURLProtocol.respond { _ in .failure(URLError(.notConnectedToInternet)) }
        let (app, _, _) = AppStateFixtures.makeApp(suite: "AuthFlow.offline")
        await app.bootstrapSession()
        XCTAssertNil(app.session.user)
        XCTAssertTrue(app.session.offline)
        XCTAssertFalse(app.hasAccount)
    }

    @MainActor func testLoginErrorMessageSurfacesVerbatim() async {
        server.set { k in
            k.loginReply = .json(403, "{\"error\":\"use_google\",\"message\":\"This account signs in with Google — use the Google button.\"}")
        }
        let (app, _, _) = AppStateFixtures.makeApp(suite: "AuthFlow.loginError")
        do {
            try await app.login(usernameOrEmail: "eve", password: "pw")
            XCTFail("expected a failure")
        } catch let failure as AuthFailure {
            XCTAssertEqual(failure.message, "This account signs in with Google — use the Google button.")
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertNil(app.session.user)

        // A successful login closes the modal and remembers the account.
        server.set { $0.loginReply = nil }
        app.openModal(.auth)
        try? await app.login(usernameOrEmail: "eve", password: "pw")
        XCTAssertEqual(app.session.user?.username, "eve")
        XCTAssertNil(app.modal)
        XCTAssertTrue(app.hasAccount)
        app.stopInboxPolling()
    }

    @MainActor func testDecideNewHighPhasePerState() async {
        let (app, _, _) = AppStateFixtures.makeApp(suite: "AuthFlow.decide")
        app.pendingScore = 120
        app.pendingMode = .easy

        // Logged out, server reachable → offer.
        app.session.user = nil
        app.session.offline = false
        app.decideNewHighPhase()
        XCTAssertEqual(app.newHighPhase, .offer)

        // Offline → nothing to offer.
        app.session.offline = true
        app.decideNewHighPhase()
        XCTAssertEqual(app.newHighPhase, .none)

        // Logged in → submitting, then the result.
        app.session.offline = false
        app.session.user = AppStateFixtures.eveUser
        app.decideNewHighPhase()
        XCTAssertEqual(app.newHighPhase, .submitting)
        await AppStateFixtures.waitUntil { app.newHighPhase == .result }
        XCTAssertEqual(app.newHighPhase, .result)
        XCTAssertEqual(app.newHighRankText, "GALACTIC RANK #3")
        XCTAssertEqual(app.newHighRows.map(\.username), ["x"])
        XCTAssertNil(app.pendingScore)
        XCTAssertEqual(app.highScores[.easy], 500)
        XCTAssertFalse(app.newHighCanRetry)
    }

    @MainActor func testSubmitPendingScoreRateLimitedOffersRetry() async {
        server.set { k in
            k.scoreReplies = [.json(429, "{\"error\":\"rate_limited\",\"message\":\"Scores can only be submitted every few seconds.\"}",
                                    headers: ["Retry-After": "0"])]
        }
        let (app, _, _) = AppStateFixtures.makeApp(suite: "AuthFlow.rateLimited")
        app.session.user = AppStateFixtures.eveUser
        app.phase = .newHigh
        app.pendingScore = 777
        app.pendingMode = .hard

        app.submitPendingScore()
        XCTAssertEqual(app.newHighPhase, .submitting)
        await AppStateFixtures.waitUntil { app.newHighPhase == .result }
        XCTAssertTrue(app.newHighCanRetry)
        XCTAssertEqual(app.newHighSubmitError, "Transmission failed: Scores can only be submitted every few seconds.")
        XCTAssertEqual(app.pendingScore, 777) // still held for the retry
        XCTAssertNotNil(app.newHighRetryAt)

        app.newHighAction(.retry)
        XCTAssertEqual(app.newHighPhase, .submitting)
        await AppStateFixtures.waitUntil { app.newHighPhase == .result && app.pendingScore == nil }
        XCTAssertNil(app.pendingScore)
        XCTAssertFalse(app.newHighCanRetry)
        XCTAssertNil(app.newHighSubmitError)
        XCTAssertEqual(app.newHighRows.count, 1)
        let submits = StubURLProtocol.requests.filter { $0.url.lastPathComponent == "submit-score.php" }
        XCTAssertEqual(submits.count, 2)
        XCTAssertEqual(submits.last?.json["score"] as? Int, 777)
        XCTAssertEqual(submits.last?.json["mode"] as? String, "hard")
    }

    @MainActor func testNewHighActionsSwitchPhases() {
        let (app, _, _) = AppStateFixtures.makeApp(suite: "AuthFlow.phases")
        app.newHighPhase = .offer
        app.newHighAction(.register)
        XCTAssertEqual(app.newHighPhase, .register)
        app.newHighAction(.backToLogin)
        XCTAssertEqual(app.newHighPhase, .offer)
        app.newHighAction(.forgot)
        XCTAssertEqual(app.newHighPhase, .forgot)
        app.newHighAction(.login)
        XCTAssertEqual(app.newHighPhase, .offer)
        app.newHighAction(.skip)
        XCTAssertEqual(app.newHighPhase, .none)
    }

    @MainActor func testFriendsInboxPopulatesPendingInvites() async {
        server.set { $0.invitesJSON = "[{\"id\":4,\"code\":\"NEBULA\",\"from\":\"bob\",\"mode\":\"hard\"}]" }
        let (app, _, _) = AppStateFixtures.makeApp(suite: "AuthFlow.inbox")
        app.session.user = AppStateFixtures.eveUser
        await app.fetchInbox()
        XCTAssertEqual(app.pendingInvites.map(\.from), ["bob"])
        XCTAssertEqual(app.friendsBadgeCount, 1)

        app.declineInvite(app.pendingInvites[0])
        XCTAssertTrue(app.pendingInvites.isEmpty)
        await AppStateFixtures.waitUntil {
            StubURLProtocol.requests.contains { $0.json["action"] as? String == "decline" && $0.json["id"] as? Int == 4 }
        }
        XCTAssertTrue(StubURLProtocol.requests.contains { $0.json["action"] as? String == "decline" })

        // Logged out, the gate opens the auth modal instead of the page.
        app.session.user = nil
        app.openFriends()
        XCTAssertEqual(app.modal, .auth)
        XCTAssertEqual(app.friendsBadgeCount, 0)
    }

    @MainActor func testUnauthorizedClearsSessionAndRebootstraps() async {
        server.set { $0.loggedIn = false }
        StubURLProtocol.respond { [server] req in
            if req.url.lastPathComponent == "games.php" {
                return .response(.json(401, "{\"error\":\"unauthorized\",\"message\":\"Log in first.\"}"))
            }
            return server.route(req)
        }
        let (app, _, _) = AppStateFixtures.makeApp(suite: "AuthFlow.unauthorized")
        app.session.user = AppStateFixtures.eveUser
        await app.fetchInbox()
        XCTAssertNil(app.session.user)
        await AppStateFixtures.waitUntil { StubURLProtocol.requests.contains { $0.url.lastPathComponent == "session.php" } }
        XCTAssertTrue(StubURLProtocol.requests.contains { $0.url.lastPathComponent == "session.php" })
    }

    @MainActor func testLogoutKeepsAccountHistory() async {
        let (app, _, defaults) = AppStateFixtures.makeApp(suite: "AuthFlow.logout")
        app.session.user = AppStateFixtures.eveUser
        app.hasAccount = true
        defaults.set("1", forKey: "neon_nebula_has_account")
        app.pendingInvites = [APIInvite(id: 1, code: "NEBULA", from: "bob", mode: "easy")]
        app.logout()
        XCTAssertNil(app.session.user)
        XCTAssertTrue(app.pendingInvites.isEmpty)
        XCTAssertTrue(app.hasAccount)
        await AppStateFixtures.waitUntil { StubURLProtocol.requests.contains { $0.url.lastPathComponent == "logout.php" } }
        XCTAssertTrue(StubURLProtocol.requests.contains { $0.url.lastPathComponent == "logout.php" })
    }
}
