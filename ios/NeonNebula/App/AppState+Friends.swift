import Foundation

// The Friends page: invites out, invites in, join by code (ui.js:1993-2124).
// The inbox is polled every 5 s while the page is open and every 20 s from
// the start screen (for the badge), never mid-mission.

extension AppState {
    /// The notice under the Game Center gate (section F of the port notes).
    nonisolated static let gameCenterNotice = "Online play needs Game Center — sign in under Settings > Game Center"
    nonisolated static let badCodeMessage = "Game codes are 4 to 12 letters or numbers."

    /// Friends and the online lobby need an account (ui.js:1996, 2129).
    func openFriends() {
        guard session.user != nil else { openModal(.auth); return }
        friendsInviteNotice = nil
        friendsJoinError = nil
        if let online, online.isHost, online.status == "open", inviteCodeField.isEmpty {
            inviteCodeField = online.code
        }
        modal = .friends
        refreshInbox()
        startInboxPolling(LobbyService.inboxPollOpen)
    }

    func closeFriends() {
        modal = nil
        startInboxPolling(LobbyService.inboxPollIdle)
    }

    // MARK: Inbox (ui.js:2015-2041)

    func startInboxPolling(_ interval: TimeInterval) {
        stopInboxPolling()
        guard session.user != nil else { return }
        inboxPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let self else { return }
                if self.phase == .start { await self.fetchInbox() }
            }
        }
    }

    func stopInboxPolling() {
        inboxPollTask?.cancel()
        inboxPollTask = nil
    }

    /// Fire-and-forget refresh (the web's `refreshInbox`).
    func refreshInbox() {
        guard session.user != nil else { return }
        Task { await fetchInbox() }
    }

    /// One inbox round trip: pending invites plus the lobby this account is
    /// already sitting in (say, after a relaunch).
    func fetchInbox() async {
        guard session.user != nil else { return }
        do {
            let data = try await lobby.inbox()
            guard session.user != nil else { return }
            pendingInvites = data.invites
            if online == nil, let game = data.game, game.status == "open", let you = game.you,
               let role = OnlineRoleName(rawValue: you) {
                online = OnlineLobby(game: game, role: role)
            }
        } catch {
            if (error as? APIError)?.isUnauthorized == true { sessionExpired() }
        }
    }

    /// The Friends button's badge count (renderFriendsBadge, ui.js:2037-2041).
    var friendsBadgeCount: Int {
        session.user == nil ? 0 : pendingInvites.count
    }

    // MARK: Invites (ui.js:2094-2124)

    /// SEND INVITE. Field checks match the web's before the request goes out.
    func sendInvite(username: String, code rawCode: String) {
        friendsInviteNotice = nil
        friendsInviteOK = false
        let name = username.trimmingCharacters(in: .whitespaces)
        let code = LobbyService.cleanCode(rawCode)
        inviteCodeField = code
        if name.isEmpty { friendsInviteNotice = "Type your friend's username."; return }
        if code.count < 4 { friendsInviteNotice = Self.badCodeMessage; return }
        Task {
            do {
                let data = try await lobby.invite(username: name, code: code)
                friendsInviteOK = true
                friendsInviteNotice = "Invite sent to \(data.to) for game \(data.code). They will see it on their Friends page."
            } catch {
                friendsInviteOK = false
                friendsInviteNotice = noteError(error)
            }
        }
    }

    /// NO THANKS on an invite row.
    func declineInvite(_ invite: APIInvite) {
        pendingInvites.removeAll { $0.id == invite.id }
        Task { [lobby] in _ = try? await lobby.decline(id: invite.id) }
    }

    /// JOIN GAME / an invite's JOIN: take the guest seat and wait in the
    /// lobby. Server messages (including `platform_mismatch`) show verbatim.
    func joinByCode(_ rawCode: String) {
        friendsJoinError = nil
        let code = LobbyService.cleanCode(rawCode)
        if code.count < 4 { friendsJoinError = Self.badCodeMessage; return }
        Task { await joinLobby(code: code) }
    }

    func joinLobby(code: String) async {
        guard await ensureGameCenter() else { return }
        do {
            let game = try await lobby.join(code: code)
            online = OnlineLobby(game: game, role: .guest)
            menuMode = .twoPlayer
            openLobbyWait()
        } catch {
            friendsJoinError = noteError(error)
        }
    }

    /// Game Center must be signed in before any lobby seat is taken.
    func ensureGameCenter() async -> Bool {
        if await matchmaking.authenticate() { return true }
        notice = Self.gameCenterNotice
        return false
    }
}
