//
//  WatchOSConnectivity.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/14/25.
//

//
//  WatchOSConnectivity.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/14/25.
//

import Foundation
import SwiftUI
import Combine

#if canImport(WatchConnectivity) && os(iOS) && !targetEnvironment(macCatalyst)
import WatchConnectivity
import UIKit


/// Wraps non-Sendable values when you *know* the framework hands you an immutable snapshot.
struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    
    static let shared = WatchConnectivityManager()
    
    // MARK: - Published Properties for SwiftUI
    @Published var connectionStatus: String = "Initializing..."
    @Published var isReachable: Bool = false
    
    // MARK: - Subject for Received Messages
    let messageSubject = PassthroughSubject<[String: Any], Never>()
    
    private let session: WCSession
    private var lastPublishedTemperatureTimestamp: Date? = nil
    
    // Use the shared instance (this is a reference type anyway)
    @Published var accessoryViewModel: AccessoryViewModel = .shared
    
    // MARK: - Init
    private override init() {
        self.session = WCSession.default
        super.init()
        
        guard WCSession.isSupported() else {
            self.connectionStatus = "Not Supported"
            self.isReachable = false
            print("WCSession is not supported on this device.")
            return
        }
        
        session.delegate = self
        session.activate()
        print("WCSession is supported. Activating session.")
    }
    
    // MARK: - Sending State TO Watch
    /// Packages and sends the current app state to the watch via Application Context.
    func syncStateToWatch(from viewModel: AccessoryViewModel) {
        guard session.isPaired, session.isWatchAppInstalled else {
            print("Cannot sync: Watch not paired or app not installed.")
            return
        }
        
        var context: [String: Any] = [
            "deviceName": UIDevice.current.name,
            "selectedView": viewModel.selectedView,
            
            "autoBrightness": viewModel.autoBrightness,
            "accelerometer": viewModel.accelerometerEnabled,
            "sleepMode": viewModel.sleepModeEnabled,
            "auroraMode": viewModel.auroraModeEnabled,
            
            "controllerConnectionStatus": viewModel.connectionStatus,
            "controllerName": viewModel.connectedDeviceName ?? "",
            
            "temperatureText": viewModel.temperature
        ]
        
        if let latest = viewModel.temperatureData.last {
            context["temperatureC"] = latest.temperature
            context["temperatureTimestamp"] = latest.timestamp
        }
        
        do {
            try session.updateApplicationContext(context)
            print("✅ Successfully synced context to watch.")
        } catch {
            print("❌ Error syncing context to watch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Sending Methods
    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        guard session.activationState == .activated else {
            print("Cannot send message: Session not activated.")
            errorHandler?(WCError(.sessionNotActivated))
            return
        }
        
        guard session.isReachable else {
            print("Cannot send message: Counterpart app is not reachable.")
            errorHandler?(WCError(.notReachable))
            return
        }
        
        session.sendMessage(message, replyHandler: replyHandler) { error in
            print("Error sending message: \(error.localizedDescription)")
            errorHandler?(error)
        }
    }
    
    func updateApplicationContext(_ context: [String: Any]) {
        guard session.activationState == .activated else {
            print("Cannot update context: Session not activated.")
            return
        }
        do {
            try session.updateApplicationContext(context)
            print("Application context updated successfully.")
        } catch {
            print("Error updating application context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Main-actor helpers
    
    private func isNewTemperatureData(_ payload: [String: Any]) -> Bool {
        if let ts = payload["temperatureTimestamp"] as? Date {
            if let last = lastPublishedTemperatureTimestamp, ts <= last {
                return false
            }
            lastPublishedTemperatureTimestamp = ts
            return true
        }
        // If no timestamp is present, treat as not data-specific and allow publish
        return true
    }
    
    private func applyAccessorySettingsFromMessage(_ message: [String: Any]) {
        // AccessoryViewModel updates
        if let autoBrightness = message["autoBrightness"] as? Bool {
            accessoryViewModel.autoBrightness = autoBrightness
            print("iOS: Updated autoBrightness to \(autoBrightness)")
        }
        if let accelerometer = message["accelerometer"] as? Bool {
            accessoryViewModel.accelerometerEnabled = accelerometer
            print("iOS: Updated accelerometerEnabled to \(accelerometer)")
        }
        if let sleepMode = message["sleepMode"] as? Bool {
            accessoryViewModel.sleepModeEnabled = sleepMode
            print("iOS: Updated sleepModeEnabled to \(sleepMode)")
        }
        if let auroraMode = message["auroraMode"] as? Bool {
            accessoryViewModel.auroraModeEnabled = auroraMode
            print("iOS: Updated auroraModeEnabled to \(auroraMode)")
        }
        if let customMessage = message["customMessage"] as? String {
            accessoryViewModel.customMessage = customMessage
            print("iOS: Updated customMessage to \"\(customMessage)\"")
        }
        
        // Update AppStorage-backed keys through UserDefaults
        let defaults = UserDefaults.standard
        if let autoBrightness = message["autoBrightness"] as? Bool {
            defaults.set(autoBrightness, forKey: "autoBrightness")
        }
        if let accelerometer = message["accelerometer"] as? Bool {
            defaults.set(accelerometer, forKey: "accelerometer")
        }
        if let sleepMode = message["sleepMode"] as? Bool {
            defaults.set(sleepMode, forKey: "sleepMode")
        }
        if let auroraMode = message["auroraMode"] as? Bool {
            // Note: your key is "arouraMode" (typo preserved to match your app)
            defaults.set(auroraMode, forKey: "arouraMode")
        }
        if let customMessage = message["customMessage"] as? String {
            defaults.set(customMessage, forKey: "customMessage")
        }
    }
    
    // MARK: - WCSessionDelegate (IMPORTANT: nonisolated entrypoints)
    
    // MARK: - WCSessionDelegate Methods
    
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        // Extract Sendable primitives *before* hopping actors
        let reachable = session.isReachable
        let errorDescription = error?.localizedDescription
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            let statusText: String
            switch activationState {
            case .activated:    statusText = "Connected"
            case .inactive:     statusText = "Inactive"
            case .notActivated: statusText = "Not Activated"
            @unknown default:   statusText = "Unknown State"
            }
            
            if let errorDescription {
                print("iOS: WCSession activation error: \(errorDescription)")
            }
            
            self.connectionStatus = statusText
            self.isReachable = (activationState == .activated) ? reachable : false
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            print("Reachability changed: \(reachable)")
            self.isReachable = reachable
            
            if self.connectionStatus == "Connected" && !reachable {
                self.connectionStatus = "Connected (Not Reachable)"
            } else if self.connectionStatus.hasPrefix("Connected") && reachable {
                self.connectionStatus = "Connected"
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let messageBox = UncheckedSendable(message)
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            let message = messageBox.value
            
            print("Received message: \(message)")
            self.applyAccessorySettingsFromMessage(message)
            if self.isNewTemperatureData(message) {
                self.messageSubject.send(message)
            } else {
                print("Duplicate/old temperature data received; skipping graph update.")
            }
        }
    }
    
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        let messageBox = UncheckedSendable(message)
        let replyBox = UncheckedSendable(replyHandler)
        
        Task { @MainActor [weak self] in
            guard let self else {
                // Always reply, even during teardown
                replyBox.value([:])
                return
            }
            
            let message = messageBox.value
            var replyData: [String: Any] = [:]
            
            if let command = message["command"] as? String, command == "getData" {
                let vm = self.accessoryViewModel
                replyData = [
                    "timestamp": Date(),
                    "deviceName": UIDevice.current.name,
                    "autoBrightness": vm.autoBrightness,
                    "accelerometer": vm.accelerometerEnabled,
                    "sleepMode": vm.sleepModeEnabled,
                    "auroraMode": vm.auroraModeEnabled,
                    "customMessage": vm.customMessage,
                    "controllerConnectionStatus": vm.connectionStatus,
                    "controllerName": vm.connectedDeviceName ?? "",
                    "temperatureText": vm.temperature
                ]
                
                if let latest = vm.temperatureData.last {
                    replyData["temperatureC"] = latest.temperature
                    replyData["temperatureTimestamp"] = latest.timestamp
                }
            } else {
                self.applyAccessorySettingsFromMessage(message)
                replyData["status"] = "Message received and processed on iOS."
            }
            
            if self.isNewTemperatureData(message) {
                self.messageSubject.send(message)
            } else {
                print("Duplicate/old temperature data received; skipping graph update.")
            }
            replyBox.value(replyData)
        }
    }
    
    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        let contextBox = UncheckedSendable(applicationContext)
        
        Task { @MainActor in
            let applicationContext = contextBox.value
            print("Received application context: \(applicationContext)")
            // Optional handle
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            print("WCSession did become inactive")
            self.connectionStatus = "Inactive"
            self.isReachable = false
        }
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            print("WCSession did deactivate, reactivating...")
            self.connectionStatus = "Deactivated"
            self.isReachable = false
            self.session.activate()   // <- use stored property, not parameter
        }
    }
    
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        // Extract primitives if you want to print them
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        
        Task { @MainActor in
            print("Watch state changed:")
            print(" - isPaired: \(paired)")
            print(" - isWatchAppInstalled: \(installed)")
        }
    }
}

// Helper extension (Included on both)
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

    @Published var accessoryViewModel: AccessoryViewModel = .shared

    private override init() { super.init() }

    func syncStateToWatch(from viewModel: AccessoryViewModel) { /* no-op */ }

    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        replyHandler?([:])
    }

    func updateApplicationContext(_ context: [String: Any]) { /* no-op */ }
}

#endif

