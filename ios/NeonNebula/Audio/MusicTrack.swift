import AVFoundation
import Foundation

/// A looping music bed (ui.js MusicTrack, L513-631) on an AVAudioPlayer:
/// `level` is the mixed level, the Settings slider scales it, and 0 mutes.
@MainActor
final class MusicTrack {
    let level: Float
    private(set) var scale: Float = 1
    private(set) var muted = false
    /// Should be sounding right now (survives interruptions).
    private(set) var wanted = false
    private var player: AVAudioPlayer?

    init(resource: String, ext: String, level: Float) {
        self.level = level
        if let url = Bundle.main.url(forResource: resource, withExtension: ext),
           let p = try? AVAudioPlayer(contentsOf: url) {
            p.numberOfLoops = -1
            p.volume = level
            p.prepareToPlay()
            player = p
        }
    }

    var isPlaying: Bool { player?.isPlaying ?? false }
    /// The bundled file was found and decoded.
    var isLoaded: Bool { player != nil }

    private var effectiveVolume: Float { muted ? 0 : level * scale }

    func play() {
        wanted = true
        guard let player else { return }
        player.volume = effectiveVolume
        if !player.isPlaying { player.play() }
    }

    func pause() {
        wanted = false
        player?.pause()
    }

    /// Next play starts from the top of the loop (each mission starts fresh).
    func rewind() {
        guard let player else { return }
        let playing = player.isPlaying
        if playing { player.pause() }
        player.currentTime = 0
        if playing { player.play() }
    }

    func setVolume(scale: Float, muted: Bool) {
        self.scale = scale
        self.muted = muted
        player?.volume = effectiveVolume
    }

    /// An interruption ended: resume if we still wanted to be playing.
    func resumeIfWanted() {
        if wanted { play() }
    }

    /// An interruption began: stop the player but keep `wanted`.
    func suspend() {
        player?.pause()
    }
}
