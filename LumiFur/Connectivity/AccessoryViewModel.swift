//
//  AccessoryViewModel.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/12/25.
//

import SwiftUI

import UIKit
import CoreBluetooth
import Combine
import ActivityKit
import WidgetKit
import Foundation // Needed for Notification.Name

// MARK: - Shared Data Keys (Use these in both App and Widget)
struct SharedDataKeys {
    static let suiteName = "group.com.richies3d.lumifur" // <<< MUST MATCH YOUR APP GROUP ID
    static let isConnected = "widgetIsConnected"
    static let connectionStatus = "widgetConnectionStatus"
    static let controllerName = "widgetControllerName"
    static let temperature = "widgetTemperature"
    static let signalStrength = "widgetSignalStrength"
    static let selectedView = "widgetSelectedView"
    // Add keys for chart data if needed, e.g.,
    // static let temperatureChartData = "widgetTemperatureChartData"
    static let widgetKind = "group.com.richies3d.LumiFur"
}

// MARK: - Data Structures

/// Data structure for CPU usage data.
struct CPUUsageData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuUsage: Int
}

/// Data structure for temperature readings.
struct TemperatureData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let temperature: Double
}

/// A wrapper for a discovered peripheral. Conforms to Identifiable and Hashable for use in SwiftUI lists.
struct PeripheralDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    let advertisementServiceUUIDs: [String]?
    let peripheral: CBPeripheral

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PeripheralDevice, rhs: PeripheralDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

/// New structure to persist previously connected devices.
struct StoredPeripheral: Identifiable, Codable {
    let id: String
    let name: String
}

// MARK: - AccessoryViewModel

