import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
func activityStateDescription(_ state: ActivityState) -> String {
    switch state {
    case .active: return "active"
    case .dismissed: return "dismissed"
    case .ended: return "ended"
    case .stale: return "stale"
    case .pending: return "pending"
    @unknown default: return "unknown"
    }
}
#endif
