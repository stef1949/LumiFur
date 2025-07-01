import AppIntents
import WidgetKit
import Foundation

/// Intent that advances the LumiFur view counter
struct ChangeLumiFurViewIntent: AppIntent {
    static let title: LocalizedStringResource = "Change LumiFur View"
    static let description = IntentDescription("Changes the currently displayed view on the LumiFur device.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let suite = SharedDataKeys.suiteName
        let defaults = UserDefaults(suiteName: suite)!
        let current = defaults.integer(forKey: SharedDataKeys.selectedView)
        let next = (current % 12) + 1
        defaults.set(next, forKey: SharedDataKeys.selectedView)

        NotificationCenter.default.post(
            name: .changeViewIntentTriggered,
            object: nil,
            userInfo: ["nextView": next]
        )

        WidgetCenter.shared.reloadTimelines(ofKind: SharedDataKeys.widgetKind)
        return .result(value: next)
    }
}

extension Notification.Name {
    static let changeViewIntentTriggered = Notification.Name("com.richies3d.LumiFur.ChangeViewIntentTriggered")
}
