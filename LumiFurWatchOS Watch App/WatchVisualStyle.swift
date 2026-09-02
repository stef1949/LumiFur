import SwiftUI

extension WatchSessionStatus {
    var tint: Color {
        switch self {
        case .activating:
            .orange
        case .reachable:
            .green
        case .unreachable:
            .yellow
        case .unsupported, .failed:
            .red
        }
    }
}
