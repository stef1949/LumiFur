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

        // Note: The #if os(watchOS) check for isCompanionAppInstalled is *NOT* included here for iOS

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

    // MARK: - WCSessionDelegate Methods (Common)

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let statusText: String
        var reachable = false

        switch activationState {
        case .activated: statusText = "Connected"; reachable = session.isReachable; print("WCSession activated successfully.")
        case .inactive: statusText = "Inactive"; print("WCSession inactive.")
        case .notActivated: statusText = "Not Activated"; print("WCSession not activated.")
        @unknown default: statusText = "Unknown State"; print("WCSession activation state unknown.")
        }

        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
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

    // --- Receiving Data (Common) ---
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message: \(message)")
        DispatchQueue.main.async {
            self.messageSubject.send(message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message with reply handler: \(message)")

        // Process the message...
        var replyData: [String: Any] = [:] // Default to an empty dictionary

        if let command = message["command"] as? String, command == "getData" {
            // Example: Prepare some data for the reply
            //replyData["requestedData"] = "Here is the data from \(WKInterfaceDevice.current().name)" // Use WKInterfaceDevice on watchOS
            replyData["timestamp"] = Date()
        } else {
            // Example: Just acknowledge receipt if command unknown or not requiring data
            replyData["status"] = "Message received and processed by Watch"
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
        session.activate() // Reactivate
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
