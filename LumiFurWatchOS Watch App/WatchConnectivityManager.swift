//
//  WatchConnectivityManager.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/14/25.
//
//  *** watchOS TARGET VERSION ***
//

import WatchConnectivity
import Combine
import SwiftUI
import WatchKit

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @MainActor static let shared = WatchConnectivityManager()  // Singleton

    // MARK: - Published Properties (For watchOS UI)
    @Published var connectionStatus: String = "Disconnected"
    @Published var isReachable: Bool = false
    @Published var companionDeviceName: String? = nil      // Received iPhone name
    @Published var connectedControllerName: String? = nil    // Received BLE Controller name
    
    @Published var selectedView: Int = 1
    // Accessory options
    @Published var autoBrightness: Bool = false {
        didSet { if oldValue != autoBrightness { print("WatchOS: autoBrightness toggled to \(autoBrightness)"); sendAccessorySettings() } }
    }
    @Published var accelerometerEnabled: Bool = false {
        didSet { if oldValue != accelerometerEnabled { print("WatchOS: accelerometerEnabled toggled to \(accelerometerEnabled)"); sendAccessorySettings() } }
    }
    @Published var sleepModeEnabled: Bool = false {
        didSet { if oldValue != sleepModeEnabled { print("WatchOS: sleepModeEnabled toggled to \(sleepModeEnabled)"); sendAccessorySettings() } }
    }
    @Published var auroraModeEnabled: Bool = false {
        didSet { if oldValue != auroraModeEnabled { print("WatchOS: auroraModeEnabled toggled to \(auroraModeEnabled)"); sendAccessorySettings() } }
    }
    @Published var customMessage: String = "" {
        didSet { if oldValue != customMessage { print("WatchOS: customMessage changed to \"\(customMessage)\""); sendAccessorySettings() } }
    }
    
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
            DispatchQueue.main.async {
                self.connectionStatus = "Not Supported"
                self.isReachable = false
                self.companionDeviceName = nil
                self.connectedControllerName = nil
            }
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
            DispatchQueue.main.async { self.updateAccessorySettings(from: response) }
        }, errorHandler: { error in
            print("WatchOS: Failed to sync from iOS: \(error.localizedDescription)")
        })
    }
    
    // MARK: - WCSessionDelegate Methods
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        let statusText: String
        var reachable = false
        
        switch activationState {
        case .activated:
            statusText = "Connected"
            reachable = session.isReachable
            print("WatchOS: WCSession activated.")
        case .inactive:
            statusText = "Inactive"
            print("WatchOS: WCSession inactive.")
        case .notActivated:
            statusText = "Not Activated"
            print("WatchOS: WCSession not activated.")
        @unknown default:
            statusText = "Unknown State"
            print("WatchOS: WCSession unknown state.")
        }
        
        if let error = error {
            print("WatchOS: Activation error: \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async {
            self.connectionStatus = statusText
            self.isReachable = reachable
            
            if activationState == .activated {
                print("WatchOS: Checking context from iOS...")
                let receivedContext = session.receivedApplicationContext
                if !receivedContext.isEmpty {
                    self.updateCompanionInfo(from: receivedContext)
                } else {
                    print("WatchOS: No context found.")
                }
            } else {
                self.companionDeviceName = nil
                self.connectedControllerName = nil
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("WatchOS: Reachability changed: \(session.isReachable)")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if self.connectionStatus.starts(with: "Connected") {
                self.connectionStatus = session.isReachable ? "Connected" : "Connected (Not Reachable)"
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("WatchOS: Received message: \(message)")
        self.updateAccessorySettings(from: message)
        DispatchQueue.main.async {
            self.messageSubject.send(message)
        }
    }
    
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        print("WatchOS: Received message with reply handler: \(message)")
        var replyData: [String: Any] = [:]
        if let command = message["command"] as? String, command == "getData" {
            replyData["status"] = "getData not supported on watchOS"
        } else {
            replyData["status"] = "Unrecognized command. Message processed on Watch."
        }
        self.updateAccessorySettings(from: message)
        DispatchQueue.main.async {
            self.messageSubject.send(message)
            replyHandler(replyData)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("WatchOS: Received application context: \(applicationContext)")
        DispatchQueue.main.async {
            self.updateCompanionInfo(from: applicationContext)
            self.updateAccessorySettings(from: applicationContext)
        }
    }
    
    // MARK: - Private Helper Methods
    private func updateCompanionInfo(from context: [String: Any]) {
        var updated = false
        if let name = context["deviceName"] as? String, self.companionDeviceName != name {
            self.companionDeviceName = name
            updated = true
            print("WatchOS: Updated companion device name: \(name)")
        } else if context.keys.contains("deviceName"), self.companionDeviceName != nil {
            self.companionDeviceName = nil
            updated = true
            print("WatchOS: Cleared companion device name.")
        }
        
        if let controllerName = context["controllerName"] as? String,
           self.connectedControllerName != controllerName {
            self.connectedControllerName = controllerName
            updated = true
            print("WatchOS: Updated connected controller name: \(controllerName)")
        }
        
        if !updated {
            print("WatchOS: No companion info changes detected.")
        }
    }
    
    private func updateAccessorySettings(from data: [String: Any]) {
        var updated = false
        
        if let autoBrightness = data["autoBrightness"] as? Bool, autoBrightness != self.autoBrightness {
            self.autoBrightness = autoBrightness
            print("WatchOS: Updated autoBrightness: \(autoBrightness)")
            updated = true
        }
        if let accelerometer = data["accelerometer"] as? Bool, accelerometer != self.accelerometerEnabled {
            self.accelerometerEnabled = accelerometer
            print("WatchOS: Updated accelerometerEnabled: \(accelerometer)")
            updated = true
        }
        if let sleepMode = data["sleepMode"] as? Bool, sleepMode != self.sleepModeEnabled {
            self.sleepModeEnabled = sleepMode
            print("WatchOS: Updated sleepModeEnabled: \(sleepMode)")
            updated = true
        }
        if let auroraMode = data["auroraMode"] as? Bool, auroraMode != self.auroraModeEnabled {
            self.auroraModeEnabled = auroraMode
            print("WatchOS: Updated auroraModeEnabled: \(auroraMode)")
            updated = true
        }
        if let customMessage = data["customMessage"] as? String, customMessage != self.customMessage {
            self.customMessage = customMessage
            print("WatchOS: Updated customMessage: \(customMessage)")
            updated = true
        }
        if !updated {
            print("WatchOS: No accessory settings changes detected.")
        }
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
