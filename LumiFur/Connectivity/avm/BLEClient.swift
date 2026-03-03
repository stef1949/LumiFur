import Foundation
@preconcurrency import CoreBluetooth
import os

// MARK: - BLEClient

/// Queue-confined CoreBluetooth transport for the LumiFur accessory.
final class BLEClient: NSObject, @unchecked Sendable {
    enum Event: Sendable {
        case stateChanged(CBManagerState)
        case discovered(PeripheralDiscovery)
        case connected(PeripheralConnection)
        case failedToConnect(PeripheralFailure)
        case disconnected(PeripheralDisconnection)
        case storedPeripheralNotFound(String)
        case deviceInfoUpdated(DeviceInfo)
        case selectedViewUpdated(Int)
        case configurationUpdated(AccessoryConfiguration)
        case liveTemperatureUpdated(Double)
        case historyDownloadStarted
        case historyDownloaded([TemperatureData])
        case historyDownloadFailed(String)
        case brightnessUpdated(UInt8)
        case otaResponseUpdated(AccessoryOTAResponse)
        case luxUpdated(UInt16)
        case scrollTextUpdated(String)
        case strobeUpdated(StrobeState)
        case rssiUpdated(Int)
        case pairingRequired
        case transportError(String)
    }

    @MainActor
    var onEvent: (@MainActor @Sendable (Event) -> Void)?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LumiFur", category: "BLEClient")
    private let queue = DispatchQueue(label: "com.richies3d.lumifur.ble", qos: .userInitiated)
    private let previewMode: Bool

    private var centralManager: CBCentralManager?
    private var targetPeripheral: CBPeripheral?
    private var characteristics = CharacteristicRegistry()
    private var historyAssembler = TemperatureHistoryAssembler()
    private var lastLuxValue: UInt16 = 0
    private var writeContinuation: CheckedContinuation<Void, Error>?
    private var rssiTimer: DispatchSourceTimer?

    override init() {
        let environment = ProcessInfo.processInfo.environment
        self.previewMode =
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ||
            environment["XCTestConfigurationFilePath"] != nil

        super.init()

        guard !previewMode else { return }
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }

    deinit {
        stopRSSIMonitoring()
        resumePendingWrite(with: BLEClientError.deinitialized)
    }

    // MARK: Public API

