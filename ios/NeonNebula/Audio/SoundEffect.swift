import AVFoundation
import Foundation

/// A one-shot effect (ui.js:663-720). `tail` plays only the file's final
/// seconds, like the crash and whoosh sounds on the web.
@MainActor
final class SoundEffect {
    let level: Float
    let tail: TimeInterval
    private(set) var scale: Float = 1
    private(set) var muted = false
    private var player: AVAudioPlayer?

    init(resource: String, ext: String, level: Float, tail: TimeInterval = 0) {
        self.level = level
        self.tail = tail
        if let url = Bundle.main.url(forResource: resource, withExtension: ext),
           let p = try? AVAudioPlayer(contentsOf: url) {
            p.numberOfLoops = 0
            p.volume = level
            p.prepareToPlay()
            player = p
        }
    }

    var isPlaying: Bool { player?.isPlaying ?? false }
    /// The bundled file was found and decoded.
    var isLoaded: Bool { player != nil }

    func setVolume(scale: Float, muted: Bool) {
        self.scale = scale
        self.muted = muted
        player?.volume = muted ? 0 : level * scale
    }

    /// Seeks to `duration - tail` (or the top) and plays.
    func play() {
        guard let player, !muted else { return }
        player.stop()
        let dur = player.duration
        player.currentTime = (tail > 0 && dur.isFinite && dur > tail) ? dur - tail : 0
        player.volume = level * scale
        player.play()
    }

    func stop() {
        guard let player else { return }
        if player.isPlaying { player.stop() }
        player.currentTime = 0
    }
}
