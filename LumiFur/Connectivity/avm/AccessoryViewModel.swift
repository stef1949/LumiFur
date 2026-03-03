import Combine
@preconcurrency import CoreBluetooth
import Foundation
import SwiftUI
import os

#if canImport(UIKit)
import UIKit
#endif

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS)
import ActivityKit
#endif

// MARK: - AccessoryViewModel

/// UI-facing state and orchestration for the LumiFur accessory.
class AccessoryViewModel: ObservableObject {
    @MainActor static let shared = AccessoryViewModel()

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LumiFur", category: "AccessoryViewModel")

    // MARK: Published state

    @Published var deviceInfo: DeviceInfo?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isScanning = false
    @Published var discoveredDevices: [PeripheralDevice] = []
    @Published private(set) var currentTempC: Double?
    @Published private(set) var temperature = "--"
    @Published private(set) var temperatureData: [TemperatureData] = []
    @Published var brightness: UInt8 = 255
    @Published var luxValue: UInt16 = 0
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var signalStrength = -100
    @Published var connectingPeripheral: PeripheralDevice?
    @Published var selectedView = 1
    @Published var strobeEnabled = false
    @Published var strobeCycleMs: UInt16 = 120
    @Published var strobeColor: Color = .white
    @Published var otaStatusMessage = "Idle"
    @Published var otaProgress = 0.0
    @Published var autoBrightness = true
    @Published var accelerometerEnabled = true
    @Published var sleepModeEnabled = true
    @Published var auroraModeEnabled = true
    @Published var customMessage = ""
    @Published var firmwareVersion = "N/A"
    @Published var previouslyConnectedDevices: [StoredPeripheral]
    @Published private(set) var targetPeripheral: CBPeripheral?
    @Published var autoReconnectEnabled = true
    @Published private(set) var isDownloadingHistory = false

    // MARK: Derived state

    var isConnected: Bool { connectionState == .connected }
    var isConnecting: Bool { connectionState == .connecting || connectionState == .reconnecting }
    var connectionStatus: String { connectionState.rawValue }
    var connectionColor: Color { connectionState.color }
    var connectionImageName: Image { connectionState.image }
    var temperatureString: String {
        guard let currentTempC else { return "--" }
        return String(format: "%.1f°C", currentTempC)
    }
    var isBluetoothReady: Bool { bluetoothState == .poweredOn }

    var connectedDevice: PeripheralDevice? {
        #if DEBUG
        if isRunningPreview {
            return discoveredDevices.first
        }
        #endif

        guard isConnected, let targetPeripheral else { return nil }
        return discoveredDevices.first { $0.id == targetPeripheral.identifier }
    }

    var connectedDeviceName: String? {
        #if DEBUG
        if isRunningPreview {
            return discoveredDevices.first?.name
        }
        #endif

        return targetPeripheral?.name
    }

    /// A throttled chart publisher that keeps only a rolling five-minute window.
    var temperatureChartPublisher: AnyPublisher<[TemperatureData], Never> {
        $temperatureData
            .map { [maxTemperatureDataPoints] all in
                let cutoff = Date().addingTimeInterval(-5 * 60)
                var window = all.filter { $0.timestamp >= cutoff }

                if window.count > maxTemperatureDataPoints {
                    window.removeFirst(window.count - maxTemperatureDataPoints)
                }

                return window
            }
            .throttle(for: .seconds(5), scheduler: RunLoop.main, latest: true)
            .eraseToAnyPublisher()
    }

    // MARK: Internal coordination state

    struct StateDigest: Equatable {
        let connectionState: ConnectionState
        let signalStrength: Int
        let temperature: String
        let selectedView: Int
        let configuration: AccessoryConfiguration
        let customMessage: String
        let connectedDeviceName: String?
        let temperatureCount: Int
        let lastTemperatureTimestamp: Date?
    }

    struct WatchStateDigest: Equatable {
        let connectionState: ConnectionState
        let temperature: String
        let selectedView: Int
        let configuration: AccessoryConfiguration
        let customMessage: String
        let connectedDeviceName: String?
    }