    func startScan() {
        queue.async { [weak self] in
            guard let self, let centralManager = self.centralManager else { return }
            guard centralManager.state == .poweredOn else {
                self.emit(.stateChanged(centralManager.state))
                return
            }

            centralManager.scanForPeripherals(
                withServices: [BLEIdentifiers.service],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: false)]
            )
        }
    }

    func stopScan() {
        queue.async { [weak self] in
            guard let self, let centralManager = self.centralManager else { return }
            centralManager.stopScan()
        }
    }

    func connect(to peripheral: CBPeripheral) {
        queue.async { [weak self] in
            guard let self, let centralManager = self.centralManager else { return }
            guard centralManager.state == .poweredOn else {
                self.emit(.stateChanged(centralManager.state))
                return
            }

            centralManager.stopScan()
            self.targetPeripheral = peripheral
            self.targetPeripheral?.delegate = self
            centralManager.connect(peripheral, options: nil)
        }
    }

    func connectToStoredUUID(_ uuidString: String) {
        queue.async { [weak self] in
            guard let self, let centralManager = self.centralManager else { return }
            guard let uuid = UUID(uuidString: uuidString) else {
                self.emit(.storedPeripheralNotFound(uuidString))
                return
            }

            let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            guard let peripheral = peripherals.first else {
                self.emit(.storedPeripheralNotFound(uuidString))
                return
            }

            self.targetPeripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
        }
    }

    func disconnect() {
        queue.async { [weak self] in
            guard let self, let centralManager = self.centralManager, let targetPeripheral = self.targetPeripheral else { return }
            centralManager.cancelPeripheralConnection(targetPeripheral)
        }
    }

    func startRSSIMonitoring(interval: TimeInterval = 1.0) {
        queue.async { [weak self] in
            guard let self else { return }

            self.rssiTimer?.cancel()
            self.rssiTimer = nil

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + interval, repeating: interval)
            timer.setEventHandler { [weak self] in
                guard
                    let self,
                    let peripheral = self.targetPeripheral,
                    peripheral.state == .connected
                else {
                    return
                }

                peripheral.readRSSI()
            }
            self.rssiTimer = timer
            timer.resume()
        }
    }

    func stopRSSIMonitoring() {
        queue.async { [weak self] in
            guard let self else { return }
            self.rssiTimer?.cancel()
            self.rssiTimer = nil
        }
    }

    func writeView(_ view: Int) {
        write(AccessoryCommandEncoder.view(view), to: .view, type: .withResponse)
    }

    func writeConfiguration(_ configuration: AccessoryConfiguration) {
        write(AccessoryCommandEncoder.accessorySettingsPayload(configuration), to: .config, type: .withResponse)
    }

    func writeBrightness(_ value: UInt8) {
        write(Data([value]), to: .brightness, type: .withResponse)
    }

    func writeScrollText(_ text: String) {
        write(AccessoryCommandEncoder.scrollText(text), to: .scrollText, preferredWriteTypeForCharacteristic: true)
    }

    func writeScrollSpeed(_ speed: UInt8) {
        write(AccessoryCommandEncoder.scrollSpeed(speed), to: .scrollText, preferredWriteTypeForCharacteristic: true)
    }

    func writeStrobe(_ settings: StrobeSettingsPayload) {
        queue.async { [weak self] in
            guard let self, let peripheral = self.targetPeripheral, let characteristic = self.characteristics[.strobeSettings] else {
                return
            }

            let writeType = self.preferredWriteType(for: characteristic)
            peripheral.writeValue(settings.encodeColorPacketRGB(), for: characteristic, type: writeType)
            peripheral.writeValue(settings.encodeSpeedPacket(), for: characteristic, type: writeType)
        }
    }

    func writeOTAAbort() {
        write(AccessoryCommandEncoder.otaAbort(), to: .ota, type: .withResponse)
    }

    func writeCommandWithResponse(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: BLEClientError.deinitialized)
                    return
                }
                guard self.writeContinuation == nil else {
                    continuation.resume(throwing: BLEClientError.writeAlreadyInProgress)
                    return
                }
                guard let peripheral = self.targetPeripheral, let characteristic = self.characteristics[.command] else {
                    continuation.resume(throwing: BLEClientError.missingCharacteristic("command"))
                    return
                }

                self.writeContinuation = continuation
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            }
        }
    }

    // MARK: Private helpers

    private func emit(_ event: Event) {
        Task { @MainActor [weak self] in
            self?.onEvent?(event)
        }
    }

    private func write(
        _ data: Data,
        to kind: AccessoryCharacteristic,
        type: CBCharacteristicWriteType
    ) {
        queue.async { [weak self] in
            guard let self, let peripheral = self.targetPeripheral, let characteristic = self.characteristics[kind] else { return }
            peripheral.writeValue(data, for: characteristic, type: type)
        }
    }

    private func write(
        _ data: Data,
        to kind: AccessoryCharacteristic,
        preferredWriteTypeForCharacteristic: Bool
    ) {
        queue.async { [weak self] in
            guard let self, let peripheral = self.targetPeripheral, let characteristic = self.characteristics[kind] else { return }
            let writeType = self.preferredWriteType(for: characteristic)
            peripheral.writeValue(data, for: characteristic, type: writeType)
        }
    }

    private func preferredWriteType(for characteristic: CBCharacteristic) -> CBCharacteristicWriteType {
        let properties = characteristic.properties
        return properties.contains(.write) ? .withResponse : .withoutResponse
    }

    private func configure(_ characteristic: CBCharacteristic, on peripheral: CBPeripheral) {
        switch characteristic.uuid {
        case BLEIdentifiers.deviceInfo:
            characteristics[.deviceInfo] = characteristic
            peripheral.readValue(for: characteristic)

        case BLEIdentifiers.view:
            characteristics[.view] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            peripheral.readValue(for: characteristic)

        case BLEIdentifiers.config:
            characteristics[.config] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            peripheral.readValue(for: characteristic)

        case BLEIdentifiers.temperature:
            characteristics[.temperature] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)

        case BLEIdentifiers.command:
            characteristics[.command] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)

        case BLEIdentifiers.temperatureLogs:
            characteristics[.temperatureLogs] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)

        case BLEIdentifiers.brightness:
            characteristics[.brightness] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            peripheral.readValue(for: characteristic)

        case BLEIdentifiers.ota:
            characteristics[.ota] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)

        case BLEIdentifiers.lux:
            characteristics[.lux] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)

        case BLEIdentifiers.scrollText:
            characteristics[.scrollText] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            peripheral.readValue(for: characteristic)

        case BLEIdentifiers.strobeSettings:
            characteristics[.strobeSettings] = characteristic
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }

        default:
            break
        }
    }

    private func requestTemperatureHistoryIfPossible() {
        guard
            let peripheral = targetPeripheral,
            let commandCharacteristic = characteristics[.command]
        else {
            return
        }

        historyAssembler.reset()
        emit(.historyDownloadStarted)
        peripheral.writeValue(
            AccessoryCommandEncoder.requestHistoryCommand,
            for: commandCharacteristic,
            type: .withResponse
        )
    }

    private func resetConnectionState() {
        stopRSSIMonitoring()
        targetPeripheral = nil
        characteristics.reset()
        historyAssembler.reset()
        lastLuxValue = 0
    }

    private func handlePairingErrorIfNeeded(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == CBATTErrorDomain,
           let code = CBATTError.Code(rawValue: nsError.code),
           code == .insufficientAuthentication || code == .insufficientAuthorization || code == .insufficientEncryption {
            emit(.pairingRequired)
            return true
        }

        if nsError.domain == CBErrorDomain,
           let code = CBError.Code(rawValue: nsError.code),
           code == .peerRemovedPairingInformation {
            emit(.pairingRequired)
            return true
        }

        return false
    }

    private func resumePendingWrite(with error: Error? = nil) {
        guard let continuation = writeContinuation else { return }
        writeContinuation = nil

        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEClient: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        emit(.stateChanged(central.state))

        if central.state != .poweredOn {
            queue.async { [weak self] in
                self?.resetConnectionState()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? localName

        guard let name, !name.isEmpty else { return }

        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map(\.uuidString)
        let discovery = PeripheralDiscovery(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            advertisementServiceUUIDs: serviceUUIDs,
            peripheral: UncheckedSendableBox(peripheral)
        )
        emit(.discovered(discovery))
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        queue.async { [weak self] in
            guard let self else { return }
            self.targetPeripheral = peripheral
            self.characteristics.reset()
            self.historyAssembler.reset()
            peripheral.delegate = self
            self.emit(.connected(PeripheralConnection(peripheral: UncheckedSendableBox(peripheral), name: peripheral.name)))
            peripheral.discoverServices([BLEIdentifiers.service])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        queue.async { [weak self] in
            guard let self else { return }
            self.resetConnectionState()
            self.emit(
                .failedToConnect(
                    PeripheralFailure(
                        id: peripheral.identifier.uuidString,
                        name: peripheral.name,
                        message: error?.localizedDescription
                    )
                )
            )
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            self.resetConnectionState()
            self.resumePendingWrite(with: BLEClientError.disconnected)
            self.emit(
                .disconnected(
                    PeripheralDisconnection(
                        id: peripheral.identifier.uuidString,
                        name: peripheral.name,
                        message: error?.localizedDescription
                    )
                )
            )
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEClient: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        queue.async { [weak self] in
            guard let self else { return }

            if let error {
                if !self.handlePairingErrorIfNeeded(error) {
                    self.emit(.transportError("Service discovery failed: \(error.localizedDescription)"))
                }
                self.disconnect()
                return
            }

            guard
                let service = peripheral.services?.first(where: { $0.uuid == BLEIdentifiers.service })
            else {
                self.emit(.transportError("Required BLE service was not found."))
                self.disconnect()
                return
            }

            peripheral.discoverCharacteristics(BLEIdentifiers.discoverableCharacteristics, for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            if let error {
                if !self.handlePairingErrorIfNeeded(error) {
                    self.emit(.transportError("Characteristic discovery failed: \(error.localizedDescription)"))
                }
                self.disconnect()
                return
            }

            guard let characteristics = service.characteristics else {
                self.emit(.transportError("No characteristics were discovered for the accessory service."))
                self.disconnect()
                return
            }

            for characteristic in characteristics {
                self.configure(characteristic, on: peripheral)
            }

            guard self.characteristics.containsAllRequired else {
                self.emit(.transportError("Essential characteristics were missing."))
                self.disconnect()
                return
            }

            self.requestTemperatureHistoryIfPossible()
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            if let error {
                if !self.handlePairingErrorIfNeeded(error) {
                    self.emit(.transportError("Characteristic update failed: \(error.localizedDescription)"))
                }
                return
            }

            guard let data = characteristic.value else { return }

            switch characteristic.uuid {
            case BLEIdentifiers.deviceInfo:
                if let info = AccessoryNotificationParser.deviceInfo(from: data) {
                    self.emit(.deviceInfoUpdated(info))
                }

            case BLEIdentifiers.view:
                if let selectedView = AccessoryNotificationParser.selectedView(from: data) {
                    self.emit(.selectedViewUpdated(selectedView))
                }

            case BLEIdentifiers.config:
                if let configuration = AccessoryNotificationParser.configuration(from: data) {
                    self.emit(.configurationUpdated(configuration))
                }

            case BLEIdentifiers.temperature:
                guard !self.historyAssembler.isDownloading else { return }
                if let celsius = AccessoryNotificationParser.liveTemperatureCelsius(from: data) {
                    self.emit(.liveTemperatureUpdated(celsius))
                }

            case BLEIdentifiers.temperatureLogs:
                if let result = self.historyAssembler.process(data) {
                    switch result {
                    case .finished(let points):
                        self.emit(.historyDownloaded(points))
                    case .failed(let message):
                        self.emit(.historyDownloadFailed(message))
                    }
                }

            case BLEIdentifiers.brightness:
                if let value = AccessoryNotificationParser.brightness(from: data) {
                    self.emit(.brightnessUpdated(value))
                }

            case BLEIdentifiers.ota:
                if let response = AccessoryNotificationParser.otaResponse(from: data) {
                    self.emit(.otaResponseUpdated(response))
                }

            case BLEIdentifiers.lux:
                guard let lux = AccessoryNotificationParser.lux(from: data) else { return }
                guard abs(Int(lux) - Int(self.lastLuxValue)) >= 5 else { return }
                self.lastLuxValue = lux
                self.emit(.luxUpdated(lux))

            case BLEIdentifiers.scrollText:
                self.emit(.scrollTextUpdated(AccessoryNotificationParser.scrollText(from: data)))

            case BLEIdentifiers.strobeSettings:
                if let strobe = AccessoryNotificationParser.strobeState(from: data) {
                    self.emit(.strobeUpdated(strobe))
                }

            default:
                break
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        emit(.rssiUpdated(RSSI.intValue))
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        queue.async { [weak self] in
            guard let self else { return }

            if let error {
                if !self.handlePairingErrorIfNeeded(error) {
                    self.emit(.transportError("Failed to write to \(characteristic.uuid.uuidString): \(error.localizedDescription)"))
                }
                self.resumePendingWrite(with: error)
                return
            }

            if characteristic.uuid == BLEIdentifiers.command {
                self.resumePendingWrite()
            }
        }
    }
}

// MARK: - Transport internals

private enum AccessoryCharacteristic: Hashable {
    case view
    case config
    case temperature
    case command
    case temperatureLogs
    case brightness
    case deviceInfo
    case ota
    case lux
    case scrollText
    case strobeSettings
}

private struct CharacteristicRegistry {
    private var storage: [AccessoryCharacteristic: CBCharacteristic] = [:]

    subscript(_ kind: AccessoryCharacteristic) -> CBCharacteristic? {
        get { storage[kind] }
        set { storage[kind] = newValue }
    }

    mutating func reset() {
        storage.removeAll(keepingCapacity: true)
    }

    var containsAllRequired: Bool {
        let required: [AccessoryCharacteristic] = [
            .view,
            .config,
            .temperature,
            .command,
            .temperatureLogs,
            .brightness,
            .ota,
            .strobeSettings,
        ]

        return required.allSatisfy { storage[$0] != nil }
    }
}

private enum BLEIdentifiers {
    static let service = CBUUID(string: "01931c44-3867-7740-9867-c822cb7df308")
    static let view = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09fe")
    static let config = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09ff")
    static let temperature = CBUUID(string: "01931c44-3867-7b5d-9774-18350e3e27db")
    static let command = CBUUID(string: "0195eec3-06d2-7fd4-a561-49493be3ee41")
    static let temperatureLogs = CBUUID(string: "0195eec2-ae6e-74a1-bcd5-215e2365477c")
    static let brightness = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09ef")
    static let deviceInfo = CBUUID(string: "cba1d466-344c-4be3-ab3f-189f80dd7599")
    static let ota = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09ee")
    static let lux = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09f0")
    static let scrollText = CBUUID(string: "7f9b8b12-1234-4c55-9b77-a19d55aa0011")
    static let strobeSettings = CBUUID(string: "7f9b8b12-1234-4c55-9b77-a19d55aa0033")

    static let discoverableCharacteristics: [CBUUID] = [
        view,
        config,
        temperature,
        command,
        temperatureLogs,
        brightness,
        deviceInfo,
        ota,
        lux,
        scrollText,
        strobeSettings,
    ]
}

private enum BLEClientError: LocalizedError {
    case deinitialized
    case disconnected
    case writeAlreadyInProgress
    case missingCharacteristic(String)

    var errorDescription: String? {
        switch self {
        case .deinitialized:
            return "The BLE client was deinitialized."
        case .disconnected:
            return "The BLE peripheral disconnected before the write completed."
        case .writeAlreadyInProgress:
            return "A write with response is already in progress."
        case .missingCharacteristic(let name):
            return "The \(name) characteristic is not available."
        }
    }
}
