import CoreGraphics
import CoreMotion
import Foundation
import Observation

/// The backdrop's parallax source: the web slides its layers against the
/// cursor (`--px`/`--py` in ±0.7, ui.js:1188-1205); on a device the tilt
/// of the phone stands in, with a drag as the fallback when motion data is
/// unavailable (the simulator).
@Observable @MainActor
final class ParallaxController {
    private(set) var offset = CGPoint.zero
    private(set) var isActive = false
    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var reference: (roll: Double, pitch: Double)? = nil

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let roll = motion.attitude.roll
            let pitch = motion.attitude.pitch
            Task { @MainActor [weak self] in self?.apply(roll: roll, pitch: pitch) }
        }
        isActive = true
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isActive = false
        reference = nil
        offset = .zero
    }

    private func apply(roll: Double, pitch: Double) {
        if reference == nil { reference = (roll, pitch) }
        guard let ref = reference else { return }
        // A few degrees of tilt sweep the full ±0.7 range; landscape swaps
        // the axes relative to the cursor, so pitch drives x and roll y.
        let x = max(-0.7, min(0.7, (pitch - ref.pitch) * 2.0))
        let y = max(-0.7, min(0.7, (roll - ref.roll) * 2.0))
        offset = CGPoint(x: x, y: y)
    }
}
