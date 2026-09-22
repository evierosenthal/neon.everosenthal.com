import Foundation
import NitroEngine

// The settings modal (ui.js:1321-1334, 2450-2480, 2811-2830) and the
// account and lead-developer actions it hosts.

extension AppState {
    /// The settings launcher: never let the pilot die while fiddling with
    /// settings mid-flight (ui.js:2811-2819).
    func openSettings() {
        isSettingsOpen = true
        if phase == .playing && !isPaused {
            settingsAutoPaused = true
            setPaused(true)
        }
    }

    /// Resume only if it was our auto-pause; a manual pause stays paused.
    func closeSettings() {
        isSettingsOpen = false
        if settingsAutoPaused {
            settingsAutoPaused = false
            if phase == .playing { setPaused(false) }
        }
    }

    /// Rocket speed, 1...300 percent (applySpeedSetting, ui.js:1321-1325).
    func setSpeedPercent(_ percent: Int) {
        let pct = max(1, min(300, percent))
        speedPercent = pct
        store.speedPercent = pct
        engine.setSpeedFactor(Double(pct) / 100)
    }

    func setMusicPercent(_ percent: Int) {
        musicPercent = max(0, min(100, percent))
        store.musicPercent = musicPercent
        audio.applySettings(musicPercent: musicPercent, sfxPercent: sfxPercent)
    }

    func setSfxPercent(_ percent: Int) {
        sfxPercent = max(0, min(100, percent))
        store.sfxPercent = sfxPercent
        audio.applySettings(musicPercent: musicPercent, sfxPercent: sfxPercent)
    }

    /// The slider's readout: "OFF" at zero (ui.js:692-693).
    static func volumeLabel(_ percent: Int) -> String {
        percent == 0 ? "OFF" : "\(percent)%"
    }

    // MARK: Account actions (ui.js:2633-2635, api/delete-account.php)

    /// The user chip's Logout link and the settings LOG OUT button. The
    /// account history flag stays so the corner button still says LOG IN.
    func logout() {
        let hadSession = session.user != nil
        session.user = nil
        pendingInvites = []
        stopInboxPolling()
        if online != nil { leaveLobby(notifyServer: true, message: nil) }
        enforceOwnedGear()
        google.signOut()
        guard hadSession else { return }
        Task { [auth] in
            try? await auth.logout() // stale session — chip already cleared
        }
    }

    /// Settings → DELETE ACCOUNT…: ask first; password accounts then type
    /// their password, Apple accounts re-authorize for a fresh code.
    func deleteAccountTapped() {
        guard session.user != nil else { return }
        deleteAccountStep = .confirm
    }

    /// The confirmation's DELETE: branch on how the account signs in.
    func deleteAccountConfirmed() {
        if session.user?.hasPassword == true {
            deleteAccountStep = .password
        } else {
            performDeleteAccount(password: nil)
        }
    }

    func cancelDeleteAccount() {
        deleteAccountStep = .none
    }

    func performDeleteAccount(password: String?) {
        deleteAccountStep = .working
        Task { await deleteAccount(password: password) }
    }

    func deleteAccount(password: String?) async {
        var appleCode: String?
        if session.user?.provider == "apple" {
            // A fresh authorization lets the server revoke Apple's grant; if
            // the pilot cancels, the server still deletes the account.
            appleCode = (try? await apple.reauthorize())?.authorizationCode
        }
        do {
            try await auth.deleteAccount(password: password, appleAuthorizationCode: appleCode)
        } catch {
            deleteAccountStep = .none
            notice = noteError(error)
            return
        }
        try? await google.disconnect()
        deleteAccountStep = .none
        session.user = nil
        pendingInvites = []
        stopInboxPolling()
        isSettingsOpen = false
        enforceOwnedGear()
        notice = "Account deleted"
    }

    // MARK: Lead developer console (api/set-role.php, api/run-migrations.php)

    /// Developer console → MAKE DEV / REMOVE DEV.
    func setRole(username: String, role: String) {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            devConsoleIsError = true
            devConsoleMessage = "Enter a pilot username first."
            return
        }
        devConsoleIsError = false
        devConsoleMessage = "Working…"
        Task {
            do {
                let result = try await auth.setRole(username: name, role: role)
                devConsoleIsError = false
                devConsoleMessage = "\(result.username) is now \(result.role == "developer" ? "a developer" : "a normal pilot")."
            } catch {
                devConsoleIsError = true
                devConsoleMessage = noteError(error)
            }
        }
    }

    /// Developer console → RUN DB MIGRATIONS.
    func runMigrations() {
        devConsoleIsError = false
        devConsoleMessage = "Running migrations…"
        Task {
            do {
                let result = try await auth.runMigrations()
                let lines = result.results.keys.sorted().map { "\($0): \(result.results[$0] ?? "")" }
                devConsoleIsError = false
                devConsoleMessage = lines.isEmpty ? "No migrations to run." : lines.joined(separator: "\n")
            } catch {
                devConsoleIsError = true
                devConsoleMessage = noteError(error)
            }
        }
    }
}
