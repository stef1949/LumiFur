//
//  WatchOSConnectivity.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/14/25.
//

import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import SwiftUI
import Combine

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @MainActor static let shared = WatchConnectivityManager()
    
    // MARK: - Published Properties for SwiftUI
    @Published var connectionStatus: String = "Initializing..."
    @Published var isReachable: Bool = false
    
    // MARK: - Subject for Received Messages
    let messageSubject = PassthroughSubject<[String: Any], Never>()
    // let contextSubject = PassthroughSubject<[String: Any], Never>() // Uncomment if using context
    
    private let session: WCSession
    // Use the updated accessory view model.
    @Published var accessoryViewModel = AccessoryViewModel.shared  // Use the shared instance
    
    // MARK: - Initialization
    override private init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            print("WCSession is supported. Activating session.")
        } else {
            print("WCSession is not supported on this device.")
            DispatchQueue.main.async {
                self.connectionStatus = "Not Supported"
                self.isReachable = false
            }
        }
    }
    
    // MARK: - Public Sending Methods
    func sendMessage(_ message: [String: Any],
                     replyHandler: (([String: Any]) -> Void)? = nil,
                     errorHandler: ((Error) -> Void)? = nil) {
        
        guard session.activationState == .activated else {
            print("Cannot send message: Session not activated.")
            errorHandler?(WCError(.sessionNotActivated))
            return
        }
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: replyHandler, errorHandler: { error in
                print("Error sending message: \(error.localizedDescription)")
                errorHandler?(error)
            })
        } else {
            print("Cannot send message: Counterpart app is not reachable.")
            errorHandler?(WCError(.notReachable))
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
    
    // MARK: - Helper to Update Accessory Settings from Message
    private func updateAccessorySettingsFromMessage(_ message: [String: Any]) {
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
        
        // Update AppStorage via UserDefaults so that SwiftUI views bound to these keys update.
                let defaults = UserDefaults.standard
                if let autoBrightness = message["autoBrightness"] as? Bool {
                    defaults.set(autoBrightness, forKey: "autoBrightness")
                    print("iOS: AppStorage autoBrightness updated to \(autoBrightness)")
                }
                if let accelerometer = message["accelerometer"] as? Bool {
                    defaults.set(accelerometer, forKey: "accelerometer")
                    print("iOS: AppStorage accelerometer updated to \(accelerometer)")
                }
                if let sleepMode = message["sleepMode"] as? Bool {
                    defaults.set(sleepMode, forKey: "sleepMode")
                    print("iOS: AppStorage sleepMode updated to \(sleepMode)")
                }
                if let auroraMode = message["auroraMode"] as? Bool {
                    // Note: The AppStorage key is "arouraMode" per your snippet.
                    defaults.set(auroraMode, forKey: "arouraMode")
                    print("iOS: AppStorage arouraMode updated to \(auroraMode)")
                }
                if let customMessage = message["customMessage"] as? String {
                    defaults.set(customMessage, forKey: "customMessage")
                    print("iOS: AppStorage customMessage updated to \"\(customMessage)\"")
                }
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
                print("iOS: WCSession activated successfully.")
            case .inactive:
                statusText = "Inactive"
                print("iOS: WCSession inactive.")
            case .notActivated:
                statusText = "Not Activated"
                print("iOS: WCSession not activated.")
            @unknown default:
                statusText = "Unknown State"
                print("iOS: WCSession activation state unknown.")
            }
            
            if let error = error {
                print("iOS: WCSession activation error: \(error.localizedDescription)")
            }
        
        DispatchQueue.main.async {
            self.connectionStatus = statusText
            self.isReachable = reachable
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("Reachability changed: \(session.isReachable)")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if self.connectionStatus == "Connected" && !session.isReachable {
                self.connectionStatus = "Connected (Not Reachable)"
            } else if self.connectionStatus.starts(with: "Connected") && session.isReachable {
                self.connectionStatus = "Connected"
            }
        }
    }
    
    // --- Receiving Data ---
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message: \(message)")
        // Update the accessory view model when a message is received.
        DispatchQueue.main.async {
            self.updateAccessorySettingsFromMessage(message)
            self.messageSubject.send(message)
        }
    }
    
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message with reply handler: \(message)")
        var replyData: [String: Any] = [:] // Default to an empty dictionary
        
        if let command = message["command"] as? String, command == "getData" {
            let vm = self.accessoryViewModel
            replyData = [
                "timestamp": Date(),
                "autoBrightness": vm.autoBrightness,
                "accelerometer": vm.accelerometerEnabled,
                "sleepMode": vm.sleepModeEnabled,
                "auroraMode": vm.auroraModeEnabled,
                "customMessage": vm.customMessage
            ]
            print("iOS: Responding with current accessory settings: \(replyData)")
        } else {
            self.updateAccessorySettingsFromMessage(message)
            replyData["status"] = "Message received and processed on iOS."
        }
        
        // ALWAYS call replyHandler with a valid dictionary
        DispatchQueue.main.async { // Or background if processing takes time, but call handler when done
            self.messageSubject.send(message) // Still broadcast if needed
            replyHandler(replyData) // <-- Pass the prepared dictionary (which might be empty)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Received application context: \(applicationContext)")
        DispatchQueue.main.async {
            // Handle context update in your app logic here...
            // self.contextSubject.send(applicationContext) // Uncomment if using context
        }
    }
    
    // MARK: - iOS Specific Delegate Methods (Included because #if os(iOS) is true)
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession did become inactive")
        DispatchQueue.main.async {
            self.connectionStatus = "Inactive"
            self.isReachable = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession did deactivate, reactivating...")
        DispatchQueue.main.async {
            self.connectionStatus = "Deactivated"
            self.isReachable = false
        }
        session.activate() // Reactivate the session
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        print("Watch state changed:")
        print(" - isPaired: \(session.isPaired)")
        print(" - isWatchAppInstalled: \(session.isWatchAppInstalled)")
        DispatchQueue.main.async {
            // Update UI or state if needed
        }
    }
}

// Helper extension (Included on both)
extension WCError {
    init(_ code: WCError.Code) {
        self.init(code, userInfo: [:])
    }
}
