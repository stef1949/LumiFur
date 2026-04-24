import Foundation
import os

// MARK: - StoredPeripheralStore

/// Persists previously connected peripherals and the last connected peripheral UUID.
struct StoredPeripheralStore {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LumiFur",
        category: "StoredPeripheralStore"
    )

    private let defaults: UserDefaults
    private let devicesKey = "PreviouslyConnectedPeripherals"
    private let lastConnectedKey = "LastConnectedPeripheralUUID"

    init(defaults: UserDefaults = StoredPeripheralStore.defaultUserDefaults()) {
        self.defaults = defaults
    }

    func load() -> [StoredPeripheral] {
        guard let data = defaults.data(forKey: devicesKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([StoredPeripheral].self, from: data)
        } catch {
            logger.error("Failed to decode stored peripherals: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ devices: [StoredPeripheral]) {
        do {
            defaults.set(try JSONEncoder().encode(devices), forKey: devicesKey)
        } catch {
            logger.error("Failed to encode stored peripherals: \(error.localizedDescription)")
        }
    }

    func upsert(id: String, name: String) -> [StoredPeripheral] {
        let newDevice = StoredPeripheral(id: id, name: name)
        var devices = load()

        if let existingIndex = devices.firstIndex(where: { $0.id == id }) {
            devices[existingIndex] = newDevice
        } else {
            devices.append(newDevice)
        }

        save(devices)
        return devices
    }

    func lastConnectedPeripheralUUID() -> String? {
        defaults.string(forKey: lastConnectedKey)
    }

    func setLastConnectedPeripheralUUID(_ uuid: String?) {
        if let uuid {
            defaults.set(uuid, forKey: lastConnectedKey)
        } else {
            defaults.removeObject(forKey: lastConnectedKey)
        }
    }

    private static func defaultUserDefaults() -> UserDefaults {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
           let isolated = UserDefaults(suiteName: "com.richies3d.LumiFur.tests") {
            return isolated
        }

        return .standard
    }
}
