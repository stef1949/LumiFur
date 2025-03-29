//
//  WatchConnectivityManager_watchOS.swift // RENAME THE FILE
//  LumiFur
//
//  Created by Stephan Ritchie on 2/14/25.
//
//  *** watchOS TARGET VERSION ***
//

import WatchConnectivity
import Combine
import SwiftUI  // For ObservableObject, @Published
import WatchKit // For WKInterfaceDevice

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager() // Singleton

    // MARK: - Published Properties (For watchOS UI)
    @Published var connectionStatus: String = "Initializing..."
    @Published var isReachable: Bool = false
    @Published var companionDeviceName: String? = nil // Stores received iPhone name
    @Published var connectedControllerName: String? = nil // Stores received BLE Controller name

    // MARK: - Combine Subjects (For watchOS App Logic)
    let messageSubject = PassthroughSubject<[String: Any], Never>()
    // let contextSubject = PassthroughSubject<[String: Any], Never>() // Define if needed

    // MARK: - Private Properties
    private let session: WCSession

    // MARK: - Initialization
    override private init() {
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            print("WatchOS: WCSession is supported. Activating session.")
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

    // MARK: - Public Sending Methods (watchOS Implementation)

    func sendMessage(_ message: [String: Any],
                     replyHandler: (([String: Any]) -> Void)? = nil,
                     errorHandler: ((Error) -> Void)? = nil) {

        guard session.activationState == .activated else {
            print("WatchOS: Cannot send message: Session not activated.")
            errorHandler?(WCError(.sessionNotActivated))
            return
        }
        guard session.isCompanionAppInstalled else {
            print("WatchOS: Cannot send message: Companion app not installed.")
            errorHandler?(WCError(.companionAppNotInstalled))
            return
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: replyHandler, errorHandler: { error in
                print("WatchOS: Error sending message: \(error.localizedDescription)")
                errorHandler?(error)
            })
        } else {
            print("WatchOS: Cannot send message: iPhone app is not reachable.")
            errorHandler?(WCError(.notReachable))
        }
    }

    // Use if watch needs to send its own context data
    func updateGenericApplicationContext(_ context: [String: Any]) {
         guard session.activationState == .activated else {
            print("WatchOS: Cannot update context: Session not activated.")
            return
        }
         guard session.isCompanionAppInstalled else {
             print("WatchOS: Cannot update context: Companion app not installed.")
             return
         }
        do {
            try session.updateApplicationContext(context)
            print("WatchOS: Generic application context updated successfully: \(context)")
        } catch {
            print("WatchOS: Error updating generic application context: \(error.localizedDescription)")
        }
    }


    // MARK: - WCSessionDelegate Methods (watchOS Implementation)

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let statusText: String
        var reachable = false

        switch activationState {
        case .activated: statusText = "Connected"; reachable = session.isReachable; print("WatchOS: WCSession activated successfully.")
        case .inactive: statusText = "Inactive"; print("WatchOS: WCSession inactive.")
        case .notActivated: statusText = "Not Activated"; print("WatchOS: WCSession not activated.")
        @unknown default: statusText = "Unknown State"; print("WatchOS: WCSession activation state unknown.")
        }

        if let error = error {
            print("WatchOS: WCSession activation failed with error: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
            self.connectionStatus = statusText
            self.isReachable = reachable

            if activationState == .activated {
                print("Watch Activated: Checking existing context from iOS...")
                let receivedContext = session.receivedApplicationContext // Non-optional dictionary
                if !receivedContext.isEmpty {
                    self.updateCompanionInfo(from: receivedContext)
                } else {
                     print("Watch Activated: No existing context found.")
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

    // --- Receiving Data ---

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("WatchOS Received message: \(message)")
        DispatchQueue.main.async {
            self.messageSubject.send(message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("WatchOS Received message with reply handler: \(message)")
        let replyData = ["status": "Message received successfully by \(WKInterfaceDevice.current().name)"] // Watch name
        DispatchQueue.main.async {
            self.messageSubject.send(message)
            replyHandler(replyData)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("WatchOS Received application context: \(applicationContext)")
        DispatchQueue.main.async {
            // self.contextSubject.send(applicationContext) // If broadcasting needed
            self.updateCompanionInfo(from: applicationContext) // Update state based on received context
        }
    }

    // MARK: - Private Helper for Processing Context (watchOS Specific)

    /// **watchOS ONLY:** Updates local state based on received Application Context from iOS.
    private func updateCompanionInfo(from context: [String: Any]) {
        var updated = false
        // Process iPhone name
        if let name = context["deviceName"] as? String {
            if self.companionDeviceName != name {
                self.companionDeviceName = name; updated = true
                print("Watch Updated companion device name: \(name)")
            }
        } else if context.keys.contains("deviceName") && self.companionDeviceName != nil {
             self.companionDeviceName = nil; updated = true
             print("Watch Cleared companion device name.")
        }

        // Process Controller name
        if context.keys.contains("controllerName") {
            let controllerName = context["controllerName"] as? String
            if self.connectedControllerName != controllerName {
                self.connectedControllerName = controllerName; updated = true
                print("Watch Updated connected controller name: \(controllerName ?? "None")")
            }
        }
         if !updated { print("Watch Received context, but no relevant state changed.")}
    }

     // MARK: - App Lifecycle Integration (watchOS Stub/Implementation)
     func applicationDidBecomeActive() {
          print("Watch App became active.")
          // Re-check context just in case it was missed during activation
          if session.activationState == .activated {
              let context = session.receivedApplicationContext
              if !context.isEmpty {
                  DispatchQueue.main.async { self.updateCompanionInfo(from: context) }
              }
          }
     }

    // NOTE: iOS specific delegate methods (sessionDidBecomeInactive, etc.) are NOT implemented here.

} // End of Class (watchOS)


// Helper extension for WCError (Can be shared or duplicated)
extension WCError {
    init(_ code: WCError.Code, userInfo: [String : Any] = [:]) {
        self.init(_nsError: NSError(domain: "WCErrorDomain", code: code.rawValue, userInfo: userInfo))
    }
}
