import Foundation
@preconcurrency import CoreMotion

@MainActor
final class WristMotionController: ObservableObject {
    private var motionManager: CMMotionManager?
    private var classifier = WristFlickClassifier()

    func start(onFlick: @escaping (WristFlickDirection) -> Void) {
        let manager: CMMotionManager
        if let motionManager {
            manager = motionManager
        } else {
            let newManager = CMMotionManager()
            motionManager = newManager
            manager = newManager
        }

        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        classifier = WristFlickClassifier()
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let timestamp = Date().timeIntervalSinceReferenceDate
            guard let direction = self.classifier.classify(
                accelerationX: motion.userAcceleration.x,
                at: timestamp
            ) else { return }
            onFlick(direction)
        }
    }

    func stop() {
        guard let motionManager, motionManager.isDeviceMotionActive else { return }
        motionManager.stopDeviceMotionUpdates()
    }

    deinit {
        motionManager?.stopDeviceMotionUpdates()
    }
}
