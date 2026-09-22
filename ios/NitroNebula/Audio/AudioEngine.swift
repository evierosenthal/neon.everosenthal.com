import AVFoundation
import Foundation

/// The app's mixer (ui.js:496-720): two music loops, three effects, the
/// Settings sliders, and the session plumbing the web doesn't need —
/// interruptions (a phone call) and route changes (headphones unplugged).
@MainActor
final class AudioEngine {
    static let bgMusicLevel: Float = 0.35
    static let homeMusicLevel: Float = 0.22
    static let newHighLevel: Float = 0.8
    static let deathLevel: Float = 0.9
    static let hitLevel: Float = 0.7
    static let deathTail: TimeInterval = 3
    static let hitTail: TimeInterval = 2

    let bgMusic = MusicTrack(resource: "background-music", ext: "m4a", level: AudioEngine.bgMusicLevel)
    let homeMusic = MusicTrack(resource: "home-music", ext: "m4a", level: AudioEngine.homeMusicLevel)
    let fanfare = SoundEffect(resource: "new-high-score", ext: "mp3", level: AudioEngine.newHighLevel)
    let death = SoundEffect(resource: "crash-death", ext: "mp3", level: AudioEngine.deathLevel, tail: AudioEngine.deathTail)
    let hit = SoundEffect(resource: "asteroid-hit", ext: "mp3", level: AudioEngine.hitLevel, tail: AudioEngine.hitTail)

    /// Headphones were unplugged (or another output vanished): the app
    /// pauses the mission so the pilot isn't caught out by sudden silence.
    var onRouteLost: (() -> Void)?

    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init() {
        let session = AVAudioSession.sharedInstance()
        // Ambient: honours the silent switch and mixes with the pilot's own music.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: nil) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            let shouldResume = options.contains(.shouldResume)
            Task { @MainActor [weak self] in
                guard let self, let type else { return }
                switch type {
                case .began: self.interruptionBegan()
                case .ended: self.interruptionEnded(shouldResume: shouldResume)
                @unknown default: break
                }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: nil) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            guard reason == .oldDeviceUnavailable else { return }
            Task { @MainActor [weak self] in self?.routeLost() }
        })

        #if DEBUG
        let missing = [("background-music.m4a", bgMusic.isLoaded), ("home-music.m4a", homeMusic.isLoaded),
                       ("new-high-score.mp3", fanfare.isLoaded), ("crash-death.mp3", death.isLoaded),
                       ("asteroid-hit.mp3", hit.isLoaded)].filter { !$0.1 }.map(\.0)
        NSLog("AudioEngine: %d/5 sound files loaded%@", 5 - missing.count,
              missing.isEmpty ? "" : " — missing: " + missing.joined(separator: ", "))
        #endif
    }

    deinit {
        // Observers are token objects; removing them is safe from any thread.
        let center = NotificationCenter.default
        for o in observers { center.removeObserver(o) }
    }

    // MARK: Settings (applyAudioSettings, ui.js:689-700)

    func applySettings(musicPercent: Int, sfxPercent: Int) {
        let music = Float(max(0, min(100, musicPercent))) / 100
        let sfx = Float(max(0, min(100, sfxPercent))) / 100
        bgMusic.setVolume(scale: music, muted: music == 0)
        homeMusic.setVolume(scale: music, muted: music == 0)
        for effect in [fanfare, death, hit] { effect.setVolume(scale: sfx, muted: sfx == 0) }
    }

    // MARK: Music (ui.js:643-661)

    func setMusicPlaying(_ playing: Bool) {
        if playing { bgMusic.play() } else { bgMusic.pause() }
    }

    func setHomeMusicPlaying(_ playing: Bool) {
        if playing { homeMusic.play() } else { homeMusic.pause() }
    }

    /// Each mission starts the gameplay loop from the top (ui.js:1921).
    func rewindMusic() {
        bgMusic.rewind()
    }

    // MARK: Effects

    func playHit() { hit.play() }
    func playDeath() { death.play() }

    func playFanfare() {
        fanfare.stop()
        fanfare.play()
    }

    func stopFanfare() {
        fanfare.stop()
    }

    // MARK: Session events

    private func interruptionBegan() {
        bgMusic.suspend()
        homeMusic.suspend()
    }

    private func interruptionEnded(shouldResume: Bool) {
        try? AVAudioSession.sharedInstance().setActive(true)
        guard shouldResume else { return }
        bgMusic.resumeIfWanted()
        homeMusic.resumeIfWanted()
    }

    private func routeLost() {
        onRouteLost?()
    }
}
