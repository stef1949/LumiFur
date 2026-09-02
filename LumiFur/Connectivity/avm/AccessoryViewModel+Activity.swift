import Foundation
import WidgetKit

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS) && !LUMIFUR_LEGACY_IOS15
import ActivityKit
#endif

// MARK: - External Sync

extension AccessoryViewModel {
    @MainActor
    func makeStateDigest() -> StateDigest {
        StateDigest(
            connectionState: connectionState,
            signalStrength: signalStrength,
            temperature: temperature,
            selectedView: selectedView,
            configuration: currentConfiguration(),
            customMessage: customMessage,
            connectedDeviceName: connectedDeviceName,
            temperatureCount: temperatureData.count,
            lastTemperatureTimestamp: temperatureData.last?.timestamp
        )
    }

    @MainActor
    func makeWatchStateDigest() -> WatchStateDigest {
        WatchStateDigest(
            connectionState: connectionState,
            temperature: temperature,
            selectedView: selectedView,
            configuration: currentConfiguration(),
            customMessage: customMessage,
            connectedDeviceName: connectedDeviceName
        )
    }

    @MainActor
    func scheduleExternalStateSync() {
        IdleCPUDiagnostics.shared.recordTaskFire("externalSync.schedule")
        pendingExternalUpdateTask?.cancel()
        pendingExternalUpdateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            IdleCPUDiagnostics.shared.recordTaskFire("externalSync.fire")
            self?.performExternalStateSyncIfNeeded()
        }

        scheduleWatchSync()
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS) && !LUMIFUR_LEGACY_IOS15
        if #available(iOS 16.1, *) {
            scheduleLiveActivityUpdate()
        }
        #endif
    }

    @MainActor
    private func performExternalStateSyncIfNeeded() {
        let digest = makeStateDigest()
        guard digest != lastSentStateDigest else { return }

        lastSentStateDigest = digest
        updateWidgetData()
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS) && !LUMIFUR_LEGACY_IOS15
        if #available(iOS 16.1, *) {
            scheduleLiveActivityUpdate()
        }
        #endif
    }

    @MainActor
    private func scheduleWatchSync() {
        pendingWatchSyncTask?.cancel()

        let delay = max(0, 5 - Date().timeIntervalSince(lastWatchSyncAt))
        pendingWatchSyncTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64((delay + 0.2) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            IdleCPUDiagnostics.shared.recordTaskFire("watchSync.fire")
            self?.syncStateToWatch()
        }
    }

    @MainActor
    private func updateWidgetData() {
        persistWidgetSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Live Activity

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS) && !LUMIFUR_LEGACY_IOS15
@available(iOS 16.1, *)
extension AccessoryViewModel {
    @MainActor
    func createContentState(
        connected: Bool? = nil,
        status: String? = nil
    ) -> LumiFur_WidgetAttributes.ContentState {
        LumiFur_WidgetAttributes.ContentState(
            connectionStatus: status ?? connectionStatus,
            signalStrength: signalStrength,
            temperature: temperature,
            selectedView: selectedView,
            isConnected: connected ?? isConnected,
            isScanning: isScanning,
            temperatureChartData: Array(temperatureData.suffix(50).map(\.temperature)),
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled,
            customMessage: customMessage
        )
    }

    @MainActor
    func startLumiFur_WidgetLiveActivity() async {
        guard !isCreatingActivity else { return }
        isCreatingActivity = true
        defer { isCreatingActivity = false }

        if let currentActivity {
            switch currentActivity.activityState {
            case .active, .stale:
                await updateLumiFur_WidgetLiveActivityIfNeeded()
                return
            case .pending:
                return
            case .dismissed, .ended:
                self.currentActivity = nil
                lastSentActivityState = nil
            @unknown default:
                self.currentActivity = nil
                lastSentActivityState = nil
            }
        }

        if let existingActivity = Activity<LumiFur_WidgetAttributes>.activities.first(where: {
            $0.activityState == .active || $0.activityState == .stale
        }) {
            currentActivity = existingActivity
            activityStateTask?.cancel()
            activityStateTask = Task { [weak self] in
                await self?.monitorActivityState(activity: existingActivity)
            }
            await updateLumiFur_WidgetLiveActivityIfNeeded()
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities are disabled for LumiFur")
            return
        }
        guard let targetPeripheral, isConnected else { return }

        do {
            let activity = try Activity<LumiFur_WidgetAttributes>.request(
                attributes: LumiFur_WidgetAttributes(name: targetPeripheral.name ?? "LumiFur Device"),
                content: .init(state: createContentState(), staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            lastSentActivityState = createContentState()
            activityStateTask?.cancel()
            activityStateTask = Task { [weak self] in
                await self?.monitorActivityState(activity: activity)
            }
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
            currentActivity = nil
        }
    }

    @MainActor
    private func monitorActivityState(activity: Activity<LumiFur_WidgetAttributes>) async {
        for await state in activity.activityStateUpdates {
            if state == .dismissed || state == .ended {
                if currentActivity?.id == activity.id {
                    currentActivity = nil
                    activityStateTask = nil
                    lastSentActivityState = nil
                }
                break
            }
        }
    }

    @MainActor
    func scheduleLiveActivityUpdate() {
        pendingLiveActivityUpdateTask?.cancel()
        pendingLiveActivityUpdateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            IdleCPUDiagnostics.shared.recordTaskFire("liveActivity.fire")
            await self?.updateLumiFur_WidgetLiveActivityIfNeeded()
        }
    }

    @MainActor
    private func updateLumiFur_WidgetLiveActivityIfNeeded() async {
        guard let currentActivity,
              currentActivity.activityState == .active || currentActivity.activityState == .stale else { return }
        let activityBox = UncheckedSendableBox(currentActivity)

        let newState = createContentState()
        guard newState != lastSentActivityState else { return }

        lastSentActivityState = newState
        await activityBox.value.update(
            ActivityContent(
                state: newState,
                staleDate: nil,
                relevanceScore: isConnected ? 100 : (isConnecting ? 75 : 50)
            )
        )
    }

    @MainActor
    func endLiveActivity(
        finalContent: LumiFur_WidgetAttributes.ContentState? = nil,
        dismissalPolicy: ActivityUIDismissalPolicy = .default
    ) async {
        let activities = Activity<LumiFur_WidgetAttributes>.activities
        guard !activities.isEmpty else {
            currentActivity = nil
            lastSentActivityState = nil
            return
        }

        activityStateTask?.cancel()
        activityStateTask = nil

        let finalActivityContent = finalContent.map { ActivityContent(state: $0, staleDate: nil) }
        for activity in activities {
            let activityBox = UncheckedSendableBox(activity)
            await activityBox.value.end(finalActivityContent, dismissalPolicy: dismissalPolicy)
        }

        self.currentActivity = nil
        lastSentActivityState = nil
    }

    @MainActor
    func endAllLumiFurActivities(
        dismissalPolicy: ActivityUIDismissalPolicy = .immediate
    ) async {
        for activity in Activity<LumiFur_WidgetAttributes>.activities {
            await activity.end(nil, dismissalPolicy: dismissalPolicy)
        }

        currentActivity = nil
        activityStateTask?.cancel()
        activityStateTask = nil
        lastSentActivityState = nil
    }
}
#else
extension AccessoryViewModel {
    @MainActor
    func scheduleLiveActivityUpdate() {}
}
#endif
