import Foundation
@preconcurrency import WatchConnectivity
import Combine
import SwiftUI
import WatchKit
import os

/// Swift 6 concurrency helper: allows passing immutable callback payloads across actor hops intentionally.
struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

struct TemperatureSample: Identifiable, Equatable {
    let timestamp: Date
    let temperatureC: Double

    var id: Date { timestamp }
}

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var connectionStatus: String = "Disconnected"
    @Published var isReachable: Bool = false
    @Published var companionDeviceName: String?
    @Published var connectedControllerName: String?
    @Published var controllerConnectionStatus: String = "Disconnected"
    @Published var temperatureText: String = "--"
    @Published var temperatureC: Double?
    @Published var temperatureTimestamp: Date?
    @Published var temperatureHistory: [TemperatureSample] = []
    @Published var selectedView: Int = 1
    @Published var autoBrightness: Bool = false
    @Published var accelerometerEnabled: Bool = false
    @Published var sleepModeEnabled: Bool = false
    @Published var auroraModeEnabled: Bool = false
    @Published var customMessage: String = ""

    let messageSubject = PassthroughSubject<WatchStateSnapshot, Never>()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LumiFur",
        category: "WatchConnectivityManager.watchOS"
    )
    private let session: WCSession
    private var syncRequestInFlight = false
    private var lastSyncRequestAt = Date.distantPast
    private let minimumSyncRequestInterval: TimeInterval = 15
    private let staleTemperatureInterval: TimeInterval = 20

    override private init() {
        session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        } else {
            connectionStatus = "Not Supported"
            isReachable = false
        }
    }

    var currentConfiguration: AccessoryConfiguration {
        AccessoryConfiguration(
            autoBrightness: autoBrightness,
            accelerometerEnabled: accelerometerEnabled,
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled
        )
    }

    nonisolated func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        let boxedMessage = UncheckedSendableBox(message)
        let boxedReply = UncheckedSendableBox(replyHandler)
        let boxedError = UncheckedSendableBox(errorHandler)

        Task { @MainActor in
            self._sendMessageOnMain(
                boxedMessage.value,
                replyHandler: boxedReply.value,
                errorHandler: boxedError.value
            )
        }
    }

    func sendCommand(
        _ payload: WatchCommandPayload,
        replyHandler: ((WatchCommandReply) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        do {
            let envelope = WatchEnvelope(payload: payload)
            let message = try SharedTransportCodec.encodeMessage(envelope)
            sendMessage(message, replyHandler: { reply in
                if let decoded = SharedTransportCodec.decodeMessage(reply, as: WatchCommandReply.self) {
                    Task { @MainActor in
                        self.apply(snapshot: decoded.snapshot)
                        replyHandler?(decoded)
                    }
                } else {
                    let fallback = WatchCommandReply(status: reply["status"] as? String ?? "Reply received.", snapshot: self.fallbackSnapshot())
                    Task { @MainActor in
                        replyHandler?(fallback)
                    }
                }
            }, errorHandler: errorHandler)
        } catch {
            errorHandler?(error)
        }
    }

    @MainActor
    private func _sendMessageOnMain(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        guard session.activationState == .activated else {
            errorHandler?(WCError(.sessionNotActivated))
            return
        }
        guard session.isCompanionAppInstalled else {
            errorHandler?(WCError(.companionAppNotInstalled))
            return
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: replyHandler) { error in
                self.logger.error("Failed to send watch message: \(error.localizedDescription, privacy: .public)")
                errorHandler?(error)
            }
            return
        }

        if replyHandler == nil {
            do {
                try session.updateApplicationContext(message)
            } catch {
                logger.error("Failed to queue watch application context: \(error.localizedDescription, privacy: .public)")
                errorHandler?(error)
            }
            return
        }

        errorHandler?(WCError(.notReachable))
    }

    func sendAccessorySettings() {
        sendCommand(.configuration(currentConfiguration))
    }

    func requestSyncFromiOS(force: Bool = true) {
        guard force || shouldRequestSyncFromiOS else { return }

        syncRequestInFlight = true
        lastSyncRequestAt = Date()
        sendCommand(
            .requestSnapshot(),
            replyHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.syncRequestInFlight = false
                }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.syncRequestInFlight = false
                    self?.logger.error("Failed to sync from iOS: \(error.localizedDescription, privacy: .public)")
                }
            }
        )
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        let receivedContext = session.receivedApplicationContext
        let errorDescription = error?.localizedDescription

        Task { @MainActor in
            switch activationState {
            case .activated:
                self.connectionStatus = "Connected"
                self.isReachable = reachable
                self.applyIfSnapshotMessage(receivedContext)
            case .inactive:
                self.connectionStatus = "Inactive"
                self.isReachable = false
            case .notActivated:
                self.connectionStatus = "Not Activated"
                self.isReachable = false
            @unknown default:
                self.connectionStatus = "Unknown State"
                self.isReachable = false
            }

            if let errorDescription {
                self.logger.error("WCSession activation error: \(errorDescription, privacy: .public)")
                self.connectionStatus = "Error"
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if self.session.activationState == .activated {
                self.connectionStatus = reachable ? "Connected" : "Connected (Unreachable)"
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let boxedMessage = UncheckedSendableBox(message)
        Task { @MainActor in
            self.applyIfSnapshotMessage(boxedMessage.value)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any],
        replyHandler: @escaping ([String : Any]) -> Void
    ) {
        let boxedMessage = UncheckedSendableBox(message)
        let boxedReplyHandler = UncheckedSendableBox(replyHandler)

        Task { @MainActor in
            self.applyIfSnapshotMessage(boxedMessage.value)
            boxedReplyHandler.value([:])
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        let boxedContext = UncheckedSendableBox(applicationContext)
        Task { @MainActor in
            self.applyIfSnapshotMessage(boxedContext.value)
        }
    }

    private func applyIfSnapshotMessage(_ message: [String: Any]) {
        if let snapshot = SharedTransportCodec.decodeMessage(message, as: WatchStateSnapshot.self) {
            apply(snapshot: snapshot)
            return
        }

        applyLegacyState(from: message)
    }

    private func apply(snapshot: WatchStateSnapshot) {
        companionDeviceName = snapshot.deviceName
        connectedControllerName = snapshot.controllerName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? snapshot.controllerName : nil
        controllerConnectionStatus = snapshot.controllerConnectionState.rawValue

        if selectedView != snapshot.selectedView {
            selectedView = snapshot.selectedView
        }

        let configuration = snapshot.configuration
        autoBrightness = configuration.autoBrightness
        accelerometerEnabled = configuration.accelerometerEnabled
        sleepModeEnabled = configuration.sleepModeEnabled
        auroraModeEnabled = configuration.auroraModeEnabled
        customMessage = snapshot.customMessage

        if temperatureText != snapshot.temperatureText {
            temperatureText = snapshot.temperatureText
        }

        if temperatureC != snapshot.temperatureC {
            temperatureC = snapshot.temperatureC
        }

        if temperatureTimestamp != snapshot.temperatureTimestamp {
            temperatureTimestamp = snapshot.temperatureTimestamp
        }

        if let tempC = snapshot.temperatureC, let timestamp = snapshot.temperatureTimestamp {
            appendTemperatureSampleIfNeeded(tempC: tempC, timestamp: timestamp)
        } else if !isConnectedOrConnecting(controllerConnectionStatus) {
            clearTemperatureCacheIfNeeded()
        }

        messageSubject.send(snapshot)
    }

    private func applyLegacyState(from data: [String: Any]) {
        let configuration = AccessoryConfiguration(
            autoBrightness: data["autoBrightness"] as? Bool ?? autoBrightness,
            accelerometerEnabled: data["accelerometer"] as? Bool ?? accelerometerEnabled,
            sleepModeEnabled: data["sleepMode"] as? Bool ?? sleepModeEnabled,
            auroraModeEnabled: ((data["auroraMode"] as? Bool) ?? (data["arouraMode"] as? Bool)) ?? auroraModeEnabled
        )

        let snapshot = WatchStateSnapshot(
            deviceName: data["deviceName"] as? String ?? companionDeviceName,
            controllerName: data["controllerName"] as? String ?? connectedControllerName,
            controllerConnectionState: ConnectionState(rawValue: data["controllerConnectionStatus"] as? String ?? controllerConnectionStatus) ?? .disconnected,
            selectedView: data["selectedView"] as? Int ?? selectedView,
            configuration: configuration,
            customMessage: data["customMessage"] as? String ?? customMessage,
            temperatureText: data["temperatureText"] as? String ?? temperatureText,
            temperatureC: data["temperatureC"] as? Double ?? temperatureC,
            temperatureTimestamp: data["temperatureTimestamp"] as? Date ?? temperatureTimestamp
        )

        apply(snapshot: snapshot)
    }

    private func fallbackSnapshot() -> WatchStateSnapshot {
        WatchStateSnapshot(
            deviceName: companionDeviceName,
            controllerName: connectedControllerName,
            controllerConnectionState: ConnectionState(rawValue: controllerConnectionStatus) ?? .disconnected,
            selectedView: selectedView,
            configuration: currentConfiguration,
            customMessage: customMessage,
            temperatureText: temperatureText,
            temperatureC: temperatureC,
            temperatureTimestamp: temperatureTimestamp
        )
    }

    private func appendTemperatureSampleIfNeeded(tempC: Double, timestamp: Date) {
        if temperatureHistory.last?.timestamp == timestamp { return }
        temperatureHistory.append(.init(timestamp: timestamp, temperatureC: tempC))

        let cutoff = Date().addingTimeInterval(-5 * 60)
        temperatureHistory.removeAll { $0.timestamp < cutoff }
    }

    private func clearTemperatureCacheIfNeeded() {
        guard temperatureC != nil ||
              temperatureTimestamp != nil ||
              !temperatureHistory.isEmpty ||
              temperatureText != "--"
        else { return }

        temperatureText = "--"
        temperatureC = nil
        temperatureTimestamp = nil
        temperatureHistory.removeAll()
    }

    private var shouldRequestSyncFromiOS: Bool {
        guard session.activationState == .activated,
              session.isCompanionAppInstalled,
              session.isReachable,
              !syncRequestInFlight
        else { return false }

        let now = Date()
        guard now.timeIntervalSince(lastSyncRequestAt) >= minimumSyncRequestInterval else {
            return false
        }

        guard isConnectedOrConnecting(controllerConnectionStatus) else {
            return temperatureTimestamp == nil && temperatureC == nil
        }

        guard let temperatureTimestamp else { return true }
        return now.timeIntervalSince(temperatureTimestamp) >= staleTemperatureInterval
    }

    func applicationDidBecomeActive() {
        Task { @MainActor in
            if self.session.activationState == .activated {
                self.requestSyncFromiOS()
                self.applyIfSnapshotMessage(self.session.receivedApplicationContext)
            }
        }
    }
}

extension WCError {
    init(_ code: WCError.Code, userInfo: [String: Any] = [:]) {
        self.init(_nsError: NSError(domain: "WCErrorDomain", code: code.rawValue, userInfo: userInfo))
    }
}
