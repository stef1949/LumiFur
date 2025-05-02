//
//  AccessoryViewModel.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/12/25.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//

import SwiftUI
import Combine
import CoreBluetooth
import WidgetKit
import Foundation // Needed for Notification.Name

// Conditional imports:
#if !targetEnvironment(macCatalyst) // Code to exclude from Mac.
import UIKit
import ActivityKit
import AccessorySetupKit
#endif
// MARK: - Shared Data Keys (Use these in both App and Widget)

// MARK: - Data Structures

/// Data structure for CPU usage data.
struct CPUUsageData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuUsage: Int
}

/// Data structure for temperature readings.
struct TemperatureData: Identifiable, Codable, Equatable {
    var id = UUID()
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
    static let shared = AccessoryViewModel()
    
    // MARK: Published Properties
    @Published var isConnected: Bool = false { didSet { updateWidgetData() } }
    @Published var isScanning: Bool = true
    @Published var discoveredDevices: [PeripheralDevice] = []   // Using our custom wrapper.
    @Published var connectionStatus: String = "Disconnected" { didSet {
        updateWidgetData()
        // Only bump the Live Activity if:
                    //  • we already have one running, and
                    //  • the app is in the background (so ActivityKit will accept it)
                    if widgetLiveActivity != nil,
                       UIApplication.shared.applicationState == .background
                    {
                        updateLumiFur_WidgetLiveActivity()
                    }
    } }
    /// Your single source of truth for connection status
        @Published var connectionState: ConnectionState = .disconnected
        /// UI mappings driven from the enum
        var connectionColor: Color      { connectionState.color }
        var connectionImageName: String { connectionState.imageName }
    
    
    @Published var temperature: String = ""  { didSet { updateWidgetData() } }
    @Published var temperatureData: [TemperatureData] = []
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var signalStrength: Int = -100 { didSet { updateWidgetData() } }
    @Published var connectingPeripheral: PeripheralDevice? = nil
    @Published var isConnecting: Bool = false
    @Published var cpuUsageData: [CPUUsageData] = [CPUUsageData(timestamp: Date(), cpuUsage: 50)]
    @Published var bootButtonState: Bool = false   // Optional additional state.
    
    //MARK: User options
    @Published var selectedView: Int = 1 { didSet { updateWidgetData() } }
    @Published var autoBrightness: Bool = true { didSet { updateWidgetData() } }
    @Published var accelerometerEnabled: Bool = true { didSet { updateWidgetData() } }
    @Published var sleepModeEnabled: Bool = true { didSet { updateWidgetData() } }
    @Published var auroraModeEnabled: Bool = true { didSet { updateWidgetData() } }
    @Published var customMessage: String = ""
    
    // NEW: Test firmware versioning
    @Published var firmwareVersion: String = "1.2.0"
    // NEW: Published property for previously connected devices.
    @Published var previouslyConnectedDevices: [StoredPeripheral] = []
    
    private var widgetLiveActivity: Activity<LumiFur_WidgetAttributes>? = nil
    private var liveActivityTerminationWorkItem: DispatchWorkItem? = nil
    
    func updateFromWatch(_ message: [String: Any]) {
        if let auto = message["autoBrightness"] as? Bool {
            self.autoBrightness = auto
        }
        if let accel = message["accelerometer"] as? Bool {
            self.accelerometerEnabled = accel
        }
        if let sleep = message["sleepMode"] as? Bool {
            self.sleepModeEnabled = sleep
        }
        if let aurora = message["auroraMode"] as? Bool {
            self.auroraModeEnabled = aurora
        }
        if let msg = message["customMessage"] as? String {
            self.customMessage = msg
        }
    }
    
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
    // Constants for History Download
    private let commandCharUUID = CBUUID(string: "0195eec3-06d2-7fd4-a561-49493be3ee41")
    private let temperatureLogsCharUUID = CBUUID(string: "0195eec2-ae6e-74a1-bcd5-215e2365477c") // History characteristic
    private let requestHistoryCommand: UInt8 = 0x01 // Command byte to request history
    private let historyPacketType: UInt8 = 0x01 // Expected type byte in history packets
    
    private var cancellables = Set<AnyCancellable>() // Add this to store subscriptions
    
    // MARK: - State for History Download
    @Published var isDownloadingHistory: Bool = false // For UI feedback if needed
    private var receivedHistoryChunks: [Int: Data] = [:] // [ChunkIndex: FloatDataBytes]
    private var totalHistoryChunksExpected: Int? = nil
    // No need for a separate reassembled array, process directly into temperatureData
    
