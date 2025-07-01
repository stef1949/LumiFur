import SwiftUI
import Combine
import CoreBluetooth
import WidgetKit
import Foundation
import os
#if !targetEnvironment(macCatalyst )
#if !targetEnvironment(watchOS )
import UIKit
#endif // !targetEnvironment(watchOS )
import ActivityKit
import AccessorySetupKit
#endif // !targetEnvironment(macCatalyst )

// MARK: - REQUIRED DEFINITIONS (Add these before AccessoryViewModel)

// --- Data Structures ---
struct PeripheralDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    let advertisementServiceUUIDs: [String]?
    let peripheral: CBPeripheral //PeripheralDevice non-Codable by default
    
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

// ADDED: Definition for StoredPeripheral
struct StoredPeripheral: Identifiable, Codable, Hashable {
    let id: String // Stores peripheral.identifier.uuidString
    let name: String
    
    // Conformance to Identifiable is met by 'let id: String'
    // Conformance to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    // Conformance to Equatable (provided by Hashable if all stored properties are Equatable,
    // but explicit definition is fine and clear)
    static func == (lhs: StoredPeripheral, rhs: StoredPeripheral) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
// MARK: - AccessoryViewModel
@available(iOS 16.1, *)
class AccessoryViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = AccessoryViewModel()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AccessoryViewModel")
    
    // --- Threading ---
    private let bleQueue = DispatchQueue(label: "com.richies3d.lumifur.bleQueue", qos: .userInitiated)
    
    // MARK: Published Properties (Must be updated on Main Thread)
    @Published var deviceInfo: DeviceInfo? = nil
    //@Published var connectionState: ConnectionState = .disconnected { didSet { updateWidgetAndActivityOnMain() } }
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isScanning: Bool = false
    @Published var discoveredDevices: [PeripheralDevice] = [] // Uses definition above
    //@Published var temperature: String = "--" { didSet { updateWidgetAndActivityOnMain() } }
    @Published var temperature: String = "--"
    //@Published var temperatureData: [TemperatureData] = [] { didSet { updateWidgetAndActivityOnMain() } }
    @Published var temperatureData: [TemperatureData] = []
    
    @Published var brightness: UInt8 = 255 // No didSet, handled by .sink
    private var brightnessCharacteristic: CBCharacteristic?
    
