//
//  SharedKeys.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/18/25.
//
import Foundation
import os
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
struct TemperatureData: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    let timestamp: Date
    let temperature: Double
}

/// Data structure for CPU usage data.
struct CPUUsageData: Identifiable, Codable, Sendable {
    var id = UUID()
    let timestamp: Date
    let cpuUsage: Int
}

// MARK: - Debug Diagnostics

#if DEBUG
/// Debug-only counters for finding idle CPU churn. Enable with
/// `LUMIFUR_IDLE_CPU_DIAGNOSTICS=1` in the app environment or a matching
/// `UserDefaults` boolean.
final class IdleCPUDiagnostics: @unchecked Sendable {
    static let shared = IdleCPUDiagnostics()

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["LUMIFUR_IDLE_CPU_DIAGNOSTICS"] == "1" ||
        UserDefaults.standard.bool(forKey: "LUMIFUR_IDLE_CPU_DIAGNOSTICS")
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LumiFur",
        category: "IdleCPU"
    )
    private let queue = DispatchQueue(label: "com.richies3d.lumifur.idle-cpu")
    private var counters: [String: Int] = [:]
    private var flushTimer: DispatchSourceTimer?

    private init() {
        guard Self.isEnabled else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            self?.flush()
        }
        flushTimer = timer
        timer.resume()
    }

    deinit {
        flushTimer?.cancel()
    }

    @inline(__always)
    func recordViewBody(_ name: String) {
        increment("view.\(name)")
    }

    @inline(__always)
    func recordPublishedChange(_ name: String) {
        increment("published.\(name)")
    }

    @inline(__always)
    func recordTransportEvent(_ name: String) {
        increment("ble.\(name)")
    }

    @inline(__always)
    func recordTimerTick(_ name: String) {
        increment("timer.\(name)")
    }

    @inline(__always)
    func recordTaskFire(_ name: String) {
        increment("task.\(name)")
    }

    private func increment(_ key: String) {
        guard Self.isEnabled else { return }

        queue.async { [weak self] in
            self?.counters[key, default: 0] += 1
        }
    }

    private func flush() {
        guard !counters.isEmpty else { return }

        let summary = counters
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(12)
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")

        counters.removeAll(keepingCapacity: true)
        logger.debug("Idle CPU counters/sec: \(summary, privacy: .public)")
    }
}
#else
final class IdleCPUDiagnostics {
    static let shared = IdleCPUDiagnostics()
    static let isEnabled = false

    private init() {}

    @inline(__always) func recordViewBody(_ name: String) {}
    @inline(__always) func recordPublishedChange(_ name: String) {}
    @inline(__always) func recordTransportEvent(_ name: String) {}
    @inline(__always) func recordTimerTick(_ name: String) {}
    @inline(__always) func recordTaskFire(_ name: String) {}
}
#endif

// MARK: - Connection State Enum

/// Enum for connection state (SHARED)
enum ConnectionState: String, Codable, Sendable { // Make it Codable for easy storage
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

    /// Return a SwiftUI Image backed by an SF Symbol
    var image: Image {
        switch self {
        case .connected:
            return Image("bluetooth.fill")
        case .disconnected, .failed, .bluetoothOff, .unknown:
            return Image("bluetooth.slash.fill")
        case .connecting, .scanning, .reconnecting:
            return Image(systemName: "antenna.radiowaves.left.and.right")
        }
    }
    // NEW: Computed property for the SF Symbol name
    var symbolName: String {
        switch self {
        case .connected:
            // "bluetooth.fill" is not an SF Symbol.
            // Choose an appropriate SF Symbol like "wifi", "bolt.fill", "network",
            // or "antenna.radiowaves.left.and.right.circle.fill"
            return "antenna.radiowaves.left.and.right" // Example: Using wifi symbol for connected
        case .disconnected, .failed, .bluetoothOff, .unknown:
            // "bluetooth.slash.fill" is not an SF Symbol.
            // Choose "wifi.slash", "bolt.slash.fill", "network.slash"
            return "antenna.radiowaves.left.and.right.slash" // Example: Using wifi.slash for disconnected states
        case .connecting, .scanning, .reconnecting:
            // This one was already good as an SF Symbol
            return "arrow.triangle.2.circlepath.circle" // Good for "in progress", often animated by default
            // Or, keep: "antenna.radiowaves.left.and.right"
        }
    }
    
    // NEW: Add a computed property to check if the symbol is a custom asset.
    var isCustomSymbol: Bool {
        switch self {
        case .connected:
            return true // Only our connected state uses a custom image
        default:
            return false
        }
    }
}

// MARK: - Live Activity Attributes (SHARED)

// IMPORTANT: Requires iOS 16.1+ checks where used if deploying below 16.1
// But the definition itself can exist.
#if canImport(ActivityKit) && !os(macOS)
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
#endif // canImport(ActivityKit)

private struct SignalBar: View, Equatable {
    let filled: Bool
    let fullHeight: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(filled ? .blue : Color.gray.opacity(0.3))
            .frame(width: 4, height: fullHeight)
    }

    static func == (lhs: SignalBar, rhs: SignalBar) -> Bool {
        lhs.filled == rhs.filled && lhs.fullHeight == rhs.fullHeight
    }
}

struct SignalStrengthView: View {
    @AppStorage("rssiMonitoringEnabled")
    private var rssiMonitoringEnabled: Bool = false
    let rssi: Int
    
    // BLE typically lives in about –100…–30 dBm
    private let bleMinRssi: Int = -100
    private let bleMaxRssi: Int =  -70
    
    private var signalLevel: Double {
        // shift –100…–30 into 0…1
        let normalized = Double(rssi - bleMinRssi) / Double(bleMaxRssi - bleMinRssi)
        return min(max(normalized, 0), 1)
    }
    
    var body: some View {
        
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<4, id: \.self) { idx in
                // Compute whether this bar is lit
                let lit = idx < Int(signalLevel * 4)
                let height = CGFloat(idx + 2) * 4
                
                SignalBar(filled: lit, fullHeight: height)
                    .equatable()                    // <-- skip redraw when unchanged
                    .animation(.easeInOut(duration: 0.3),
                               value: lit)       // <-- still animate fill changes
            }
            
            if rssiMonitoringEnabled {
                Text("\(rssi)dBm")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3),
                               value: rssiMonitoringEnabled)
            }
        }
        // Flatten into a single layer so the GPU only re-rasterizes one texture
        //.compositingGroup()
        //.drawingGroup()
    }
}
