import SwiftUI
import CoreBluetooth

class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectionStatus = "Disconnected"
    
    private var centralManager: CBCentralManager!
    var espPeripheral: CBPeripheral?
    
    // Define the service UUID
    private let serviceUUID = CBUUID(string: "01931c44-3867-7740-9867-c822cb7df308")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - CBCentralManagerDelegate Methods
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            connectionStatus = "Scanning for devices..."
            // Scan only for devices with our specific service UUID
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        } else {
            connectionStatus = "Bluetooth unavailable"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Only add the device if it's not already in the list
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            DispatchQueue.main.async {
                self.discoveredDevices.append(peripheral)
            }
        }
    }
    
    func connectToDevice(_ peripheral: CBPeripheral) {
        espPeripheral = peripheral
        espPeripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
        connectionStatus = "Connecting..."
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.connectionStatus = "Connected to \(peripheral.name ?? "ESP32")"
            self.isConnected = true
            // Start discovering services after connection
            peripheral.discoverServices([self.serviceUUID])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionStatus = "Failed to connect"
            self.isConnected = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionStatus = "Disconnected"
            self.isConnected = false
            // Restart scanning after disconnection
            self.centralManager.scanForPeripherals(withServices: [self.serviceUUID], options: nil)
        }
    }
    
    // MARK: - CBPeripheralDelegate Methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            // Only discover characteristics for our specific service
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
}
