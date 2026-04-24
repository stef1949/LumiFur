import AppIntents
import WidgetKit
import Foundation

/// Intent that advances the LumiFur view counter
struct ChangeLumiFurViewIntent: AppIntent {
    static let title: LocalizedStringResource = "Change LumiFur View"
    static let description = IntentDescription("Changes the currently displayed view on the LumiFur device.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let store = WidgetSnapshotStore()
        let snapshot = store.loadSnapshot() ?? .placeholder
        let availableViewCount = max(snapshot.availableViewCount, 1)
        let currentView = min(max(snapshot.selectedView, 1), availableViewCount)
        let nextView = currentView == availableViewCount ? 1 : currentView + 1

        store.savePendingCommand(
            PendingWidgetCommand(
                id: UUID(),
                createdAt: .now,
                kind: .setView,
                selectedView: nextView
            )
        )

        WidgetCenter.shared.reloadTimelines(ofKind: SharedDataKeys.widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedDataKeys.controlWidgetKind)
        return .result(value: nextView)
    }
}
