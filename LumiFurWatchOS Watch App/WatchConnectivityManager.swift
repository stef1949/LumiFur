//
//  WatchConnectivityManager.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/14/25.
//

import WatchConnectivity
import SwiftUI

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager() // Singleton instance

    @Published var connectionStatus: String = "Not connected"

    override private init() {
        super.init()
        activateSession()
    }

    private func activateSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self  // 'self' is strongly referenced here.
            session.activate()
        }
    }

    // MARK: - WCSessionDelegate Methods

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.connectionStatus = "Error: \(error.localizedDescription)"
            } else {
                self.connectionStatus = "Connected (\(activationState.rawValue))"
            }
        }
    }

    #if !os(watchOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession did become inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession did deactivate, reactivating...")
        WCSession.default.activate()
    }
    #endif

    // Example for handling incoming messages:
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message: \(message)")
    }
}
