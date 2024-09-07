import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var targetPeripheral: CBPeripheral?
    var targetCharacteristic: CBCharacteristic?
    @Published var cpuUsageData: [CPUUsageDataPoint] = []

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Optionally start scanning immediately
            // startScanning()
        } else {
            print("Bluetooth is not available.")
        }
    }

    func startScanning() {
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == "Teensy" { // Replace with your device's name
            targetPeripheral = peripheral
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                // Save the characteristic for later use
                targetCharacteristic = characteristic
            }
        }
    }

    func sendData(data: Data) {
        if let characteristic = targetCharacteristic {
            targetPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, let string = String(data: data, encoding: .utf8) {
            if string.starts(with: "CPU Usage:") {
                if let cpuUsage = Double(string.replacingOccurrences(of: "CPU Usage: ", with: "").replacingOccurrences(of: "%", with: "")) {
                    DispatchQueue.main.async {
                        let dataPoint = CPUUsageDataPoint(secondsAgo: self.cpuUsageData.count, cpuUsage: cpuUsage)
                        self.cpuUsageData.append(dataPoint)
                        if self.cpuUsageData.count > 20 {
                            self.cpuUsageData.removeFirst()
                        }
                    }
                }
            }
        }
    }
}
