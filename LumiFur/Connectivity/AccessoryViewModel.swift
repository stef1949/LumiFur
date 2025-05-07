import SwiftUI
import Combine
import CoreBluetooth
import WidgetKit
import Foundation
import os

#if !targetEnvironment(macCatalyst)
import UIKit
import ActivityKit
import AccessorySetupKit
#endif

// MARK: - REQUIRED DEFINITIONS (Add these before AccessoryViewModel)

// --- Data Structures ---
struct PeripheralDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    let advertisementServiceUUIDs: [String]?
    let peripheral: CBPeripheral

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PeripheralDevice, rhs: PeripheralDevice) -> Bool { lhs.id == rhs.id }
}

// MARK: - AccessoryViewModel

@available(iOS 16.1, *)
class AccessoryViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = AccessoryViewModel()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AccessoryViewModel")

    // --- Threading ---
    private let bleQueue = DispatchQueue(label: "com.richies3d.lumifur.bleQueue", qos: .userInitiated)

    // MARK: Published Properties (Must be updated on Main Thread)
    @Published var connectionState: ConnectionState = .disconnected { didSet { updateWidgetAndActivityOnMain() } }
    @Published var isScanning: Bool = false
    @Published var discoveredDevices: [PeripheralDevice] = [] // Uses definition above
    @Published var temperature: String = "--" { didSet { updateWidgetAndActivityOnMain() } }
    
    
    
    @Published var temperatureData: [TemperatureData] = [] { didSet { updateWidgetAndActivityOnMain() } }
    
    // 1) Raw incoming temperature readings
        private let rawTempSubject = PassthroughSubject<TemperatureData, Never>()
    
        // 2) Public publisher of a down-sampled, 3-minute sliding window, throttled to 1 Hz
        lazy var temperatureChartPublisher: AnyPublisher<[TemperatureData], Never> = {
            rawTempSubject
                // build & maintain a 3-minute sliding buffer in place
                .scan([TemperatureData]()) { buffer, new in
                    // make a mutable copy
                    var buf = buffer
                    // 2) mutate buffer in place — do NOT return it
                    buf.append(new)
                    let cutoff = Date().addingTimeInterval(-3 * 60)
                    buf.removeAll { $0.timestamp < cutoff }
                    return buf
                }
                // only emit at most once per second
                .throttle(for: .seconds(5), scheduler: RunLoop.main, latest: true)
                // down-sample to ~100 points
                .map { buffer in
                    let strideSize = max(1, buffer.count / 100)
                    return buffer.enumerated().compactMap { idx, el in
                        idx % strideSize == 0 ? el : nil
                    }
                }
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        }()
        // 3) Call this whenever you get a new reading
        func didReceive(_ point: TemperatureData) {
            rawTempSubject.send(point)
        }
    
    
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var signalStrength: Int = -100 { didSet { updateWidgetAndActivityOnMain() } }
    @Published var connectingPeripheral: PeripheralDevice? = nil // Uses definition above
    @Published var cpuUsageData: [CPUUsageData] = [] // Uses definition above
    @Published var bootButtonState: Bool = false

    // User options - didSet triggers writes + UI updates
    @Published var selectedView: Int = 1 {
        didSet {
            // Only write if the change didn't come from the peripheral itself
            if !updateFromPeripheral {
                writeViewToCharacteristic() // Write initiated by UI/Watch
            }
            // Always update widgets/activities regardless of source
            updateWidgetAndActivityOnMain()
            // Reset the flag after processing didSet
            updateFromPeripheral = false
        }
    }
    
    @Published var autoBrightness: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
    @Published var accelerometerEnabled: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
    @Published var sleepModeEnabled: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
    @Published var auroraModeEnabled: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
    @Published var customMessage: String = "" { didSet { updateWidgetAndActivityOnMain() /* TODO: Add write if needed */ } }

    @Published var firmwareVersion: String = "N/A"
    @Published var previouslyConnectedDevices: [StoredPeripheral] = [] // Uses definition above

    // Derived Published Properties (Computed on Main Thread)
    var isConnected: Bool { connectionState == .connected }
    var isConnecting: Bool { connectionState == .connecting || connectionState == .reconnecting } // Uses fixed ConnectionState
    var connectionStatus: String { connectionState.rawValue }
    var connectionColor: Color { connectionState.color }
    var connectionImageName: String { connectionState.imageName }
    private var updateFromPeripheral = false
    
    var connectedDevice: PeripheralDevice? {
            guard isConnected, let target = targetPeripheral else { return nil }
            // Find the full PeripheralDevice object from your discovered list
            // based on the targetPeripheral's identifier
            return discoveredDevices.first { $0.id == target.identifier }
            // Note: This relies on discoveredDevices being up-to-date.
            // Alternatively, you could construct a basic PeripheralDevice here if needed,
            // but finding it in the list is usually better if possible.
        }

        // This property returns just the name String?
        var connectedDeviceName: String? {
            return targetPeripheral?.name
        }
   // var connectedDeviceName: String? { targetPeripheral?.name }
    
    var isBluetoothReady: Bool {
            // Check if centralManager is initialized AND its state is poweredOn
            guard let manager = centralManager else { return false } // Handle pre-initialization case
            return manager.state == .poweredOn
        }
    
    // MARK: Private Properties
    private var centralManager: CBCentralManager!
    @Published private(set) var targetPeripheral: CBPeripheral?
    private var targetCharacteristic: CBCharacteristic? // For View
    private var configCharacteristic: CBCharacteristic? // For Config
    private var temperatureCharacteristic: CBCharacteristic? // For Live Temp
    private var commandCharacteristic: CBCharacteristic? // For Commands
    private var temperatureLogsCharacteristic: CBCharacteristic? // For History

    private var rssiUpdateTimer: Timer?
    private var isManualDisconnect: Bool = false
    private var didAttemptAutoReconnect: Bool = false
    private var lastConnectedPeripheralUUID: String?

    // Service and characteristic UUIDs
    private let serviceUUID = CBUUID(string: "01931c44-3867-7740-9867-c822cb7df308")
    private let viewCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09fe")
    private let configCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09ff")
    private let tempCharUUID = CBUUID(string: "01931c44-3867-7b5d-9774-18350e3e27db")
    private let commandCharUUID = CBUUID(string: "0195eec3-06d2-7fd4-a561-49493be3ee41")
    private let temperatureLogsCharUUID = CBUUID(string: "0195eec2-ae6e-74a1-bcd5-215e2365477c")
    private let requestHistoryCommand: UInt8 = 0x01
    private let historyPacketType: UInt8 = 0x01

    private var cancellables = Set<AnyCancellable>()

    // MARK: - State for History Download
    @Published var isDownloadingHistory: Bool = false
    private var receivedHistoryChunks: [Int: Data] = [:]
    private var totalHistoryChunksExpected: Int? = nil
    private let maxTemperatureDataPoints = 200

    // MARK: - Live Activity
    private var currentActivity: Activity<LumiFur_WidgetAttributes>? = nil
    private var activityStateTask: Task<Void, Error>? = nil

    
    // MARK: Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)

        self.previouslyConnectedDevices = loadStoredPeripherals()
        self.lastConnectedPeripheralUUID = UserDefaults.standard.string(forKey: "LastConnectedPeripheralUUID")

        $targetPeripheral
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWidgetAndActivityOnMain()
            }
            .store(in: &cancellables)

        DispatchQueue.main.async {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleChangeViewIntent(_:)),
                name: .changeViewIntentTriggered,
                object: nil
            )
        }

        updateWidgetAndActivityOnMain()
        Task { await endAllLumiFurActivities() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .changeViewIntentTriggered, object: nil)
        rssiUpdateTimer?.invalidate()
        activityStateTask?.cancel()
        logger.info("AccessoryViewModel deinitialized.")
    }

    // MARK: - Public Methods (Called from UI - Main Thread)

    func scanForDevices() {
        bleQueue.async { [weak self] in self?._scanForDevices() }
    }

    func stopScan() {
        bleQueue.async { [weak self] in self?._stopScan() }
    }

    func connect(to device: PeripheralDevice) { // Uses definition
        bleQueue.async { [weak self] in self?._connect(to: device) }
    }

    func connectToStoredPeripheral(_ stored: StoredPeripheral) { // Uses definition
        bleQueue.async { [weak self] in self?._connectToStoredPeripheral(stored) }
    }

    func disconnect() {
        logger.info("Manual disconnect initiated.")
        isManualDisconnect = true
        Task { @MainActor in await endLiveActivity() }
        bleQueue.async { [weak self] in self?._disconnect() }
    }

    func setView(_ view: Int) {
        guard view >= 1 && view <= 20, view != selectedView else { return }
        logger.info("Setting view to \(view)")
        self.selectedView = view // didSet triggers write + widget update
    }

    func startRSSIMonitoring() {
        DispatchQueue.main.async { [weak self] in self?._startRSSIMonitoring() }
    }

    func stopRSSIMonitoring() {
        DispatchQueue.main.async { [weak self] in self?._stopRSSIMonitoring() }
    }

    // MARK: - Private Methods (Executed on BLE Queue)

    /// Internal scan logic, runs on bleQueue
    private func _scanForDevices() {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot scan: Bluetooth is not powered on")
            DispatchQueue.main.async { self.connectionState = .bluetoothOff } // Fixed enum case
            return
        }
        DispatchQueue.main.async {
            self.discoveredDevices.removeAll()
            self.connectionState = .scanning
            self.isScanning = true
        }
        logger.info("Starting BLE scan on bleQueue...")
        centralManager.scanForPeripherals(withServices: [self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: false)])
    }

    /// Internal stop scan logic, runs on bleQueue
    private func _stopScan() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.stopScan()
        logger.info("Stopped BLE scan on bleQueue.")
        DispatchQueue.main.async {
            self.isScanning = false
            if self.connectionState == .scanning {
                self.connectionState = .disconnected
            }
        }
    }

    /// Internal connect logic, runs on bleQueue
    private func _connect(to device: PeripheralDevice) { // Uses definition
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot connect: Bluetooth is not powered on.")
            DispatchQueue.main.async { self.connectionState = .bluetoothOff } // Fixed enum case
            return
        }
        _stopScan()
        let peripheralToConnect = device.peripheral
        DispatchQueue.main.async { [weak self] in // Added weak self
            guard let self = self else { return }
            self.connectingPeripheral = device
            self.connectionState = .connecting
            self.targetPeripheral = peripheralToConnect // Assign targetPeripheral on the main thread
        }
        isManualDisconnect = false
        logger.info("Attempting to connect to \(device.name) (\(device.id)) on bleQueue...")
        //targetPeripheral = device.peripheral
        targetPeripheral?.delegate = self
        centralManager.connect(device.peripheral, options: nil)
    }

    /// Internal disconnect logic, runs on bleQueue
    private func _disconnect() {
        if let peripheral = targetPeripheral {
            logger.log("Cancelling connection to peripheral: \(peripheral.name ?? "Unknown") (\(peripheral.identifier.uuidString)) on bleQueue")
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            logger.warning("Disconnect called but targetPeripheral is nil on bleQueue.")
        }
    }

    // MARK: - Encoding Helper
    /// Encodes accessory settings into a single Data payload.
    func encodedAccessorySettingsPayload(
        autoBrightness: Bool,
        accelerometerEnabled: Bool,
        sleepModeEnabled: Bool,
        auroraModeEnabled: Bool
    ) -> Data {
        return Data([
            autoBrightness ? 1 : 0,
            accelerometerEnabled ? 1 : 0,
            sleepModeEnabled ? 1 : 0,
            auroraModeEnabled ? 1 : 0
        ])
    }

    /// Internal method to write the selected view, runs on bleQueue
    private func writeViewToCharacteristic() {
        bleQueue.async { [weak self] in
            guard let self = self,
                  let peripheral = self.targetPeripheral,
                  let characteristic = self.targetCharacteristic
            else {
                self?.logger.warning("Cannot write view: peripheral or view characteristic not available.")
                return
            }
            let data = Data([UInt8(self.selectedView)])
            self.logger.debug("Writing view \(self.selectedView) to \(characteristic.uuid) on bleQueue")
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    /// Internal method to write config, runs on bleQueue
    func writeConfigToCharacteristic() {
        bleQueue.async { [weak self] in
            guard let self = self,
                  let peripheral = self.targetPeripheral,
                  let characteristic = self.configCharacteristic
            else {
                self?.logger.warning("Cannot write config: peripheral or config characteristic not available.")
                return
            }
            let payload = self.encodedAccessorySettingsPayload(
                autoBrightness: self.autoBrightness,
                accelerometerEnabled: self.accelerometerEnabled,
                sleepModeEnabled: self.sleepModeEnabled,
                auroraModeEnabled: self.auroraModeEnabled
            )
            let payloadHex = payload.map { String(format: "%02x", $0) }.joined(separator: " ")
            self.logger.debug("Writing config payload to \(characteristic.uuid): \(payloadHex) on bleQueue")
            peripheral.writeValue(payload, for: characteristic, type: .withResponse)
        }
    }

    /// Internal method to find characteristic, runs on bleQueue
    private func getCharacteristic(uuid: CBUUID) -> CBCharacteristic? {
        return targetPeripheral?.services?
            .first { $0.uuid == self.serviceUUID }?
            .characteristics?
            .first { $0.uuid == uuid }
    }

    // MARK: - CBCentralManagerDelegate Methods (Called on bleQueue)

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var newState: ConnectionState = .unknown
        var shouldScan = false
        var shouldAttemptReconnect = false

        switch central.state {
        case .poweredOn:
            newState = .disconnected
            shouldScan = true
            if !didAttemptAutoReconnect, let _ = lastConnectedPeripheralUUID {
                shouldAttemptReconnect = true; didAttemptAutoReconnect = true; shouldScan = false
                newState = .reconnecting // Fixed enum case
            }
        case .poweredOff: newState = .bluetoothOff; _stopScan() // Fixed enum case
        case .unauthorized: newState = .unknown; logger.error("Bluetooth unauthorized.")
        case .unsupported: newState = .unknown; logger.error("Bluetooth unsupported.")
        case .resetting: newState = .unknown; logger.warning("Bluetooth resetting.")
        case .unknown: newState = .unknown; logger.warning("Bluetooth state unknown.")
        @unknown default: newState = .unknown; logger.warning("Bluetooth state @unknown default.")
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if central.state != .poweredOn {
                self.targetPeripheral = nil; self.discoveredDevices.removeAll(); self.connectingPeripheral = nil; self.isScanning = false
                self.stopRSSIMonitoring(); Task { await self.endLiveActivity() }
            }
            self.connectionState = newState
            if shouldAttemptReconnect {
                self._connectToStoredUUID(self.lastConnectedPeripheralUUID!)
            } else if shouldScan && self.connectionState == .disconnected {
                self.scanForDevices()
            }
        }
    }

    private func _connectToStoredUUID(_ uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else {
            logger.error("Invalid UUID string for reconnect: \(uuidString)")
            DispatchQueue.main.async { self.connectionState = .disconnected }; _scanForDevices()
            return
        }
        logger.info("Retrieving peripheral for auto-reconnect: \(uuidString) on bleQueue")
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
            // Use PeripheralDevice initializer
            let device = PeripheralDevice(id: peripheral.identifier, name: peripheral.name ?? "Unknown", rssi: -100, advertisementServiceUUIDs: nil, peripheral: peripheral)
            _connect(to: device)
        } else {
            logger.warning("Peripheral \(uuidString) not found by retrievePeripherals. Starting scan.")
            DispatchQueue.main.async { self.connectionState = .disconnected }; _scanForDevices()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        guard let name = peripheral.name, !name.isEmpty else { return }
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { $0.uuidString }
        // Use PeripheralDevice initializer
        let device = PeripheralDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue, advertisementServiceUUIDs: serviceUUIDs, peripheral: peripheral)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let index = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self.discoveredDevices[index] = device
            } else {
                self.discoveredDevices.append(device)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to \(peripheral.name ?? "Unknown") (\(peripheral.identifier.uuidString)) on bleQueue.")
        peripheral.delegate = self
        let uuidString = peripheral.identifier.uuidString
        UserDefaults.standard.set(uuidString, forKey: "LastConnectedPeripheralUUID")
        lastConnectedPeripheralUUID = uuidString
        let name = peripheral.name ?? "Unknown"
        let id = peripheral.identifier
        addToPreviouslyConnected(id: uuidString, name: name)
        peripheral.discoverServices([self.serviceUUID])

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.targetPeripheral = peripheral
            self.connectionState = .connected
            self.isScanning = false
            self.connectingPeripheral = nil
            self.startRSSIMonitoring()
            
            self.startLumiFur_WidgetLiveActivity() // Run on main thread
            // Use PeripheralDevice initializer
            let device = PeripheralDevice(id: id, name: name, rssi: -100, advertisementServiceUUIDs: nil, peripheral: peripheral)
            if let index = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) { self.discoveredDevices[index] = device }
            else { self.discoveredDevices.append(device) }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        logger.error("Failed to connect to \(peripheral.name ?? "Unknown"). Error: \(error?.localizedDescription ?? "Unknown") on bleQueue.")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.targetPeripheral?.identifier == peripheral.identifier { self.targetPeripheral = nil }
            self.connectingPeripheral = nil; self.connectionState = .failed // Fixed enum case
            self.scanForDevices()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        let reason = error != nil ? "Error: \(error!.localizedDescription)" : (isManualDisconnect ? "Manual disconnect" : "Unexpected disconnect")
        logger.warning("Disconnected from \(peripheral.name ?? "Unknown"). Reason: \(reason) on bleQueue.")
        let wasManual = isManualDisconnect; let shouldReconnect = !wasManual; let reconnectUUID = lastConnectedPeripheralUUID
        isManualDisconnect = false

        // Create content state using the correct type initializer
        let finalActivityState = createContentState(connected: false, status: ConnectionState.disconnected.rawValue)
        let dismissalDate = Date().addingTimeInterval(15 * 60)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.targetPeripheral?.identifier == peripheral.identifier {
                self.targetPeripheral = nil; self.temperature = "--"; self.signalStrength = -100; self.firmwareVersion = "N/A"
                self.configCharacteristic = nil; self.targetCharacteristic = nil; self.temperatureCharacteristic = nil
                self.commandCharacteristic = nil; self.temperatureLogsCharacteristic = nil; self.temperatureData.removeAll()
            }
            self.stopRSSIMonitoring(); self.connectingPeripheral = nil; self.connectionState = .disconnected

            Task {
                if !wasManual {
                    self.logger.info("Scheduling Live Activity end for \(dismissalDate.formatted())")
                    await self.endLiveActivity(finalContent: finalActivityState, dismissalPolicy: .after(dismissalDate))
                } else {
                    await self.endLiveActivity(dismissalPolicy: .immediate)
                }
            }

            if shouldReconnect, let uuidToReconnect = reconnectUUID {
                self.logger.info("Attempting automatic reconnection to \(uuidToReconnect)")
                self.connectionState = .reconnecting // Fixed enum case
                self.bleQueue.async { self._connectToStoredUUID(uuidToReconnect) }
            } else {
                self.logger.info("Not auto-reconnecting. Starting scan."); self.scanForDevices()
            }
        }
    }

    // MARK: - CBPeripheralDelegate Methods (Called on bleQueue)

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error { logger.error("Error discovering services: \(error.localizedDescription)"); DispatchQueue.main.async { [weak self] in self?.showError(message: "Service discovery error") }; return }
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == self.serviceUUID {
            peripheral.discoverCharacteristics([viewCharUUID, configCharUUID, tempCharUUID, commandCharUUID, temperatureLogsCharUUID], for: service)
            return
        }
        logger.warning("Service \(self.serviceUUID) not found."); DispatchQueue.main.async { [weak self] in self?.showError(message: "Required service not found.") }; _disconnect()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error { logger.error("Error discovering characteristics: \(error.localizedDescription)"); DispatchQueue.main.async { [weak self] in self?.showError(message: "Characteristic discovery error") }; return }
        guard let characteristics = service.characteristics else { return }
        var foundCommand = false; var foundLogs = false
        for characteristic in characteristics {
            switch characteristic.uuid {
            case viewCharUUID: targetCharacteristic = characteristic; peripheral.setNotifyValue(true, for: characteristic); peripheral.readValue(for: characteristic)
            case configCharUUID: configCharacteristic = characteristic; peripheral.setNotifyValue(true, for: characteristic); peripheral.readValue(for: characteristic)
            case tempCharUUID: temperatureCharacteristic = characteristic; peripheral.setNotifyValue(true, for: characteristic)
            case commandCharUUID: commandCharacteristic = characteristic; peripheral.setNotifyValue(true, for: characteristic); foundCommand = true
            case temperatureLogsCharUUID: temperatureLogsCharacteristic = characteristic; peripheral.setNotifyValue(true, for: characteristic); foundLogs = true
            default: break
            }
        }
        if foundCommand, foundLogs, let cmdChar = commandCharacteristic {
            DispatchQueue.main.async { [weak self] in self?.resetHistoryDownloadState() }
            requestTemperatureHistory(peripheral: peripheral, characteristic: cmdChar)
        } else { logger.warning("Did not find all required characteristics for history download.") }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { logger.error("Error updating value for \(characteristic.uuid): \(error.localizedDescription)"); DispatchQueue.main.async { [weak self] in self?.showError(message: "Characteristic update error") }; return }
        guard let data = characteristic.value else { logger.warning("Received nil data for \(characteristic.uuid)."); return }
        switch characteristic.uuid {
        case viewCharUUID: handleViewUpdate(data: data)
        case configCharUUID: handleConfigUpdate(data: data)
        case tempCharUUID:
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDownloadingHistory else { return }
                self.bleQueue.async { self.handleLiveTemperatureUpdate(data: data) }
            }
        case temperatureLogsCharUUID: handleHistoryChunk(data: data)
        default: break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error { logger.error("Error reading RSSI: \(error.localizedDescription)"); return }
        DispatchQueue.main.async { [weak self] in self?.signalStrength = RSSI.intValue }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { logger.error("Error writing value to \(characteristic.uuid): \(error.localizedDescription)"); DispatchQueue.main.async { [weak self] in self?.showError(message: "Error writing command.") } }
        else { logger.debug("Successfully wrote value to \(characteristic.uuid).") }
    }

    // MARK: - Data Handling Helpers (Called on bleQueue)

    // Modify handleViewUpdate to set the flag
    private func handleViewUpdate(data: Data) {
        let viewValue = data.first.map { Int($0) } ?? 1
        logger.debug("Processing view update. Raw: \(data as NSData), Parsed: \(viewValue) on bleQueue.")

        DispatchQueue.main.async { [weak self] in
             guard let self = self else { return }
             if self.selectedView != viewValue {
                logger.info("Updating selectedView from peripheral data: \(self.selectedView) -> \(viewValue) (on main)")
                // Set flag BEFORE updating the published property
                self.updateFromPeripheral = true
                self.selectedView = viewValue // This will now trigger didSet, but writeViewToCharacteristic will be skipped
             } else {
                 logger.debug("Received view update (\(viewValue)) from peripheral, matches current state. Ignoring. (on main)")
             }
        }
    }

    private func handleConfigUpdate(data: Data) {
        guard data.count >= 4 else { return }
        let autoB = data[0] == 1; let accel = data[1] == 1; let sleep = data[2] == 1; let aurora = data[3] == 1
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.autoBrightness != autoB { self.autoBrightness = autoB }
            if self.accelerometerEnabled != accel { self.accelerometerEnabled = accel }
            if self.sleepModeEnabled != sleep { self.sleepModeEnabled = sleep }
            if self.auroraModeEnabled != aurora { self.auroraModeEnabled = aurora }
        }
    }

    // Inside AccessoryViewModel…

    private func handleLiveTemperatureUpdate(data: Data) {
        guard
            let tempString = String(data: data, encoding: .utf8),
            let tempValue = Double(
                tempString
                    .replacingOccurrences(of: "°C", with: "")
                    .trimmingCharacters(in: .whitespaces)
            )
        else {
            DispatchQueue.main.async { [weak self] in
                self?.temperature = "?"
            }
            return
        }

        let newDataPoint = TemperatureData(timestamp: Date(), temperature: tempValue)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // update the display string as before
            self.temperature = tempString
            // feed the Combine pipeline instead of mutating an array
            self.didReceive(newDataPoint)
        }
    }

    private func handleHistoryChunk(data: Data) {
        guard data.count >= 3 else { return }
        let packetType = data[0]; let chunkIndex = Int(data[1]); let totalChunks = Int(data[2]); let payload = data.subdata(in: 3..<data.count)
        guard packetType == historyPacketType else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.isDownloadingHistory { self.isDownloadingHistory = true; self.receivedHistoryChunks.removeAll(); self.totalHistoryChunksExpected = totalChunks }
            self.receivedHistoryChunks[chunkIndex] = payload
            if let totalExpected = self.totalHistoryChunksExpected, self.receivedHistoryChunks.count == totalExpected { self.bleQueue.async { self.processCompletedHistoryDownload() } }
        }
    }

    private func processCompletedHistoryDownload() {
        let chunksToProcess = self.receivedHistoryChunks; let totalChunks = self.totalHistoryChunksExpected ?? 0
        guard totalChunks > 0, chunksToProcess.count == totalChunks else { DispatchQueue.main.async { [weak self] in self?.resetHistoryDownloadState() }; return }
        var decodedHistoryPoints: [TemperatureData] = []; var errorOccurred = false; let processingStartTime = Date()
        for i in 0..<totalChunks {
            guard let chunkData = chunksToProcess[i] else { errorOccurred = true; break }
            let floatSize = MemoryLayout<Float>.stride; let floatCount = chunkData.count / floatSize
            for j in 0..<floatCount {
                let byteOffset = j * floatSize; guard byteOffset + floatSize <= chunkData.count else { errorOccurred = true; break }
                let floatBytes = chunkData.subdata(in: byteOffset..<byteOffset + floatSize); let tempValue = floatBytes.withUnsafeBytes { $0.load(as: Float.self) }
                let interval: TimeInterval = 60.0; let totalPoints = decodedHistoryPoints.count + (floatCount - 1 - j) + ((totalChunks - 1 - i) * 5)
                let estimatedTimestamp = processingStartTime.addingTimeInterval(-Double(totalPoints) * interval)
                decodedHistoryPoints.append(TemperatureData(timestamp: estimatedTimestamp, temperature: Double(tempValue)))
            }
            if errorOccurred { break }
        }
        if !errorOccurred {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                var combinedData = decodedHistoryPoints + self.temperatureData
                if combinedData.count > self.maxTemperatureDataPoints { combinedData.removeFirst(combinedData.count - self.maxTemperatureDataPoints) }
                self.temperatureData = combinedData; self.resetHistoryDownloadState()
            }
        } else { DispatchQueue.main.async { [weak self] in self?.resetHistoryDownloadState() } }
    }

    private func requestTemperatureHistory(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let commandData = Data([requestHistoryCommand])
        peripheral.writeValue(commandData, for: characteristic, type: .withResponse)
    }

    // MARK: - Timer Methods (Managed on Main Thread)
    private func _startRSSIMonitoring() {
        guard Thread.isMainThread else { return }
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.bleQueue.async { self?.targetPeripheral?.readRSSI() }
        }
    }

    private func _stopRSSIMonitoring() {
        guard Thread.isMainThread else { return }
        rssiUpdateTimer?.invalidate(); rssiUpdateTimer = nil
    }

    // MARK: - State Update Helpers (Called on Main Thread)
    private func resetHistoryDownloadState() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.resetHistoryDownloadState() }; return }
        isDownloadingHistory = false; receivedHistoryChunks.removeAll(); totalHistoryChunksExpected = nil
    }

    private func showError(message: String) {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.showError(message: message) }; return }
        errorMessage = message; showError = true
    }

    // MARK: - Persistence Helpers
    private func addToPreviouslyConnected(id: String, name: String) {
        let newDevice = StoredPeripheral(id: id, name: name)
        var storedDevices = loadStoredPeripherals()
        if !storedDevices.contains(where: { $0.id == newDevice.id }) {
            storedDevices.append(newDevice); saveStoredPeripherals(storedDevices)
            DispatchQueue.main.async { [weak self] in self?.previouslyConnectedDevices = storedDevices }
        }
    }

    private func loadStoredPeripherals() -> [StoredPeripheral] {
        guard let data = UserDefaults.standard.data(forKey: "PreviouslyConnectedPeripherals"),
              let stored = try? JSONDecoder().decode([StoredPeripheral].self, from: data) else { return [] }
        return stored
    }

    private func saveStoredPeripherals(_ devices: [StoredPeripheral]) {
        if let data = try? JSONEncoder().encode(devices) { UserDefaults.standard.set(data, forKey: "PreviouslyConnectedPeripherals") }
        else { logger.error("Failed to encode previously connected peripherals.") }
    }

    private func _connectToStoredPeripheral(_ stored: StoredPeripheral) { // Uses definition
        guard let uuid = UUID(uuidString: stored.id) else { logger.error("Invalid UUID string for stored peripheral: \(stored.id)"); return }
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
            // Use PeripheralDevice initializer
            let device = PeripheralDevice(id: peripheral.identifier, name: peripheral.name ?? stored.name, rssi: -100, advertisementServiceUUIDs: nil, peripheral: peripheral)
            _connect(to: device)
        } else {
            logger.warning("Stored peripheral \(uuid) not found by retrievePeripherals. Starting scan.")
            DispatchQueue.main.async { self.connectionState = .disconnected }; _scanForDevices()
        }
    }

    // MARK: - Widget & Live Activity Update Helpers (Called on Main Thread)
    private func updateWidgetAndActivityOnMain() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.updateWidgetAndActivityOnMain() }; return }
        updateWidgetData(); updateLumiFur_WidgetLiveActivity()
    }

    private func updateWidgetData() {
        guard Thread.isMainThread else { return }
        guard let defaults = UserDefaults(suiteName: SharedDataKeys.suiteName) else { return }
        defaults.set(isConnected, forKey: SharedDataKeys.isConnected)
        defaults.set(connectionStatus, forKey: SharedDataKeys.connectionStatus)
        defaults.set(connectedDeviceName, forKey: SharedDataKeys.controllerName)
        defaults.set(temperature, forKey: SharedDataKeys.temperature)
        defaults.set(signalStrength, forKey: SharedDataKeys.signalStrength)
        defaults.set(selectedView, forKey: SharedDataKeys.selectedView)
        // --- Fixed: Use correct keys from SharedDataKeys ---
        defaults.set(autoBrightness, forKey: SharedDataKeys.autoBrightness)
        defaults.set(accelerometerEnabled, forKey: SharedDataKeys.accelerometerEnabled)
        defaults.set(sleepModeEnabled, forKey: SharedDataKeys.sleepModeEnabled)
        defaults.set(auroraModeEnabled, forKey: SharedDataKeys.auroraModeEnabled)
        defaults.set(customMessage, forKey: SharedDataKeys.customMessage)
        saveTemperatureHistoryToUserDefaults(defaults: defaults)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedDataKeys.widgetKind)
    }

    private func saveTemperatureHistoryToUserDefaults(defaults: UserDefaults) {
        guard Thread.isMainThread else { return }
        let historyToSave = Array(temperatureData.suffix(50))
        do { let encodedData = try JSONEncoder().encode(historyToSave); defaults.set(encodedData, forKey: SharedDataKeys.temperatureHistory) }
        catch { logger.error("Failed to encode temperature history for widget: \(error)") }
    }

    // MARK: - Live Activity Management (Called on Main Thread)
    private func createContentState(connected: Bool? = nil, status: String? = nil) -> LumiFur_WidgetAttributes.ContentState {
        guard Thread.isMainThread else { return LumiFur_WidgetAttributes.ContentState(connectionStatus: "Error", signalStrength: -100, temperature: "--", selectedView: 1, isConnected: false, isScanning: false, temperatureChartData: [], sleepModeEnabled: true, auroraModeEnabled: true, customMessage: "") }
        let recentTemperatures = temperatureData.suffix(50).map { $0.temperature }
        // Use Initializer
        return LumiFur_WidgetAttributes.ContentState(connectionStatus: status ?? connectionStatus, signalStrength: signalStrength, temperature: temperature, selectedView: selectedView, isConnected: connected ?? isConnected, isScanning: isScanning, temperatureChartData: Array(recentTemperatures), sleepModeEnabled: sleepModeEnabled, auroraModeEnabled: auroraModeEnabled, customMessage: customMessage)
    }

    @available(iOS 16.1, *)
    func startLumiFur_WidgetLiveActivity() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.startLumiFur_WidgetLiveActivity() }; return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let connectedPeripheral = targetPeripheral else { return }
        Task {
            await endAllLumiFurActivities()
            let attributes = LumiFur_WidgetAttributes(name: connectedPeripheral.name ?? "LumiFur Device")
            let initialState = createContentState()
            do {
                let activity = try Activity<LumiFur_WidgetAttributes>.request(attributes: attributes, content: .init(state: initialState, staleDate: nil), pushType: nil)
                self.currentActivity = activity; logger.info("Started Live Activity: \(activity.id)")
                self.activityStateTask?.cancel(); self.activityStateTask = Task { await self.monitorActivityState(activity: activity) }
            } catch { logger.error("FAILED to start Live Activity: \(error.localizedDescription)"); self.currentActivity = nil }
        }
    }

    @available(iOS 16.1, *)
    private func monitorActivityState(activity: Activity<LumiFur_WidgetAttributes>) async {
        for await stateUpdate in activity.activityStateUpdates {
            logger.info("   Activity \(activity.id) state: \(activityStateDescription(stateUpdate))") // Use helper
            if stateUpdate == .dismissed || stateUpdate == .stale {
                Task { @MainActor [weak self] in
                    if self?.currentActivity?.id == activity.id { self?.currentActivity = nil; self?.activityStateTask?.cancel(); self?.activityStateTask = nil }
                }
                break
            }
        }
        Task { @MainActor [weak self] in if self?.currentActivity?.id == activity.id { self?.activityStateTask = nil } }
    }

    @available(iOS 16.1, *)
    func updateLumiFur_WidgetLiveActivity() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.updateLumiFur_WidgetLiveActivity() }; return }
        guard let activity = currentActivity, activity.activityState == .active else { return }
        let updatedState = createContentState()
        let updatedContent = ActivityContent(state: updatedState, staleDate: nil, relevanceScore: isConnected ? 100 : 50)
        Task { await activity.update(updatedContent) }
    }

    @available(iOS 16.1, *)
    private func endLiveActivity(finalContent: LumiFur_WidgetAttributes.ContentState? = nil, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        guard let activity = currentActivity else { return }
        logger.info("Ending Live Activity \(activity.id) policy: \(dismissalPolicyDescription(dismissalPolicy))") // Use helper
        activityStateTask?.cancel(); activityStateTask = nil
        let finalActivityContent = finalContent != nil ? ActivityContent(state: finalContent!, staleDate: nil) : nil
        await activity.end(finalActivityContent, dismissalPolicy: dismissalPolicy)
        logger.info("Requested end for LA \(activity.id). State: \(activityStateDescription(activity.activityState))") // Use helper
        currentActivity = nil
    }

    @available(iOS 16.1, *)
    private func endAllLumiFurActivities(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async {
        for activity in Activity<LumiFur_WidgetAttributes>.activities { await activity.end(nil, dismissalPolicy: dismissalPolicy) }
         Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let current = self.currentActivity, Activity<LumiFur_WidgetAttributes>.activities.first(where: { $0.id == current.id }) == nil {
                self.currentActivity = nil; self.activityStateTask?.cancel(); self.activityStateTask = nil
            }
        }
    }

    // MARK: - Intent Handling (Called on Main Thread via Notification)
    @objc private func handleChangeViewIntent(_ notification: Notification) {
        guard Thread.isMainThread else { return }
        if let userInfo = notification.userInfo, let nextView = userInfo["nextView"] as? Int { self.setView(nextView) }
    }

} // End of AccessoryViewModel


// MARK: - Helper Extensions
@available(iOS 16.1, *)
func activityStateDescription(_ state: ActivityState) -> String {
    switch state { case .active: return "active"; case .dismissed: return "dismissed"; case .ended: return "ended"; case .stale: return "stale"; @unknown default: return "unknown" }
}

@available(iOS 16.1, *)
func dismissalPolicyDescription(_ policy: ActivityUIDismissalPolicy) -> String {
    switch policy { case .default: return "default"; case .immediate: return "immediate"; default: return "other (e.g., after date)" }
}
