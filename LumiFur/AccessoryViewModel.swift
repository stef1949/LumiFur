import Foundation
import AccessorySetupKit
import CoreBluetooth
import SwiftUI


class AccessoryViewModel: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var discoveredAccessories: [ASAccessory] = []
    @Published var connectionStatus = "Disconnected"
    
    private var session = ASAccessorySession()
    private var currentAccessory: ASAccessory?
    
    // Define the service UUID
    private let serviceUUID = CBUUID(string: "01931c44-3867-7740-9867-c822cb7df308")
    
    override init() {
            super.init()
            // Activate the session and handle events
            session.activate(on: DispatchQueue.main) { [weak self] event in
                self?.handleSessionEvent(event: event)
            }
        }

        // MARK: - Handle Session Events

        private func handleSessionEvent(event: ASAccessoryEvent) {
            switch event.eventType {
            case .activated:
                connectionStatus = "Session activated. Discovering accessories..."
            case .accessoryAdded:
                if let accessory = event.accessory {
                    DispatchQueue.main.async {
                        if !self.discoveredAccessories.contains(where: { $0.bluetoothIdentifier == accessory.bluetoothIdentifier }) {
                            self.discoveredAccessories.append(accessory)
                            print("Accessory added: \(accessory.displayName)")
                        }
                    }
                }
            case .accessoryRemoved:
                if let accessory = event.accessory {
                    DispatchQueue.main.async {
                        self.discoveredAccessories.removeAll { $0.bluetoothIdentifier == accessory.bluetoothIdentifier }
                        print("Accessory removed: \(accessory.displayName)")
                    }
                }
            default:
                print("Unhandled event: \(event.eventType)")
            }
        }

        // MARK: - Connect to Accessory

        func connectToAccessory(_ accessory: ASAccessory) {
            guard accessory.bluetoothIdentifier != nil else {
                connectionStatus = "Cannot connect. Missing Bluetooth identifier."
                return
            }

            // Simulate a connection process (use CoreBluetooth for real connection)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.currentAccessory = accessory
                self.isConnected = true
                self.connectionStatus = "Connected to \(accessory.displayName)"
            }
        }

        func disconnectAccessory() {
            guard isConnected else {
                connectionStatus = "No active connection."
                return
            }

            // Simulate a disconnection process
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.currentAccessory = nil
                self.isConnected = false
                self.connectionStatus = "Disconnected."
            }
        }
    }
