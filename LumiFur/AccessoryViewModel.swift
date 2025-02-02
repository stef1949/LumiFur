import SwiftUI
import CoreBluetooth

struct CPUUsageElement: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuUsage: Int
}


class AccessoryViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // BLE State
    @Published var isConnected = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectionStatus = "Disconnected"
    @Published var temperature = "N/A"
    @Published var selectedView = 1
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var signalStrength = -100
    // BLE Manager
    @Published var connectingPeripheral: CBPeripheral?
    @Published var isConnecting = false
        
    // Stored CPU usage data for demonstration
    @Published var cpuUsageData: [CPUUsageElement] = [
        CPUUsageElement(timestamp: Date(), cpuUsage: 50)
    ]
    
    // Computed property to expose the connected peripheral
    var connectedPeripheral: CBPeripheral? {
        return isConnected ? peripheral : nil
    }
        
    // BLE Manager
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rssiUpdateTimer: Timer?
    
    // Service UUIDs
    private let serviceUUID = CBUUID(string: "01931c44-3867-7740-9867-c822cb7df308")
    private let viewCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09fe")
    // Config characteristic UUID not yet configured
    private let configCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09ff")
    private let tempCharUUID = CBUUID(string: "01931c44-3867-7b5d-9774-18350e3e27db")
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - BLE Management
    func connect() {
        discoveredDevices.removeAll()
        connectionStatus = "Scanning for devices..."
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    func connect(to peripheral: CBPeripheral) {
            connectingPeripheral = peripheral
            isConnecting = true
            connectionStatus = "Connecting..."
            centralManager.connect(peripheral, options: nil)
        }
    func disconnect() {
            if let peripheral = peripheral {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    
    func changeView(_ delta: Int) {
            let newView = max(1, min(12, selectedView + delta))
            if newView != selectedView {
                selectedView = newView
                writeViewToCharacteristic()
            }
        }
    func setView(_ view: Int) {
        guard view >= 1 && view <= 12, view != selectedView else { return }
        selectedView = view
        writeViewToCharacteristic()
    }
    
    func startRSSIMonitoring() {
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.peripheral?.readRSSI()
        }
    }
    
    // MARK: - CBCentralManagerDelegate Methods
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
            if central.state == .poweredOn {
                connectionStatus = "Bluetooth is On"
            } else {
                connectionStatus = "Bluetooth unavailable"
            }
        }
    
    func centralManager(_ central: CBCentralManager,
                            didDiscover peripheral: CBPeripheral,
                            advertisementData: [String : Any],
                            rssi RSSI: NSNumber) {
            // Add the discovered device if it is not already in the list.
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredDevices.append(peripheral)
            }
        }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            DispatchQueue.main.async {
                self.isConnected = true
                self.isConnecting = false
                self.connectingPeripheral = nil
                self.connectionStatus = "Connected"
                self.peripheral = peripheral
                peripheral.delegate = self
                peripheral.discoverServices([self.serviceUUID])
            }
        }
    func centralManager(_ central: CBCentralManager,
                            didFailToConnect peripheral: CBPeripheral,
                            error: Error?) {
            DispatchQueue.main.async {
                self.connectionStatus = "Failed to connect"
                self.isConnected = false
                self.isConnecting = false
                self.connectingPeripheral = nil
            }
        }
    func centralManager(_ central: CBCentralManager,
                            didDisconnectPeripheral peripheral: CBPeripheral,
                            error: Error?) {
            DispatchQueue.main.async {
                self.isConnected = false
                self.peripheral = nil
                self.connectionStatus = "Disconnected"
                self.isConnecting = false
                self.connectingPeripheral = nil
            }
        }
    
    // MARK: - CBPeripheralDelegate Methods
    func peripheral(_ peripheral: CBPeripheral,
                        didDiscoverServices error: Error?) {
            if let error = error {
                print("Error discovering services: \(error.localizedDescription)")
                showError(message: "Service discovery error: \(error.localizedDescription)")
                return
            }
            guard let services = peripheral.services else { return }
            for service in services where service.uuid == serviceUUID {
                    peripheral.discoverCharacteristics([viewCharUUID, tempCharUUID], for: service)
                }
            }
    
    func peripheral(_ peripheral: CBPeripheral,
                        didDiscoverCharacteristicsFor service: CBService,
                        error: Error?) {
            if let error = error {
                print("Error discovering characteristics: \(error.localizedDescription)")
                showError(message: "Characteristic discovery error: \(error.localizedDescription)")
                return
            }
            guard let characteristics = service.characteristics else { return }
            for characteristic in characteristics {
                if characteristic.uuid == viewCharUUID {
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic)
                } else if characteristic.uuid == tempCharUUID {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    
    func peripheral(_ peripheral: CBPeripheral,
                        didUpdateValueFor characteristic: CBCharacteristic,
                        error: Error?) {
            if let error = error {
                print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
                showError(message: "Update error: \(error.localizedDescription)")
                return
            }
            guard let data = characteristic.value else { return }
            if characteristic.uuid == viewCharUUID {
                let viewValue = data.first.map { Int($0) } ?? 1
                DispatchQueue.main.async {
                    self.selectedView = viewValue
                }
            } else if characteristic.uuid == tempCharUUID {
                let tempString = String(data: data, encoding: .utf8) ?? "N/A"
                DispatchQueue.main.async {
                    self.temperature = tempString
                }
            }
        }
    func peripheral(_ peripheral: CBPeripheral,
                        didReadRSSI RSSI: NSNumber,
                        error: Error?) {
            DispatchQueue.main.async {
                self.signalStrength = RSSI.intValue
            }
        }
// MARK: - Private Methods
        
        private func writeViewToCharacteristic() {
            guard let peripheral = peripheral,
                  let characteristic = getCharacteristic(uuid: viewCharUUID) else { return }
            let data = Data([UInt8(selectedView)])
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
        
        private func getCharacteristic(uuid: CBUUID) -> CBCharacteristic? {
            return peripheral?.services?.flatMap { $0.characteristics ?? [] }
                .first { $0.uuid == uuid }
        }
        
        private func showError(message: String) {
            DispatchQueue.main.async {
                self.errorMessage = message
                self.showError = true
            }
        }
    }
