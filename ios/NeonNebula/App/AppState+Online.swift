import Foundation
import NeonEngine

// The online round (ui.js:2283-2393) over Game Center instead of WebRTC.
// The server lobby pairs the two accounts; `matchmaking.connect` links the
// two phones; then the same handshake as the web runs on the data channel:
//
//   guest -> hello          host -> hello, go       guest launches -> ready
//   host launches on ready, so its first snapshot lands on a live guest.
//
// The host's engine simulates and streams snapshots (`engine(_:send:)`);
// the guest applies them and sends back Pilot 2's steering.

extension AppState {
    enum OnlineError: Error, LocalizedError {
        /// Game Center paired us with someone other than the lobby's other seat.
        case wrongPeer
        /// The pilot who said hello is not the account in the other seat.
        case wrongPilot(String)

        var errorDescription: String? {
            switch self {
            case .wrongPeer: return "Could not link to your friend's Game Center player. Try again."
            case .wrongPilot(let name): return "A different pilot (\(name)) connected. Try again."
            }
        }
    }

    /// How long to keep asking the lobby for the other side's player id
    /// before accepting whoever Game Center matched us with.
    nonisolated static let peerIDGrace: TimeInterval = 6

    // MARK: Connect (beginOnlineGame, ui.js:2289-2309)

    func beginOnlineGame() {
        guard let current = online else { return }
        stopLobbyPolling()
        lobbyPhase = .connecting
        modal = .lobby
        connectTask?.cancel()
        let code = current.code
        let role = current.role
        connectTask = Task { await connectOnline(code: code, role: role) }
    }

    func connectOnline(code: String, role: OnlineRoleName) async {
        do {
            // Tell the other side who to expect from Game Center.
            if let myID = matchmaking.gamePlayerID {
                _ = try? await lobby.signal(code: code, payload: .gameCenter(gamePlayerID: myID))
            }
            var link: OnlineLink?
            var attempt = 0
            while link == nil {
                attempt += 1
                let candidate = try await matchmaking.connect(code: code, role: role)
                guard online?.code == code else { candidate.transport.close(); return }
                let expected = await expectedPeerID(code: code)
                if let expected, let got = candidate.peerPlayerID, got != expected {
                    candidate.transport.close()
                    if attempt >= 2 { throw OnlineError.wrongPeer }
                    continue // one more try with a fresh match
                }
                link = candidate
            }
            guard let link else { return }
            guard online?.code == code, !Task.isCancelled else { link.transport.close(); return }
            let net = NetSession(transport: link.transport)
            netSession = net
            peerHello = nil
            net.onMessage = { [weak self] message in self?.handleNetMessage(message) }
            net.onClosed = { [weak self] reason in self?.handleNetClosed(reason: reason) }
            let gear = loadout1
            net.send(.hello(.init(name: session.user?.username ?? "", skin: gear.skin, trail: gear.trail, flame: gear.flame)))
        } catch is CancellationError {
            return
        } catch {
            guard online?.code == code else { return }
            Task { [lobby] in _ = try? await lobby.leave(code: code) }
            let message = (error as? APIError)?.message ?? (error as? LocalizedError)?.errorDescription ?? "Could not connect."
            leaveLobby(notifyServer: false, message: message)
        }
    }

    /// The other seat's `gamePlayerID`, relayed through the lobby's signal
    /// channel. Polled for a short grace period; nil if it never arrives.
    func expectedPeerID(code: String) async -> String? {
        let deadline = Date().addingTimeInterval(Self.peerIDGrace)
        var after = 0
        repeat {
            if let reply = try? await lobby.signals(code: code, after: after) {
                for message in reply.messages {
                    after = max(after, message.id)
                    if message.payload.type == "gc", let id = message.payload.gamePlayerID { return id }
                }
            }
            guard online?.code == code, !Task.isCancelled else { return nil }
            try? await Task.sleep(for: .seconds(LobbyService.signalPoll))
        } while Date() < deadline && !Task.isCancelled
        return nil
    }

    // MARK: Handshake (handleNetMessage, ui.js:2314-2330)

