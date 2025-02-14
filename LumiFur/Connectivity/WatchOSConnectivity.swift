//
//  WatchOSConnectivity.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/14/25.
//

import Foundation
import WatchConnectivity

class iOSConnectivityProvider: NSObject, WCSessionDelegate {
    static let shared = iOSConnectivityProvider()
    
    override private init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate Methods
    
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("iOS WCSession activated: \(activationState.rawValue)")
    }
    
    // These two methods are required on iOS 13+.
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession did become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession did deactivate, reactivating...")
        WCSession.default.activate()
    }
    
    // Optional: Handle incoming messages from watchOS.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let command = message["command"] as? String {
            print("Received command from watch: \(command)")
            // Process the command accordingly.
            replyHandler(["response": "Command \(command) processed"])
        }
    }
}