    let client: BLEClient
    private let store: StoredPeripheralStore
    private let isRunningPreview: Bool
    private let maxTemperatureDataPoints = 600
    private let liveTempChangeThresholdC = 0.1
    private let changeViewIntentNotification = Notification.Name("com.richies3d.LumiFur.ChangeViewIntentTriggered")
    private var notificationTokens: [NSObjectProtocol] = []
    private var bluetoothState: CBManagerState
    private var lastPublishedTempC: Double?
    private var lastConnectedPeripheralUUID: String?
    private var didAttemptAutoReconnect = false
    private var isManualDisconnect = false
    var pendingExternalUpdateTask: Task<Void, Never>?
    var pendingWatchSyncTask: Task<Void, Never>?
    var lastSentStateDigest: StateDigest?
    var lastSentWatchDigest: WatchStateDigest?
    var lastWatchSyncAt = Date.distantPast
    private var pendingStrobeWriteTask: Task<Void, Never>?
    private var otaTask: Task<Void, Never>?
    private var otaGeneration: UInt64 = 0
    private var otaInProgress = false

    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS)
    var currentActivity: Activity<LumiFur_WidgetAttributes>?
    var activityStateTask: Task<Void, Never>?
    var lastSentActivityState: LumiFur_WidgetAttributes.ContentState?
    var pendingLiveActivityUpdateTask: Task<Void, Never>?
    var isCreatingActivity = false
    #endif

    // MARK: Init

    @MainActor
    init(
        client: BLEClient = BLEClient(),
        store: StoredPeripheralStore = StoredPeripheralStore()
    ) {
        let environment = ProcessInfo.processInfo.environment
        self.client = client
        self.store = store
        self.isRunningPreview = environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        self.bluetoothState =
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ||
            environment["XCTestConfigurationFilePath"] != nil
            ? .poweredOn
            : .unknown
        self.previouslyConnectedDevices = store.load()
        self.lastConnectedPeripheralUUID = store.lastConnectedPeripheralUUID()

        configureTransport()
        registerObservers()

        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS)
        if !isRunningPreview {
            Task { @MainActor [weak self] in
                await self?.endAllLumiFurActivities()
            }
        }
        #endif
    }

    deinit {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        pendingExternalUpdateTask?.cancel()
        pendingWatchSyncTask?.cancel()
        pendingStrobeWriteTask?.cancel()
        otaTask?.cancel()

        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS)
        pendingLiveActivityUpdateTask?.cancel()
        activityStateTask?.cancel()
        #endif
    }

    // MARK: Public API

    func encodedAccessorySettingsPayload(
        autoBrightness: Bool,
        accelerometerEnabled: Bool,
        sleepModeEnabled: Bool,
        auroraModeEnabled: Bool
    ) -> Data {
        AccessoryCommandEncoder.accessorySettingsPayload(
            autoBrightness: autoBrightness,
            accelerometerEnabled: accelerometerEnabled,
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled
        )
    }

    func loadStoredPeripherals() -> [StoredPeripheral] {
        store.load()
    }

    func saveStoredPeripherals(_ devices: [StoredPeripheral]) {
        store.save(devices)
        previouslyConnectedDevices = devices
    }

    @MainActor
    func scanForDevices() {
        if isRunningPreview {
            discoveredDevices = [
                PeripheralDevice(
                    id: UUID(),
                    name: "LumiFur-1234",
                    rssi: -55,
                    advertisementServiceUUIDs: ["FFF0"],
                    peripheral: nil
                ),
                PeripheralDevice(
                    id: UUID(),
                    name: "LumiFur-BBBB",
                    rssi: -68,
                    advertisementServiceUUIDs: ["FFF0"],
                    peripheral: nil
                ),
            ]
            isScanning = false
            connectionState = .disconnected
            return
        }

        guard isBluetoothReady else {
            connectionState = .bluetoothOff
            return
        }

        discoveredDevices.removeAll(keepingCapacity: true)
        connectingPeripheral = nil
        isScanning = true
        connectionState = .scanning
        client.startScan()
        scheduleExternalStateSync()
    }

    @MainActor
    func stopScan() {
        client.stopScan()
        isScanning = false

        if connectionState == .scanning {
            connectionState = .disconnected
        }

        scheduleExternalStateSync()
    }

    @MainActor
    func connect(to device: PeripheralDevice) {
        guard isBluetoothReady else {
            connectionState = .bluetoothOff
            return
        }
        guard let peripheral = device.peripheral else {
            logger.warning("Attempted to connect without a CoreBluetooth peripheral instance.")
            return
        }

        stopScan()
        connectingPeripheral = device
        connectionState = .connecting
        targetPeripheral = peripheral
        isManualDisconnect = false
        client.connect(to: peripheral)
        scheduleExternalStateSync()
    }

    @MainActor
    func disconnect() {
        isManualDisconnect = true
        client.disconnect()
    }

    @MainActor
    func connectToStoredPeripheral(_ stored: StoredPeripheral) {
        guard isBluetoothReady else {
            connectionState = .bluetoothOff
            return
        }

        connectionState = .reconnecting
        connectingPeripheral = nil
        client.connectToStoredUUID(stored.id)
        scheduleExternalStateSync()
    }

    @MainActor
    func setView(_ view: Int) {
        guard (1...50).contains(view), selectedView != view else { return }
        selectedView = view
        client.writeView(view)
        scheduleExternalStateSync()
    }

    @MainActor
    func faceButtonTapped(_ faceIndex: Int) {
        setView(faceIndex)
    }

    @MainActor
    func sendScrollText(_ text: String) {
        customMessage = text
        client.writeScrollText(text)
        scheduleExternalStateSync()
    }

    @MainActor
    func sendScrollSpeed(_ speed: UInt8) {
        client.writeScrollSpeed(speed)
    }

    @MainActor
    func setBrightness(_ value: UInt8) {
        guard brightness != value else { return }
        brightness = value
        client.writeBrightness(value)
    }

    @MainActor
    func setStrobeSettings(enabled: Bool, color: Color, cycleMs: UInt16) {
        let clampedCycle = UInt16(max(1, min(10_000, Int(cycleMs))))
        let rgb = color.toRGB8() ?? RGB8(r: 255, g: 255, b: 255)
        let payload = StrobeSettingsPayload(enabled: enabled, rgb: rgb, cycleMs: clampedCycle)

        strobeEnabled = enabled
        strobeColor = Color(rgb)
        strobeCycleMs = clampedCycle

        pendingStrobeWriteTask?.cancel()
        pendingStrobeWriteTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            self?.client.writeStrobe(payload)
        }
    }

    @MainActor
    func writeConfigToCharacteristic() {
        let configuration = AccessoryConfiguration(
            autoBrightness: autoBrightness,
            accelerometerEnabled: accelerometerEnabled,
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled
        )
        client.writeConfiguration(configuration)
        scheduleExternalStateSync()
    }

    @MainActor
    func startRSSIMonitoring() {
        client.startRSSIMonitoring()
    }

    @MainActor
    func stopRSSIMonitoring() {
        client.stopRSSIMonitoring()
    }

    @MainActor
    func startOTAUpdate(firmwareData: Data) {
        guard isConnected else {
            otaStatusMessage = "OTA Error: Peripheral not ready"
            return
        }

        otaTask?.cancel()
        otaGeneration &+= 1
        otaInProgress = true
        otaProgress = 0
        otaStatusMessage = "Starting OTA..."

        let generation = otaGeneration

        otaTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.runOTAUpdate(firmwareData: firmwareData, generation: generation)
            } catch is CancellationError {
                return
            } catch {
                self.otaStatusMessage = "OTA Error: \(error.localizedDescription)"
                self.otaProgress = 0
                self.otaInProgress = false
            }
        }
    }

    @MainActor
    func abortOTAUpdate() {
        otaTask?.cancel()
        otaGeneration &+= 1
        otaInProgress = false
        otaProgress = 0
        otaStatusMessage = "OTA Aborted"
        client.writeOTAAbort()
    }

    @MainActor
    func syncStateToWatch() {
        let digest = makeWatchStateDigest()
        guard digest != lastSentWatchDigest else { return }

        lastSentWatchDigest = digest
        lastWatchSyncAt = Date()
        WatchConnectivityManager.shared.syncStateToWatch(from: self)
    }

    // MARK: Transport wiring

    @MainActor
    private func configureTransport() {
        let selfBox = WeakUncheckedSendableBox(self)
        client.onEvent = { event in
            selfBox.value?.handleTransportEvent(event)
        }
    }

    @MainActor
    private func registerObservers() {
        let selfBox = WeakUncheckedSendableBox(self)
        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: changeViewIntentNotification,
                object: nil,
                queue: .main
            ) { notification in
                let nextView = notification.userInfo?["nextView"] as? Int
                MainActor.assumeIsolated {
                    guard let nextView else { return }
                    selfBox.value?.setView(nextView)
                }
            }
        )

        #if canImport(UIKit)
        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    selfBox.value?.handleAppDidBecomeActive()
                }
            }
        )
        #endif
    }

    @MainActor
    private func handleTransportEvent(_ event: BLEClient.Event) {
        switch event {
        case .stateChanged(let state):
            handleBluetoothStateChange(state)

        case .discovered(let discovery):
            let device = PeripheralDevice(
                id: discovery.id,
                name: discovery.name,
                rssi: discovery.rssi,
                advertisementServiceUUIDs: discovery.advertisementServiceUUIDs,
                peripheral: discovery.peripheral.value
            )

            if connectionState == .reconnecting,
               let lastConnectedPeripheralUUID,
               discovery.id.uuidString == lastConnectedPeripheralUUID {
                connect(to: device)
            } else {
                upsertDiscoveredDevice(device)
            }

        case .connected(let connection):
            handleConnected(connection)

        case .failedToConnect(let failure):
            handleConnectionFailure(failure)

        case .disconnected(let disconnection):
            Task { @MainActor [weak self] in
                await self?.handleDisconnect(disconnection)
            }

        case .storedPeripheralNotFound:
            connectionState = .disconnected
            scanForDevices()

        case .deviceInfoUpdated(let info):
            deviceInfo = info
            firmwareVersion = info.fw
            scheduleExternalStateSync()

        case .selectedViewUpdated(let view):
            guard selectedView != view else { return }
            selectedView = view
            scheduleExternalStateSync()

        case .configurationUpdated(let configuration):
            apply(configuration: configuration)

        case .liveTemperatureUpdated(let celsius):
            applyLiveTemperature(celsius)

        case .historyDownloadStarted:
            isDownloadingHistory = true

        case .historyDownloaded(let history):
            isDownloadingHistory = false
            apply(history: history)

        case .historyDownloadFailed(let message):
            isDownloadingHistory = false
            logger.warning("Temperature history download failed: \(message)")

        case .brightnessUpdated(let value):
            brightness = value

        case .otaResponseUpdated(let response):
            otaStatusMessage = response.statusMessage
            if response.resetsProgress {
                otaProgress = 0
            }

        case .luxUpdated(let value):
            luxValue = value

        case .scrollTextUpdated(let text):
            customMessage = text
            scheduleExternalStateSync()

        case .strobeUpdated(let state):
            strobeEnabled = state.enabled
            strobeCycleMs = state.cycleMs
            strobeColor = Color(state.rgb)

        case .rssiUpdated(let rssi):
            if signalStrength != rssi {
                signalStrength = rssi
                scheduleExternalStateSync()
            }

        case .pairingRequired:
            presentError("Pairing required. Enter the passkey shown on the device.")

        case .transportError(let message):
            logger.error("BLE transport error: \(message)")
            presentError(message)
        }
    }

    @MainActor
    private func handleBluetoothStateChange(_ state: CBManagerState) {
        bluetoothState = state

        switch state {
        case .poweredOn:
            if !didAttemptAutoReconnect, let lastConnectedPeripheralUUID {
                didAttemptAutoReconnect = true
                connectionState = .reconnecting
                client.connectToStoredUUID(lastConnectedPeripheralUUID)
            } else if !isConnected && !isScanning {
                connectionState = .disconnected
                scanForDevices()
            }

        case .poweredOff:
            clearConnectionState()
            connectionState = .bluetoothOff
            didAttemptAutoReconnect = false

        case .unauthorized, .unsupported, .resetting, .unknown:
            clearConnectionState()
            connectionState = .unknown
            didAttemptAutoReconnect = false

        @unknown default:
            clearConnectionState()
            connectionState = .unknown
            didAttemptAutoReconnect = false
        }

        scheduleExternalStateSync()
    }

    @MainActor
    private func handleConnected(_ connection: PeripheralConnection) {
        let peripheral = connection.peripheral.value
        let uuid = peripheral.identifier.uuidString

        targetPeripheral = peripheral
        connectionState = .connected
        isScanning = false
        connectingPeripheral = nil
        isManualDisconnect = false
        didAttemptAutoReconnect = false
        deviceInfo = nil

        lastConnectedPeripheralUUID = uuid
        store.setLastConnectedPeripheralUUID(uuid)
        previouslyConnectedDevices = store.upsert(id: uuid, name: connection.name ?? "Unknown")

        startRSSIMonitoring()
        scheduleExternalStateSync()

        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS)
        Task { [weak self] in
            await self?.startLumiFur_WidgetLiveActivity()
        }
        #endif
    }

    @MainActor
    private func handleConnectionFailure(_ failure: PeripheralFailure) {
        if targetPeripheral?.identifier.uuidString == failure.id {
            targetPeripheral = nil
        }

        connectingPeripheral = nil
        connectionState = .failed
        didAttemptAutoReconnect = false
        scheduleExternalStateSync()

        if !isScanning {
            scanForDevices()
        }
    }

    @MainActor
    private func handleDisconnect(_ disconnection: PeripheralDisconnection) async {
        let wasManualDisconnect = isManualDisconnect
        isManualDisconnect = false

        clearConnectionState()
        connectionState = .disconnected
        connectingPeripheral = nil
        scheduleExternalStateSync()

        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS)
        let finalState = createContentState(connected: false, status: ConnectionState.disconnected.rawValue)

        if wasManualDisconnect {
            await endLiveActivity(finalContent: finalState, dismissalPolicy: .immediate)
        } else if disconnection.message != nil {
            let dismissalDate = Date().addingTimeInterval(15 * 60)
            await endLiveActivity(finalContent: finalState, dismissalPolicy: .after(dismissalDate))
        } else {
            await endLiveActivity(finalContent: finalState, dismissalPolicy: .immediate)
        }
        #endif

        if !wasManualDisconnect, autoReconnectEnabled, let lastConnectedPeripheralUUID {
            connectionState = .reconnecting
            client.connectToStoredUUID(lastConnectedPeripheralUUID)
        } else if !wasManualDisconnect {
            scanForDevices()
        }
    }

    // MARK: State mutation helpers

    @MainActor
    private func apply(configuration: AccessoryConfiguration) {
        autoBrightness = configuration.autoBrightness
        accelerometerEnabled = configuration.accelerometerEnabled
        sleepModeEnabled = configuration.sleepModeEnabled
        auroraModeEnabled = configuration.auroraModeEnabled
        scheduleExternalStateSync()
    }

    @MainActor
    private func applyLiveTemperature(_ celsius: Double) {
        currentTempC = celsius

        if lastPublishedTempC == nil || abs(celsius - (lastPublishedTempC ?? celsius)) >= liveTempChangeThresholdC {
            lastPublishedTempC = celsius
            temperature = temperatureString
        }

        appendTemperatureSample(TemperatureData(timestamp: Date(), temperature: celsius))
        scheduleExternalStateSync()
    }

    @MainActor
    private func apply(history: [TemperatureData]) {
        let cappedHistory = Array(history.suffix(maxTemperatureDataPoints))
        temperatureData = cappedHistory
        currentTempC = cappedHistory.last?.temperature
        lastPublishedTempC = currentTempC
        temperature = temperatureString
        scheduleExternalStateSync()
    }

    @MainActor
    private func appendTemperatureSample(_ sample: TemperatureData) {
        temperatureData.append(sample)

        let cutoff = Date().addingTimeInterval(-10 * 60)
        if let firstRetained = temperatureData.firstIndex(where: { $0.timestamp >= cutoff }), firstRetained > 0 {
            temperatureData.removeFirst(firstRetained)
        } else if temperatureData.first?.timestamp ?? .distantFuture < cutoff {
            temperatureData.removeAll(keepingCapacity: true)
            temperatureData.append(sample)
        }

        if temperatureData.count > maxTemperatureDataPoints {
            temperatureData.removeFirst(temperatureData.count - maxTemperatureDataPoints)
        }
    }

    @MainActor
    private func upsertDiscoveredDevice(_ device: PeripheralDevice) {
        if let existingIndex = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[existingIndex] = device
        } else {
            discoveredDevices.append(device)
        }
    }

    @MainActor
    private func clearConnectionState() {
        targetPeripheral = nil
        deviceInfo = nil
        currentTempC = nil
        lastPublishedTempC = nil
        temperature = "--"
        temperatureData.removeAll(keepingCapacity: true)
        signalStrength = -100
        firmwareVersion = "N/A"
        luxValue = 0
        isScanning = false
        isDownloadingHistory = false
        client.stopRSSIMonitoring()
    }

    @MainActor
    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }

    @MainActor
    func currentConfiguration() -> AccessoryConfiguration {
        AccessoryConfiguration(
            autoBrightness: autoBrightness,
            accelerometerEnabled: accelerometerEnabled,
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled
        )
    }

    // MARK: OTA helpers

    @MainActor
    private func runOTAUpdate(firmwareData: Data, generation: UInt64) async throws {
        try await client.writeCommandWithResponse(AccessoryCommandEncoder.otaStart(size: firmwareData.count))
        try await Task.sleep(nanoseconds: 300_000_000)

        let mtu = 185
        let chunkSize = mtu - 3
        var offset = 0

        while offset < firmwareData.count {
            try Task.checkCancellation()
            guard otaGeneration == generation else { throw CancellationError() }

            let end = min(offset + chunkSize, firmwareData.count)
            let chunk = firmwareData.subdata(in: offset..<end)
            try await client.writeCommandWithResponse(AccessoryCommandEncoder.otaChunk(chunk))

            offset = end
            otaProgress = Double(offset) / Double(max(firmwareData.count, 1))
            otaStatusMessage = "Uploading... \(Int(otaProgress * 100))%"
        }

        try await client.writeCommandWithResponse(AccessoryCommandEncoder.otaFinish())
        otaStatusMessage = "Finalizing OTA..."
        otaInProgress = false
    }

    // MARK: Notifications

    @MainActor
    private func handleChangeViewIntent(_ notification: Notification) {
        guard let nextView = notification.userInfo?["nextView"] as? Int else { return }
        setView(nextView)
    }

    @MainActor
    private func handleAppDidBecomeActive() {
        guard isConnected else { return }

        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS)
        Task { [weak self] in
            await self?.startLumiFur_WidgetLiveActivity()
        }
        #endif
    }
}