    // Define maximum size for the main temperatureData array
    private let maxTemperatureDataPoints = 200 // Keep last 200 points (live + history)
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
        WidgetCenter.shared.reloadAllTimelines()
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
        guard view >= 1 && view <= 20, view != selectedView else { return }
        print("AccessoryViewModel: Setting view to \(view)")
        selectedView = view
        writeViewToCharacteristic()
        updateWidgetData() // Called automatically by didSet on selectedView
    }
    
    /// Begins periodic RSSI monitoring.
    func startRSSIMonitoring() {
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.targetPeripheral?.readRSSI()
        }
    }
    /// Stops periodic RSSI monitoring.
    func stopRSSIMonitoring() {
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = nil
    }
    
    /// Set a specific view and write the change to the characteristic.
    func setautoBrightness(_ autoBrightnessValue: Bool) {
        print("AccessoryViewModel: Setting Auto Brightness to \(autoBrightnessValue)")
        autoBrightness = autoBrightnessValue
        writeViewToCharacteristic()
        updateWidgetData() // Called automatically by didSet on selectedView
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

        defaults.set(accelerometerEnabled, forKey: SharedDataKeys.accelerometerEnabled)
        defaults.set(auroraModeEnabled, forKey: SharedDataKeys.auroraModeEnabled)

        
        saveTemperatureHistoryToUserDefaults(defaults: defaults)
        
        // Optional: Write chart data (ensure it's in a UserDefaults compatible format)
        let chartDataToWrite = temperatureData.suffix(10).map { $0.temperature }
        defaults.set(chartDataToWrite, forKey: SharedDataKeys.temperatureHistory)

        WidgetCenter.shared.reloadTimelines(ofKind: SharedDataKeys.widgetKind)
    }
    
    // Helper function to reload widgets
    private func reloadWidgetTimelines() {
        // Use the ACTUAL kind string defined in your LumiFur_Widget struct
        // Example: If your widget defines `static let kind: String = "com.richies3d.lumifur.statuswidget"`
        let widgetKind = "com.richies3d.lumifur.statuswidget" // <<< REPLACE with your widget's actual kind string
        
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        print("AccessoryViewModel: Requested widget timeline reload for kind: \(widgetKind)")
    }
    
    // Helper function to save history
    private func saveTemperatureHistoryToUserDefaults(defaults: UserDefaults) {
        // Ensure temperatureData is updated correctly before this is called
        // Encode the history using JSONEncoder
        let historyToSave = Array(temperatureData.suffix(50)) // Keep last 50 points, adjust as needed
        do {
            let encodedData = try JSONEncoder().encode(historyToSave)
            defaults.set(encodedData, forKey: SharedDataKeys.temperatureHistory)
            print("AccessoryViewModel: Saved \(historyToSave.count) temperature points to UserDefaults.")
        } catch {
            print("AccessoryViewModel: Failed to encode temperature history for widget: \(error)")
        }
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
                self.updateWidgetData()
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
            self.connectionState = .connected
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
            self.targetPeripheral?.readRSSI()
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
            self.connectionState = .unknown
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
            self.connectionState = .disconnected
            self.isConnecting = false
            self.connectingPeripheral = nil
            self.stopRSSIMonitoring()
            
            // Update the live activity immediately upon disconnection
            self.updateLumiFur_WidgetLiveActivity()
            
            self.liveActivityTerminationWorkItem?.cancel()
            self.liveActivityTerminationWorkItem = nil
            
            // Create a new termination work item to end live activity after 10 minutes of inactivity.
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
            self.connectionState = .connecting
            return
        }
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([viewCharUUID, configCharUUID, tempCharUUID, commandCharUUID, temperatureLogsCharUUID], for: service)
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
        
        
        var foundCommandCharacteristic: CBCharacteristic? = nil
        var foundTempLogsCharacteristic: CBCharacteristic? = nil
        
        print(">>> Discovering characteristics for service: \(service.uuid)")
        for characteristic in characteristics {
            print("  > Found characteristics: \(characteristic.uuid)")
            if characteristic.uuid == viewCharUUID {
                print("    - Matches View Characteristic")
                targetCharacteristic = characteristic // Assuming targetCharacteristic is viewChar
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic) // Read initial value
            } else if characteristic.uuid == configCharUUID {
                    print("    - Matches View Characteristic")
                    targetCharacteristic = characteristic // Assuming targetCharacteristic is configChar
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic) // Read initial value
            } else if characteristic.uuid == tempCharUUID {
                print("    - Matches Live Temperature Characteristic")
                temperatureCharacteristic = characteristic // Store reference if needed elsewhere
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == self.commandCharUUID {
                print("    - Matches Command Characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
                foundCommandCharacteristic = characteristic  // Assign the discovered characteristic
            } else if characteristic.uuid == temperatureLogsCharUUID {
                print("    - Matches Temperature Logs Characteristic")
                peripheral.setNotifyValue(true, for: characteristic) // Enable notifications for history chunks
                foundTempLogsCharacteristic = characteristic  // (Optional, if needed later)
            }
        }
        
        // --- Trigger History Request AFTER finding necessary characteristics ---
        // Ensure we found the command char to write to AND the logs char to receive on
        if let commandCharToWrite = foundCommandCharacteristic, foundTempLogsCharacteristic != nil {
            print(">>> Found required characteristics. Requesting history...")
            resetHistoryDownloadState()
            requestTemperatureHistory(peripheral: peripheral, characteristic: commandCharToWrite)
        } else {
            print("!!! Did not find all required characteristics for history download.")
            if foundCommandCharacteristic == nil { print("    - Command Characteristic (\(self.commandCharUUID.uuidString)) NOT found.") }
            if foundTempLogsCharacteristic == nil { print("    - Temperature Logs Characteristic (\(self.temperatureLogsCharUUID.uuidString)) NOT found.") }
        }
    } // End of function
    // Helper to reset state
    private func resetHistoryDownloadState() {
        DispatchQueue.main.async { // Ensure state updates on main thread
            self.isDownloadingHistory = false
            self.receivedHistoryChunks.removeAll()
            self.totalHistoryChunksExpected = nil
        }
    }
    
    // Function to send the request command
    private func requestTemperatureHistory(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let commandData = Data([requestHistoryCommand])
        print(">>> Requesting temperature history by writing \(commandData as NSData) to \(characteristic.uuid)...")
        // Use .withoutResponse if your ESP32 characteristic is WRITE_NR
        // Use .withResponse if it's WRITE
        peripheral.writeValue(commandData, for: characteristic, type: .withResponse)
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        print(">>> peripheral:didUpdateValueFor called for characteristic: \(characteristic.uuid)")
        if let error = error {
            print("!!! Error updating value for \(characteristic.uuid): \(error.localizedDescription)")
            self.showError(message: "Update error: \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else {
            print("!!! Data received for \(characteristic.uuid) is nil.")
            return
        }
        print(">>> Raw data received for \(characteristic.uuid): \(data as NSData) (Count: \(data.count))")
        
        // --- Route based on Characteristic UUID ---
        
        switch characteristic.uuid {
            
        case viewCharUUID:
            // --- Handle View Updates ---
            handleViewUpdate(data: data)
            
        case tempCharUUID:
            // --- Handle LIVE Temperature Updates (ONLY if not downloading history) ---
            if !isDownloadingHistory {
                handleLiveTemperatureUpdate(data: data)
            } else {
                print("--- Ignoring live temperature update on \(characteristic.uuid) while downloading history.")
            }
            
        case temperatureLogsCharUUID:
            // --- Handle Incoming History Chunks ---
            handleHistoryChunk(data: data)
            
        default:
            print(">>> Received data for an unexpected characteristic: \(characteristic.uuid)")
        }
    }
    
    // --- Helper Functions for Data Handling ---
    
    private func handleViewUpdate(data: Data) {
        let viewValue = data.first.map { Int($0) } ?? 1
        DispatchQueue.main.async {
            if self.selectedView != viewValue {
                print(">>> Updating selectedView from \(self.selectedView) to \(viewValue)")
                self.selectedView = viewValue // Keep didSet here to update widget etc.
            }
        }
    }
    
    private func handleLiveTemperatureUpdate(data: Data) {
        print(">>> Handling LIVE temperature update.")
        // Attempt to decode the string
        let tempString = String(data: data, encoding: .utf8)
        print(">>> Attempted UTF-8 decoding. Resulting string: \(tempString ?? "Decoding Failed (nil)")")
        
        if let validTempString = tempString {
            DispatchQueue.main.async {
                print(">>> Successfully decoded live temp string: '\(validTempString)'")
                // Update the display string immediately
                self.temperature = validTempString
                
                // Parse the double value
                let cleanedString = validTempString.replacingOccurrences(of: "°C", with: "").trimmingCharacters(in: .whitespaces)
                print(">>> Live Temp String cleaned for Double parsing: '\(cleanedString)'")
                
                if let tempValue = Double(cleanedString) {
                    print(">>> Successfully parsed live temp Double: \(tempValue)")
                    // Create the data point
                    let newDataPoint = TemperatureData(timestamp: Date(), temperature: tempValue)
                    
                    // Append to main array and limit size
                    self.temperatureData.append(newDataPoint)
                    if self.temperatureData.count > self.maxTemperatureDataPoints {
                        self.temperatureData.removeFirst(self.temperatureData.count - self.maxTemperatureDataPoints)
                    }
                    print(">>> Appended LIVE Temperature Data. Total points: \(self.temperatureData.count)")
                    
                } else {
                    print("!!! FAILED to parse live temp '\(cleanedString)' as Double.")
                }
                
                // Update widget AFTER processing live data point
                self.updateWidgetData()
                // Update live activity (only runs if in background)
                self.updateLumiFur_WidgetLiveActivity()
            }
        } else {
            print("!!! FAILED to decode received LIVE Data into a UTF-8 String for temperature.")
        }
    }
    
    
    private func handleHistoryChunk(data: Data) {
        print(">>> Handling HISTORY temperature chunk.")
        guard data.count >= 3 else { // Need at least Type, Index, Total bytes
            print("!!! History chunk too small (\(data.count) bytes). Ignoring.")
            return
        }
        
        let packetType = data[0]
        let chunkIndex = Int(data[1])
        let totalChunks = Int(data[2])
        let payload = data.subdata(in: 3..<data.count) // Data after the header
        
        print(">>> History Chunk Info: Type=\(packetType), Index=\(chunkIndex), Total=\(totalChunks), PayloadSize=\(payload.count)")
        
        guard packetType == historyPacketType else {
            print("!!! Received packet on history characteristic with unexpected type: \(packetType). Ignoring.")
            return
        }
        
        DispatchQueue.main.async { // Update state on main thread
            // If first chunk, initialize download state
            if !self.isDownloadingHistory { // Use this instead of index == 0 for robustness
                print(">>> First history chunk received. Starting download.")
                self.isDownloadingHistory = true
                self.receivedHistoryChunks.removeAll() // Clear previous attempts
                self.totalHistoryChunksExpected = totalChunks
            }
            
            // Store the chunk payload (only the float data)
            self.receivedHistoryChunks[chunkIndex] = payload
            print(">>> Stored history chunk \(chunkIndex + 1) of \(self.totalHistoryChunksExpected ?? 0).")
            
            
            // Check if download is complete
            if let totalExpected = self.totalHistoryChunksExpected, self.receivedHistoryChunks.count == totalExpected {
                print(">>> All history chunks received (\(totalExpected)). Processing...")
                self.processCompletedHistoryDownload()
            }
        }
    }
    
    
    private func processCompletedHistoryDownload() {
        print(">>> Processing completed history download.")
        guard let totalChunks = totalHistoryChunksExpected, totalChunks > 0 else {
            print("!!! Error: Cannot process history, total chunks expected is invalid.")
            resetHistoryDownloadState()
            return
        }
        
        var decodedHistoryPoints: [TemperatureData] = []
        var errorOccurred = false
        
        for i in 0..<totalChunks {
            guard let chunkData = receivedHistoryChunks[i] else {
                print("!!! Error: Missing history chunk data for index \(i). Aborting processing.")
                errorOccurred = true
                break // Stop processing if a chunk is missing
            }
            
            // Process floats within the chunk
            let floatSize = MemoryLayout<Float>.stride // Size of a Float (usually 4 bytes)
            let floatCount = chunkData.count / floatSize
            
            print("  > Processing chunk \(i): \(chunkData.count) bytes, expected \(floatCount) floats.")
            
            for j in 0..<floatCount {
                let byteOffset = j * floatSize
                guard byteOffset + floatSize <= chunkData.count else {
                    print("!!! Error: Invalid byte offset while processing floats in chunk \(i).")
                    errorOccurred = true
                    break
                }
                let floatBytes = chunkData.subdata(in: byteOffset..<byteOffset + floatSize)
                
                // Convert bytes to Float, assuming little-endian (common for ESP32/iOS)
                // Use withUnsafeBytes for safe conversion
                let tempValue = floatBytes.withUnsafeBytes { $0.load(as: Float.self) }
                
                // TODO: Timestamp Estimation - This is inaccurate!
                // Ideally, ESP32 sends timestamps or app logs receive time per chunk.
                // For now, using Date() makes them all current time.
                // A better estimation might involve calculating backwards from now based on interval.
                let estimatedTimestamp = Date() // Placeholder - very inaccurate for history
                
                decodedHistoryPoints.append(TemperatureData(timestamp: estimatedTimestamp, temperature: Double(tempValue)))
                print("    - Decoded Float \(j): \(tempValue)")
            }
            if errorOccurred { break } // Exit outer loop if inner loop had error
        }
        
        if !errorOccurred {
            print(">>> Successfully decoded \(decodedHistoryPoints.count) historical data points.")
            
            // --- Merge Data ---
            // Prepend historical data to the main array
            var combinedData = decodedHistoryPoints + self.temperatureData // History first
            
            // Optional: Add duplicate checking if needed based on value/timestamp estimation
            
            // Limit total size
            if combinedData.count > self.maxTemperatureDataPoints {
                combinedData.removeFirst(combinedData.count - self.maxTemperatureDataPoints)
            }
            
            // Update the main published property
            self.temperatureData = combinedData
            print(">>> Merged history. Final temperatureData count: \(self.temperatureData.count)")
            
            // Trigger widget update with the full history + any subsequent live data
            self.updateWidgetData()
            // Update Live Activity (if active)
            self.updateLumiFur_WidgetLiveActivity()
            
        } else {
            print("!!! History download processing failed due to errors.")
        }
        
        // --- Clean up state regardless of success/failure ---
        resetHistoryDownloadState()
        print(">>> History download state reset.")
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didReadRSSI RSSI: NSNumber,
                    error: Error?) {
        DispatchQueue.main.async {
            self.signalStrength = RSSI.intValue
            self.updateLumiFur_WidgetLiveActivity()  // Update the live activity with the new signal strength.
        }
    }
    
    /// Encodes accessory settings into a single Data payload.
    /// Each setting is represented by a single byte (1 = true, 0 = false).
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
    
    // MARK: - Private Methods
    
    /// Writes the currently selected view to the appropriate characteristic.
    private func writeViewToCharacteristic() {
        guard let peripheral = self.targetPeripheral,
              let characteristic = getCharacteristic(uuid: viewCharUUID) else { return }
        let data = Data([UInt8(selectedView)])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    /// Writes the currently selected view to the appropriate characteristic.
     func writeConfigToCharacteristic() {
         // Log that the write method was called.
             print("Attempting to write config to characteristic...")
             // Check if the target peripheral exists.
             guard let peripheral = self.targetPeripheral else {
                 print("Error: targetPeripheral is nil.")
                 return
             }
             // Check if the characteristic exists.
             guard let characteristic = getCharacteristic(uuid: configCharUUID) else {
                 print("Error: Config characteristic with UUID \(configCharUUID) not found.")
                 return
             }
        
        let payload = encodedAccessorySettingsPayload(
            autoBrightness: self.autoBrightness,
            accelerometerEnabled: self.accelerometerEnabled,
            sleepModeEnabled: self.sleepModeEnabled,
            auroraModeEnabled: self.auroraModeEnabled
        )
        
        // Convert payload to a hexadecimal string representation.
            let payloadHex = payload.map { String(format: "%02x", $0) }.joined(separator: " ")
            // Log the payload and the characteristic to which it will be written.
            print("Writing config payload to characteristic \(characteristic.uuid.uuidString): \(payloadHex)")
            
            peripheral.writeValue(payload, for: characteristic, type: .withResponse)
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
    
    private var state: ConnectionState {
            ConnectionState(rawValue: connectionStatus) ?? .unknown
        }

        //var connectionColor: Color { state.color }
        //var connectionImageName: String { state.imageName }
 
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
        guard #available(iOS 16.1, *) else {
            print("Live Activities require iOS 16.1 or later.")
            return
        }
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("Live Activities are disabled.")
            return
        }

        // End any existing activities before creating a new one
        for activity in Activity<LumiFur_WidgetAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        if widgetLiveActivity != nil {
            print("Live activity already exists, updating instead.")
            updateLumiFur_WidgetLiveActivity()
            return
        }
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
            isScanning: isScanning,
            temperatureChartData: Array(recentTemperatures),
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled,
            customMessage: ""
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
        // Checks for value change before updating live activity
        let updatedState = LumiFur_WidgetAttributes.ContentState(
            connectionStatus: connectionStatus,
            signalStrength: signalStrength,
            temperature: temperature,
            selectedView: selectedView,
            isConnected: isConnected,
            isScanning: isScanning,
            temperatureChartData: Array(recentTemperatures),
            sleepModeEnabled: sleepModeEnabled,
            auroraModeEnabled: auroraModeEnabled,
            customMessage: ""
        )
        // Wrap the updated state in ActivityContent.
        let updatedContent = ActivityContent(state: updatedState, staleDate: nil)
        
        for activity in Activity<LumiFur_WidgetAttributes>.activities {
            Task {
                do {
                    await activity.update(updatedContent)
                    print("Live Activity updated.")
                }
            }
        }
    }
}
