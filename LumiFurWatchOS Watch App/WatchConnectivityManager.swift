import Foundation
@preconcurrency import WatchConnectivity
import WatchKit
import os

struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
}

enum WatchConnectivityCallbackBridge {
    // WCSession invokes these closures on a background thread. Create that boundary
    // outside MainActor, then explicitly hop before touching observable app state.
    nonisolated static func makeReplyHandler(
        _ action: @escaping @MainActor @Sendable ([String: Any]) -> Void
    ) -> @Sendable ([String: Any]) -> Void {
        { reply in
            let boxedReply = UncheckedSendableBox(value: reply)
            Task { @MainActor in
                action(boxedReply.value)
            }
        }
    }

    nonisolated static func makeErrorHandler(
        _ action: @escaping @MainActor @Sendable (String) -> Void
    ) -> @Sendable (any Error) -> Void {
        { error in
            let description = error.localizedDescription
            Task { @MainActor in
                action(description)
            }
        }
    }
}

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published private(set) var sessionStatus: WatchSessionStatus = .activating
    @Published private(set) var companionDeviceName: String?
    @Published private(set) var controllerName: String?
    @Published private(set) var controllerState: ConnectionState = .disconnected
    @Published private(set) var selectedView = 1
    @Published private(set) var configuration = AccessoryConfiguration(
        autoBrightness: false,
        accelerometerEnabled: false,
        sleepModeEnabled: false,
        auroraModeEnabled: false,
        staticColorEnabled: false,
        mouthBrightnessOverrideEnabled: false
    )
    @Published private(set) var customMessage = ""
    @Published private(set) var temperatureText = "--"
    @Published private(set) var temperatureC: Double?
    @Published private(set) var temperatureTimestamp: Date?
    @Published private(set) var temperatureHistory: [TemperatureSample] = []
    @Published private(set) var isCommandInFlight = false
    @Published private(set) var errorMessage: String?

    private enum Rollback: Sendable {
        case none
        case selectedView(Int)
        case configuration(AccessoryConfiguration)
    }

    private static let snapshotCacheKey = "watch.lastSnapshot"
    private let session: WCSession
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.richies3d.LumiFur.watch",
        category: "WatchConnectivity"
    )
    private var syncRequestInFlight = false
    private var lastSyncRequestAt = Date.distantPast
    private let minimumSyncRequestInterval: TimeInterval = 15

    override private init() {
        session = .default
        super.init()

        restoreCachedSnapshot()

        guard WCSession.isSupported() else {
            sessionStatus = .unsupported
            return
        }

        session.delegate = self
        session.activate()
    }

    var canControlController: Bool {
        sessionStatus.isReachable && controllerState.isConnected && !isCommandInFlight
    }

    var canRequestConnection: Bool {
        sessionStatus.isReachable && !controllerState.isInProgress && !isCommandInFlight
    }

    func refresh(force: Bool = false) {
        guard !syncRequestInFlight, !isCommandInFlight else { return }
        guard force || Date().timeIntervalSince(lastSyncRequestAt) >= minimumSyncRequestInterval else { return }

        syncRequestInFlight = true
        lastSyncRequestAt = Date()
        perform(
            .requestSnapshot(),
            rollback: .none,
            presentsErrors: false
        )
    }

    func connectController() {
        guard canRequestConnection else {
            presentUnavailableMessage()
            return
        }
        perform(.connect())
    }

    func disconnectController() {
        guard sessionStatus.isReachable, !isCommandInFlight else {
            presentUnavailableMessage()
            return
        }
        perform(.disconnect())
    }

    func selectView(_ view: Int) {
        let count = SharedOptions.protoActionOptions.count
        guard FaceSelection.clamped(view, count: count) == view else { return }
        guard canControlController else {
            presentUnavailableMessage()
            return
        }

        let previous = selectedView
        guard previous != view else { return }
        selectedView = view
        WKInterfaceDevice.current().play(.click)
        perform(.setView(view), rollback: .selectedView(previous))
    }

    func moveSelectedView(by offset: Int) {
        guard let next = FaceSelection.adjacent(
            to: selectedView,
            offset: offset,
            count: SharedOptions.protoActionOptions.count
        ) else { return }
        selectView(next)
    }

    func setAutoBrightness(_ enabled: Bool) {
        var updated = configuration
        updated.autoBrightness = enabled
        updateConfiguration(updated)
    }
    func setStaticColorEnabled(_ enabled: Bool) {
        var updated = configuration
        updated.staticColorEnabled = enabled
        updateConfiguration(updated)
    }
    func setmouthBrightnessOverride(_ enabled: Bool) {
        var updated = configuration
        updated.mouthBrightnessOverrideEnabled = enabled
        updateConfiguration(updated)
    }
    func setAccelerometerEnabled(_ enabled: Bool) {
        var updated = configuration
        updated.accelerometerEnabled = enabled
        updateConfiguration(updated)
    }

    func setSleepModeEnabled(_ enabled: Bool) {
        var updated = configuration
        updated.sleepModeEnabled = enabled
        updateConfiguration(updated)
    }

    func setAuroraModeEnabled(_ enabled: Bool) {
        var updated = configuration
        updated.auroraModeEnabled = enabled
        updateConfiguration(updated)
    }

    func clearError() {
        errorMessage = nil
    }

    func applicationDidBecomeActive() {
        refresh()
    }

    func handleBackgroundConnectivity() async {
        if session.activationState != .activated {
            session.activate()
        }

        for _ in 0..<50 {
            if session.activationState == .activated, !session.hasContentPending {
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        logger.warning("Background Watch Connectivity delivery did not finish before the task window ended.")
    }

    private func updateConfiguration(_ updated: AccessoryConfiguration) {
        guard canControlController else {
            presentUnavailableMessage()
            return
        }

        let previous = configuration
        configuration = updated
        perform(.configuration(updated), rollback: .configuration(previous))
    }

    private func perform(
        _ payload: WatchCommandPayload,
        rollback: Rollback = .none,
        presentsErrors: Bool = true
    ) {
        guard session.activationState == .activated,
              session.isCompanionAppInstalled,
              session.isReachable
        else {
            syncRequestInFlight = false
            apply(rollback)
            if presentsErrors { presentUnavailableMessage() }
            return
        }

        guard !isCommandInFlight else {
            syncRequestInFlight = false
            apply(rollback)
            return
        }

        let message: [String: Any]
        do {
            message = try SharedTransportCodec.encodeMessage(WatchEnvelope(payload: payload))
        } catch {
            syncRequestInFlight = false
            apply(rollback)
            present(error.localizedDescription, if: presentsErrors)
            return
        }

        isCommandInFlight = true
        let replyHandler = WatchConnectivityCallbackBridge.makeReplyHandler { [weak self] reply in
            self?.handleReply(
                reply,
                rollback: rollback,
                presentsErrors: presentsErrors
            )
        }
        let errorHandler = WatchConnectivityCallbackBridge.makeErrorHandler { [weak self] description in
            self?.handleFailure(
                description,
                rollback: rollback,
                presentsErrors: presentsErrors
            )
        }

        session.sendMessage(
            message,
            replyHandler: replyHandler,
            errorHandler: errorHandler
        )
    }

    private func handleReply(
        _ reply: [String: Any],
        rollback: Rollback,
        presentsErrors: Bool
    ) {
        defer {
            isCommandInFlight = false
            syncRequestInFlight = false
        }

        guard let decoded = SharedTransportCodec.decodeMessage(reply, as: WatchCommandReply.self) else {
            apply(rollback)
            present("The iPhone returned an unreadable response.", if: presentsErrors)
            return
        }

        apply(snapshot: decoded.snapshot)

        let status = decoded.status.lowercased()
        if status.contains("rejected") || status.contains("failed") || status.contains("missing") || status.contains("unavailable") {
            present(decoded.status, if: presentsErrors)
            WKInterfaceDevice.current().play(.failure)
        } else if presentsErrors {
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func handleFailure(
        _ description: String,
        rollback: Rollback,
        presentsErrors: Bool
    ) {
        isCommandInFlight = false
        syncRequestInFlight = false
        apply(rollback)
        logger.error("Watch command failed: \(description, privacy: .public)")
        present(description, if: presentsErrors)
        if presentsErrors { WKInterfaceDevice.current().play(.failure) }
    }

    private func apply(_ rollback: Rollback) {
        switch rollback {
        case .none:
            break
        case .selectedView(let previous):
            selectedView = previous
        case .configuration(let previous):
            configuration = previous
        }
    }

    private func present(_ message: String, if shouldPresent: Bool) {
        guard shouldPresent else { return }
        errorMessage = message
    }

    private func presentUnavailableMessage() {
        if !sessionStatus.isReachable {
            errorMessage = "Open LumiFur on the paired iPhone and try again."
        } else if controllerState.isInProgress {
            errorMessage = "The controller is still connecting."
        } else if !controllerState.isConnected {
            errorMessage = "Connect the LumiFur controller first."
        } else {
            errorMessage = "Please wait for the current action to finish."
        }
    }

    private func apply(snapshot: WatchStateSnapshot, persist: Bool = true) {
        companionDeviceName = snapshot.deviceName
        let trimmedName = snapshot.controllerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        controllerName = trimmedName?.isEmpty == false ? trimmedName : nil
        controllerState = snapshot.controllerConnectionState
        selectedView = FaceSelection.clamped(
            snapshot.selectedView,
            count: SharedOptions.protoActionOptions.count
        )
        configuration = snapshot.configuration
        customMessage = snapshot.customMessage
        temperatureText = snapshot.temperatureText
        temperatureC = snapshot.temperatureC
        temperatureTimestamp = snapshot.temperatureTimestamp

        if let temperatureC = snapshot.temperatureC,
           let timestamp = snapshot.temperatureTimestamp {
            appendTemperatureSample(temperatureC, at: timestamp)
        } else if !snapshot.controllerConnectionState.isConnected {
            temperatureHistory.removeAll()
        }

        if persist { cache(snapshot) }
    }

    private func applyLegacyState(_ data: [String: Any]) {
        let legacyConfiguration = AccessoryConfiguration(
            autoBrightness: data["autoBrightness"] as? Bool ?? configuration.autoBrightness,
            accelerometerEnabled: data["accelerometer"] as? Bool ?? configuration.accelerometerEnabled,
            sleepModeEnabled: data["sleepMode"] as? Bool ?? configuration.sleepModeEnabled,
            auroraModeEnabled: (data["auroraMode"] as? Bool)
                ?? (data["arouraMode"] as? Bool)
                ?? configuration.auroraModeEnabled,
            staticColorEnabled: data["staticColor"] as? Bool ?? configuration.staticColorEnabled,
            mouthBrightnessOverrideEnabled: data["mouthBrightnessOverride"] as? Bool ?? configuration.mouthBrightnessOverrideEnabled
        )

        apply(snapshot: WatchStateSnapshot(
            deviceName: data["deviceName"] as? String ?? companionDeviceName,
            controllerName: data["controllerName"] as? String ?? controllerName,
            controllerConnectionState: ConnectionState(
                rawValue: data["controllerConnectionStatus"] as? String ?? controllerState.rawValue
            ) ?? .unknown,
            selectedView: data["selectedView"] as? Int ?? selectedView,
            configuration: legacyConfiguration,
            customMessage: data["customMessage"] as? String ?? customMessage,
            temperatureText: data["temperatureText"] as? String ?? temperatureText,
            temperatureC: data["temperatureC"] as? Double ?? temperatureC,
            temperatureTimestamp: data["temperatureTimestamp"] as? Date ?? temperatureTimestamp
        ))
    }

    private func receive(_ message: [String: Any]) {
        if let snapshot = SharedTransportCodec.decodeMessage(message, as: WatchStateSnapshot.self) {
            apply(snapshot: snapshot)
        } else {
            applyLegacyState(message)
        }
    }

    private func appendTemperatureSample(_ temperatureC: Double, at timestamp: Date) {
        guard temperatureHistory.last?.timestamp != timestamp else { return }
        temperatureHistory.append(.init(timestamp: timestamp, temperatureC: temperatureC))
        let cutoff = Date().addingTimeInterval(-5 * 60)
        temperatureHistory.removeAll { $0.timestamp < cutoff }
    }

    private func cache(_ snapshot: WatchStateSnapshot) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.snapshotCacheKey)
    }

    private func restoreCachedSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: Self.snapshotCacheKey),
              let snapshot = try? JSONDecoder().decode(WatchStateSnapshot.self, from: data)
        else { return }
        apply(snapshot: snapshot, persist: false)
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        let errorDescription = error?.localizedDescription

        Task { @MainActor [weak self] in
            guard let self else { return }

            if let errorDescription {
                self.sessionStatus = .failed(errorDescription)
                self.logger.error("WCSession activation failed: \(errorDescription, privacy: .public)")
                return
            }

            switch activationState {
            case .activated:
                self.sessionStatus = reachable ? .reachable : .unreachable
                if reachable { self.refresh(force: true) }
            case .inactive, .notActivated:
                self.sessionStatus = .unreachable
            @unknown default:
                self.sessionStatus = .unreachable
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.sessionStatus = reachable ? .reachable : .unreachable
            if reachable { self.refresh(force: true) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let boxedMessage = UncheckedSendableBox(value: message)
        Task { @MainActor [weak self] in
            self?.receive(boxedMessage.value)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let boxedMessage = UncheckedSendableBox(value: message)
        let boxedReply = UncheckedSendableBox(value: replyHandler)
        Task { @MainActor [weak self] in
            self?.receive(boxedMessage.value)
            boxedReply.value(["status": "Snapshot received."])
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let boxedContext = UncheckedSendableBox(value: applicationContext)
        Task { @MainActor [weak self] in
            self?.receive(boxedContext.value)
        }
    }
}
