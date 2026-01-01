import Foundation
@preconcurrency import CoreBluetooth

// MARK: - Accessory Types (moved from AccessoryViewModel.swift)
struct PeripheralDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    let advertisementServiceUUIDs: [String]?
    let peripheral: CBPeripheral? // PeripheralDevice non-Codable by default. Made optional so we can use `nil` in previews

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PeripheralDevice, rhs: PeripheralDevice) -> Bool { lhs.id == rhs.id }
}

struct DeviceInfo: Codable {
    let fw: String
    let commit: String
    let branch: String
    let build: String
    let model: String
    let compat: String
    let id: String
}

struct StoredPeripheral: Identifiable, Codable, Hashable {
    let id: String // Stores peripheral.identifier.uuidString
    let name: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: StoredPeripheral, rhs: StoredPeripheral) -> Bool {
        lhs.id == rhs.id
    }
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