// MARK: - Preview Helpers

#if DEBUG
@MainActor
extension AccessoryViewModel {
    convenience init(
        isConnected: Bool,
        isScanning: Bool = false,
        firmwareVersion: String = "N/A",
        discoveredDevices: [PeripheralDevice] = [],
        errorMessage: String? = nil
    ) {
        self.init(client: BLEClient(), store: StoredPeripheralStore())

        if isConnected {
            connectionState = .connected
        } else if isScanning {
            connectionState = .scanning
        } else {
            connectionState = .disconnected
        }

        self.firmwareVersion = firmwareVersion
        self.discoveredDevices = discoveredDevices

        if let errorMessage {
            self.errorMessage = errorMessage
            showError = true
        }
    }

    static var previewDisconnected: AccessoryViewModel {
        AccessoryViewModel(isConnected: false)
    }

    static var previewScanning: AccessoryViewModel {
        AccessoryViewModel(isConnected: false, isScanning: true)
    }

    static var previewConnected: AccessoryViewModel {
        AccessoryViewModel(
            isConnected: true,
            firmwareVersion: "2.1.0",
            discoveredDevices: [
                PeripheralDevice(
                    id: UUID(),
                    name: "LumiFur-1234",
                    rssi: -55,
                    advertisementServiceUUIDs: ["FFF0"],
                    peripheral: nil
                )
            ]
        )
    }

    static var previewError: AccessoryViewModel {
        AccessoryViewModel(
            isConnected: false,
            errorMessage: "Failed to connect. The device is out of range."
        )
    }
}
#endif
