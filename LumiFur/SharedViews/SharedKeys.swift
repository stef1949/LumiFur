//
//  SharedKeys.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/18/25.
//
import Foundation
import SwiftUI // Needed for Color if used in ConnectionState
#if canImport(ActivityKit)
import ActivityKit // Needed for ActivityAttributes
#endif

// MARK: - Shared Data Keys (Use these in both App and Widget)

struct SharedDataKeys {
    static let suiteName = "group.com.richies3d.LumiFur" // <<< MUST MATCH YOUR APP GROUP ID
    static let widgetKind = "com.richies3d.LumiFur.statuswidget"
    
    static let isConnected = "widgetIsConnected"
    static let connectionStatus = "widgetConnectionStatus"
    static let controllerName = "widgetControllerName"
    static let signalStrength = "widgetSignalStrength"
    static let temperature = "widgetTemperature"
    static let temperatureHistory = "temperatureHistoryData" // NEW Temp history for widgets
    static let autoBrightness = "widgetAutoBrightness"
    static let selectedView = "widgetSelectedView"
    static let accelerometerEnabled = "accelerometerEnabled"
    static let sleepModeEnabled = "sleepModeEnabled"
    static let auroraModeEnabled = "auroraModeEnabled"
    static let customMessage = "sharedCustomMessage"
}

// MARK: - Shared Data Structures

/// Data structure for temperature readings (SHARED)
struct TemperatureData: Identifiable, Codable, Equatable {
    var id = UUID()
    let timestamp: Date
    let temperature: Double
}

/// Data structure for CPU usage data.
struct CPUUsageData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuUsage: Int
}

/// New structure to persist previously connected devices.
struct StoredPeripheral: Identifiable, Codable {
    let id: String
    let name: String
}

// MARK: - Connection State Enum

/// Enum for connection state (SHARED)
enum ConnectionState: String {
    case disconnected = "Disconnected"
    case scanning = "Scanning..."
    case connecting = "Connecting..."
    case connected = "Connected"
    case failed = "Failed to connect"       // <--- Make sure this exists
    case bluetoothOff = "Bluetooth is off" // <--- Make sure this exists
    case reconnecting = "Reconnecting..."  // <--- Make sure this exists
    case unknown = "Unknown State"

    var color: Color {
        switch self {
        case .connected: .green
        case .connecting, .scanning, .reconnecting: .orange // Includes reconnecting
        case .disconnected, .failed, .bluetoothOff: .red // Includes failed, bluetoothOff
        case .unknown: .gray
        }
    }

    var imageName: String {
        switch self {
        case .connected: "bluetooth.fill"
        case .disconnected, .failed, .bluetoothOff, .unknown: "antenna.radiowaves.left.and.right.slash" // Includes failed, btOff
        case .connecting, .scanning, .reconnecting: "antenna.radiowaves.left.and.right.circle" // Includes reconnecting
        }
    }
}

// MARK: - Live Activity Attributes (SHARED)

// IMPORTANT: Requires iOS 16.1+ checks where used if deploying below 16.1
// But the definition itself can exist.
#if canImport(ActivityKit)
@available(iOS 16.1, *) // Keep this if supporting below 16.1
struct LumiFur_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var connectionStatus: String
        var signalStrength: Int
        var temperature: String
        var selectedView: Int
        var isConnected: Bool
        var isScanning: Bool
        var temperatureChartData: [Double] // Keep this as Double if the LA UI uses it directly
        var sleepModeEnabled: Bool
        var auroraModeEnabled: Bool
        var customMessage: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}
#endif
