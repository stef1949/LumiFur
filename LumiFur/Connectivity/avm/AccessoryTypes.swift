import Foundation
@preconcurrency import CoreBluetooth

// MARK: - Accessory Types

/// A UI-facing representation of a discovered peripheral.
struct PeripheralDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    let advertisementServiceUUIDs: [String]?
    let peripheral: CBPeripheral? // PeripheralDevice non-Codable by default. Made optional so we can use `nil` in previews

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PeripheralDevice, rhs: PeripheralDevice) -> Bool { lhs.id == rhs.id }
}

/// Firmware metadata advertised by the controller.
struct DeviceInfo: Codable, Equatable, Sendable {
    let fw: String
    let commit: String
    let branch: String
    let build: String
    let model: String
    let compat: String
    let id: String
}

/// A previously connected peripheral persisted in user defaults.
struct StoredPeripheral: Identifiable, Codable, Hashable, Sendable {
    let id: String // Stores peripheral.identifier.uuidString
    let name: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: StoredPeripheral, rhs: StoredPeripheral) -> Bool {
        lhs.id == rhs.id
    }
}

/// A Sendable snapshot of an advertised peripheral used by the BLE transport.
struct PeripheralDiscovery: Sendable {
    let id: UUID
    let name: String
    let rssi: Int
    let advertisementServiceUUIDs: [String]?
    let peripheral: UncheckedSendableBox<CBPeripheral>
}

/// A Sendable snapshot of a successfully connected peripheral.
struct PeripheralConnection: Sendable {
    let peripheral: UncheckedSendableBox<CBPeripheral>
    let name: String?
}

/// A Sendable snapshot of a connection failure.
struct PeripheralFailure: Sendable {
    let id: String
    let name: String?
    let message: String?
}

/// A Sendable snapshot of a disconnect event.
struct PeripheralDisconnection: Sendable {
    let id: String
    let name: String?
    let message: String?
}

/// A parsed strobe state from the controller.
struct StrobeState: Equatable, Sendable {
    let enabled: Bool
    let rgb: RGB8
    let cycleMs: UInt16
}


#if DEBUG
extension PeripheralDevice {
    static let mock: PeripheralDevice = PeripheralDevice(
        id: UUID(),
        name: "LumiFur-1234",
        rssi: -55,
        advertisementServiceUUIDs: ["FFF0"],
        peripheral: nil               // Previews. We never actually connect
    )
}
#endif