    /// Call this whenever you want to write the new brightness to the device.
    private func writeBrightness(_ newValue: UInt8) {
        guard let peripheral = targetPeripheral,
              let characteristic = brightnessCharacteristic else {
            logger.warning("Cannot write brightness: peripheral or brightness characteristic not available.")
            return
        }
        
        let data = Data([newValue])
        logger.debug("Writing brightness \(newValue) to \(characteristic.uuid) on bleQueue")
        bleQueue.async {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
    }
    
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
    //@Published var signalStrength: Int = -100 { didSet { updateWidgetAndActivityOnMain() } }
    @Published var signalStrength: Int = -100
    @Published var connectingPeripheral: PeripheralDevice? = nil // Uses definition above
    @Published var cpuUsageData: [CPUUsageData] = [] // Uses definition above
    @Published var bootButtonState: Bool = false
    
    // User options - didSet triggers writes + UI updates
    //@Published var selectedView: Int = 1 {
    @Published private(set) var selectedView: Int = 1
    
    // MARK: - OTA State Tracking
    @Published var otaStatusMessage: String = "Idle"
    @Published var otaProgress: Double = 0.0
    private var totalOTASize: Int = 0
    private var otaBytesSent: Int = 0
    private var otaTimer: Timer?
    
    /*
     @Published var autoBrightness: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
     @Published var accelerometerEnabled: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
     @Published var sleepModeEnabled: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
     @Published var auroraModeEnabled: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
     @Published var customMessage: String = "" { didSet { updateWidgetAndActivityOnMain() /* TODO: Add write if needed */ } }
     */
    @Published var autoBrightness: Bool = true { didSet { writeConfigToCharacteristic() } }
    @Published var accelerometerEnabled: Bool = true { didSet { writeConfigToCharacteristic() } }
    @Published var sleepModeEnabled: Bool = true { didSet { writeConfigToCharacteristic() } }
    @Published var auroraModeEnabled: Bool = true { didSet { writeConfigToCharacteristic() } }
    @Published var customMessage: String = "" { didSet { writeConfigToCharacteristic() } }
    
    @Published var firmwareVersion: String = "N/A"
    @Published var previouslyConnectedDevices: [StoredPeripheral] = [] // Uses definition above
    
    // Derived Published Properties (Computed on Main Thread)
    var isConnected: Bool { connectionState == .connected }
    var isConnecting: Bool { connectionState == .connecting || connectionState == .reconnecting } // Uses fixed ConnectionState
    var connectionStatus: String { connectionState.rawValue }
    var connectionColor: Color { connectionState.color }
    // var connectionImageName: String { connectionState.imageName }
    
    var connectionImageName: Image {
        connectionState.image
    }
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
    private var otaCharacteristic: CBCharacteristic? // For OTA Updates
    
    private var rssiUpdateTimer: Timer?
    private var isManualDisconnect: Bool = false
    @Published var autoReconnectEnabled: Bool = true
    private var didAttemptAutoReconnect: Bool = false
    private var lastConnectedPeripheralUUID: String?
    
    // Service and characteristic UUIDs
    private let serviceUUID = CBUUID(string: "01931c44-3867-7740-9867-c822cb7df308")
    private let viewCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09fe")
    private let configCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09ff")
    private let tempCharUUID = CBUUID(string: "01931c44-3867-7b5d-9774-18350e3e27db")
    private let commandCharUUID = CBUUID(string: "0195eec3-06d2-7fd4-a561-49493be3ee41")
    private let temperatureLogsCharUUID = CBUUID(string: "0195eec2-ae6e-74a1-bcd5-215e2365477c")
    private let brightnessCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09ef")
    private let requestHistoryCommand: UInt8 = 0x01
    private let historyPacketType: UInt8 = 0x01
    //private let deviceInfoServiceUUID = CBUUID(string: "cba1d466-344c-4be3-ab3f-189f80dd7518")
    private let deviceInfoCharUUID = CBUUID(string: "cba1d466-344c-4be3-ab3f-189f80dd7599")
    private let otaCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09ee")
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - State for History Download
    @Published var isDownloadingHistory: Bool = false
    private var receivedHistoryChunks: [Int: Data] = [:]
    private var totalHistoryChunksExpected: Int? = nil
    private let maxTemperatureDataPoints = 200
    
    // MARK: - Live Activity
    private var currentActivity: Activity<LumiFur_WidgetAttributes>? = nil
    private var activityStateTask: Task<Void, Error>? = nil
    
    // 2) A subject you’ll send new samples into
    let temperatureSubject = PassthroughSubject<TemperatureData, Never>()
    
    @MainActor
    // MARK: Initialization
    override init() {
        super.init()
        
        temperatureSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in
                self?.temperatureData.append(sample)
            }
            .store(in: &cancellables)
        
        // Whenever `brightness` changes, send it over BLE
        $brightness
            .dropFirst() // ignore initial value
            .debounce(for: .milliseconds(5), scheduler: RunLoop.main) // ADDED: Debounce UI changes
            .sink { [weak self] newVal in
                guard let self = self else { return }
                // ADDED: Only write if the change didn't come from the peripheral
                if !self.updateFromPeripheral {
                    self.writeBrightness(newVal)
                }
            }
            .store(in: &cancellables)
        
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)
        
        self.previouslyConnectedDevices = loadStoredPeripherals()
        logger.info("Initialized previouslyConnectedDevices with \(self.previouslyConnectedDevices.count) items: \(self.previouslyConnectedDevices.map { $0.name })") // ADD THIS
        self.lastConnectedPeripheralUUID = UserDefaults.standard.string(forKey: "LastConnectedPeripheralUUID")
        
        $targetPeripheral
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.updateWidgetAndActivity()
                }
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
        
        // 2) ALSO listen for “app became active”
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // ————————————————————————————————————————————————
        // Batch all widget/LiveActivity updates into one debounce:
        //Publishers.MergeMany(
        // 1) Build an array of AnyPublisher<Void,Never>:
        let uiUpdateTriggers: [AnyPublisher<Void, Never>] = [
            $connectionState.map    { _ in () }.eraseToAnyPublisher(),
            $temperature.map        { _ in () }.eraseToAnyPublisher(),
            $temperatureData.map    { _ in () }.eraseToAnyPublisher(),
            $signalStrength.map     { _ in () }.eraseToAnyPublisher(),
            $autoBrightness.map     { _ in () }.eraseToAnyPublisher(),
            $accelerometerEnabled.map { _ in () }.eraseToAnyPublisher(),
            $sleepModeEnabled.map     { _ in () }.eraseToAnyPublisher(),
            $auroraModeEnabled.map    { _ in () }.eraseToAnyPublisher(),
            $selectedView.map         { _ in () }.eraseToAnyPublisher(),
            $customMessage.map        { _ in () }.eraseToAnyPublisher()
        ]
        
        // 2) Merge them, debounce, and sink:
        Publishers.MergeMany(uiUpdateTriggers)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.updateWidgetAndActivity()
                }
            }
            .store(in: &cancellables)
        // ————————————————————————————————————————————————
        
        Task { @MainActor in
            self.updateWidgetAndActivity()
        }
        Task { await endAllLumiFurActivities() }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        rssiUpdateTimer?.invalidate()
        activityStateTask?.cancel()
        logger.info("AccessoryViewModel deinitialized.")
    }
    
    // MARK: — APP BACK TO FOREGROUND
    @objc private func appDidBecomeActive() {
        // Only if we’re actually connected, and we don’t already have one
        guard isConnected else { return }
        
        // Check our stored reference _and_ the system list
        let alreadyRunning = currentActivity?.activityState == .active
        || !Activity<LumiFur_WidgetAttributes>.activities.isEmpty
        
        guard !alreadyRunning else {
            logger.info("App open → live activity already present; skipping start.")
            return
        }
        // Kick off the async start
        Task { @MainActor in
            logger.info("App open → no live activity, launching one now.")
            await startLumiFur_WidgetLiveActivity()
        }
    }
    
    // MARK: - Public Methods (Called from UI - Main Thread)
    
    /// OTA Update Methods
    
    func startOTAUpdate(firmwareData: Data) {
        guard let peripheral = targetPeripheral,
              let characteristic = commandCharacteristic else {
            otaStatusMessage = "OTA Error: Peripheral not ready"
            return
        }
        
        otaStatusMessage = "Starting OTA..."
        otaProgress = 0.0
        otaBytesSent = 0
        totalOTASize = firmwareData.count
        
        var size = UInt32(firmwareData.count)
        var packet = Data([0x01])
        packet.append(Data(bytes: &size, count: 4))
        
        peripheral.writeValue(packet, for: characteristic, type: .withResponse)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.sendOTAPayload(firmwareData: firmwareData)
        }
    }
    
    private func sendOTAPayload(firmwareData: Data) {
        guard let peripheral = targetPeripheral,
              let characteristic = commandCharacteristic else { return }
        
        let mtu = 185
        let chunkSize = mtu - 3
        var offset = 0
        
        otaTimer?.invalidate()
        otaTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if offset >= firmwareData.count {
                timer.invalidate()
                self.endOTAUpdate()
                return
            }
            
            let end = min(offset + chunkSize, firmwareData.count)
            let chunk = firmwareData.subdata(in: offset..<end)
            var packet = Data([0x02])
            packet.append(chunk)
            
            peripheral.writeValue(packet, for: characteristic, type: .withResponse)
            offset += chunk.count
            self.otaBytesSent = offset
            self.otaProgress = Double(offset) / Double(self.totalOTASize)
            self.otaStatusMessage = "Uploading... \(Int(self.otaProgress * 100))%"
        }
    }
    
    func endOTAUpdate() {
        guard let peripheral = targetPeripheral,
              let characteristic = commandCharacteristic else { return }
        
        otaStatusMessage = "Finalizing OTA..."
        let endPacket = Data([0x03])
        peripheral.writeValue(endPacket, for: characteristic, type: .withResponse)
    }
    
    func abortOTAUpdate() {
        guard let peripheral = targetPeripheral,
              let characteristic = otaCharacteristic else { return }
        
        otaTimer?.invalidate()
        otaProgress = 0.0
        otaStatusMessage = "OTA Aborted"
        let abortPacket = Data([0x04])
        peripheral.writeValue(abortPacket, for: characteristic, type: .withResponse)
    }
    func scanForDevices() {
        DispatchQueue.main.async { self._scanForDevices() }
    }

    func stopScan() {
        DispatchQueue.main.async { self._stopScan() }
    }
    func connect(to device: PeripheralDevice) { // Uses definition
        DispatchQueue.main.async { self._connect(to: device) }
    }
    func connectToStoredPeripheral(_ stored: StoredPeripheral) { // Uses definition
        DispatchQueue.main.async { self._connectToStoredPeripheral(stored) }
    }
    @MainActor
    func disconnect() {
        // schedule everything on the BLE queue
        bleQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1) mark this as a manual disconnect (on bleQueue!)
            self.isManualDisconnect = true
            
            // 2) actually cancel the connection
            if let p = self.targetPeripheral {
                self.logger.info("Manual disconnect → cancelling on bleQueue.")
                self.centralManager.cancelPeripheralConnection(p)
            }
        }
    }
    
    // 2) In your “button” action, change + write + schedule all in one place:
    func setView(_ view: Int) {
        guard view >= 1 && view <= 50, view != selectedView else { return }
        logger.info("Setting view to \(view)")
        // Update model
        selectedView = view
        // Send to peripheral immediately
        writeViewToCharacteristic()
        // Debounced widget / LiveActivity update
        scheduleLiveActivityUpdate()
    }
    
    // 3) Same for face buttons:
    func faceButtonTapped(_ faceIndex: Int) {
        guard faceIndex != selectedView else { return }
        selectedView = faceIndex
        writeViewToCharacteristic()
        scheduleLiveActivityUpdate()
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
        guard !isScanning else {
            logger.debug("Scan already in progress—skipping duplicate scan call.")
            return
        }
        
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot scan: Bluetooth is not powered on")
            DispatchQueue.main.async { self.connectionState = .bluetoothOff } // Fixed enum case
            return
        }
        
        // Reset UI state
        DispatchQueue.main.async {
            self.discoveredDevices.removeAll()
            self.connectionState = .scanning
            self.isScanning = true
        }
        
        logger.info("Starting BLE scan on bleQueue...")
        centralManager.scanForPeripherals(
            withServices: [self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: false)])
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
        //targetPeripheral = device.peripheral // Redundent as it is set on Main thread
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
        // 1️⃣ Compute desired new state & flags
        var newState: ConnectionState = .unknown
        var shouldScan = false
        var shouldAttemptReconnect = false
        
        switch central.state {
        case .poweredOn:
            newState = .disconnected
            shouldScan = true
            // only check existence here; don’t bind `uuid` until we use it
            if !didAttemptAutoReconnect, lastConnectedPeripheralUUID != nil {
                didAttemptAutoReconnect   = true
                shouldAttemptReconnect    = true
                shouldScan                = false
                newState                  = .reconnecting
            }
            
        case .poweredOff:
            newState = .bluetoothOff
            _stopScan()
        case .unauthorized:
            newState = .unknown
            logger.error("Bluetooth unauthorized.")
        case .unsupported:
            newState = .unknown
            logger.error("Bluetooth unsupported.")
        case .resetting:
            newState = .unknown
            logger.warning("Bluetooth resetting.")
        case .unknown:
            newState = .unknown
            logger.warning("Bluetooth state unknown.")
            
            /*@unknown */ default:
            newState = .unknown
            logger.warning("Bluetooth state @unknown default.")
        }
        
        // snapshot into immutable lets
        let stateCopy      = newState
        let scanCopy       = shouldScan
        let reconnectCopy  = shouldAttemptReconnect
        let uuidToTry      = lastConnectedPeripheralUUID
        
        
        // 2️⃣ perform UI/state updates on the main queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.connectionState = stateCopy
            self.scheduleLiveActivityUpdate()
            
            if central.state != .poweredOn {
                self.targetPeripheral     = nil
                self.discoveredDevices.removeAll()
                self.connectingPeripheral = nil
                self.isScanning           = false
                self.stopRSSIMonitoring()
            }
            
            // 3️⃣ reconnect or scan
            if reconnectCopy, let uuid = uuidToTry {
                self.logger.info("Auto-reconnect to \(uuid)")
                self.bleQueue.async { [weak self] in
                    self?._connectToStoredUUID(uuid)
                }
            }
            else if scanCopy, self.connectionState == .disconnected {
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
            let device = PeripheralDevice(id: peripheral.identifier, name: peripheral.name ?? "Unknown", rssi: self.signalStrength, advertisementServiceUUIDs: nil, peripheral: peripheral)
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
        // 1) If we have a stored UUID and this is our old device, auto-reconnect:
        if let lastUUID = lastConnectedPeripheralUUID,
           peripheral.identifier.uuidString == lastUUID,
           connectionState == .reconnecting { // Only if we are actively trying to reconnect
            logger.info("Auto-reconnect (via scan): found stored peripheral \(lastUUID), stopping scan and connecting.")
            _stopScan() // Stop scan before connecting
            
            let device = PeripheralDevice(
                id: peripheral.identifier,
                name: peripheral.name ?? "Unknown",
                rssi: RSSI.intValue,
                advertisementServiceUUIDs: (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map(\.uuidString),
                peripheral: peripheral
            )
            // Kick off connect on the bleQueue (already on it, but for consistency)
            _connect(to: device) // No need for bleQueue.async here as we are already on it.
            return
        }
        
        // 2) Otherwise, normal discovery UI update:
        guard let name = peripheral.name, !name.isEmpty else { return }
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
            .map { $0.uuidString }
        
        let device = PeripheralDevice(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            advertisementServiceUUIDs: serviceUUIDs,
            peripheral: peripheral
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let idx = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self.discoveredDevices[idx] = device
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
        //let id = peripheral.identifier
        addToPreviouslyConnected(id: uuidString, name: name)
        peripheral.discoverServices([self.serviceUUID])
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.targetPeripheral = peripheral
            self.connectionState = .connected
            self.isScanning = false
            self.connectingPeripheral = nil
            self.startRSSIMonitoring()
            self.didAttemptAutoReconnect = false // Reset for next BT cycle
            self.startRSSIMonitoring() // This internally dispatches to main for timer setup
            // ——————— Live Activity handling ———————
            if let activity = self.currentActivity,
               activity.activityState == .active {
                // already running: just update it
                self.scheduleLiveActivityUpdate()
            } else {
                // not running yet: start a new one
                Task { @MainActor in
                    await self.startLumiFur_WidgetLiveActivity()
                }
            }
            // Use PeripheralDevice initializer
            let device = PeripheralDevice(id: peripheral.identifier, name: name, rssi: self.signalStrength, advertisementServiceUUIDs: nil, peripheral: peripheral)
            if let index =
                self.discoveredDevices.firstIndex(where: { $0.id == device.id }) { self.discoveredDevices[index] = device
            } else { self.discoveredDevices.append(device)
            }
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
            self.didAttemptAutoReconnect = false // Allow retry on next BT power on
            // Decide if we should scan or not. If auto-reconnect failed, scanning is often the next step.
            if !self.isScanning { self.scanForDevices() }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        // We’ll need to know if we should try to reconnect later
        // let reconnectUUID = lastConnectedPeripheralUUID
        let wasManual = isManualDisconnect
        isManualDisconnect = false // Reset flag
        
        let peripheralName = peripheral.name ?? "Unknown"
        let peripheralID = peripheral.identifier.uuidString
        let errorDescription = error?.localizedDescription ?? "No error"
        logger.info("Disconnected from \(peripheralName) (\(peripheralID)). Was manual: \(wasManual). Error: \(errorDescription) on bleQueue.")
        
        Task { @MainActor in
            self.logger.info("didDisconnectPeripheral: wasManual = \(wasManual)")
            
            // Reset connection-specific state
            if self.targetPeripheral?.identifier == peripheral.identifier {
                self.targetPeripheral = nil
                self.temperature = "--"
                self.signalStrength = -100
                self.firmwareVersion = "N/A"
                self.configCharacteristic = nil
                self.targetCharacteristic = nil
                self.temperatureCharacteristic = nil
                self.commandCharacteristic = nil
                self.temperatureLogsCharacteristic = nil
                self.temperatureData.removeAll() // Or decide if you want to keep old data
                self.brightnessCharacteristic = nil // ADDED: Reset brightness characteristic
            }
            
            self.connectionState = .disconnected
            self.connectingPeripheral = nil
            self.stopRSSIMonitoring() // This internally dispatches to main
            
            // Live Activity handling
            let finalState = self.createContentState(
                connected: false,
                status: ConnectionState.disconnected.rawValue
            )
            
            // 3️⃣ End or schedule end of the Live Activity
            if wasManual {
                self.logger.info("Manual disconnect → ending Live Activity immediately.")
                await self.endLiveActivity(finalContent: finalState, dismissalPolicy: .immediate)
            } else if error != nil { // Unexpected disconnect with error
                let dismissalDate = Date().addingTimeInterval(15 * 60) // Keep LA for a while
                self.logger.info("Unexpected disconnect (with error) → ending Live Activity at \(dismissalDate).")
                await self.endLiveActivity(finalContent: finalState, dismissalPolicy: .after(dismissalDate))
            } else { // Graceful disconnect from peripheral side (e.g. peripheral powered off)
                self.logger.info("Graceful disconnect from peripheral → ending Live Activity immediately.")
                await self.endLiveActivity(finalContent: finalState, dismissalPolicy: .immediate)
            }
            // currentActivity is set to nil by endLiveActivity
            
            // Reconnect or scan logic
            if !wasManual && self.autoReconnectEnabled,
               let uuidToReconnect = self.lastConnectedPeripheralUUID {
                self.logger.info("Auto-Reconnect is ON → attempting reconnect to \(uuidToReconnect)")
                self.connectionState = .reconnecting // Update state
                // Re-enable auto-reconnect attempt flag if it was specific to one session
                self.didAttemptAutoReconnect = false
                bleQueue.async { [uuidToReconnect] in
                    AccessoryViewModel.shared._connectToStoredUUID(uuidToReconnect)
                }
            } else if !wasManual {
                self.logger.info("Not auto-reconnecting (either disabled or no last UUID); starting scan.")
                if !self.isScanning { self.scanForDevices() } // Start scan if not already scanning
            }
            // If it was a manual disconnect, typically we go to .disconnected and wait for user action.
        }
    }
    
    // MARK: - CBPeripheralDelegate Methods (Called on bleQueue)
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription)"); DispatchQueue.main.async { [weak self] in self?.showError(message: "Service discovery error") }; return }
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == self.serviceUUID {
            let characteristicsToDiscover = [
                viewCharUUID,
                configCharUUID,
                tempCharUUID,
                commandCharUUID,
                temperatureLogsCharUUID,
                brightnessCharUUID,
                deviceInfoCharUUID,
                otaCharUUID
            ]
            peripheral.discoverCharacteristics(characteristicsToDiscover, for: service)
            return
        }
        logger.warning("Service \(self.serviceUUID) not found."); DispatchQueue.main.async { [weak self] in self?.showError(message: "Required service not found.") }; _disconnect()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger.error("Error discovering characteristics for service \(service.uuid) on \(peripheral.identifier.uuidString): \(error.localizedDescription)");
            DispatchQueue.main.async { [weak self] in self?.showError(message: "Characteristic discovery error: \(error.localizedDescription)") };
            _disconnect() // Critical failure
            return
        }
        guard let characteristics = service.characteristics else {
            logger.warning("No characteristics found for service \(service.uuid) on \(peripheral.identifier.uuidString).")
            _disconnect() // Critical failure
            return
        }
        
        var foundAllRequired = true // Assume success initially
        for characteristic in characteristics {
            logger.debug("Found characteristic \(characteristic.uuid) for service \(service.uuid)")
            switch characteristic.uuid {
            case deviceInfoCharUUID:
                peripheral.readValue(for: characteristic)
            case viewCharUUID:
                targetCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic) // Initial read
            case configCharUUID:
                configCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic) // Initial read
            case tempCharUUID:
                temperatureCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case commandCharUUID:
                commandCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic) // Ensure notifications are enabled if peripheral sends responses here
            case temperatureLogsCharUUID:
                temperatureLogsCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case brightnessCharUUID: // ADDED: Handle brightness characteristic
                brightnessCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic) // Enable notifications for two-way sync
                // Optionally read initial value:
                peripheral.readValue(for: characteristic)
            case otaCharUUID:
                otaCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                logger.debug("Ignoring unknown characteristic \(characteristic.uuid)")
            }
        }
        
        // Verify all essential characteristics were found
        if targetCharacteristic == nil { logger.warning("View characteristic (\(self.viewCharUUID)) not found."); foundAllRequired = false }
        if configCharacteristic == nil { logger.warning("Config characteristic (\(self.configCharUUID)) not found."); foundAllRequired = false }
        if temperatureCharacteristic == nil { logger.warning("Temperature characteristic (\(self.tempCharUUID)) not found."); foundAllRequired = false }
        if commandCharacteristic == nil { logger.warning("Command characteristic (\(self.commandCharUUID)) not found."); foundAllRequired = false }
        if temperatureLogsCharacteristic == nil { logger.warning("TemperatureLogs characteristic (\(self.temperatureLogsCharUUID)) not found."); foundAllRequired = false }
        if brightnessCharacteristic == nil { logger.warning("Brightness characteristic (\(self.brightnessCharUUID)) not found."); foundAllRequired = false } // ADDED
        if otaCharacteristic == nil { logger.warning("OTA characteristic (\(self.otaCharUUID)) not found."); foundAllRequired = false }
        if !foundAllRequired {
            logger.error("Essential characteristics missing for \(peripheral.identifier.uuidString). Disconnecting.")
            DispatchQueue.main.async { [weak self] in self?.showError(message: "Essential characteristics missing.") }
            _disconnect()
            return
        }
        
        logger.info("All required characteristics discovered and configured for \(peripheral.identifier.uuidString).")
        // Request history after confirming commandCharacteristic is set
        if let cmdChar = commandCharacteristic {
            DispatchQueue.main.async { [weak self] in self?.resetHistoryDownloadState() } // Reset on main
            requestTemperatureHistory(peripheral: peripheral, characteristic: cmdChar)
        } else {
            // This case should be caught by foundAllRequired check, but as a safeguard:
            logger.warning("Command characteristic not available for history download request.")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error updating value for \(characteristic.uuid): \(error.localizedDescription)");
            DispatchQueue.main.async { [weak self] in self?.showError(message: "Characteristic \(characteristic.uuid.uuidString.prefix(4)) update error") };
            return
        }
        guard let data = characteristic.value else {
            logger.warning("Received nil data for \(characteristic.uuid) on \(peripheral.identifier.uuidString).");
            return
        }
        switch characteristic.uuid {
        case deviceInfoCharUUID:
            if let jsonString = String(data: data, encoding: .utf8),
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    let info = try JSONDecoder().decode(DeviceInfo.self, from: jsonData)
                    DispatchQueue.main.async { [weak self] in
                        self?.deviceInfo = info
                        self?.firmwareVersion = info.fw // Optional: to bind to existing UI
                    }
                } catch {
                    logger.error("Failed to decode DeviceInfo JSON: \(error.localizedDescription)")
                }
            } else {
                logger.warning("Invalid UTF-8 in DeviceInfo characteristic")
            }
        case viewCharUUID:
            handleViewUpdate(data: data)
        case configCharUUID:
            handleConfigUpdate(data: data)
        case tempCharUUID:
            // Check isDownloadingHistory on the main thread before dispatching to bleQueue
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDownloadingHistory  else { return }
                if !self.isDownloadingHistory { // Check on main thread
                    self.bleQueue.async { // Process on BLE queue
                        self.handleLiveTemperatureUpdate(data: data)
                    }
                } else {
                    self.logger.debug("Ignoring live temperature update while history download is in progress.")
                }
            }
        case temperatureLogsCharUUID:
            handleHistoryChunk(data: data)
        case commandCharUUID:
            logger.info("Received data on command characteristic \(characteristic.uuid): \(data.map { String(format: "%02x", $0) }.joined())")
            // Handle any response to commands if your peripheral sends them here.
            // For example, an ACK/NACK for history request initiation.
            
        case brightnessCharUUID: // ADDED: Handle brightness updates from peripheral
            logger.debug("→ Handling brightness update from peripheral for \(characteristic.uuid)")
            // brightnessCharUUID has fired—unwrap and store
            if data.count >= 1 {
                let val = data[0]
                logger.debug("    Parsed brightness value: \(val)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let oldUPFState = self.updateFromPeripheral // Save current flag state
                    self.updateFromPeripheral = true           // Set flag: this update is from peripheral
                    if self.brightness != val { // Only update if different to avoid unnecessary UI churn
                        self.brightness = val                      // Update @Published var (sink will see flag as true)
                    }
                    self.updateFromPeripheral = oldUPFState    // Restore flag state
                }
            } else {
                logger.warning("    Brightness data too short: \(data.count) byte(s)")
            }
            
        case otaCharUUID:
            let bytes = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            logger.info("OTA response: \(bytes)")
            
            if data.count == 2 {
                let code = data[0]
                let detail = data[1]
                
                DispatchQueue.main.async {
                    switch (code, detail) {
                    case (0x01, 0x00): self.otaStatusMessage = "OTA Started"
                    case (0x03, 0x00): self.otaStatusMessage = "OTA Complete — Rebooting..."
                    case (0x04, 0x00): self.otaStatusMessage = "OTA Aborted"
                    case (0xFF, _):
                        self.otaStatusMessage = "OTA Error \(detail)"
                        self.otaTimer?.invalidate()
                        self.otaProgress = 0.0
                    default:
                        self.otaStatusMessage = "OTA Unknown Response"
                    }
                }
            }
            
        default:
            logger.warning("Received data for unhandled characteristic \(characteristic.uuid).")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            logger.error("Error reading RSSI for \(peripheral.identifier.uuidString): \(error.localizedDescription)");
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.signalStrength = RSSI.intValue
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error writing value to \(characteristic.uuid): \(error.localizedDescription)");
            DispatchQueue.main.async { [weak self] in
                self?.showError(message: "Error writing command.") } }
        else { logger.debug("Successfully wrote value to \(characteristic.uuid).") }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error changing notification state for \(characteristic.uuid) on \(peripheral.identifier.uuidString): \(error.localizedDescription)")
            return
        }
        if characteristic.isNotifying {
            logger.info("Notifications ENABLED for \(characteristic.uuid) on \(peripheral.identifier.uuidString).")
        } else {
            logger.info("Notifications DISABLED for \(characteristic.uuid) on \(peripheral.identifier.uuidString). This might be an issue if unexpected.")
        }
    }
    
    // MARK: - Data Handling Helpers (Called on bleQueue)
    
    
    // FIXED: Improved updateFromPeripheral flag scoping
    // Modify handleViewUpdate to set the flag
    private func handleViewUpdate(data: Data) { // data processing can be on bleQueue, UI update on main
        guard let viewValue = data.first.map ({ Int($0) })// ?? 1
        else {
            logger.warning("Invalid data for view update: \(data.map { String(format: "%02x", $0) }.joined())")
            return
        }
        logger.debug("Processing view update. Raw: \(data as NSData), Parsed: \(viewValue) on bleQueue.")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.selectedView != viewValue {
                logger.info("Updating selectedView from peripheral data: \(self.selectedView) -> \(viewValue) (on main)")
                // ADDED: More robust flag handling
                let oldUPFState = self.updateFromPeripheral
                self.updateFromPeripheral = true
                self.selectedView = viewValue // This will now trigger didSet, but writeViewToCharacteristic will be skipped by updateFromPeripheral
                self.updateFromPeripheral = oldUPFState
            } else {
                logger.debug("Received view update (\(viewValue)) from peripheral, matches current state. Ignoring. (on main)")
            }
        }
    }
    
    private func handleConfigUpdate(data: Data) { // data processing can be on bleQueue, UI update on main
        guard data.count >= 4 else {
            logger.warning("Config data too short: \(data.count) bytes. Expected at least 4.")
            return
        }
        let autoB = data[0] == 1
        let accel = data[1] == 1
        let sleep = data[2] == 1
        let aurora = data[3] == 1
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // ADDED: More robust flag handling
            let oldUPFState = self.updateFromPeripheral
            self.updateFromPeripheral = true // Temporarily set to prevent feedback loop via property didSets
            
            if self.autoBrightness != autoB { self.autoBrightness = autoB }
            if self.accelerometerEnabled != accel { self.accelerometerEnabled = accel }
            if self.sleepModeEnabled != sleep { self.sleepModeEnabled = sleep }
            if self.auroraModeEnabled != aurora { self.auroraModeEnabled = aurora }
            
            self.updateFromPeripheral = oldUPFState // Restore previous flag state
            // updateWidgetAndActivityOnMain() is called by individual property didSets if values changed.
        }
    }
    
    // Inside AccessoryViewModel…
    
    private func handleLiveTemperatureUpdate(data: Data) { // Called on bleQueue
        guard let tempString = String(data: data, encoding: .utf8)
        else {
            logger.warning("Failed to decode temperature string from data: \(data.map { String(format: "%02x", $0) }.joined())")
            DispatchQueue.main.async { [weak self] in self?.temperature = "Error" }
            return
        }
        
        let cleanedTempString = tempString
            .replacingOccurrences(of: "°C", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let tempValue = Double(cleanedTempString) else {
            logger.warning("Failed to parse temperature double from string: '\(cleanedTempString)' (original: '\(tempString)')")
            DispatchQueue.main.async { [weak self] in self?.temperature = "?" }
            return
        }
        
        let newDataPoint = TemperatureData(timestamp: Date(), temperature: tempValue)
        // logger.debug("Live temperature update: \(tempValue)°C")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.temperature = String(format: "%.1f°C", tempValue) // Standardize format
            self.didReceive(newDataPoint) // Feed the Combine pipeline
        }
    }
    
    private func handleHistoryChunk(data: Data) {
        guard data.count >= 3 else {
            logger.warning("History chunk data too short: \(data.count) bytes. Expected at least 3.")
            return
        }
        
        let packetType = data[0]
        let chunkIndex = Int(data[1])
        let totalChunks = Int(data[2])
        let payload = data.subdata(in: 3..<data.count)
        
        guard packetType == historyPacketType else {
            logger.warning("Received history chunk with incorrect packet type: \(packetType). Expected: \(self.historyPacketType)")
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.isDownloadingHistory {
                self.isDownloadingHistory = true; self.receivedHistoryChunks.removeAll(); self.totalHistoryChunksExpected = totalChunks
                self.temperatureData.removeAll() // Clear old live data before loading history
                logger.info("Starting history download. Expecting \(totalChunks) chunks.")
            }
            
            // Validate totalChunks consistency
            if let expected = self.totalHistoryChunksExpected, expected != totalChunks {
                logger.warning("Inconsistent total chunks received. Expected \(expected), got \(totalChunks). Resetting download.")
                self.resetHistoryDownloadState() // This is on main, safe
                return
            }
            
            
            self.receivedHistoryChunks[chunkIndex] = payload
            if let totalExpected =
                self.totalHistoryChunksExpected, self.receivedHistoryChunks.count == totalExpected {
                logger.info("All \(totalExpected) history chunks received. Processing...")
                // Dispatch processing to BLE queue to avoid blocking main thread if it's heavy
                self.bleQueue.async {
                    self.processCompletedHistoryDownload()
                }
            }
        }
    }
    private func processCompletedHistoryDownload() {
        let chunksToProcess = self.receivedHistoryChunks
        let totalChunks = self.totalHistoryChunksExpected ?? 0
        
        guard totalChunks > 0, chunksToProcess.count == totalChunks else { logger.error("Mismatch in expected (\(totalChunks)) and received (\(chunksToProcess.count)) chunks during final processing.")
            DispatchQueue.main.async { [weak self] in
                self?.resetHistoryDownloadState() }
            return
        }
        
        var decodedHistoryPoints: [TemperatureData] = []
        var errorOccurred = false
        let processingStartTime = Date() // Use as reference for "now" when calculating timestamps
        
        // Assuming chunks are 0-indexed and should be processed in order
        for i in 0..<totalChunks {
            guard let chunkData = chunksToProcess[i] else {
                logger.error("Missing chunk data for index \(i) during processing.")
                errorOccurred = true
                break
            }
            
            let floatSize = MemoryLayout<Float>.stride
            let floatCount = chunkData.count / floatSize
            for j in 0..<floatCount {
                let byteOffset = j * floatSize
                let tempValue = chunkData.withUnsafeBytes { $0.load(fromByteOffset: byteOffset, as: Float.self) }
                let pointsInThisChunkRemaining = floatCount - 1 - j
                var pointsInFutureChunks = 0
                if i < totalChunks - 1 {
                    let avgPointsPerChunk = 5 // Placeholder, as in original logic
                    pointsInFutureChunks = (totalChunks - 1 - i) * avgPointsPerChunk
                }
                let pointsIndexFromNewest = decodedHistoryPoints.count + pointsInThisChunkRemaining + pointsInFutureChunks
                
                let interval: TimeInterval = 60.0 // 1 minute per point
                let estimatedTimestamp = processingStartTime.addingTimeInterval(-Double(pointsIndexFromNewest) * interval)
                
                decodedHistoryPoints.append(TemperatureData(timestamp: estimatedTimestamp, temperature: Double(tempValue)))
            }
            if errorOccurred { break }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !errorOccurred {
                // Sort by timestamp just in case reconstruction wasn't perfectly ordered
                let sortedHistory = decodedHistoryPoints.sorted(by: { $0.timestamp < $1.timestamp })
                self.temperatureData = sortedHistory
                logger.info("Successfully processed and loaded \(self.temperatureData.count) historical temperature points.")
                
            } else {
                logger.error("Error occurred during history processing. Data may be incomplete or incorrect.")
                // Potentially clear temperatureData or leave as is.
                // self.temperatureData.removeAll()
            }
            self.resetHistoryDownloadState() // Always reset state, on main thread
        }
    }
    
    private func requestTemperatureHistory(peripheral: CBPeripheral, characteristic: CBCharacteristic) { // Called on bleQueue
        let commandData = Data([requestHistoryCommand])
        logger.info("Requesting temperature history from \(peripheral.identifier.uuidString) using char \(characteristic.uuid)...")
        peripheral.writeValue(commandData, for: characteristic, type: .withResponse) // Use .withResponse if peripheral ACKs
    }
    
    /*
     ; guard byteOffset + floatSize <= chunkData.count else { errorOccurred = true; break }
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
     */
    
    
    
    // MARK: - Timer Methods (Managed on Main Thread)
    private func _startRSSIMonitoring() { // Called on Main Thread
        // guard Thread.isMainThread else { return }
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.bleQueue.async {
                guard let self = self, let p = self.targetPeripheral, p.state == .connected else {
                    // self?.logger.debug("RSSI Timer: Peripheral not connected, not reading RSSI.")
                    // No need to stop timer here, it will keep trying; stopRSSIMonitoring handles explicit stops.
                    return
                }
                // self?.logger.debug("RSSI Timer: Requesting RSSI read for \(p.identifier.uuidString)")
                p.readRSSI()
            }
        }
        // logger.info("RSSI monitoring started.")
    }
    
    private func _stopRSSIMonitoring() {  // Called on Main Thread
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = nil
    }
    
    // MARK: - State Update Helpers (Called on Main Thread)
    private func resetHistoryDownloadState() {
        
        isDownloadingHistory = false
        receivedHistoryChunks.removeAll()
        totalHistoryChunksExpected = nil
        logger.info("History download state reset.")
    }
    
    private func showError(message: String) { // Must be called on Main Thread
        logger.error("Displaying error to user: \(message)")
        errorMessage = message
        showError = true // This will trigger UI updates
    }
    
    
    
    // MARK: - Persistence Helpers (Function now correctly uses the defined StoredPeripheral)
    private func addToPreviouslyConnected(id: String, name: String) { // Called on bleQueue
        let newDevice = StoredPeripheral(id: id, name: name)
        // Load, modify, save should be atomic or careful with threading if called from multiple places.
        // Currently, only called from didConnect (bleQueue).
        var storedDevices = loadStoredPeripherals() // This reads from UserDefaults, can be slow.
        
        if let existingIndex = storedDevices.firstIndex(where: { $0.id == newDevice.id }) {
            // Optional: Update name if it changed? For now, just ensure it exists.
            storedDevices[existingIndex] = newDevice
            logger.debug("Device \(id) already in previouslyConnectedDevices. Name: \(storedDevices[existingIndex].name)")
        } else {
            storedDevices.append(newDevice)
            saveStoredPeripherals(storedDevices) // This writes to UserDefaults.
            logger.info("Added \(name) (\(id)) to previouslyConnectedDevices.")
            DispatchQueue.main.async { [weak self] in // Update published property on main
                self?.previouslyConnectedDevices = storedDevices
            }
        }
    }
    
    // This function now correctly uses the defined StoredPeripheral
    private func loadStoredPeripherals() -> [StoredPeripheral] { // Can be called from any thread, UserDefaults is thread-safe for reads
        guard let data = UserDefaults.standard.data(forKey: "PreviouslyConnectedPeripherals") else {
            logger.info("No previously connected peripherals found in UserDefaults.")
            return []
        }
        do {
            let stored = try JSONDecoder().decode([StoredPeripheral].self, from: data)
            logger.info("Loaded \(stored.count) previously connected peripherals.")
            return stored
        } catch {
            logger.error("Failed to decode previously connected peripherals: \(error.localizedDescription)")
            return []
        }
    }
    
    // This function now correctly uses the defined StoredPeripheral
    private func saveStoredPeripherals(_ devices: [StoredPeripheral]) { // Can be called from any thread, UserDefaults is thread-safe for writes
        do {
            let data = try JSONEncoder().encode(devices)
            UserDefaults.standard.set(data, forKey: "PreviouslyConnectedPeripherals")
            // logger.debug("Saved \(devices.count) previously connected peripherals to UserDefaults.")
        } catch {
            logger.error("Failed to encode previously connected peripherals: \(error.localizedDescription)")
        }
    }
    
    private func _connectToStoredPeripheral(_ stored: StoredPeripheral) { // Called on bleQueue
        guard let uuid = UUID(uuidString: stored.id) else {
            logger.error("Invalid UUID string for stored peripheral: \(stored.id) (\(stored.name))");
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .disconnected
                self?._scanForDevices() // Fallback to scan
            }
            return
        }
        
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
    @MainActor
    private func updateWidgetAndActivity() {
        updateWidgetData()
        scheduleLiveActivityUpdate()
    }
    
    private func updateWidgetData() { // Called on Main Thread
        
        guard let defaults = UserDefaults(suiteName: SharedDataKeys.suiteName) else {
            print("❌ Couldn’t open shared defaults")
            return
        }
        
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
        
        // Save a limited history for the widget
        saveTemperatureHistoryToUserDefaults(defaults: defaults)
        
        WidgetCenter.shared.reloadAllTimelines()
        
    }
    
    private func saveTemperatureHistoryToUserDefaults(defaults: UserDefaults) { // Called on Main Thread
        
        let historyToSave = Array(temperatureData.suffix(50)) // Keep last 50 points for widget
        do {
            let encodedData = try
            JSONEncoder().encode(historyToSave)
            defaults.set(encodedData, forKey: SharedDataKeys.temperatureHistory)
        }
        catch {
            logger.error("Failed to encode temperature history for widget: \(error)") }
    }
    
    // MARK: - Live Activity Management (Called on Main Thread)
    private func createContentState(connected: Bool? = nil, status: String? = nil) -> LumiFur_WidgetAttributes.ContentState { // Called on Main Thread
        
        let recentTemperatures = temperatureData.suffix(50).map { $0.temperature } // Double values
        
        return LumiFur_WidgetAttributes.ContentState(
            connectionStatus: status ?? self.connectionStatus,
            signalStrength: self.signalStrength,
            temperature: self.temperature, // This is the String representation
            selectedView: self.selectedView,
            isConnected: connected ?? self.isConnected,
            isScanning: self.isScanning,
            temperatureChartData: Array(recentTemperatures), // Pass the Double array
            sleepModeEnabled: self.sleepModeEnabled,
            auroraModeEnabled: self.auroraModeEnabled,
            customMessage: self.customMessage
        )
    }
    
    // — at class scope —
    private var isCreatingActivity = false // Protects startLumiFur_WidgetLiveActivity
    
    // — replace your startLumiFur_WidgetLiveActivity() with this —
    @available(iOS 16.1, *)
    @MainActor
    func startLumiFur_WidgetLiveActivity() async {
        // 0) Prevent re-entrant calls
        guard !isCreatingActivity else {
            logger.info("Already creating or managing a Live Activity; skipping start call.")
            return
        }
        isCreatingActivity = true
        defer { isCreatingActivity = false } // Ensure flag is reset
        
        await endAllLumiFurActivities()  // Clean up any existing/stray activities first
        
        // 2) If *we* already have an active or stale LA, bail
        if let activity = currentActivity,
           (activity.activityState == .active || activity.activityState == .stale) {
            logger.info("Live Activity \(activity.id) already managed and active/stale. Updating.")
            await updateLumiFur_WidgetLiveActivityIfNeeded() // Just update it
            return
        }
        
        // 3) Adopt any system-outstanding LA of our type
        if let strayActivity = Activity<LumiFur_WidgetAttributes>.activities.first {
            logger.info("Adopting stray Live Activity \(strayActivity.id) (state: \(activityStateDescription(strayActivity.activityState))).")
            currentActivity = strayActivity
            activityStateTask?.cancel()
            activityStateTask = Task { await self.monitorActivityState(activity: strayActivity) }
            await updateLumiFur_WidgetLiveActivityIfNeeded() // Update the adopted activity
            return
        }
        
        // 4) Final gating
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.error("Live Activities disabled by user.")
            return
        }
        guard let connectedPeripheral = targetPeripheral, isConnected
        else {
            logger.warning("No device connected—won’t start Live Activity.")
            return
        }
        
        // 5) Fire the new activity
        do {
            let attributes = LumiFur_WidgetAttributes(name: connectedPeripheral.name ?? "LumiFur Device")
            let initialState = createContentState()// Create fresh state on main actor
            
            let newActivity = try Activity<LumiFur_WidgetAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            logger.info("Started Live Activity: \(newActivity.id)")
            currentActivity = newActivity
            lastSentState = initialState // Initialize lastSentState
            
            // 6) Watch its lifecycle
            activityStateTask?.cancel() // Cancel any previous monitor task
            
            activityStateTask = Task { await self.monitorActivityState(activity: newActivity) }
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
            currentActivity = nil
        }
    }
    
    @available(iOS 16.1, *)
    @MainActor
    private func monitorActivityState(activity: Activity<LumiFur_WidgetAttributes>) async {
        logger.info("Monitoring state for Live Activity \(activity.id)...")
        for await stateUpdate in activity.activityStateUpdates {
            logger.info("Live Activity \(activity.id) state update: \(activityStateDescription(stateUpdate))") // Use helper
            if stateUpdate == .dismissed || stateUpdate == .ended { // .stale means it's still visible but not updating
                logger.info("Live Activity \(activity.id) dismissed or ended. Clearing local reference.")
                if self.currentActivity?.id == activity.id {
                    self.currentActivity = nil
                    self.activityStateTask?.cancel() // Cancel this monitor task itself
                    self.activityStateTask = nil
                    self.lastSentState = nil
                }
                break // Exit loop as activity is no longer active
            }
        }
        // Fallback if loop finishes without explicit clear (e.g. task cancellation)
        if self.currentActivity?.id == activity.id && (activity.activityState == .dismissed || activity.activityState == .ended) {
            self.currentActivity = nil
            self.activityStateTask = nil
            self.lastSentState = nil
        }
        logger.info("Stopped monitoring Live Activity \(activity.id). Final state: \(activityStateDescription(activity.activityState))")
    }
    
    private var lastSentState: LumiFur_WidgetAttributes.ContentState?
    private var pendingUpdateTask: Task<Void, Never>?
    
    /*
     func faceButtonTapped(_ faceIndex: Int) {
     guard faceIndex != selectedView else { return }
     selectedView = faceIndex
     scheduleLiveActivityUpdate()
     }
     */
    
    //@MainActor
    func scheduleLiveActivityUpdate() {
        pendingUpdateTask?.cancel()
        pendingUpdateTask = Task {
            do {
                try await Task.sleep(nanoseconds: 200_000_000) // CHANGED: 200ms debounce
                await updateLumiFur_WidgetLiveActivityIfNeeded()
            } catch is CancellationError {
                // logger.debug("Live Activity update task cancelled.")
            } catch {
                logger.error("Error in scheduled Live Activity update task: \(error)")
            }
        }
    }
    
    @MainActor
    private func updateLumiFur_WidgetLiveActivityIfNeeded() async {
        guard let activity = currentActivity,
              activity.activityState == .active else { return }
        
        // create state off‑main if it’s heavy
        let newState = createContentState() // Create state on MainActor
        
        guard newState != lastSentState else {
            // logger.debug("Live Activity state unchanged, no update sent.")
            return
        }
        lastSentState = newState
        
        let content = ActivityContent(
            state: newState,
            staleDate: nil, // Or Date().addingTimeInterval(5 * 60) if updates are infrequent
            relevanceScore: isConnected ? 100 : (isConnecting ? 75 : 50) // Adjust relevance
        )
        await activity.update(content)
    }
    
    
    @MainActor
    @available(iOS 16.1, *)
    private func endLiveActivity(finalContent: LumiFur_WidgetAttributes.ContentState? = nil, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        guard let activity = currentActivity else { return }
        
        logger.info("Ending Live Activity \(activity.id) policy: \(ActivityUIDismissalPolicy.self)") // Use helper
        
        activityStateTask?.cancel() // Stop monitoring its state
        activityStateTask = nil
        
        let finalActivityContent = finalContent.map { ActivityContent(state: $0, staleDate: nil) }
        
        await activity.end(finalActivityContent, dismissalPolicy: dismissalPolicy)
        logger.info("Requested end for LA \(activity.id). State: \(activityStateDescription(activity.activityState))") // Use helper
        
        // Clear local reference as we've initiated its end
        self.currentActivity = nil
        self.lastSentState = nil
    }
    
    @available(iOS 16.1, *)
    @MainActor
    private func endAllLumiFurActivities(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async {
        for activity in Activity<LumiFur_WidgetAttributes>.activities { await activity.end(nil, dismissalPolicy: dismissalPolicy)
        }
        if let current = self.currentActivity, Activity<LumiFur_WidgetAttributes>.activities.first(where: { $0.id == current.id }) == nil {
            self.currentActivity = nil
            self.activityStateTask?.cancel()
            self.activityStateTask = nil
            self.lastSentState = nil
        }
    }
    
    // MARK: - Intent Handling (Called on Main Thread via Notification)
    @objc private func handleChangeViewIntent(_ notification: Notification) {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.handleChangeViewIntent(notification) }
            return
        }
        if let userInfo = notification.userInfo, let nextView = userInfo["nextView"] as? Int {
            logger.info("Received ChangeViewIntent for view: \(nextView)")
            self.setView(nextView) // This handles UI update, writing to peripheral, and LA update
        } else {
            logger.warning("Received ChangeViewIntent with invalid or missing userInfo.")
        }
    }
    
}// End of AccessoryViewModel

// MARK: - Helper Extensions
@available(iOS 16.1, *)
func activityStateDescription(_ state: ActivityState) -> String {
    switch state {
    case .active: return "active"
    case .dismissed: return "dismissed"
    case .ended: return "ended"
    case .stale: return "stale"
    case .pending: return "pending" // ??????
    @unknown default: return "unknown"
    }
}

/*
 @available(iOS 16.1, *)
 func dismissalPolicyDescription(_ policy: ActivityUIDismissalPolicy) -> String {
 switch policy {
 case .default: return "default"
 case .immediate: return "immediate"
 case .after(Date): return "after date"
 @unknown default: return "unknown policy"
 }
 }
 */


