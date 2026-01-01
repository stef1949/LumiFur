import SwiftUI
import Combine
@preconcurrency import CoreBluetooth
import WidgetKit
import Foundation
import os
#if !targetEnvironment(macCatalyst )
#if canImport(UIKit)
import UIKit
#endif // !targetEnvironment(watchOS )
import ActivityKit
import AccessorySetupKit
#endif // !targetEnvironment(macCatalyst )

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
    
    // MARK: – Ambient-light (lux) characteristic
    @Published var luxValue: UInt16 = 0
    
    private var scrollTextCharacteristic: CBCharacteristic? // Scroll text/speed characteristic
    
    @MainActor
    private func bleAsync(_ work: @escaping @Sendable (CBCentralManager) -> Void) {
        guard let manager = centralManager else {
            logger.error("bleAsync called before centralManager initialized")
            return
        }
        let box = UncheckedSendableBox(manager)
        bleQueue.async { [box] in
            work(box.value)
        }
    }
    
    @MainActor
    private func writeBrightness(_ newValue: UInt8) {
        guard let peripheral = targetPeripheral,
              let characteristic = brightnessCharacteristic else {
            logger.warning("Cannot write brightness: peripheral or brightness characteristic not available.")
            return
        }

        let data = Data([newValue])
        let pBox = UncheckedSendableBox(peripheral)
        let cBox = UncheckedSendableBox(characteristic)

        bleAsync { _ in
            pBox.value.writeValue(data, for: cBox.value, type: .withResponse)
        }
    }
    
    // 1) Raw incoming temperature readings
    //private let rawTempSubject = PassthroughSubject<TemperatureData, Never>()
    
    // 2) Public publisher of a down-sampled, 3-minute sliding window, throttled to 1 Hz
        // This publisher should be the only temperature data source observed by chart views.
    lazy var temperatureChartPublisher: AnyPublisher<[TemperatureData], Never> = {
        // The source of truth is now the @Published property itself.
        // Its publisher ($temperatureData) emits the entire array whenever it's mutated.
        return $temperatureData
            // Throttle updates to prevent the UI from refreshing too frequently.
            .throttle(for: .seconds(1.5), scheduler: DispatchQueue.main, latest: true)
            // Ensure the final data is delivered on the main thread, where UI updates must occur.
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }()
    
    private func didReceive(_ newDataPoint: TemperatureData) {
        // This is the line that actually triggers the UI update in the chart.
        temperatureData.append(newDataPoint)
        
        // Optional: You might want to prune old data to prevent the array from growing forever.
        // For example, keep only the last 5 minutes of data.
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        temperatureData.removeAll { $0.timestamp < fiveMinutesAgo }
    }
    
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    //@Published var signalStrength: Int = -100 { didSet { updateWidgetAndActivityOnMain() } }
    @Published var signalStrength: Int = -100
    @Published var connectingPeripheral: PeripheralDevice? = nil // Uses definition above
    @Published var cpuUsageData: [CPUUsageData] = [] // Uses definition above
    @Published var bootButtonState: Bool = false
    
    // User options - didSet triggers writes + UI updates
    @Published var selectedView: Int = 1
    
    // MARK: - OTA State Tracking
    @Published var otaStatusMessage: String = "Idle"
    @Published var otaProgress: Double = 0.0
    @MainActor private var totalOTASize: Int = 0
    @MainActor private var otaBytesSent: Int = 0
    @MainActor private var otaTimer: Timer?
    @MainActor private var otaTask: Task<Void, Never>?
    @MainActor private var otaGeneration: UInt64 = 0
    @MainActor private var otaWriteContinuation: CheckedContinuation<Void, Never>?
    @MainActor private var otaInProgress: Bool = false
    @MainActor
    private func writeWithResponse(_ data: Data,
                                   peripheral: CBPeripheral,
                                   characteristic: CBCharacteristic) async {
        let pBox = UncheckedSendableBox(peripheral)
        let cBox = UncheckedSendableBox(characteristic)

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            // Store continuation on MainActor; resumed by didWriteValueFor
            self.otaWriteContinuation = cont

            // Do the actual write on the BLE queue
            self.bleAsync { _ in
                pBox.value.writeValue(data, for: cBox.value, type: .withResponse)
            }
        }
    }
    
    /*
     @Published var autoBrightness: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
     @Published var accelerometerEnabled: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
     @Published var sleepModeEnabled: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
     @Published var auroraModeEnabled: Bool = true { didSet { writeConfigToCharacteristic(); updateWidgetAndActivityOnMain() } }
     @Published var customMessage: String = "" { didSet { updateWidgetAndActivityOnMain() /* TODO: Add write if needed */ } }
     */
    @Published var autoBrightness: Bool = true {
        didSet {
            guard oldValue != autoBrightness else { return }
            if !updateFromPeripheral { writeConfigToCharacteristic() }
        }
    }

    @Published var accelerometerEnabled: Bool = true {
        didSet {
            guard oldValue != accelerometerEnabled else { return }
            if !updateFromPeripheral { writeConfigToCharacteristic() }
        }
    }

    @Published var sleepModeEnabled: Bool = true {
        didSet {
            guard oldValue != sleepModeEnabled else { return }
            if !updateFromPeripheral { writeConfigToCharacteristic() }
        }
    }

    @Published var auroraModeEnabled: Bool = true {
        didSet {
            guard oldValue != auroraModeEnabled else { return }
            if !updateFromPeripheral { writeConfigToCharacteristic() }
        }
    }

    @Published var customMessage: String = "" {
        didSet {
            guard oldValue != customMessage else { return }
            if !updateFromPeripheral { writeConfigToCharacteristic() }
        }
    }
    
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

    @MainActor
    private func applyPeripheralUpdate(_ updates: () -> Void) {
        let old = updateFromPeripheral
        updateFromPeripheral = true
        updates()
        updateFromPeripheral = old
    }
    
    var connectedDevice: PeripheralDevice? {
        #if DEBUG
        // In SwiftUI previews we don't have a real CBPeripheral,
        // so just use the first discovered device as the "connected" one.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return discoveredDevices.first
        }
        #endif

        guard isConnected, let target = targetPeripheral else { return nil }
        return discoveredDevices.first { $0.id == target.identifier }
    }

    var connectedDeviceName: String? {
        #if DEBUG
        // Same trick for previews: use the mock device name.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return discoveredDevices.first?.name
        }
        #endif

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
    
    private var luxCharacteristic: CBCharacteristic?
    
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
    private let luxCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09f0")
    
    private let custColUUID = CBUUID(string: "7f9b8b12-1234-4c55-9b77-a19d55aa0022")
    
    private let scrollTextCharUUID = CBUUID(string: "7f9b8b12-1234-4c55-9b77-a19d55aa0011")
    
        // Threshold to filter insignificant changes
        private let luxThreshold: UInt16 = 5
        private var lastLuxValue: UInt16 = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - State for History Download
    @Published var isDownloadingHistory: Bool = false
    private var receivedHistoryChunks: [Int: Data] = [:]
    private var totalHistoryChunksExpected: Int? = nil
    private let maxTemperatureDataPoints = 200
    
    // MARK: - Live Activity
    private var currentActivity: Activity<LumiFur_WidgetAttributes>? = nil
    private var activityStateTask: Task<Void, Error>? = nil
    
    /// A running count of how many instances are alive
    nonisolated(unsafe) private static var _instanceCount = 0
    nonisolated(unsafe) static var instanceCount: Int { _instanceCount }
    
    @MainActor private var rssiMonitoringGeneration: UInt64 = 0
    
    // MARK: Initialization
    @MainActor
    override init() {
        super.init()
        AccessoryViewModel._instanceCount += 1
        let countNow = AccessoryViewModel.instanceCount
        logger.warning("🔧 AccessoryViewModel init — now \(countNow) instance(s)")

        // SwiftUI previews
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            logger.info("Running in SwiftUI previews – skipping CBCentralManager, notifications, and live activities.")

            // Give previews some deterministic baseline state if you want:
            self.connectionState = .disconnected
            self.previouslyConnectedDevices = []
            self.temperatureData = []
            self.signalStrength = -100

            // Return here so we do *not* create CBCentralManager
            return
        }

        // Real app behaviour (sim / device runs)
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)

        previouslyConnectedDevices = loadStoredPeripherals()
        logger.info("Initialized previouslyConnectedDevices with \(self.previouslyConnectedDevices.count) items: \(self.previouslyConnectedDevices.map(\.name))")

        lastConnectedPeripheralUUID = UserDefaults.standard.string(forKey: "LastConnectedPeripheralUUID")

        configureCombinePipelines()
        registerNotificationObservers()
        setupWidgetAndActivityDebounce()

        updateWidgetAndActivity()

        Task { [weak self] in
            guard let self else { return }
            await self.endAllLumiFurActivities()
        }
    }

    // MARK: Setup Helpers
    private func configureCombinePipelines() {
        // Brightness → BLE write (skip if it originated from peripheral)
        $brightness
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(20), scheduler: RunLoop.main)
            .sink { [weak self] newVal in
                guard let self else { return }
                guard !self.updateFromPeripheral else { return }
                self.writeBrightness(newVal)
            }
            .store(in: &cancellables)
    }

    private func registerNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChangeViewIntent(_:)),
            name: .changeViewIntentTriggered,
            object: nil
        )

        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }


    private struct StateDigest: Equatable {
        let connectionState: ConnectionState
        let signalStrength: Int
        let temperature: String
        let selectedView: Int
        let autoBrightness: Bool
        let accelerometerEnabled: Bool
        let sleepModeEnabled: Bool
        let auroraModeEnabled: Bool
        let customMessage: String
        let connectedDeviceName: String?
        let temperatureDataCount: Int
        let temperatureDataLast: Date?
    }
    private struct WatchStateDigest: Equatable {
        let connectionState: ConnectionState
        let temperature: String
        let selectedView: Int
        let autoBrightness: Bool
        let accelerometerEnabled: Bool
        let sleepModeEnabled: Bool
        let auroraModeEnabled: Bool
        let customMessage: String
        let connectedDeviceName: String?
    }

    @MainActor
    private func makeStateDigest() -> StateDigest {
        StateDigest(
            connectionState: connectionState,
            signalStrength: signalStrength,
            temperature: temperature,
            selectedView: selectedView,
            autoBrightness: autoBrightness,
            accelerometerEnabled: accelerometerEnabled,
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled,
            customMessage: customMessage,
            connectedDeviceName: connectedDeviceName,
            temperatureDataCount: temperatureData.count,
            temperatureDataLast: temperatureData.last?.timestamp
        )
    }
    @MainActor
    private func makeWatchStateDigest() -> WatchStateDigest {
        WatchStateDigest(
            connectionState: connectionState,
            temperature: temperature,
            selectedView: selectedView,
            autoBrightness: autoBrightness,
            accelerometerEnabled: accelerometerEnabled,
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled,
            customMessage: customMessage,
            connectedDeviceName: connectedDeviceName
        )
    }

    private func setupWidgetAndActivityDebounce() {
        let temperatureDataDigest: AnyPublisher<Void, Never> = {
            // Break the chain with explicit intermediate types to help the compiler
            let base: AnyPublisher<[TemperatureData], Never> = $temperatureData.eraseToAnyPublisher()
            let mapped: AnyPublisher<(count: Int, last: Date?), Never> = base
                .map { data -> (count: Int, last: Date?) in
                    return (count: data.count, last: data.last?.timestamp)
                }
                .eraseToAnyPublisher()
            let deduped: AnyPublisher<(count: Int, last: Date?), Never> = mapped
                .removeDuplicates { lhs, rhs in
                    return lhs.count == rhs.count && lhs.last == rhs.last
                }
                .eraseToAnyPublisher()
            return deduped
                .map { _ in () }
                .eraseToAnyPublisher()
        }()

        let pConnection = $connectionState.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        let pTemperature = $temperature.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        let pSignal = $signalStrength.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        let pAuto = $autoBrightness.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        let pAccel = $accelerometerEnabled.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        let pSleep = $sleepModeEnabled.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        let pAurora = $auroraModeEnabled.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        let pView = $selectedView.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        let pMsg = $customMessage.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        let pTarget = $targetPeripheral
            .map { $0?.identifier }
            .removeDuplicates()
            .map { _ in () }
            .eraseToAnyPublisher()

        let stateTriggers: [AnyPublisher<Void, Never>] = [
            pConnection,
            pTemperature,
            temperatureDataDigest,
            pSignal,
            pAuto,
            pAccel,
            pSleep,
            pAurora,
            pView,
            pMsg,
            pTarget
        ]

        let stateDigestPublisher = Publishers.MergeMany(stateTriggers)
            .receive(on: RunLoop.main)
            .map { [weak self] _ in self?.makeStateDigest() }
            .compactMap { $0 }
            .removeDuplicates()
            .share()

        stateDigestPublisher
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.updateWidgetAndActivity() }
            .store(in: &cancellables)

        stateDigestPublisher
            .throttle(for: .seconds(1.5), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.syncStateToWatch() }
            .store(in: &cancellables)
    }
    
    deinit {
        AccessoryViewModel._instanceCount -= 1
        let countNow = AccessoryViewModel.instanceCount
        logger.warning("🗑️ AccessoryViewModel deinit — now \(countNow) instance(s)")

        // Perform cleanup on the MainActor to satisfy Sendable/isolation rules.
        Task { @MainActor [weak self] in
            guard let self else { return }
            NotificationCenter.default.removeObserver(self)

            // Stop timers/tasks
            self.rssiUpdateTimer?.invalidate()
            self.rssiUpdateTimer = nil

            self.pendingUpdateTask?.cancel()
            self.pendingUpdateTask = nil

            self.otaTask?.cancel()
            self.otaTask = nil

            self.activityStateTask?.cancel()
            self.activityStateTask = nil

            // Tear down Combine
            self.cancellables.removeAll()

            self.logger.warning("AccessoryViewModel deinitialized (MainActor cleanup).")
        }
    }
    
    // MARK: — APP BACK TO FOREGROUND
    #if canImport(UIKit)
    @objc private func appDidBecomeActive() {
        guard isConnected else { return }

        let alreadyRunning =
            currentActivity?.activityState == .active
            || !Activity<LumiFur_WidgetAttributes>.activities.isEmpty

        guard !alreadyRunning else {
            logger.info("App open → live activity already present; skipping start.")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            logger.info("App open → no live activity, launching one now.")
            await self.startLumiFur_WidgetLiveActivity()
        }
    }
    #endif
    
    // MARK: - Public Methods (Called from UI - Main Thread)
    
    // MARK: - OTA Update Methods (MainActor entrypoints)

    @MainActor
    func startOTAUpdate(firmwareData: Data) {
        guard let peripheral = targetPeripheral,
              let characteristic = commandCharacteristic else {
            otaStatusMessage = "OTA Error: Peripheral not ready"
            return
        }

        // Cancel any existing OTA
        otaTask?.cancel()
        otaGeneration &+= 1
        otaInProgress = true

        otaStatusMessage = "Starting OTA..."
        otaProgress = 0.0
        otaBytesSent = 0
        totalOTASize = firmwareData.count

        let gen = otaGeneration

        otaTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // 1) Send START packet: [0x01][u32 size LE]
                var size = UInt32(firmwareData.count)
                var start = Data([0x01])
                start.append(Data(bytes: &size, count: 4))

                await self.writeWithResponse(start, peripheral: peripheral, characteristic: characteristic)

                // Small settle delay (replaces DispatchQueue.main.asyncAfter)
                try await Task.sleep(nanoseconds: 300_000_000)

                // 2) Stream payload
                try await self.sendOTAPayload(firmwareData: firmwareData,
                                             peripheral: peripheral,
                                             characteristic: characteristic,
                                             generation: gen)

                // 3) Finalize
                await self.endOTAUpdate(peripheral: peripheral, characteristic: characteristic, generation: gen)

            } catch is CancellationError {
                // Task cancelled: just exit cleanly
            } catch {
                self.otaStatusMessage = "OTA Error: \(error.localizedDescription)"
                self.otaInProgress = false
            }
        }
    }

    @MainActor
    private func sendOTAPayload(firmwareData: Data,
                                peripheral: CBPeripheral,
                                characteristic: CBCharacteristic,
                                generation: UInt64) async throws {
        // Basic MTU chunking (keep your existing values)
        let mtu = 185
        let chunkSize = mtu - 3

        var offset = 0

        while offset < firmwareData.count {
            try Task.checkCancellation()
            guard otaGeneration == generation else { throw CancellationError() }

            let end = min(offset + chunkSize, firmwareData.count)
            let chunk = firmwareData.subdata(in: offset..<end)

            // Packet: [0x02] + chunk
            var packet = Data([0x02])
            packet.append(chunk)

            await writeWithResponse(packet, peripheral: peripheral, characteristic: characteristic)

            offset = end
            otaBytesSent = offset
            otaProgress = Double(offset) / Double(max(totalOTASize, 1))
            otaStatusMessage = "Uploading... \(Int(otaProgress * 100))%"
        }
    }

    @MainActor
    private func endOTAUpdate(peripheral: CBPeripheral,
                              characteristic: CBCharacteristic,
                              generation: UInt64) async {
        guard otaGeneration == generation else { return }

        otaStatusMessage = "Finalizing OTA..."

        let endPacket = Data([0x03])
        await writeWithResponse(endPacket, peripheral: peripheral, characteristic: characteristic)

        otaStatusMessage = "OTA Complete — Rebooting..."
        otaInProgress = false
    }

    @MainActor
    func abortOTAUpdate() {
        otaTask?.cancel()
        otaGeneration &+= 1
        otaInProgress = false

        otaWriteContinuation?.resume()
        otaWriteContinuation = nil

        otaProgress = 0.0
        otaStatusMessage = "OTA Aborted"

        // If your peripheral expects abort on OTA characteristic, keep this.
        // Otherwise use commandCharacteristic (depends on your firmware protocol).
        guard let peripheral = targetPeripheral,
              let characteristic = otaCharacteristic else { return }

        let abortPacket = Data([0x04])
        let pBox = UncheckedSendableBox(peripheral)
        let cBox = UncheckedSendableBox(characteristic)

        bleAsync { _ in
            pBox.value.writeValue(abortPacket, for: cBox.value, type: .withResponse)
        }
    }
    
    @MainActor
    func scanForDevices() {
        // 1️⃣ Special case: SwiftUI previews
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Fake "scan" for the preview canvas
            logger.info("SwiftUI preview: faking scanForDevices()")

            isScanning = false
            connectionState = .disconnected   // or .scanning if you have that case

            // Populate some mock devices so the UI has something to show
            discoveredDevices = [
                .mock,
                PeripheralDevice(
                    id: UUID(),
                    name: "LumiFur-BBBB",
                    rssi: -68,
                    advertisementServiceUUIDs: ["FFF0"],
                    peripheral: nil
                )
            ]

            return
        }

        // 2️⃣ Normal runtime behaviour (device / sim running app)
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot scan: Bluetooth is not powered on.")
            connectionState = .bluetoothOff
            return
        }

        // UI state: MainActor
        discoveredDevices.removeAll()
        connectionState = .scanning
        isScanning = true

        // BLE call: bleQueue
        bleAsync { [serviceUUID] manager in
            manager.scanForPeripherals(
                withServices: [serviceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: false)]
            )
        }
    }

    @MainActor
    func stopScan() {
        guard centralManager.state == .poweredOn else { return }

        bleAsync { manager in
            manager.stopScan()
        }

        isScanning = false
        if connectionState == .scanning { connectionState = .disconnected }
    }
    
    @MainActor
    func connect(to device: PeripheralDevice) {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot connect: Bluetooth is not powered on.")
            connectionState = .bluetoothOff
            return
        }

        // 2️⃣ Real app: be defensive about centralManager existing
            guard let manager = centralManager else {
                logger.error("connect(to:) called before centralManager was initialized.")
                connectionState = .unknown
                return
            }

            guard manager.state == .poweredOn else {
                logger.warning("Cannot connect: Bluetooth is not powered on.")
                connectionState = .bluetoothOff
                return
            }

            // 3️⃣ We must have a real CBPeripheral to connect
            guard let peripheral = device.peripheral else {
                // This really shouldn’t happen in the *real* app.
                logger.warning("connect(to:) called with device that has nil CBPeripheral; aborting connect.")
                return
            }

        
        stopScan()

        connectingPeripheral = device
        connectionState = .connecting
        targetPeripheral = device.peripheral
        targetPeripheral?.delegate = self
        isManualDisconnect = false

        let peripheralBox = UncheckedSendableBox(peripheral)

        bleAsync { manager in
            manager.connect(peripheralBox.value, options: nil)
        }
    }

    @MainActor
    func disconnect() {
        isManualDisconnect = true

        guard let p = targetPeripheral else { return }
        let peripheralBox = UncheckedSendableBox(p)

        bleAsync { manager in
            manager.cancelPeripheralConnection(peripheralBox.value)
        }
    }
    func connectToStoredPeripheral(_ stored: StoredPeripheral) { // Uses definition
        DispatchQueue.main.async { self._connectToStoredPeripheral(stored) }
    }
    
    // 2) In your “button” action, change + write + schedule all in one place:
    func setView(_ view: Int) {
        guard view >= 1 && view <= 50, view != selectedView else { return }
        logger.info("Setting view to \(view)")
        // Update model
        self.selectedView = view
        // Send to peripheral immediately
        writeViewToCharacteristic()
        // Debounced widget / LiveActivity update
        //scheduleLiveActivityUpdate()
    }
    
    // 3) Same for face buttons:
    func faceButtonTapped(_ faceIndex: Int) {
        setView(faceIndex)
    }
    
    @MainActor
    func sendScrollText(_ text: String) {
        guard let peripheral = targetPeripheral,
              let characteristic = scrollTextCharacteristic else {
            logger.warning("Cannot send scroll text: peripheral or scrollTextCharacteristic not available.")
            return
        }
        // Opcode 0x01 + text bytes (max 63 to fit 64 with terminator on device)
        let utf8 = text.data(using: .utf8) ?? Data()
        let maxPayload = 63
        let payload: Data = utf8.prefix(maxPayload)
        var packet = Data([0x01])
        packet.append(payload)

        let pBox = UncheckedSendableBox(peripheral)
        let cBox = UncheckedSendableBox(characteristic)
        
        let props = characteristic.properties
        guard props.contains(.write) || props.contains(.writeWithoutResponse) else {
            self.logger.error("Scroll text characteristic is not writable (props=\(props.rawValue)).")
            return
        }
        let writeType: CBCharacteristicWriteType = props.contains(.write) ? .withResponse : .withoutResponse
        
        bleAsync { [packet, writeType] _ in
            pBox.value.writeValue(packet, for: cBox.value, type: writeType)
        }
    }

    @MainActor
    func sendScrollSpeed(_ speed: UInt8) {
        guard let peripheral = targetPeripheral,
              let characteristic = scrollTextCharacteristic else {
            logger.warning("Cannot send scroll speed: peripheral or scrollTextCharacteristic not available.")
            return
        }
        // Opcode 0x02 + clamped speed (1…100)
        let clamped = max(1, min(100, Int(speed)))
        let packet = Data([0x02, UInt8(clamped)])

        let pBox = UncheckedSendableBox(peripheral)
        let cBox = UncheckedSendableBox(characteristic)
        
        let props = characteristic.properties
        guard props.contains(.write) || props.contains(.writeWithoutResponse) else {
            self.logger.error("Scroll speed characteristic is not writable (props=\(props.rawValue)).")
            return
        }
        let writeType: CBCharacteristicWriteType = props.contains(.write) ? .withResponse : .withoutResponse
        
        bleAsync { [packet, writeType] _ in
            pBox.value.writeValue(packet, for: cBox.value, type: writeType)
        }
    }
    
    @MainActor
    func startRSSIMonitoring() {
        _startRSSIMonitoring()
    }
    @MainActor
    private func _startRSSIMonitoring() {
        rssiUpdateTimer?.invalidate()
        
        rssiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                        guard let self = self else { return }
                        guard let p = self.targetPeripheral, p.state == .connected else { return }
                        
                        let pBox = UncheckedSendableBox(p)
                        self.bleAsync { _ in
                            pBox.value.readRSSI()
                        }
                    }
        }
    }
    @MainActor
    func stopRSSIMonitoring() {
        _stopRSSIMonitoring()
    }

    @MainActor
    private func _stopRSSIMonitoring() {
        // Bump generation so any in-flight timer tick becomes a no-op
        rssiMonitoringGeneration &+= 1

        guard let timer = rssiUpdateTimer else { return } // already stopped
        timer.invalidate()
        rssiUpdateTimer = nil

        logger.debug("RSSI monitoring stopped (gen=\(self.rssiMonitoringGeneration)).")
    }
    
    // MARK: - Watch Sync (ADD THIS NEW METHOD)
    
    /// The single function that triggers a sync to the watch.
    func syncStateToWatch() {
        // Build a digest of the values that matter for the watch
        let digest = makeWatchStateDigest()
        // If nothing changed since last send, skip
        if let last = lastSentWatchDigest, last == digest {
            return
        }
        lastSentWatchDigest = digest
        // Proceed with actual sync
        WatchConnectivityManager.shared.syncStateToWatch(from: self) // Pass self to the watch manager to be packaged and sent
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
            DispatchQueue.main.async { self.connectionState = .bluetoothOff
            } // Fixed enum case
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
    private func _connect(to device: PeripheralDevice) {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot connect: Bluetooth is not powered on.")
            DispatchQueue.main.async {
                self.connectionState = .bluetoothOff
            }
            return
        }

        // Must have a real CBPeripheral to connect
        guard let peripheralToConnect = device.peripheral else {
            logger.warning("Cannot connect: PeripheralDevice has nil CBPeripheral (id: \(device.id), name: \(device.name)).")
            return
        }

        _stopScan()

        // Update UI-related state on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectingPeripheral = device
            self.connectionState = .connecting
            self.targetPeripheral = peripheralToConnect
        }

        isManualDisconnect = false
        logger.info("Attempting to connect to \(device.name) (\(device.id)) on bleQueue...")

        // Configure delegate and start connection with a non-optional peripheral
        peripheralToConnect.delegate = self
        centralManager.connect(peripheralToConnect, options: nil)
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
    @MainActor
    private func writeViewToCharacteristic() {
        guard let peripheral = targetPeripheral,
              let characteristic = targetCharacteristic else {
            logger.warning("Cannot write view: peripheral or view characteristic not available.")
            return
        }

        let view = selectedView
        let data = Data([UInt8(view)])

        let pBox = UncheckedSendableBox(peripheral)
        let cBox = UncheckedSendableBox(characteristic)

        bleAsync { _ in
            pBox.value.writeValue(data, for: cBox.value, type: .withResponse)
        }
    }
    
    
    /// Internal method to write config, runs on bleQueue
    @MainActor
    func writeConfigToCharacteristic() {
        guard let peripheral = targetPeripheral,
              let characteristic = configCharacteristic else {
            logger.warning("Cannot write config: peripheral or config characteristic not available.")
            return
        }

        let payload = encodedAccessorySettingsPayload(
            autoBrightness: autoBrightness,
            accelerometerEnabled: accelerometerEnabled,
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled
        )

        let pBox = UncheckedSendableBox(peripheral)
        let cBox = UncheckedSendableBox(characteristic)

        bleAsync { _ in
            pBox.value.writeValue(payload, for: cBox.value, type: .withResponse)
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
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor [weak self] in
            self?.handleCentralStateUpdate(state)
        }
    }

    @MainActor
    private func handleCentralStateUpdate(_ state: CBManagerState) {
        // 1) Compute desired new state & flags on MainActor (safe)
        var newState: ConnectionState = .unknown
        var shouldScan = false
        var shouldAttemptReconnect = false

        switch state {
        case .poweredOn:
            newState = .disconnected
            shouldScan = true

            if !didAttemptAutoReconnect, lastConnectedPeripheralUUID != nil {
                didAttemptAutoReconnect = true
                shouldAttemptReconnect  = true
                shouldScan              = false
                newState                = .reconnecting
            }

        case .poweredOff:
            newState = .bluetoothOff
            stopScan()                      // ✅ MainActor-safe wrapper
            didAttemptAutoReconnect = false

        case .unauthorized:
            newState = .unknown
            logger.error("Bluetooth unauthorized.")
            didAttemptAutoReconnect = false

        case .unsupported:
            newState = .unknown
            logger.error("Bluetooth unsupported.")

        case .resetting:
            newState = .unknown
            logger.warning("Bluetooth resetting.")
            didAttemptAutoReconnect = false

        case .unknown:
            newState = .unknown
            logger.warning("Bluetooth state unknown.")

        @unknown default:
            newState = .unknown
            logger.warning("Bluetooth state @unknown default.")
        }

        // Snapshot the UUID once (MainActor-safe)
        let uuidToTry = lastConnectedPeripheralUUID

        // 2) Apply state updates (MainActor)
        connectionState = newState

        if state != .poweredOn {
            targetPeripheral = nil
            discoveredDevices.removeAll()
            connectingPeripheral = nil
            isScanning = false
            stopRSSIMonitoring()
        }

        // 3) Reconnect or scan (MainActor entrypoints)
        if shouldAttemptReconnect, let uuid = uuidToTry {
            logger.info("Auto-reconnect to \(uuid)")
            _connectToStoredUUID(uuid)      // Make sure this method is MainActor-safe internally
        } else if shouldScan, connectionState == .disconnected {
            scanForDevices()               // ✅ MainActor-safe wrapper
        }
    }
    
    private func _connectToStoredUUID(_ uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else {
            logger.error("Invalid UUID string for reconnect: \(uuidString)")
            DispatchQueue.main.async {
                           self.connectionState = .disconnected
                           self._scanForDevices()
                       }
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
            DispatchQueue.main.async {
                            self.connectionState = .disconnected
                            self._scanForDevices()
                        }
        }
    }
    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String : Any],
                                    rssi RSSI: NSNumber) {
        Task { @MainActor [weak self] in
            self?.handleDidDiscover(peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
    }

    @MainActor
    private func handleDidDiscover(_ peripheral: CBPeripheral,
                                   advertisementData: [String: Any],
                                   rssi RSSI: NSNumber) {
        // Auto-reconnect path
        if let lastUUID = lastConnectedPeripheralUUID,
           peripheral.identifier.uuidString == lastUUID,
           connectionState == .reconnecting {

            logger.info("Auto-reconnect (via scan): found stored peripheral \(lastUUID), connecting.")
            stopScan()

            let device = PeripheralDevice(
                id: peripheral.identifier,
                name: peripheral.name ?? "Unknown",
                rssi: RSSI.intValue,
                advertisementServiceUUIDs: (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map(\.uuidString),
                peripheral: peripheral
            )
            connect(to: device)
            return
        }

        // Normal discovery update
        guard let name = peripheral.name, !name.isEmpty else { return }
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map(\.uuidString)

        let device = PeripheralDevice(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            advertisementServiceUUIDs: serviceUUIDs,
            peripheral: peripheral
        )
        upsertDiscoveredDevice(device)
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            self?.handleDidConnect(peripheral)
        }
    }

    @MainActor
    private func handleDidConnect(_ peripheral: CBPeripheral) {
        logger.info("Connected to \(peripheral.name ?? "Unknown") (\(peripheral.identifier.uuidString))")

        // UI/Model state
        targetPeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connected
        isScanning = false
        connectingPeripheral = nil
        didAttemptAutoReconnect = false

        // Persist
        let uuidString = peripheral.identifier.uuidString
        UserDefaults.standard.set(uuidString, forKey: "LastConnectedPeripheralUUID")
        lastConnectedPeripheralUUID = uuidString
        addToPreviouslyConnected(id: uuidString, name: peripheral.name ?? "Unknown")

        // Kick off discovery on BLE queue (important!)
        let pBox = UncheckedSendableBox(peripheral)
        bleAsync { [serviceUUID] _ in
            pBox.value.discoverServices([serviceUUID])
        }

        startRSSIMonitoring()

        // Live Activity handling (your existing logic is fine)
        if currentActivity?.activityState != .active {
            Task { @MainActor in
                await startLumiFur_WidgetLiveActivity()
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor [weak self] in
            self?.handleDidFailToConnect(peripheral, error: error)
        }
    }

    @MainActor
    private func handleDidFailToConnect(_ peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown")")
        if targetPeripheral?.identifier == peripheral.identifier { targetPeripheral = nil }
        connectingPeripheral = nil
        connectionState = .failed
        didAttemptAutoReconnect = false
        if !isScanning { scanForDevices() }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor [weak self] in
            await self?.handleDidDisconnect(peripheralID: peripheral.identifier.uuidString,
                                            peripheralName: peripheral.name,
                                            error: error)
        }
    }

    @MainActor
    private func handleDidDisconnect(peripheralID: String,
                                     peripheralName: String?,
                                     error: Error?) async {
        let wasManual = isManualDisconnect
        isManualDisconnect = false

        let name = peripheralName ?? "Unknown"
        let errorDescription = error?.localizedDescription ?? "No error"
        logger.info("Disconnected from \(name) (\(peripheralID)). Was manual: \(wasManual). Error: \(errorDescription).")

        // Reset connection-specific state (compare by ID string so we don't need CBPeripheral here)
        if targetPeripheral?.identifier.uuidString == peripheralID {
            targetPeripheral = nil
            temperature = "--"
            signalStrength = -100
            firmwareVersion = "N/A"

            configCharacteristic = nil
            targetCharacteristic = nil
            temperatureCharacteristic = nil
            commandCharacteristic = nil
            temperatureLogsCharacteristic = nil
            brightnessCharacteristic = nil
            otaCharacteristic = nil
            luxCharacteristic = nil
            scrollTextCharacteristic = nil

            temperatureData.removeAll()
        }

        connectionState = .disconnected
        connectingPeripheral = nil
        stopRSSIMonitoring()

        // Live Activity handling
        let finalState = createContentState(
            connected: false,
            status: ConnectionState.disconnected.rawValue
        )

        if wasManual {
            logger.info("Manual disconnect → ending Live Activity immediately.")
            await endLiveActivity(finalContent: finalState, dismissalPolicy: .immediate)
        } else if error != nil {
            let dismissalDate = Date().addingTimeInterval(15 * 60)
            logger.info("Unexpected disconnect (with error) → ending Live Activity at \(dismissalDate).")
            await endLiveActivity(finalContent: finalState, dismissalPolicy: .after(dismissalDate))
        } else {
            logger.info("Graceful disconnect → ending Live Activity immediately.")
            await endLiveActivity(finalContent: finalState, dismissalPolicy: .immediate)
        }

        // Reconnect or scan
        if !wasManual, autoReconnectEnabled,
           let uuidToReconnect = lastConnectedPeripheralUUID {
            logger.info("Auto-Reconnect ON → attempting reconnect to \(uuidToReconnect)")
            connectionState = .reconnecting
            didAttemptAutoReconnect = false
            _connectToStoredUUID(uuidToReconnect)   // ensure this uses bleAsync internally
        } else if !wasManual {
            logger.info("Not auto-reconnecting; starting scan.")
            if !isScanning { scanForDevices() }
        }
    }


    // MARK: - CBPeripheralDelegate (called on bleQueue)

    // Small helpers: run CBPeripheral ops on bleQueue without touching @MainActor state.
    private func peripheralAsync(_ peripheral: CBPeripheral,
                                 _ work: @escaping @Sendable (CBPeripheral) -> Void) {
        let pBox = UncheckedSendableBox(peripheral)
        bleQueue.async { [pBox] in
            work(pBox.value)
        }
    }

    private func peripheralServiceAsync(_ peripheral: CBPeripheral,
                                        _ service: CBService,
                                        _ work: @escaping @Sendable (CBPeripheral, CBService) -> Void) {
        let pBox = UncheckedSendableBox(peripheral)
        let sBox = UncheckedSendableBox(service)
        bleQueue.async { [pBox, sBox] in
            work(pBox.value, sBox.value)
        }
    }

    private func peripheralCharAsync(_ peripheral: CBPeripheral,
                                     _ characteristic: CBCharacteristic,
                                     _ work: @escaping @Sendable (CBPeripheral, CBCharacteristic) -> Void) {
        let pBox = UncheckedSendableBox(peripheral)
        let cBox = UncheckedSendableBox(characteristic)
        bleQueue.async { [pBox, cBox] in
            work(pBox.value, cBox.value)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor [weak self] in
            self?.handleDidDiscoverServices(peripheral, error: error)
        }
    }

    @MainActor
    private func handleDidDiscoverServices(_ peripheral: CBPeripheral, error: Error?) {
        if let error {
            logger.error("Error discovering services: \(error.localizedDescription)")
            showError(message: "Service discovery error")
            return
        }

        guard let services = peripheral.services else { return }

        guard let service = services.first(where: { $0.uuid == self.serviceUUID }) else {
            logger.warning("Service \(self.serviceUUID) not found.")
            showError(message: "Required service not found.")
            disconnect() // use your MainActor wrapper that schedules cancel on bleQueue
            return
        }

        let characteristicsToDiscover: [CBUUID] = [
            viewCharUUID,
            configCharUUID,
            tempCharUUID,
            commandCharUUID,
            temperatureLogsCharUUID,
            brightnessCharUUID,
            deviceInfoCharUUID,
            otaCharUUID,
            luxCharUUID,
            scrollTextCharUUID
        ]

        // Actual discover call runs on bleQueue
        peripheralServiceAsync(peripheral, service) { p, s in
            p.discoverCharacteristics(characteristicsToDiscover, for: s)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        Task { @MainActor [weak self] in
            self?.handleDidDiscoverCharacteristics(peripheral, service: service, error: error)
        }
    }

    @MainActor
    private func handleDidDiscoverCharacteristics(_ peripheral: CBPeripheral,
                                                 service: CBService,
                                                 error: Error?) {
        if let error {
            logger.error("Error discovering characteristics for \(service.uuid): \(error.localizedDescription)")
            showError(message: "Characteristic discovery error: \(error.localizedDescription)")
            disconnect()
            return
        }

        guard let characteristics = service.characteristics else {
            logger.warning("No characteristics for service \(service.uuid).")
            disconnect()
            return
        }

        var foundAllRequired = true

        for ch in characteristics {
            logger.debug("Found characteristic \(ch.uuid)")

            switch ch.uuid {
            case deviceInfoCharUUID:
                peripheralCharAsync(peripheral, ch) { p, c in p.readValue(for: c) }

            case viewCharUUID:
                targetCharacteristic = ch
                peripheralCharAsync(peripheral, ch) { p, c in
                    p.setNotifyValue(true, for: c)
                    p.readValue(for: c)
                }

            case configCharUUID:
                configCharacteristic = ch
                peripheralCharAsync(peripheral, ch) { p, c in
                    p.setNotifyValue(true, for: c)
                    p.readValue(for: c)
                }

            case tempCharUUID:
                temperatureCharacteristic = ch
                peripheralCharAsync(peripheral, ch) { p, c in p.setNotifyValue(true, for: c) }

            case commandCharUUID:
                commandCharacteristic = ch
                peripheralCharAsync(peripheral, ch) { p, c in p.setNotifyValue(true, for: c) }

            case temperatureLogsCharUUID:
                temperatureLogsCharacteristic = ch
                peripheralCharAsync(peripheral, ch) { p, c in p.setNotifyValue(true, for: c) }

            case brightnessCharUUID:
                brightnessCharacteristic = ch
                peripheralCharAsync(peripheral, ch) { p, c in
                    p.setNotifyValue(true, for: c)
                    p.readValue(for: c)
                }

            case otaCharUUID:
                otaCharacteristic = ch
                peripheralCharAsync(peripheral, ch) { p, c in p.setNotifyValue(true, for: c) }

            case luxCharUUID:
                luxCharacteristic = ch
                peripheralCharAsync(peripheral, ch) { p, c in p.setNotifyValue(true, for: c) }
                
            case scrollTextCharUUID:
                scrollTextCharacteristic = ch
                peripheralCharAsync(peripheral, ch) { p, c in
                    p.setNotifyValue(true, for: c)
                    p.readValue(for: c) // read current text on connect
                    // Removed the line: p.writeValue(Data(Text), for: c, type: .withResponse)
                }

            default:
                break
            }
        }

        if targetCharacteristic == nil { logger.warning("Missing view characteristic"); foundAllRequired = false }
        if configCharacteristic == nil { logger.warning("Missing config characteristic"); foundAllRequired = false }
        if temperatureCharacteristic == nil { logger.warning("Missing temperature characteristic"); foundAllRequired = false }
        if commandCharacteristic == nil { logger.warning("Missing command characteristic"); foundAllRequired = false }
        if temperatureLogsCharacteristic == nil { logger.warning("Missing temperature logs characteristic"); foundAllRequired = false }
        if brightnessCharacteristic == nil { logger.warning("Missing brightness characteristic"); foundAllRequired = false }
        if otaCharacteristic == nil { logger.warning("Missing OTA characteristic"); foundAllRequired = false }

        guard foundAllRequired else {
            logger.error("Essential characteristics missing; disconnecting.")
            showError(message: "Essential characteristics missing.")
            disconnect()
            return
        }

        logger.info("All required characteristics discovered/configured.")

        if let cmdChar = commandCharacteristic {
            resetHistoryDownloadState()
            requestTemperatureHistory(peripheral: peripheral, characteristic: cmdChar)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        let uuid = characteristic.uuid
        let data = characteristic.value
        let peripheralID = peripheral.identifier.uuidString

        Task { @MainActor [weak self] in
            self?.handleDidUpdateValue(peripheralID: peripheralID,
                                       uuid: uuid,
                                       data: data,
                                       error: error)
        }
    }

    @MainActor
    private func handleDidUpdateValue(peripheralID: String,
                                      uuid: CBUUID,
                                      data: Data?,
                                      error: Error?) {
        if let error {
            if isPairingError(error) {
                showError(message: "Pairing required. Enter the passkey shown on the device.")
                return
            }
            logger.error("Error updating \(uuid): \(error.localizedDescription)")
            showError(message: "Characteristic \(uuid.uuidString.prefix(4)) update error")
            return
        }

        guard let data else {
            logger.warning("Nil data for \(uuid) on \(peripheralID)")
            return
        }

        switch uuid {
        case deviceInfoCharUUID:
            if let jsonString = String(data: data, encoding: .utf8),
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    let info = try JSONDecoder().decode(DeviceInfo.self, from: jsonData)
                    deviceInfo = info
                    firmwareVersion = info.fw
                } catch {
                    logger.error("Failed to decode DeviceInfo: \(error.localizedDescription)")
                }
            }

        case viewCharUUID:
            handleViewUpdate(data: data)

        case configCharUUID:
            handleConfigUpdate(data: data)

        case tempCharUUID:
            guard !isDownloadingHistory else { return }
            handleLiveTemperatureUpdate(data: data)

        case temperatureLogsCharUUID:
            handleHistoryChunk(data: data)

        case commandCharUUID:
            logger.info("Command RX: \(data.map { String(format: "%02x", $0) }.joined())")

        case brightnessCharUUID:
            if let val = data.first {
                applyPeripheralUpdate {
                    if brightness != val { brightness = val }
                }
            }

        case otaCharUUID:
            let bytes = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            logger.info("OTA response: \(bytes)")
            if data.count == 2 {
                let code = data[0], detail = data[1]
                switch (code, detail) {
                case (0x01, 0x00): otaStatusMessage = "OTA Started"
                case (0x03, 0x00): otaStatusMessage = "OTA Complete — Rebooting..."
                case (0x04, 0x00): otaStatusMessage = "OTA Aborted"
                case (0xFF, _):
                    otaStatusMessage = "OTA Error \(detail)"
                    otaTimer?.invalidate()
                    otaProgress = 0.0
                default:
                    otaStatusMessage = "OTA Unknown Response"
                }
            }

        case luxCharUUID:
            guard data.count >= 2 else { return }
            let rawLux = UInt16(data[0]) | (UInt16(data[1]) << 8)
            if abs(Int(rawLux) - Int(lastLuxValue)) >= Int(luxThreshold) {
                lastLuxValue = rawLux
                luxValue = rawLux
            }
            
        case scrollTextCharUUID:
            // Firmware echoes current text (null-terminated). Decode safely.
            let rawBytes = [UInt8](data)
            let trimmed = rawBytes.prefix { $0 != 0 }
            let text = String(bytes: trimmed, encoding: .utf8)
                       ?? String(bytes: trimmed, encoding: .ascii)
                       ?? ""
            applyPeripheralUpdate {
                if customMessage != text { customMessage = text }
            }

        default:
            logger.warning("Unhandled characteristic \(uuid)")
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didReadRSSI RSSI: NSNumber,
                                error: Error?) {
        Task { @MainActor [weak self] in
            self?.handleDidReadRSSI(value: RSSI.intValue, error: error, peripheralID: peripheral.identifier.uuidString)
        }
    }

    @MainActor
    private func handleDidReadRSSI(value: Int, error: Error?, peripheralID: String) {
        if let error {
            logger.error("RSSI read error for \(peripheralID): \(error.localizedDescription)")
            return
        }
        signalStrength = value
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didWriteValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            if let error {
                if self.isPairingError(error) {
                    self.showError(message: "Pairing required. Enter the passkey shown on the device.")
                } else {
                    self.logger.error("Error writing value to \(characteristic.uuid): \(error.localizedDescription)")
                    self.showError(message: "Error writing command.")
                }

                // Unblock OTA sender so it can fail/cancel cleanly
                self.otaWriteContinuation?.resume()
                self.otaWriteContinuation = nil
                self.otaInProgress = false
                return
            }

            // Resume OTA “await write” when the ACK corresponds to the OTA pipe.
            // Your OTA packets are written to commandCharacteristic.
            if self.otaInProgress, characteristic.uuid == self.commandCharUUID {
                self.otaWriteContinuation?.resume()
                self.otaWriteContinuation = nil
            }

            self.logger.debug("Successfully wrote value to \(characteristic.uuid).")
        }
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
    
    
    // Peripheral-originated updates should not echo back over BLE.
    @MainActor
    private func handleViewUpdate(data: Data) {
        guard let viewValue = data.first.map({ Int($0) }) else {
            logger.warning("Invalid view update bytes: \(data.map { String(format: "%02x", $0) }.joined())")
            return
        }

        guard selectedView != viewValue else { return }
        applyPeripheralUpdate {
            selectedView = viewValue
        }
    }
    
    @MainActor
    private func handleConfigUpdate(data: Data) {
        guard data.count >= 4 else {
            logger.warning("Config data too short: \(data.count) bytes (need 4).")
            return
        }

        let autoB  = data[0] == 1
        let accel  = data[1] == 1
        let sleep  = data[2] == 1
        let aurora = data[3] == 1

        applyPeripheralUpdate {
            // Only assign if changed to avoid extra didSet churn
            if autoBrightness != autoB { autoBrightness = autoB }
            if accelerometerEnabled != accel { accelerometerEnabled = accel }
            if sleepModeEnabled != sleep { sleepModeEnabled = sleep }
            if auroraModeEnabled != aurora { auroraModeEnabled = aurora }
        }
    }
    // Inside AccessoryViewModel…
    @MainActor
    private func handleLiveTemperatureUpdate(data: Data) {
        guard let tempString = String(data: data, encoding: .utf8) else {
            logger.warning("Temp decode failed: \(data.map { String(format: "%02x", $0) }.joined())")
            temperature = "Error"
            return
        }

        let cleaned = tempString
            .replacingOccurrences(of: "°C", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let tempValue = Double(cleaned) else {
            logger.warning("Temp parse failed: '\(cleaned)' (raw '\(tempString)')")
            temperature = "?"
            return
        }

        temperature = String(format: "%.1f°C", tempValue)

        let newPoint = TemperatureData(timestamp: Date(), temperature: tempValue)
        didReceive(newPoint) // appends + prunes window
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
                    DispatchQueue.main.async {   self.processCompletedHistoryDownload()}
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
    
    
    
    
    // MARK: - State Update Helpers (Called on Main Thread)
    private func upsertDiscoveredDevice(_ device: PeripheralDevice) {
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
    }

    private func resetHistoryDownloadState() {
        
        isDownloadingHistory = false
        receivedHistoryChunks.removeAll()
        totalHistoryChunksExpected = nil
        logger.info("History download state reset.")
    }
    
    private func isPairingError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == CBATTErrorDomain,
           let code = CBATTError.Code(rawValue: ns.code) {
            return code == .insufficientAuthentication
                || code == .insufficientEncryption
                || code == .insufficientAuthorization
        }
        if ns.domain == CBErrorDomain,
           let code = CBError.Code(rawValue: ns.code) {
            return code == .peerRemovedPairingInformation
        }
        return false
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
    func loadStoredPeripherals() -> [StoredPeripheral] { // Can be called from any thread, UserDefaults is thread-safe for reads
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
    func saveStoredPeripherals(_ devices: [StoredPeripheral]) { // Can be called from any thread, UserDefaults is thread-safe for writes
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
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .disconnected
            }
            _scanForDevices()
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
            logger.error("❌ Couldn’t open shared defaults")
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
    private var pendingUpdateTask: Task<Void, Never>? = nil
    // Last watch payload digest sent; used to avoid redundant syncs when only timestamps change
    private var lastSentWatchDigest: WatchStateDigest? = nil
    
    /*
     func faceButtonTapped(_ faceIndex: Int) {
     guard faceIndex != selectedView else { return }
     selectedView = faceIndex
     scheduleLiveActivityUpdate()
     }
     */
    
    @MainActor
    func scheduleLiveActivityUpdate() {
        pendingUpdateTask?.cancel()
        pendingUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await updateLumiFur_WidgetLiveActivityIfNeeded()
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
        
        logger.info("Ending Live Activity \(activity.id) policy: \(String(describing: dismissalPolicy))") // Use helper
        
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
    
    /*
#if DEBUG
    /// An initializer specifically for creating configured instances for SwiftUI Previews or tests.
    /// This initializer allows us to set the internal state that our get-only computed properties depend on.
    convenience init(
        isConnected: Bool,
        isScanning: Bool = false,
        firmwareVersion: String = "N/A",
        discoveredDevices: [PeripheralDevice] = [], // Assuming PeripheralDevice is your model
        errorMessage: String? = nil
    ) {
        self.init() // Call the main designated initializer of the class.
        
        if isConnected {
            self.targetPeripheral = PeripheralDevice.mock.peripheral
        }
        
        self.firmwareVersion = firmwareVersion
        self.discoveredDevices = discoveredDevices
        
        if let errorMessage = errorMessage {
            self.errorMessage = errorMessage
            self.showError = true
        }
    }
#endif // DEBUG
    */
    
}// End of AccessoryViewModel


/// Debug / preview helpers for SwiftUI and tests.
#if DEBUG
extension AccessoryViewModel {
    /// Convenience initializer for SwiftUI previews / tests.
    convenience init(
        isConnected: Bool,
        isScanning: Bool = false,
        firmwareVersion: String = "N/A",
        discoveredDevices: [PeripheralDevice] = [],
        errorMessage: String? = nil
    ) {
        self.init()

        // Shape the BLE "status" surface that the UI reads.
        if isConnected {
            self.connectionState = .connected
        }
        if isScanning {
            self.connectionState = .scanning
        }
        self.firmwareVersion = firmwareVersion
        self.discoveredDevices = discoveredDevices

        if let errorMessage {
            self.errorMessage = errorMessage
            self.showError = true

        }

        // DO NOT touch isConnected (it's get-only)
        // DO NOT call real Bluetooth APIs.
    }

    static var previewDisconnected: AccessoryViewModel {
        AccessoryViewModel(
            isConnected: false,
            firmwareVersion: "N/A",
            discoveredDevices: []
        )
    }

    static var previewScanning: AccessoryViewModel {
        AccessoryViewModel(
            isConnected: false,
            isScanning: true,
            firmwareVersion: "N/A",
            discoveredDevices: []
        )
    }
    
    static var previewConnected: AccessoryViewModel {
        AccessoryViewModel(
            isConnected: true,
            firmwareVersion: "2.1.0",
            discoveredDevices: [.mock]
        )
    }

    static var previewError: AccessoryViewModel {
        AccessoryViewModel(
            isConnected: false,
            firmwareVersion: "N/A",
            discoveredDevices: [],
            errorMessage: "Failed to connect. The device is out of range."
        )
    }
}
#endif

// MARK: - Helper Extensions
/*
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
*/
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