    func handleNetMessage(_ message: NetMessage) {
        guard let current = online else { return }
        switch message {
        case .hello(let hello):
            // The pilot saying hello must be the account in the other seat.
            let otherSeat = current.isHost ? current.game?.guest : current.game?.host
            if let otherSeat, hello.name != otherSeat {
                let code = current.code
                netSession?.close()
                netSession = nil
                Task { [lobby] in _ = try? await lobby.leave(code: code) }
                leaveLobby(notifyServer: false, message: OnlineError.wrongPilot(hello.name).errorDescription)
                return
            }
            peerHello = hello
            if current.isHost { netSession?.send(.go) }
        case .go:
            if !current.isHost, peerHello != nil, !isOnlineGame { launchOnlineGame() }
        case .ready:
            if current.isHost, peerHello != nil, !isOnlineGame { launchOnlineGame() }
        case .bye:
            handleNetClosed(reason: "bye")
        case .input, .snapshot:
            if isOnlineGame { engine.receive(message) }
        }
    }

    // MARK: Launch (launchOnlineGame, ui.js:2332-2371)

    func launchOnlineGame() {
        guard let current = online else { return }
        let role = current.role
        let mine = loadout1
        let theirs = peerHello.map { LoadoutIDs(skin: $0.skin, trail: $0.trail, flame: $0.flame) } ?? LoadoutIDs()
        modal = nil
        lobbyPhase = .setup
        isOnlineGame = true
        connectionLost = false

        let diff = current.mode.difficulty
        score = 0
        health = 100
        pendingHUDScore = nil
        pendingHUDHealth = nil
        pendingGameOver = nil
        difficulty = diff
        currentMode = current.mode.tier.duoMode
        liveTier = currentMode.tier
        audio.rewindMusic()
        isLocalMultiplayer = false
        isCPUMultiplayer = false

        // Host flies as pilot 1 in its own gear; the guest is pilot 2 in theirs.
        let p1 = (role == .host ? mine : theirs).resolved
        let p2 = (role == .host ? theirs : mine).resolved
        var config = GameConfig()
        config.initialDifficulty = diff
        config.controlModePreference = .keyboard
        config.speedFactor = Double(speedPercent) / 100
        config.skin = p1.skin
        config.trail = p1.trail
        config.flame = p1.flame
        config.skin2 = p2.skin
        config.trail2 = p2.trail
        config.flame2 = p2.flame
        config.online = role == .host ? .host : .guest

        phase = .playing
        isPaused = false
        sendReadyOnLaunch = role == .guest
        pendingStart = config
        if let size = canvasSize { launchPendingStart(worldSize: size) }
        sync()
    }

    /// The engine is running with an online config: the guest can now take
    /// snapshots, so it tells the host to start simulating.
    func onlineEngineDidStart() {
        guard sendReadyOnLaunch else { return }
        sendReadyOnLaunch = false
        netSession?.send(.ready)
        netSession?.expectingSnapshots = true
    }

    // MARK: Link lost (handleNetClosed, ui.js:2373-2384)

    func handleNetClosed(reason: String) {
        let closing = netSession
        netSession = nil
        if isOnlineGame && phase == .playing {
            connectionLost = true
            handleGameOver(score: engine.score)
        } else if lobbyPhase == .connecting || (online?.status == "started" && !isOnlineGame) {
            if let code = online?.code { Task { [lobby] in _ = try? await lobby.leave(code: code) } }
            leaveLobby(notifyServer: false, message: "The connection dropped (\(reason)).")
        }
        closing?.close()
    }

    /// Tidy up after an online round (endOnlineGame, ui.js:2387-2393;
    /// called from handleGameOver).
    func endOnlineGame() {
        if let code = online?.code { Task { [lobby] in _ = try? await lobby.finish(code: code) } }
        netSession?.close()
        netSession = nil
        online = nil
        peerHello = nil
        isOnlineGame = false
        sendReadyOnLaunch = false
    }

    /// Backgrounded: an online round can't be paused, so it ends as a lost
    /// connection; an unstarted lobby is left like the web's `beforeunload`
    /// (ui.js:2784-2786).
    func willResignActiveOnlineHook() {
        if isOnlineGame && phase == .playing {
            netSession?.close()
            netSession = nil
            connectionLost = true
            handleGameOver(score: engine.score)
        } else if online != nil && !isOnlineGame {
            leaveLobby(notifyServer: true, message: nil)
        }
    }
}
