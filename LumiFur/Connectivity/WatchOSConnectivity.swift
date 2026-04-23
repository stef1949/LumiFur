import Foundation
import SwiftUI
import Combine
import os

#if canImport(WatchConnectivity) && os(iOS) && !targetEnvironment(macCatalyst)
import WatchConnectivity
import UIKit

/// Wraps non-Sendable values when a framework callback hands us an immutable snapshot.
struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var connectionStatus: String = "Initializing..."
    @Published var isReachable: Bool = false

    let messageSubject = PassthroughSubject<[String: Any], Never>()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LumiFur",
        category: "WatchConnectivityManager.iOS"
    )
    private let session: WCSession
    private var lastPublishedTemperatureTimestamp: Date?
    private var accessoryViewModel: AccessoryViewModel?

    private override init() {
        session = WCSession.default
        super.init()

        guard WCSession.isSupported() else {
            connectionStatus = "Not Supported"
            isReachable = false
            logger.info("WCSession is not supported on this device.")
            return
        }

        session.delegate = self
        session.activate()
        logger.info("Activating WCSession.")
    }

    func attach(accessoryViewModel: AccessoryViewModel) {
        self.accessoryViewModel = accessoryViewModel
    }

    func syncStateToWatch(from viewModel: AccessoryViewModel) {
        guard session.isPaired, session.isWatchAppInstalled else {
            logger.info("Skipping watch sync because no paired watch app is available.")
            return
        }

        do {
            let snapshot = viewModel.currentWatchSnapshot(deviceName: UIDevice.current.name)
            try session.updateApplicationContext(SharedTransportCodec.encodeMessage(snapshot))
        } catch {
            logger.error("Failed to sync state to watch: \(error.localizedDescription, privacy: .public)")
        }
    }

    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        guard session.activationState == .activated else {
            errorHandler?(WCError(.sessionNotActivated))
            return
        }

        guard session.isReachable else {
            errorHandler?(WCError(.notReachable))
            return
        }

        session.sendMessage(message, replyHandler: replyHandler) { error in
            self.logger.error("Failed to send watch message: \(error.localizedDescription, privacy: .public)")
            errorHandler?(error)
        }
    }

    private func currentSnapshot() -> WatchStateSnapshot {
        accessoryViewModel?.currentWatchSnapshot(deviceName: UIDevice.current.name) ??
        WatchStateSnapshot(
            deviceName: UIDevice.current.name,
            controllerName: nil,
            controllerConnectionState: .disconnected,
            selectedView: 1,
            configuration: .init(
                autoBrightness: true,
                accelerometerEnabled: true,
                sleepModeEnabled: true,
                auroraModeEnabled: true
            ),
            customMessage: "",
            temperatureText: "--",
            temperatureC: nil,
            temperatureTimestamp: nil
        )
    }

    private func currentReply(status: String) -> WatchCommandReply {
        WatchCommandReply(status: status, snapshot: currentSnapshot())
    }

    private func isNewTemperatureData(_ snapshot: WatchStateSnapshot) -> Bool {
        guard let timestamp = snapshot.temperatureTimestamp else { return true }
        if let last = lastPublishedTemperatureTimestamp, timestamp <= last {
            return false
        }
        lastPublishedTemperatureTimestamp = timestamp
        return true
    }

    private func applyLegacyAccessorySettingsFromMessage(_ message: [String: Any]) {
        guard let accessoryViewModel else { return }

        let configuration = AccessoryConfiguration(
            autoBrightness: message["autoBrightness"] as? Bool ?? accessoryViewModel.autoBrightness,
            accelerometerEnabled: message["accelerometer"] as? Bool ?? accessoryViewModel.accelerometerEnabled,
            sleepModeEnabled: message["sleepMode"] as? Bool ?? accessoryViewModel.sleepModeEnabled,
            auroraModeEnabled: ((message["auroraMode"] as? Bool) ?? (message["arouraMode"] as? Bool)) ?? accessoryViewModel.auroraModeEnabled
        )

        if message["autoBrightness"] != nil ||
            message["accelerometer"] != nil ||
            message["sleepMode"] != nil ||
            message["auroraMode"] != nil ||
            message["arouraMode"] != nil {
            _ = accessoryViewModel.applyUserConfiguration(configuration)
        }

        if let customMessage = message["customMessage"] as? String {
            _ = accessoryViewModel.updateCustomMessage(customMessage)
        }
    }

    private func legacyReplyData() -> [String: Any] {
        let snapshot = currentSnapshot()
        return [
            "timestamp": Date(),
            "deviceName": snapshot.deviceName ?? UIDevice.current.name,
            "selectedView": snapshot.selectedView,
            "autoBrightness": snapshot.configuration.autoBrightness,
            "accelerometer": snapshot.configuration.accelerometerEnabled,
            "sleepMode": snapshot.configuration.sleepModeEnabled,
            "auroraMode": snapshot.configuration.auroraModeEnabled,
            "customMessage": snapshot.customMessage,
            "controllerConnectionStatus": snapshot.controllerConnectionState.rawValue,
            "controllerName": snapshot.controllerName ?? "",
            "temperatureText": snapshot.temperatureText,
        ].merging(
            snapshot.temperatureC.map {
                [
                    "temperatureC": $0,
                    "temperatureTimestamp": snapshot.temperatureTimestamp as Any,
                ]
            } ?? [:]
        ) { current, _ in current }
    }

    private func handleCommand(_ envelope: WatchEnvelope) -> WatchCommandReply {
        guard let accessoryViewModel else {
            return currentReply(status: "Accessory state is unavailable on iPhone.")
        }

        switch envelope.payload.type {
        case .requestSnapshot:
            return currentReply(status: "Snapshot refreshed.")

        case .setView:
            guard let selectedView = envelope.payload.selectedView else {
                return currentReply(status: "Missing view selection.")
            }

            let didAccept = accessoryViewModel.setView(selectedView)
            return currentReply(status: didAccept ? "View change requested." : "View change rejected.")

        case .connect:
            return currentReply(status: accessoryViewModel.attemptRemoteConnect())

        case .disconnect:
            accessoryViewModel.disconnect()
            return currentReply(status: "Disconnect requested.")

        case .updateConfiguration:
            guard let configuration = envelope.payload.configuration else {
                return currentReply(status: "Missing configuration payload.")
            }

            let didApply = accessoryViewModel.applyUserConfiguration(configuration)
            return currentReply(status: didApply ? "Configuration updated." : "Configuration update queued locally.")

        case .updateCustomMessage:
            let didApply = accessoryViewModel.updateCustomMessage(envelope.payload.customMessage ?? "")
            return currentReply(status: didApply ? "Custom message updated." : "Custom message saved locally.")
        }
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

            switch activationState {
            case .activated:
                self.connectionStatus = "Connected"
            case .inactive:
                self.connectionStatus = "Inactive"
            case .notActivated:
                self.connectionStatus = "Not Activated"
            @unknown default:
                self.connectionStatus = "Unknown State"
            }

            self.isReachable = activationState == .activated ? reachable : false

            if let errorDescription {
                self.logger.error("WCSession activation error: \(errorDescription, privacy: .public)")
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isReachable = reachable
            if self.connectionStatus == "Connected" && !reachable {
                self.connectionStatus = "Connected (Not Reachable)"
            } else if self.connectionStatus.hasPrefix("Connected") && reachable {
                self.connectionStatus = "Connected"
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let boxedMessage = UncheckedSendable(message)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let message = boxedMessage.value

            if let envelope = SharedTransportCodec.decodeMessage(message, as: WatchEnvelope.self) {
                _ = self.handleCommand(envelope)
                return
            }

            self.applyLegacyAccessorySettingsFromMessage(message)
            self.messageSubject.send(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let boxedMessage = UncheckedSendable(message)
        let boxedReply = UncheckedSendable(replyHandler)

        Task { @MainActor [weak self] in
            guard let self else {
                boxedReply.value([:])
                return
            }

            let message = boxedMessage.value

            if let envelope = SharedTransportCodec.decodeMessage(message, as: WatchEnvelope.self) {
                let reply = self.handleCommand(envelope)
                let encodedReply = (try? SharedTransportCodec.encodeMessage(reply)) ?? ["status": reply.status]
                boxedReply.value(encodedReply)
                return
            }

            if let command = message["command"] as? String, command == "getData" {
                boxedReply.value(self.legacyReplyData())
                return
            }

            self.applyLegacyAccessorySettingsFromMessage(message)
            self.messageSubject.send(message)
            boxedReply.value(["status": "Message received and processed on iOS."])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let boxedContext = UncheckedSendable(applicationContext)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let context = boxedContext.value

            if let envelope = SharedTransportCodec.decodeMessage(context, as: WatchEnvelope.self) {
                _ = self.handleCommand(envelope)
                return
            }

            self.applyLegacyAccessorySettingsFromMessage(context)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.connectionStatus = "Inactive"
            self?.isReachable = false
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.connectionStatus = "Deactivated"
            self.isReachable = false
            self.session.activate()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled

        Task { @MainActor [weak self] in
            self?.logger.info("Watch state changed. paired=\(paired, privacy: .public) installed=\(installed, privacy: .public)")
        }
    }
}

extension WCError {
    init(_ code: WCError.Code) {
        self = WCError(_nsError: NSError(domain: WCError.errorDomain, code: code.rawValue, userInfo: [:]))
    }
}

#else

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var connectionStatus: String = "Not Supported"
    @Published var isReachable: Bool = false

    let messageSubject = PassthroughSubject<[String: Any], Never>()

    func attach(accessoryViewModel: AccessoryViewModel) {}
    func syncStateToWatch(from viewModel: AccessoryViewModel) {}

    private override init() { super.init() }
}

#endif
