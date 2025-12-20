//
//  WatchConnectivityManager.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/14/25.
//
//  *** watchOS TARGET VERSION ***
//

import Foundation
import WatchConnectivity
import Combine
import SwiftUI
import WatchKit

struct TemperatureSample: Identifiable, Equatable {
    let timestamp: Date
    let temperatureC: Double

    var id: Date { timestamp }
}

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @MainActor static let shared = WatchConnectivityManager()  // Singleton
    
    // MARK: - Published Properties (For watchOS UI)
    @Published var connectionStatus: String = "Disconnected"
    @Published var isReachable: Bool = false
    @Published var companionDeviceName: String? = nil      // Received iPhone name
    @Published var connectedControllerName: String? = nil    // Received BLE Controller name
    @Published var controllerConnectionStatus: String = "Disconnected"
    @Published var temperatureText: String = "--"
    @Published var temperatureC: Double? = nil
    @Published var temperatureTimestamp: Date? = nil
    @Published var temperatureHistory: [TemperatureSample] = []
    
    // State properties for your settings view
    @Published var selectedView: Int = 1
    @Published var autoBrightness: Bool = false
    @Published var accelerometerEnabled: Bool = false
    @Published var sleepModeEnabled: Bool = false
    @Published var auroraModeEnabled: Bool = false
    @Published var customMessage: String = ""
    
    // MARK: - Combine Subjects
    let messageSubject = PassthroughSubject<[String: Any], Never>()
    
    // MARK: - Private Properties
    private let session: WCSession
    
    // MARK: - Initialization
    override private init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            print("WatchOS: WCSession activated.")
        } else {
            print("WatchOS: WCSession is not supported on this device.")
                       // Since this is the init, we can safely set these properties directly.
                       // No need for a dispatch queue here as the object is not yet in use.
                       self.connectionStatus = "Not Supported"
                       self.isReachable = false
        }
    }
    
    // MARK: - Public Sending Methods
    func sendMessage(_ message: [String: Any],
                     replyHandler: (([String: Any]) -> Void)? = nil,
                     errorHandler: ((Error) -> Void)? = nil) {
        guard session.activationState == .activated else {
            print("WatchOS: Session not activated.")
            errorHandler?(WCError(.sessionNotActivated))
            return
        }
        guard session.isCompanionAppInstalled else {
            print("WatchOS: Companion app not installed.")
            errorHandler?(WCError(.companionAppNotInstalled))
            return
        }
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: replyHandler) { error in
                print("WatchOS: Error sending message: \(error.localizedDescription)")
                errorHandler?(error)
            }
        } else {
            print("WatchOS: iPhone app is not reachable.")
            errorHandler?(WCError(.notReachable))
        }
    }
    
    func sendAccessorySettings() {
        let settings: [String: Any] = [
            "autoBrightness": self.autoBrightness,
            "accelerometer": self.accelerometerEnabled,
            "sleepMode": self.sleepModeEnabled,
            "auroraMode": self.auroraModeEnabled,
            "customMessage": self.customMessage
        ]
        print("WatchOS: Sending accessory settings: \(settings)")
        sendMessage(settings, replyHandler: { response in
            print("WatchOS: Received reply: \(response)")
        }, errorHandler: { error in
            print("WatchOS: Failed to send accessory settings: \(error.localizedDescription)")
        })
    }
    
    func updateGenericApplicationContext(_ context: [String: Any]) {
        guard session.activationState == .activated, session.isCompanionAppInstalled else {
            print("WatchOS: Cannot update context: Session not active or companion app missing.")
            return
        }
        do {
            try session.updateApplicationContext(context)
            print("WatchOS: Application context updated: \(context)")
        } catch {
            print("WatchOS: Error updating application context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - SYNC with iOS
    func requestSyncFromiOS() {
        print("WatchOS: Requesting sync from iOS")
        sendMessage(["command": "getData"], replyHandler: { response in
            print("WatchOS: Received sync response: \(response)")
            // Response handler is on a background thread,
            // so you must dispatch to the main thread to update the UI state.
            DispatchQueue.main.async {
                self.updateCompanionInfo(from: response)
                self.updateAccessorySettings(from: response)
            }
        }, errorHandler: { error in
            print("WatchOS: Failed to sync from iOS: \(error.localizedDescription)")
        })
    }
    
    // MARK: - WCSessionDelegate Methods
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // This delegate is on a background thread.
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.connectionStatus = "Connected"
                self.isReachable = session.isReachable
                print("WatchOS: WCSession activated.")
                
                // Once activated, check for any existing context from the phone.
                let receivedContext = session.receivedApplicationContext
                if !receivedContext.isEmpty {
                    self.updateCompanionInfo(from: receivedContext)
                }
                
            case .inactive:
                self.connectionStatus = "Inactive"
                self.isReachable = false
                print("WatchOS: WCSession inactive.")
            case .notActivated:
                self.connectionStatus = "Not Activated"
                self.isReachable = false
                print("WatchOS: WCSession not activated.")
            @unknown default:
                self.connectionStatus = "Unknown State"
                self.isReachable = false
                print("WatchOS: WCSession unknown state.")
            }
            
            if let error = error {
                print("WatchOS: Activation error: \(error.localizedDescription)")
                self.connectionStatus = "Error"
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        // Delegate is on a background thread.
        DispatchQueue.main.async {
            print("WatchOS: Reachability changed: \(session.isReachable)")
            self.isReachable = session.isReachable
            // FIX: More robust status update. Only show reachable status if fully connected.
            if self.session.activationState == .activated {
                self.connectionStatus = session.isReachable ? "Connected" : "Connected (Unreachable)"
            }
        }
    }
    
    // Delegate is on a background thread.
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("WatchOS: Received message: \(message)")
        
        // FIX: You MUST dispatch to the main thread before updating @Published properties.
        DispatchQueue.main.async {
            self.updateAccessorySettings(from: message)
            self.messageSubject.send(message)
        }
    }
    
    // Delegate is on a background thread.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        print("WatchOS: Received message with reply handler: \(message)")
        
        // Process the message and prepare a reply
        var replyData: [String: Any] = [:]
        if let command = message["command"] as? String, command == "getData" {
            replyData["status"] = "getData not supported on watchOS"
        }
        
        // FIX: You MUST dispatch to the main thread before updating @Published properties.
        DispatchQueue.main.async {
            self.updateAccessorySettings(from: message)
            self.messageSubject.send(message)
            // It's safe to call the replyHandler here, as it just sends data back.
            replyHandler(replyData)
        }
    }
    
    // Delegate is on a background thread.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("WatchOS: Received application context: \(applicationContext)")
        
        DispatchQueue.main.async {
            self.updateCompanionInfo(from: applicationContext)
            self.updateAccessorySettings(from: applicationContext)
        }
    }
    
    // MARK: - Private Helper Methods
    
    // FIX: Mark helper methods that modify @Published properties with @MainActor.
    // This enforces that they are always called on the main thread.
    @MainActor
    private func updateCompanionInfo(from context: [String: Any]) {
        if let name = context["deviceName"] as? String, self.companionDeviceName != name {
            self.companionDeviceName = name
            print("WatchOS: Updated companion device name: \(name)")
        }
        
        if let controllerName = context["controllerName"] as? String {
            let trimmed = controllerName.trimmingCharacters(in: .whitespacesAndNewlines)
            let nextValue: String? = trimmed.isEmpty ? nil : trimmed
            if self.connectedControllerName != nextValue {
                self.connectedControllerName = nextValue
                print("WatchOS: Updated connected controller name: \(nextValue ?? "nil")")
            }
        }
    }
    
    // FIX: Mark helper methods that modify @Published properties with @MainActor.
    @MainActor
    private func updateAccessorySettings(from data: [String: Any]) {
        if let view = data["selectedView"] as? Int, view != self.selectedView {
            self.selectedView = view
            print("WatchOS: Updated selectedView from sync: \(view)")
        }
        if let autoBrightness = data["autoBrightness"] as? Bool, autoBrightness != self.autoBrightness {
            self.autoBrightness = autoBrightness
            print("WatchOS: Updated autoBrightness: \(autoBrightness)")
        }
        if let accelerometer = data["accelerometer"] as? Bool, accelerometer != self.accelerometerEnabled {
            self.accelerometerEnabled = accelerometer
            print("WatchOS: Updated accelerometerEnabled: \(accelerometer)")
        }
        if let sleepMode = data["sleepMode"] as? Bool, sleepMode != self.sleepModeEnabled {
            self.sleepModeEnabled = sleepMode
            print("WatchOS: Updated sleepModeEnabled: \(sleepMode)")
        }
        if let auroraMode = data["auroraMode"] as? Bool, auroraMode != self.auroraModeEnabled {
            self.auroraModeEnabled = auroraMode
            print("WatchOS: Updated auroraModeEnabled: \(auroraMode)")
        }
        if let customMessage = data["customMessage"] as? String, customMessage != self.customMessage {
            self.customMessage = customMessage
            print("WatchOS: Updated customMessage: \(customMessage)")
        }

        if let status = data["controllerConnectionStatus"] as? String, status != self.controllerConnectionStatus {
            self.controllerConnectionStatus = status
            print("WatchOS: Updated controllerConnectionStatus: \(status)")

            if status == "Disconnected" || status == "Failed to connect" || status == "Bluetooth is off" {
                clearTemperatureCacheIfNeeded()
            }
        }

        if let tempText = data["temperatureText"] as? String, tempText != self.temperatureText {
            self.temperatureText = tempText
            print("WatchOS: Updated temperatureText: \(tempText)")
            if tempText == "--" {
                clearTemperatureCacheIfNeeded()
            }
        }

        if let tempC = data["temperatureC"] as? Double {
            if self.temperatureC != tempC {
                self.temperatureC = tempC
                print("WatchOS: Updated temperatureC: \(tempC)")
            }

            let timestamp = (data["temperatureTimestamp"] as? Date) ?? Date()
            if self.temperatureTimestamp != timestamp {
                self.temperatureTimestamp = timestamp
            }

            appendTemperatureSampleIfNeeded(tempC: tempC, timestamp: timestamp)
        }
    }

    @MainActor
    private func appendTemperatureSampleIfNeeded(tempC: Double, timestamp: Date) {
        // Avoid duplicates (syncs can resend the latest sample).
        if temperatureHistory.last?.timestamp == timestamp { return }

        temperatureHistory.append(.init(timestamp: timestamp, temperatureC: tempC))

        // Keep a small in-memory window for charts.
        let cutoff = Date().addingTimeInterval(-5 * 60)
        temperatureHistory.removeAll { $0.timestamp < cutoff }
    }

    @MainActor
    private func clearTemperatureCacheIfNeeded() {
        guard temperatureC != nil || temperatureTimestamp != nil || !temperatureHistory.isEmpty || temperatureText != "--" else { return }
        temperatureText = "--"
        temperatureC = nil
        temperatureTimestamp = nil
        temperatureHistory.removeAll()
    }
    
    // MARK: - App Lifecycle Integration
    func applicationDidBecomeActive() {
        print("WatchOS: App became active.")
        if session.activationState == .activated {
            self.requestSyncFromiOS()
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                DispatchQueue.main.async { self.updateCompanionInfo(from: context) }
            }
        }
    }
}


// MARK: - WCError Helper Extension
extension WCError {
    init(_ code: WCError.Code, userInfo: [String: Any] = [:]) {
        self.init(_nsError: NSError(domain: "WCErrorDomain", code: code.rawValue, userInfo: userInfo))
    }
}
