import Foundation

// The online lobby (ui.js:2126-2281): the host picks a mode and a code and
// opens it, both sides watch who is seated, the host starts. The 2 s status
// poll doubles as the heartbeat the server expects (45 s without one and the
// lobby expires).

extension AppState {
    func openLobby() {
        guard session.user != nil else { openModal(.auth); return }
        lobbySetupMessage = nil
        lobbyMessage = nil
        if let online, online.status == "open" { openLobbyWait(); return }
        lobbyPhase = .setup
        lobbyCodeField = lobby.newGameCode()
        modal = .lobby
    }

    /// NEW CODE.
    func shuffleLobbyCode() {
        lobbyCodeField = lobby.newGameCode()
    }

    /// OPEN LOBBY (createLobby, ui.js:2148-2163).
    func createLobby() {
        lobbySetupMessage = nil
        let code = LobbyService.cleanCode(lobbyCodeField)
        lobbyCodeField = code
        if code.count < 4 { lobbySetupMessage = Self.badCodeMessage; return }
        guard !lobbyBusy else { return }
        lobbyBusy = true
        Task {
            defer { lobbyBusy = false }
            guard await ensureGameCenter() else { return }
            do {
                let game = try await lobby.create(code: code, mode: lobbyModeChoice.rawValue)
                online = OnlineLobby(game: game, role: .host)
                openLobbyWait()
            } catch {
                lobbySetupMessage = noteError(error)
            }
        }
    }

    func openLobbyWait() {
        modal = .lobby
        lobbyPhase = .wait
        lobbyMessage = nil
        startLobbyPolling()
    }

    // MARK: Wait-phase copy (renderLobby, ui.js:2191-2222)

    /// Pilot 2 is seated and online, so the host may START.
    var lobbyReady: Bool {
        guard let g = online?.game else { return false }
        return g.guest != nil && g.guestOnline
    }

    var lobbySubtitle: String {
        guard let online else { return "Two pilots, two screens, one score" }
        if lobbyPhase == .connecting { return "Linking the two screens" }
        return online.isHost ? "You are the host" : "You are Pilot 2"
    }

    var lobbyStatusText: String {
        guard let online else { return "" }
        if lobbyPhase == .connecting { return "Connecting to your friend…" }
        if online.isHost {
            return lobbyReady
                ? "Your friend is in. Press START when you are both ready."
                : "Share the code \(online.code) or invite a friend. The game starts when you say so."
        }
        return "Hosted by \(online.game?.host ?? "?"). The host starts the game — hang tight."
    }

    // MARK: Polling (ui.js:2224-2248)

    func startLobbyPolling() {
        stopLobbyPolling()
        lobbyPollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollLobby()
                try? await Task.sleep(for: .seconds(LobbyService.lobbyPoll))
            }
        }
    }

    func stopLobbyPolling() {
        lobbyPollTask?.cancel()
        lobbyPollTask = nil
    }

    /// One status round trip; the guest launches when the host has started.
    func pollLobby() async {
        guard let current = online, lobbyPhase == .wait else { return }
        do {
            let game = try await lobby.status(code: current.code)
            guard var online, online.code == current.code, lobbyPhase == .wait else { return }
            online.game = game
            online.status = game.status
            self.online = online
            if game.status == "started" && !online.isHost { beginOnlineGame(); return }
            if game.status == "finished" { leaveLobby(notifyServer: false, message: "The host closed the game."); return }
            if !online.isHost && !game.hostOnline { leaveLobby(notifyServer: false, message: "The host left."); return }
        } catch {
            if let api = error as? APIError {
                if api.code == "not_found" || api.code == "forbidden" {
                    leaveLobby(notifyServer: false, message: "That game is gone.")
                } else if api.isUnauthorized {
                    sessionExpired()
                    leaveLobby(notifyServer: false, message: nil)
                }
            }
        }
    }

    /// Leave the lobby (ui.js:2251-2268). `notifyServer` is false when the
    /// server already knows; `message` reopens the setup phase with a notice.
    func leaveLobby(notifyServer: Bool, message: String?) {
        let code = online?.code
        stopLobbyPolling()
        connectTask?.cancel()
        connectTask = nil
        matchmaking.cancel()
        netSession?.close()
        netSession = nil
        if let code, notifyServer {
            Task { [lobby] in _ = try? await lobby.leave(code: code) }
        }
        online = nil
        peerHello = nil
        lobbyPhase = .setup
        if let message {
            modal = .lobby
            lobbyCodeField = lobby.newGameCode()
            lobbySetupMessage = message
        } else if modal == .lobby {
            modal = nil
        }
    }

    /// START (hostStart, ui.js:2270-2281).
    func hostStart() {
        guard let current = online, current.isHost, !lobbyBusy else { return }
        lobbyBusy = true
        Task {
            defer { lobbyBusy = false }
            do {
                let game = try await lobby.start(code: current.code)
                guard var online, online.code == current.code else { return }
                online.game = game
                online.status = "started"
                self.online = online
                beginOnlineGame()
            } catch {
                lobbyMessage = noteError(error)
            }
        }
    }

    /// INVITE A FRIEND: over to the Friends page with the code filled in.
    func inviteFromLobby() {
        stopLobbyPolling()
        inviteCodeField = online?.code ?? ""
        modal = nil
        openFriends()
    }
}