/// A unified BLE manager that scans, connects, and communicates with peripherals.
/// This class implements both CBCentralManagerDelegate and CBPeripheralDelegate,
/// and exposes published properties for SwiftUI.
class AccessoryViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: Published Properties
    
    @Published var isConnected: Bool = false { didSet { updateWidgetData() } }
    @Published var isScanning: Bool = true
    @Published var discoveredDevices: [PeripheralDevice] = []   // Using our custom wrapper.
    @Published var connectionStatus: String = "Disconnected" { didSet { updateWidgetData() } }
    @Published var temperature: String = ""  { didSet { updateWidgetData() } }
    @Published var temperatureData: [TemperatureData] = []
    @Published var selectedView: Int = 1 { didSet { updateWidgetData() } }
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var signalStrength: Int = -100 { didSet { updateWidgetData() } }
    @Published var connectingPeripheral: PeripheralDevice? = nil
    @Published var isConnecting: Bool = false
    @Published var cpuUsageData: [CPUUsageData] = [CPUUsageData(timestamp: Date(), cpuUsage: 50)]
    @Published var bootButtonState: Bool = false   // Optional additional state.
    
    // NEW: Test firmware versioning
    @Published var firmwareVersion: String = "1.2.0"
    // NEW: Published property for previously connected devices.
    @Published var previouslyConnectedDevices: [StoredPeripheral] = []
    
    private var widgetLiveActivity: Activity<LumiFur_WidgetAttributes>? = nil
    private var liveActivityTerminationWorkItem: DispatchWorkItem? = nil
    
    // MARK: Private Properties
    
    private var centralManager: CBCentralManager!
    @Published var targetPeripheral: CBPeripheral?
    private var targetCharacteristic: CBCharacteristic?
    private var temperatureCharacteristic: CBCharacteristic?
    private var rssiUpdateTimer: Timer?
    
    // New properties for automatic reconnectivity:
    private var autoReconnectPeripheral: CBPeripheral?
    private var isManualDisconnect: Bool = false
    private var didAttemptAutoReconnect: Bool = false  // Ensure we only try auto-reconnect once per launch.
    
    // Service and characteristic UUIDs.
    private let serviceUUID = CBUUID(string: "01931c44-3867-7740-9867-c822cb7df308")
    private let viewCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09fe")
    // Config characteristic UUID (not currently used).
    private let configCharUUID = CBUUID(string: "01931c44-3867-7427-96ab-8d7ac0ae09ff")
    private let tempCharUUID = CBUUID(string: "01931c44-3867-7b5d-9774-18350e3e27db")
    
    
    private var cancellables = Set<AnyCancellable>() // Add this to store subscriptions
    
    // MARK: Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        // Load any previously stored connected devices.
        self.previouslyConnectedDevices = loadStoredPeripherals()
        // Subscribe to targetPeripheral changes to update controller name for widget
                $targetPeripheral
                    .sink { [weak self] peripheral in
                        self?.updateWidgetData() // Update widget when peripheral changes (name might change)
                    }
                    .store(in: &cancellables)

                // Initial data write if needed, or rely on property changes
                updateWidgetData()
        NotificationCenter.default.addObserver(
                   self,
                   selector: #selector(handleChangeViewIntent(_:)),
                   name: .changeViewIntentTriggered,
                   object: nil
                   )
            }
    deinit {
             // --- Remove Observer ---
             NotificationCenter.default.removeObserver(self, name: .changeViewIntentTriggered, object: nil)
        }

    // --- Add Handler for Notification (if using Option B) ---
    @objc private func handleChangeViewIntent(_ notification: Notification) {
         if let userInfo = notification.userInfo, let nextView = userInfo["nextView"] as? Int {
             print("AccessoryViewModel: Received change view intent notification for view \(nextView)")
             // Call the existing method to change the view via BLE
             self.setView(nextView)
             // Note: setView likely already calls updateWidgetData which reloads the widget,
             // so the reload in the intent might be slightly redundant but ensures faster feedback.
         }
    }
    // MARK: - Public Methods
    
    /// Begins scanning for peripherals that advertise the specified service.
    func scanForDevices() {
        guard centralManager.state == .poweredOn else {
            print("Cannot scan: Bluetooth is not powered on")
            connectionStatus = "Bluetooth not powered on"
            return
        }
        // Clear the device list and update the status.
        discoveredDevices.removeAll()
        connectionStatus = "Scanning for devices..."
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    func stopScan() {
            // Only stop if the manager is initialized and powered on
            if centralManager != nil && centralManager.state == .poweredOn {
                 centralManager.stopScan()
                 print("Stopped scanning.") // Add log
            }
            // Update the scanning state regardless
            DispatchQueue.main.async { // Ensure UI updates on main thread
                 self.isScanning = false
                 // Optionally update connection status if needed when stopping scan manually
                  if !self.isConnected && self.connectionStatus == "Scanning for devices..." {
                      self.connectionStatus = "Disconnected"
                  }
            }
        }
    
    /// Connects to the specified device.
    func connect(to device: PeripheralDevice) {
        guard centralManager.state == .poweredOn else {
            print("Cannot connect: Bluetooth is not powered on")
            connectionStatus = "Bluetooth not powered on"
            return
        }
        
        // When connecting, we consider this a user-initiated connection.
        isManualDisconnect = false
        isScanning = false
        connectingPeripheral = device
        isConnecting = true
        connectionStatus = "Connecting..."
        centralManager.stopScan()  // Stop scanning once a connection attempt begins.
        targetPeripheral = device.peripheral
        targetPeripheral?.delegate = self
        centralManager.connect(device.peripheral, options: nil)
    }
    
    /// Disconnects from the currently connected peripheral.
    func disconnect() {
        // Mark as a manual disconnect so that auto-reconnection is skipped.
        isManualDisconnect = true
        if let peripheral = targetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        // Clear the stored peripheral and last device info.
        autoReconnectPeripheral = nil
        connectionStatus = "Disconnected"
        UserDefaults.standard.removeObject(forKey: "LastConnectedPeripheral")
    }
    
    /// Change the view (for example, for an LED matrix configuration) and update the BLE characteristic.
    func changeView(_ delta: Int) {
        let newView = max(1, min(12, selectedView + delta))
        if newView != selectedView {
            selectedView = newView
            writeViewToCharacteristic()
        }
    }
    
    /// Set a specific view and write the change to the characteristic.
    func setView(_ view: Int) {
        guard view >= 1 && view <= 12, view != selectedView else { return }
        print("AccessoryViewModel: Setting view to \(view)")
        selectedView = view
        writeViewToCharacteristic()
        // updateWidgetData() // Called automatically by didSet on selectedView
    }
    
    /// Begins periodic RSSI monitoring.
    func startRSSIMonitoring() {
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.targetPeripheral?.readRSSI()
        }
    }
    
    /// Stops periodic RSSI monitoring.
    func stopRSSIMonitoring() {
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = nil
    }
    
    
    private func updateWidgetData() {
           // IMPORTANT: Ensure you have an App Group set up and use the correct ID
           guard let defaults = UserDefaults(suiteName: SharedDataKeys.suiteName) else {
               print("Error: Could not access shared UserDefaults suite. Check App Group configuration.")
               return
           }

           let controllerName = targetPeripheral?.name // Get name from current peripheral

           print("AccessoryViewModel: Writing data to shared UserDefaults for widget.")
           defaults.set(isConnected, forKey: SharedDataKeys.isConnected)
           defaults.set(connectionStatus, forKey: SharedDataKeys.connectionStatus)
           defaults.set(controllerName, forKey: SharedDataKeys.controllerName) // Writes nil if peripheral is nil
           defaults.set(temperature, forKey: SharedDataKeys.temperature)
           defaults.set(signalStrength, forKey: SharedDataKeys.signalStrength)
           defaults.set(selectedView, forKey: SharedDataKeys.selectedView)

           // Optional: Write chart data (ensure it's in a UserDefaults compatible format)
           // let chartDataToWrite = temperatureData.suffix(10).map { $0.temperature }
           // defaults.set(chartDataToWrite, forKey: SharedDataKeys.temperatureChartData)
            let widgetKind = "group.com.richies3d.LumiFur"
           // Notify WidgetKit that the timeline needs to be reloaded
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind) // Use the 'kind' string from your widget
       }
    // MARK: - CBCentralManagerDelegate Methods
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .unknown:
                print("Central state: unknown")
            case .resetting:
                print("Central state: resetting")
            case .unsupported:
                print("Central state: unsupported")
            case .unauthorized:
                print("Central state: unauthorized")
            case .poweredOff:
                print("Central state: poweredOff")
                self.centralManager.stopScan()
                self.connectionStatus = "Bluetooth is off"
            case .poweredOn:
                print("Central state: poweredOn")
                // Optionally, you can start scanning automatically:
                 self.scanForDevices()
                if !self.didAttemptAutoReconnect {
                    self.didAttemptAutoReconnect = true
                    if let uuidString = UserDefaults.standard.string(forKey: "LastConnectedPeripheral"),
                       let uuid = UUID(uuidString: uuidString) {
                        let peripherals = self.centralManager.retrievePeripherals(withIdentifiers: [uuid])
                        if let peripheral = peripherals.first {
                            print("Auto-reconnecting to last device: \(peripheral.name ?? "Unknown")")
                            self.autoReconnectPeripheral = peripheral
                            // Create a temporary PeripheralDevice wrapper (RSSI & advertisement data unavailable)
                            let device = PeripheralDevice(
                                id: peripheral.identifier,
                                name: peripheral.name ?? "Unknown",
                                rssi: -100,
                                advertisementServiceUUIDs: nil,
                                peripheral: peripheral
                            )
                            self.connect(to: device)
                        }
                    }
                }
            @unknown default:
                fatalError("Unknown central manager state")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        // Only add devices that have a non-empty name.
        guard let name = peripheral.name, !name.isEmpty else { return }
        
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { $0.uuidString }
        let device = PeripheralDevice(id: peripheral.identifier,
                                      name: name,
                                      rssi: RSSI.intValue,
                                      advertisementServiceUUIDs: serviceUUIDs,
                                      peripheral: peripheral)
        if !discoveredDevices.contains(where: { $0.id == device.id }) {
            DispatchQueue.main.async {
                self.discoveredDevices.append(device)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.isScanning = false
            self.liveActivityTerminationWorkItem?.cancel()
            self.liveActivityTerminationWorkItem = nil
            self.isConnecting = false
            self.connectingPeripheral = nil
            self.connectionStatus = "Connected" /* to \(peripheral.name ?? "Unknown")*/
            self.targetPeripheral = peripheral
            // Save the peripheral so we can auto-reconnect if needed.
            self.autoReconnectPeripheral = peripheral
            // Persist the last connected device's UUID.
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "LastConnectedPeripheral")
            
            // Optionally, add the auto-connected device to the discoveredDevices list.
                    if !self.discoveredDevices.contains(where: { $0.id == peripheral.identifier }) {
                        let device = PeripheralDevice(
                            id: peripheral.identifier,
                            name: peripheral.name ?? "Unknown",
                            rssi: -100,
                            advertisementServiceUUIDs: nil,
                            peripheral: peripheral
                        )
                        self.discoveredDevices.append(device)
                    }
            // NEW: Save the connected device to the list of previously connected devices.
                        self.addToPreviouslyConnected(peripheral: peripheral)
            peripheral.delegate = self
            peripheral.discoverServices([self.serviceUUID])
            self.startRSSIMonitoring()
            
            self.startLumiFur_WidgetLiveActivity()
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
            self.targetPeripheral = nil
            self.connectionStatus = "Disconnected"
            self.isConnecting = false
            self.connectingPeripheral = nil
            self.stopRSSIMonitoring()
            
            // Update the live activity immediately upon disconnection
                   self.updateLumiFur_WidgetLiveActivity()
            
            self.liveActivityTerminationWorkItem = DispatchWorkItem {
                Task {
                    await self.widgetLiveActivity?.end(nil as ActivityContent<LumiFur_WidgetAttributes.ContentState>?, dismissalPolicy: .immediate)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (10 * 60), execute: self.liveActivityTerminationWorkItem!) //Stops Live Activity after 20 minutes of inactivity
            
            // If the disconnect was not manual, attempt automatic reconnection.
                        if !self.isManualDisconnect, let autoPeripheral = self.autoReconnectPeripheral {
                            self.connectionStatus = "Reconnecting..."
                            print("Attempting automatic reconnection to \(autoPeripheral.name ?? "Unknown")")
                            central.connect(autoPeripheral, options: nil)
                        } else {
                            // Otherwise, restart scanning.
                            self.scanForDevices()
                            self.isScanning = true
                        }
        }
    }
    
    // MARK: - CBPeripheralDelegate Methods
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            self.showError(message: "Service discovery error: \(error.localizedDescription)")
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
            self.showError(message: "Characteristic discovery error: \(error.localizedDescription)")
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
            print("Error updating value for \(characteristic.uuid): \(error.localizedDescription)")
            self.showError(message: "Update error: \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else { return }
        
        if characteristic.uuid == viewCharUUID {
            // Assume the first byte represents the view value.
            let viewValue = data.first.map { Int($0) } ?? 1
            DispatchQueue.main.async {
                self.selectedView = viewValue
            }
        } else if characteristic.uuid == tempCharUUID {
            // Decode the string (e.g., "47.7°C") sent by your C++ code
            if let tempString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    // Store the raw string for display
                    self.temperature = tempString
                    
                    // Remove the "°C" suffix (and any extra whitespace) so we can convert to a number
                    let cleanedString = tempString.replacingOccurrences(of: "°C", with: "").trimmingCharacters(in: .whitespaces)
                    if let tempValue = Double(cleanedString) {
                        // Append a new data point for your chart
                        self.temperatureData.append(TemperatureData(timestamp: Date(), temperature: tempValue))
                    }
                    // Optionally update your Live Activity if needed
                    self.updateLumiFur_WidgetLiveActivity()
                }
            } else {
                DispatchQueue.main.async {
                    self.temperature = "N/A"
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didReadRSSI RSSI: NSNumber,
                    error: Error?) {
        DispatchQueue.main.async {
            self.signalStrength = RSSI.intValue
            self.updateLumiFur_WidgetLiveActivity()  // Update the live activity with the new signal strength.
        }
    }
    
    // MARK: - Private Methods
    
    /// Writes the currently selected view to the appropriate characteristic.
    private func writeViewToCharacteristic() {
        guard let peripheral = self.targetPeripheral,
              let characteristic = getCharacteristic(uuid: viewCharUUID) else { return }
        let data = Data([UInt8(selectedView)])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    /// Helper method that searches through discovered services and characteristics.
    private func getCharacteristic(uuid: CBUUID) -> CBCharacteristic? {
        return targetPeripheral?.services?.flatMap { $0.characteristics ?? [] }
            .first { $0.uuid == uuid }
    }
    
    /// Updates error state so that SwiftUI can present an alert.
    private func showError(message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
    
    // NEW: Adds a connected peripheral to persistent storage if not already present.
    private func addToPreviouslyConnected(peripheral: CBPeripheral) {
        let newDevice = StoredPeripheral(id: peripheral.identifier.uuidString, name: peripheral.name ?? "Unknown")
        var storedDevices = loadStoredPeripherals()
        if !storedDevices.contains(where: { $0.id == newDevice.id }) {
            storedDevices.append(newDevice)
            saveStoredPeripherals(storedDevices)
            DispatchQueue.main.async {
                self.previouslyConnectedDevices = storedDevices
            }
        }
    }
    // NEW: Loads previously connected devices from UserDefaults.
        private func loadStoredPeripherals() -> [StoredPeripheral] {
            if let data = UserDefaults.standard.data(forKey: "PreviouslyConnectedPeripherals") {
                let decoder = JSONDecoder()
                if let stored = try? decoder.decode([StoredPeripheral].self, from: data) {
                    return stored
                }
            }
            return []
        }
    
    // NEW: Saves the provided list of devices to UserDefaults.
        private func saveStoredPeripherals(_ devices: [StoredPeripheral]) {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(devices) {
                UserDefaults.standard.set(data, forKey: "PreviouslyConnectedPeripherals")
            }
        }
    
    func connectToStoredPeripheral(_ stored: StoredPeripheral) {
            if let uuid = UUID(uuidString: stored.id) {
                let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
                if let peripheral = peripherals.first {
                    let device = PeripheralDevice(
                        id: peripheral.identifier,
                        name: peripheral.name ?? stored.name,
                        rssi: -100,
                        advertisementServiceUUIDs: nil,
                        peripheral: peripheral
                    )
                    connect(to: device)
                } else {
                    print("Peripheral with UUID \(stored.id) not found")
                }
            }
        }
}

extension AccessoryViewModel {
   
    var connectionColor: Color {
            switch connectionStatus {
            case "Connected":
                return .green
            case "Connecting...":
                return .yellow
            case "Disconnected":
                return .red
            default:
                return .gray
            }
        }
    
    /// Returns true if Bluetooth is powered on.
    var isBluetoothReady: Bool {
        return centralManager.state == .poweredOn
    }
    
    /// Returns the connected device wrapper if connected.
    var connectedDevice: PeripheralDevice? {
        guard isConnected, let target = targetPeripheral else { return nil }
        return discoveredDevices.first { $0.id == target.identifier }
    }
    
    func startLumiFur_WidgetLiveActivity() {
        let recentTemperatures = temperatureData.suffix(10).map { $0.temperature }
        // Use the connected device name if available; otherwise, a placeholder.
        let deviceName = connectedDevice?.name ?? "Unknown Device"
        let attributes = LumiFur_WidgetAttributes(name: deviceName)
        let initialState = LumiFur_WidgetAttributes.ContentState(
            connectionStatus: connectionStatus,
            signalStrength: signalStrength,
            temperature: temperature,
            selectedView: selectedView,
            isConnected: isConnected,
            isScanning:isScanning,
            temperatureChartData: Array(recentTemperatures)
        )
        // Wrap the initial state in ActivityContent.
        let initialContent = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            widgetLiveActivity = try Activity<LumiFur_WidgetAttributes>.request(
                attributes: attributes,
                content: initialContent,
                pushType: nil
            )
            if let id = widgetLiveActivity?.id {
                print("Started Live Activity: \(id)")
            }
        } catch {
            print("Error starting live activity: \(error): \(error.localizedDescription)")
        }
    }
    
    /// Updates all active BLE Live Activities with the latest state.
    func updateLumiFur_WidgetLiveActivity() {
        // Only update live activity when the app is in the background
            guard UIApplication.shared.applicationState == .background else {
                print("App is in the foreground, skipping live activity update")
                return
            }
        let recentTemperatures = temperatureData.suffix(50).map { $0.temperature }
        
        let updatedState = LumiFur_WidgetAttributes.ContentState(
            connectionStatus: connectionStatus,
            signalStrength: signalStrength,
            temperature: temperature,
            selectedView: selectedView,
            isConnected: isConnected,
            isScanning: isScanning,
            temperatureChartData: Array(recentTemperatures)
        )
        // Wrap the updated state in ActivityContent.
        let updatedContent = ActivityContent(state: updatedState, staleDate: nil)
        
        for activity in Activity<LumiFur_WidgetAttributes>.activities {
            Task {
                do {
                     await activity.update(updatedContent)
                }
            }
        }
    }}
