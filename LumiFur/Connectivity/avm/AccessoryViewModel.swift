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

private struct TemperatureWindowReducer: Sendable {
    let maxPoints: Int

    func callAsFunction(_ all: [TemperatureData]) -> [TemperatureData] {
        let cutoff = Date().addingTimeInterval(-5 * 60)
        var window = all.filter { $0.timestamp >= cutoff }

        if window.count > maxPoints {
            window.removeFirst(window.count - maxPoints)
        }

        return window
    }
}

// MARK: - AccessoryViewModel

/// UI-facing state and orchestration for the LumiFur accessory.
@MainActor
final class AccessoryViewModel: ObservableObject {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LumiFur", category: "AccessoryViewModel")

    // MARK: Published state

    @Published var deviceInfo: DeviceInfo?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isScanning = false
    @Published var discoveredDevices: [PeripheralDevice] = []
    private(set) var currentTempC: Double?
    @Published private(set) var temperature = "--"
    private(set) var temperatureData: [TemperatureData] = []
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
        let maxPoints = maxTemperatureDataPoints
        let reducer = TemperatureWindowReducer(maxPoints: maxPoints)

        return temperatureDataSubject
            .receive(on: Self.chartProcessingQueue)
            .map(reducer.callAsFunction)
            .removeDuplicates()
            .receive(on: RunLoop.main)
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
    private let defaults: UserDefaults
    private let widgetSnapshotStore: WidgetSnapshotStore
    private let isRunningPreview: Bool
    private let maxTemperatureDataPoints = 600
    private let liveTempChangeThresholdC = 0.1
    private let defaultRSSIInterval: TimeInterval = 1.0
    private let idleRSSIInterval: TimeInterval = 10.0
    private var notificationTokens: [NSObjectProtocol] = []
    private var bluetoothState: CBManagerState
    private let temperatureDataSubject = CurrentValueSubject<[TemperatureData], Never>([])
    private var lastPublishedTempC: Double?
    private var lastConnectedPeripheralUUID: String?
    private var didAttemptAutoReconnect = false
    private var isManualDisconnect = false
    private var isAppActive = true
    private var lastProcessedWidgetCommandID: UUID?
    var pendingExternalUpdateTask: Task<Void, Never>?
    var pendingWatchSyncTask: Task<Void, Never>?
    var lastSentStateDigest: StateDigest?
    var lastSentWatchDigest: WatchStateDigest?
    var lastWatchSyncAt = Date.distantPast
    private var pendingStrobeWriteTask: Task<Void, Never>?
    private var otaTask: Task<Void, Never>?
    private var otaGeneration: UInt64 = 0
    private var otaInProgress = false
    private static let chartProcessingQueue = DispatchQueue(
        label: "com.richies3d.lumifur.chart-processing",
        qos: .utility
    )

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
        store: StoredPeripheralStore = StoredPeripheralStore(),
        defaults: UserDefaults = .standard
    ) {
        let environment = ProcessInfo.processInfo.environment
        self.client = client
        self.store = store
        self.defaults = defaults
        self.widgetSnapshotStore = WidgetSnapshotStore()
        self.isRunningPreview = environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        self.bluetoothState =
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ||
            environment["XCTestConfigurationFilePath"] != nil
            ? .poweredOn
            : .unknown
        self.previouslyConnectedDevices = store.load()
        self.lastConnectedPeripheralUUID = store.lastConnectedPeripheralUUID()

        restorePersistedPreferences()

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

    @MainActor
    private func restorePersistedPreferences() {
        migrateLegacyPreferenceKeysIfNeeded(defaults)

        autoBrightness = persistedBool(
            in: defaults,
            key: "autoBrightness",
            defaultValue: autoBrightness
        )
        accelerometerEnabled = persistedBool(
            in: defaults,
            key: "accelerometer",
            defaultValue: accelerometerEnabled
        )
        sleepModeEnabled = persistedBool(
            in: defaults,
            key: "sleepMode",
            defaultValue: sleepModeEnabled
        )
        auroraModeEnabled = persistedBool(
            in: defaults,
            key: "auroraMode",
            defaultValue: auroraModeEnabled
        )

        if let storedMessage = defaults.object(forKey: "customMessageText") as? String {
            customMessage = storedMessage
        }
    }

    @MainActor
    private func migrateLegacyPreferenceKeysIfNeeded(_ defaults: UserDefaults) {
        if defaults.object(forKey: "auroraMode") == nil,
           let legacyAuroraMode = defaults.object(forKey: "arouraMode") as? Bool {
            defaults.set(legacyAuroraMode, forKey: "auroraMode")
        }

        if defaults.object(forKey: "customMessageEnabled") == nil,
           let legacyEnabled = defaults.object(forKey: "customMessage") as? Bool {
            defaults.set(legacyEnabled, forKey: "customMessageEnabled")
        }

        if defaults.object(forKey: "customMessageText") == nil,
           let legacyMessage = defaults.object(forKey: "customMessage") as? String {
            defaults.set(legacyMessage, forKey: "customMessageText")
        }

        if defaults.object(forKey: "auroraMode") != nil {
            defaults.removeObject(forKey: "arouraMode")
        }

        if defaults.object(forKey: "customMessageEnabled") != nil ||
            defaults.object(forKey: "customMessageText") != nil {
            defaults.removeObject(forKey: "customMessage")
        }
    }

    @MainActor
    private func persistedBool(
        in defaults: UserDefaults,
        key: String,
        defaultValue: Bool
    ) -> Bool {
        guard let storedValue = defaults.object(forKey: key) as? Bool else {
            return defaultValue
        }

        return storedValue
    }

    private func persistCurrentPreferences() {
        defaults.set(autoBrightness, forKey: "autoBrightness")
        defaults.set(accelerometerEnabled, forKey: "accelerometer")
        defaults.set(sleepModeEnabled, forKey: "sleepMode")
        defaults.set(auroraModeEnabled, forKey: "auroraMode")
        defaults.removeObject(forKey: "arouraMode")
        defaults.set(customMessage, forKey: "customMessageText")
        defaults.set(!customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, forKey: "customMessageEnabled")
    }

    private func applyConfigurationState(_ configuration: AccessoryConfiguration, persist: Bool = true) {
        let didChangeAutoBrightness = assignIfChanged(
            "autoBrightness",
            current: &autoBrightness,
            newValue: configuration.autoBrightness
        )
        let didChangeAccelerometer = assignIfChanged(
            "accelerometerEnabled",
            current: &accelerometerEnabled,
            newValue: configuration.accelerometerEnabled
        )
        let didChangeSleepMode = assignIfChanged(
            "sleepModeEnabled",
            current: &sleepModeEnabled,
            newValue: configuration.sleepModeEnabled
        )
        let didChangeAuroraMode = assignIfChanged(
            "auroraModeEnabled",
            current: &auroraModeEnabled,
            newValue: configuration.auroraModeEnabled
        )

        if persist, didChangeAutoBrightness || didChangeAccelerometer || didChangeSleepMode || didChangeAuroraMode {
            persistCurrentPreferences()
        }

        if didChangeAutoBrightness || didChangeAccelerometer || didChangeSleepMode || didChangeAuroraMode {
            scheduleExternalStateSync()
        }
    }

    @discardableResult
    func applyUserConfiguration(_ configuration: AccessoryConfiguration, syncToDevice: Bool = true) -> Bool {
        applyConfigurationState(configuration)

        guard syncToDevice else { return true }
        guard isConnected else { return false }
        guard client.canWriteConfiguration() else {
            presentError("Accessory is not ready to accept configuration changes yet.")
            return false
        }

        client.writeConfiguration(configuration)
        return true
    }

    @discardableResult
    func updateCustomMessage(_ text: String, syncToDevice: Bool = true) -> Bool {
        customMessage = text
        persistCurrentPreferences()
        scheduleExternalStateSync()

        guard syncToDevice else { return true }
        guard isConnected else { return false }
        guard client.canWriteScrollText() else {
            presentError("Accessory is not ready to accept custom text yet.")
            return false
        }

        client.writeScrollText(text)
        return true
    }

    @discardableResult
    func resetConfigurationToDefaults(syncToDevice: Bool = true) -> Bool {
        applyUserConfiguration(
            AccessoryConfiguration(
                autoBrightness: true,
                accelerometerEnabled: true,
                sleepModeEnabled: true,
                auroraModeEnabled: true
            ),
            syncToDevice: syncToDevice
        )
    }

    func currentWatchSnapshot(deviceName: String? = nil) -> WatchStateSnapshot {
        WatchStateSnapshot(
            deviceName: deviceName,
            controllerName: connectedDeviceName,
            controllerConnectionState: connectionState,
            selectedView: selectedView,
            configuration: currentConfiguration(),
            customMessage: customMessage,
            temperatureText: temperature,
            temperatureC: temperatureData.last?.temperature,
            temperatureTimestamp: temperatureData.last?.timestamp
        )
    }

    func currentWidgetSnapshot() -> WidgetSnapshot {
        WidgetSnapshot(
            isConnected: isConnected,
            connectionStatus: connectionStatus,
            controllerName: connectedDeviceName,
            signalStrength: signalStrength,
            temperatureText: temperature,
            temperatureHistory: Array(temperatureData.suffix(50)),
            selectedView: selectedView,
            availableViewCount: SharedOptions.protoActionOptions.count,
            configuration: currentConfiguration(),
            customMessage: customMessage
        )
    }

    func persistWidgetSnapshot() {
        widgetSnapshotStore.saveSnapshot(currentWidgetSnapshot())
    }

    @discardableResult
    func attemptRemoteConnect() -> String {
        guard isBluetoothReady else {
            connectionState = .bluetoothOff
            return "Bluetooth is unavailable."
        }

        if isConnected {
            return "Controller already connected."
        }

        if isConnecting {
            return "Connection already in progress."
        }

        if let lastConnectedPeripheralUUID {
            connectionState = .reconnecting
            connectingPeripheral = nil
            client.connectToStoredUUID(lastConnectedPeripheralUUID)
            scheduleExternalStateSync()
            return "Reconnecting to the last controller."
        }

        scanForDevices()
        return "Scanning for LumiFur controllers."
    }

    func processPendingWidgetCommandIfNeeded() {
        guard isConnected else { return }
        guard let command = widgetSnapshotStore.loadPendingCommand() else { return }
        guard command.id != lastProcessedWidgetCommandID else {
            widgetSnapshotStore.clearPendingCommand(id: command.id)
            return
        }

        switch command.kind {
        case .setView:
            if setView(command.selectedView) {
                lastProcessedWidgetCommandID = command.id
                widgetSnapshotStore.clearPendingCommand(id: command.id)
            }
        }
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

    @discardableResult
    @MainActor
    func setView(_ view: Int) -> Bool {
        guard (1...50).contains(view), selectedView != view else { return false }
        guard isConnected else {
            presentError("Connect to your LumiFur controller before changing the view.")
            return false
        }
        guard client.canWriteView() else {
            presentError("Accessory is not ready to accept a new view yet.")
            return false
        }
        selectedView = view
        client.writeView(view)
        scheduleExternalStateSync()
        return true
    }

    @MainActor
    func faceButtonTapped(_ faceIndex: Int) {
        setView(faceIndex)
    }

    @MainActor
    func sendScrollText(_ text: String) {
        _ = updateCustomMessage(text)
    }

    @MainActor
    func sendScrollSpeed(_ speed: UInt8) {
        client.writeScrollSpeed(speed)
    }

    @MainActor
    func setBrightness(_ value: UInt8) {
        guard brightness != value else { return }
        guard client.canWriteBrightness() else {
            presentError("Accessory is not ready to accept brightness updates yet.")
            return
        }
        brightness = value
        client.writeBrightness(value)
    }

    @MainActor
    func setStrobeSettings(enabled: Bool, color: Color, cycleMs: UInt16) {
        guard client.canWriteStrobeSettings() else {
            presentError("Accessory is not ready to accept strobe settings yet.")
            return
        }
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
        _ = applyUserConfiguration(currentConfiguration())
    }

    @MainActor
    func startRSSIMonitoring() {
        client.startRSSIMonitoring(interval: preferredRSSIMonitoringInterval())
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
        #if canImport(UIKit)
        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    selfBox.value?.handleAppDidBecomeActive()
                }
            }
        )
        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    selfBox.value?.handleAppWillResignActive()
                }
            }
        )
        #endif
    }

    @MainActor
    private func handleTransportEvent(_ event: BLEClient.Event) {
        IdleCPUDiagnostics.shared.recordTransportEvent(event.idleCPUCounterName)

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
            assignIfChanged("deviceInfo", current: &deviceInfo, newValue: info)
            assignIfChanged("firmwareVersion", current: &firmwareVersion, newValue: info.fw)
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
            assignIfChanged("isDownloadingHistory", current: &isDownloadingHistory, newValue: true)

        case .historyDownloaded(let history):
            assignIfChanged("isDownloadingHistory", current: &isDownloadingHistory, newValue: false)
            apply(history: history)

        case .historyDownloadFailed(let message):
            assignIfChanged("isDownloadingHistory", current: &isDownloadingHistory, newValue: false)
            logger.warning("Temperature history download failed: \(message)")

        case .brightnessUpdated(let value):
            assignIfChanged("brightness", current: &brightness, newValue: value)

        case .otaResponseUpdated(let response):
            otaStatusMessage = response.statusMessage
            if response.resetsProgress {
                otaProgress = 0
            }

        case .luxUpdated(let value):
            applyLuxValueIfNeeded(value)

        case .scrollTextUpdated(let text):
            if assignIfChanged("customMessage", current: &customMessage, newValue: text) {
                persistCurrentPreferences()
                scheduleExternalStateSync()
            }

        case .strobeUpdated(let state):
            assignIfChanged("strobeEnabled", current: &strobeEnabled, newValue: state.enabled)
            assignIfChanged("strobeCycleMs", current: &strobeCycleMs, newValue: state.cycleMs)
            strobeColor = Color(state.rgb)

        case .rssiUpdated(let rssi):
            if shouldPublishRSSI(rssi) {
                signalStrength = rssi
                IdleCPUDiagnostics.shared.recordPublishedChange("signalStrength")
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
        processPendingWidgetCommandIfNeeded()

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
        applyConfigurationState(configuration)
    }

    @MainActor
    private func applyLiveTemperature(_ celsius: Double) {
        currentTempC = celsius
        IdleCPUDiagnostics.shared.recordPublishedChange("currentTempC")
        let previousTemperature = temperature

        if lastPublishedTempC == nil || abs(celsius - (lastPublishedTempC ?? celsius)) >= liveTempChangeThresholdC {
            lastPublishedTempC = celsius
            temperature = temperatureString
            IdleCPUDiagnostics.shared.recordPublishedChange("temperature")
        }

        appendTemperatureSample(TemperatureData(timestamp: Date(), temperature: celsius))

        if temperature != previousTemperature {
            scheduleExternalStateSync()
        }
    }

    @MainActor
    private func apply(history: [TemperatureData]) {
        let cappedHistory = Array(history.suffix(maxTemperatureDataPoints))
        temperatureData = cappedHistory
        currentTempC = cappedHistory.last?.temperature
        lastPublishedTempC = currentTempC
        temperature = temperatureString
        IdleCPUDiagnostics.shared.recordPublishedChange("temperature")
        publishTemperatureDataSnapshot()
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

        publishTemperatureDataSnapshot()
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
        publishTemperatureDataSnapshot()
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
    private func handleAppDidBecomeActive() {
        isAppActive = true
        processPendingWidgetCommandIfNeeded()
        syncStateToWatch()
        guard isConnected else { return }
        startRSSIMonitoring()

        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS)
        Task { [weak self] in
            await self?.startLumiFur_WidgetLiveActivity()
        }
        #endif
    }

    @MainActor
    private func handleAppWillResignActive() {
        isAppActive = false
        stopRSSIMonitoring()
    }

    @MainActor
    private func publishTemperatureDataSnapshot() {
        IdleCPUDiagnostics.shared.recordPublishedChange("temperatureData")
        temperatureDataSubject.send(temperatureData)
    }

    @MainActor
    private func preferredRSSIMonitoringInterval() -> TimeInterval {
        guard isAppActive else { return idleRSSIInterval }

        guard defaults.bool(forKey: "rssiMonitoringEnabled") else {
            return idleRSSIInterval
        }

        let configured = defaults.double(forKey: "rssiUpdateInterval")
        return configured > 0 ? configured : defaultRSSIInterval
    }

    @MainActor
    private func shouldPublishRSSI(_ rssi: Int) -> Bool {
        if defaults.bool(forKey: "rssiMonitoringEnabled") {
            return signalStrength != rssi
        }

        return signalStrengthBucket(for: signalStrength) != signalStrengthBucket(for: rssi)
    }

    @MainActor
    private func signalStrengthBucket(for rssi: Int) -> Int {
        let normalized = Double(rssi + 100) / 30
        return min(max(Int(normalized * 4), 0), 4)
    }

    @MainActor
    private func applyLuxValueIfNeeded(_ value: UInt16) {
        guard luxBucket(for: luxValue) != luxBucket(for: value) else { return }
        luxValue = value
        IdleCPUDiagnostics.shared.recordPublishedChange("luxValue")
    }

    @MainActor
    private func luxBucket(for value: UInt16) -> Int {
        let minLux = 1.0
        let maxLux = 4097.0
        let clamped = min(max(Double(value), minLux), maxLux)
        let progress = (log10(clamped) - log10(minLux)) / (log10(maxLux) - log10(minLux))
        return Int((progress * 24).rounded(.down))
    }

    @discardableResult
    @MainActor
    private func assignIfChanged<Value: Equatable>(
        _ key: String,
        current: inout Value,
        newValue: Value
    ) -> Bool {
        guard current != newValue else { return false }
        current = newValue
        IdleCPUDiagnostics.shared.recordPublishedChange(key)
        return true
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

