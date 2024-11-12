import Foundation
import CoreBluetooth
import Combine

// CPU Usage Data Structure
struct CPUUsageData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuUsage: Double
}

final class BluetoothManager: NSObject, ObservableObject {
    // Singleton instance
    static let shared = BluetoothManager()
    
    private var centralManager: CBCentralManager!
    @Published var targetPeripheral: CBPeripheral?
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var discoveredDevices: Set<CBPeripheral> = []
    @Published var cpuUsageData: [CPUUsageData] = []
    @Published var signalStrength: Int = -100  // Default to weak signal
    
    private var rssiUpdateTimer: Timer?
    private var targetCharacteristic: CBCharacteristic?
    weak var delegate: BluetoothManagerDelegate?
    
    // Define the service UUID
    private let serviceUUID = CBUUID(string: "01931c44-3867-7740-9867-c822cb7df308")
    private let characteristicUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09fe")
    private let temperatureCharacteristicUUID = CBUUID(string: "01931c44-3867-7b5d-9774-18350e3e27db")
    
    override private init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    deinit {
        if let peripheral = targetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func startMonitoringSignalStrength() {
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let peripheral = self.targetPeripheral,
                  self.isConnected else {
                return
            }
            print("Reading RSSI...")
            peripheral.readRSSI()
        }
    }
    
    func stopMonitoringSignalStrength() {
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = nil
    }
    
    func updateCPUUsage(_ usage: Double) {
        DispatchQueue.main.async {
            let newDataPoint = CPUUsageData(timestamp: Date(), cpuUsage: usage)
            self.cpuUsageData.append(newDataPoint)
            if self.cpuUsageData.count > 10 {
                self.cpuUsageData.removeFirst()
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on and ready.")
            startScanning()
        case .poweredOff:
            DispatchQueue.main.async {
                self.connectionStatus = "Bluetooth is powered off"
                self.isConnected = false
                self.discoveredDevices.removeAll()
            }
        case .unauthorized:
            DispatchQueue.main.async {
                self.connectionStatus = "Bluetooth permission denied"
            }
        default:
            DispatchQueue.main.async {
                self.connectionStatus = "Bluetooth unavailable"
            }
        }
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        
        print("Starting scan for devices...")
        DispatchQueue.main.async {
            self.connectionStatus = "Scanning..."
        }
        
        if !isConnected {
            DispatchQueue.main.async {
                self.discoveredDevices.removeAll()
            }
        }
        
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {
        DispatchQueue.main.async {
            self.discoveredDevices.insert(peripheral)
            if peripheral.identifier == self.targetPeripheral?.identifier {
                self.signalStrength = RSSI.intValue
                print("Discovered RSSI: \(RSSI.intValue) dBm") // Debug print
            }
        }
        delegate?.didDiscoverDevice(peripheral, rssi: RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "unknown")")
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected to \(peripheral.name ?? "Unknown Device")"
            self.targetPeripheral = peripheral
        }
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        delegate?.didConnectToDevice(peripheral)
        startMonitoringSignalStrength()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(peripheral.name ?? "unknown")")
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
            self.signalStrength = -100
        }
        
        stopMonitoringSignalStrength()
        delegate?.didDisconnectDevice(peripheral)
        
        if let error = error {
            print("Disconnection error: \(error.localizedDescription)")
            if targetPeripheral?.identifier == peripheral.identifier {
                central.connect(peripheral, options: nil)
            }
        }
    }
    
    func connect(_ peripheral: CBPeripheral) {
        print("Attempting to connect to: \(peripheral.name ?? "unknown")")
        stopScanning()
        targetPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            print("Error reading RSSI: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.main.async {
            self.signalStrength = RSSI.intValue
            print("Updated RSSI: \(RSSI.intValue) dBm") // Debug print
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        print("Discovering services...")
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                print("Found matching service: \(service.uuid)")
                peripheral.discoverCharacteristics(
                    [characteristicUUID, temperatureCharacteristicUUID],
                    for: service
                )
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        print("Discovered characteristics")
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("Found characteristic: \(characteristic.uuid)")
            if characteristic.uuid == characteristicUUID {
                targetCharacteristic = characteristic
            }
            
            if characteristic.properties.contains(.notify) {
                print("Enabling notifications for characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        guard error == nil else {
            print("Error receiving notification: \(error!.localizedDescription)")
            return
        }
        
        if characteristic.uuid == temperatureCharacteristicUUID,
           let data = characteristic.value,
           let temperatureString = String(data: data, encoding: .utf8) {
            print("Received temperature: \(temperatureString)")
        }
    }
    
    func sendData(data: Data) {
        guard let characteristic = targetCharacteristic,
              let peripheral = targetPeripheral,
              isConnected else {
            print("Cannot send data: no connection")
            return
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}

protocol BluetoothManagerDelegate: AnyObject {
    func didDiscoverDevice(_ peripheral: CBPeripheral, rssi: NSNumber)
    func didConnectToDevice(_ peripheral: CBPeripheral)
    func didDisconnectDevice(_ peripheral: CBPeripheral)
}
