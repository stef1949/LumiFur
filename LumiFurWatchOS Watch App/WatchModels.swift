import Foundation

enum WatchDestination: String, CaseIterable, Identifiable, Hashable {
    case faces
    case status
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .faces: "Faces"
        case .status: "Status"
        case .settings: "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .faces: "Choose the active display"
        case .status: "Temperature and connection"
        case .settings: "Controller preferences"
        }
    }

    var systemImage: String {
        switch self {
        case .faces: "theatermasks.fill"
        case .status: "chart.xyaxis.line"
        case .settings: "gearshape.fill"
        }
    }
}

enum WatchSessionStatus: Equatable {
    case activating
    case reachable
    case unreachable
    case unsupported
    case failed(String)

    var title: String {
        switch self {
        case .activating: "Connecting to iPhone"
        case .reachable: "iPhone Connected"
        case .unreachable: "iPhone Unavailable"
        case .unsupported: "Watch Connectivity Unavailable"
        case .failed: "Connection Error"
        }
    }

    var systemImage: String {
        switch self {
        case .activating: "arrow.trianglehead.2.clockwise.rotate.90"
        case .reachable: "iphone.radiowaves.left.and.right"
        case .unreachable: "iphone.slash"
        case .unsupported: "exclamationmark.triangle"
        case .failed: "exclamationmark.circle"
        }
    }

    var isReachable: Bool {
        self == .reachable
    }
}

extension ConnectionState {
    var isInProgress: Bool {
        switch self {
        case .scanning, .connecting, .reconnecting:
            true
        default:
            false
        }
    }

    var isConnected: Bool {
        self == .connected
    }
}

struct TemperatureSample: Identifiable, Equatable {
    let timestamp: Date
    let temperatureC: Double

    var id: Date { timestamp }
}

enum FaceSelection {
    static func clamped(_ selection: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(selection, 1), count)
    }

    static func adjacent(to selection: Int, offset: Int, count: Int) -> Int? {
        guard count > 0, offset != 0 else { return nil }
        let current = clamped(selection, count: count)
        let next = clamped(current + offset, count: count)
        return next == current ? nil : next
    }
}

enum WristFlickDirection: Equatable {
    case left
    case right
}

struct WristFlickClassifier {
    let accelerationThreshold: Double
    let cooldown: TimeInterval
    private(set) var lastFlickAt: TimeInterval = -.infinity

    init(accelerationThreshold: Double = 1.2, cooldown: TimeInterval = 0.6) {
        self.accelerationThreshold = accelerationThreshold
        self.cooldown = cooldown
    }

    mutating func classify(accelerationX: Double, at timestamp: TimeInterval) -> WristFlickDirection? {
        guard timestamp - lastFlickAt >= cooldown else { return nil }

        if accelerationX <= -accelerationThreshold {
            lastFlickAt = timestamp
            return .left
        }

        if accelerationX >= accelerationThreshold {
            lastFlickAt = timestamp
            return .right
        }

        return nil
    }
}
