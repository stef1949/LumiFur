//
//  SharedKeys.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/18/25.
//
import Foundation

// MARK: - Shared Data Keys (Use these in both App and Widget)

struct SharedDataKeys {
    static let suiteName = "group.com.richies3d.LumiFur" // <<< MUST MATCH YOUR APP GROUP ID
    static let isConnected = "widgetIsConnected"
    static let connectionStatus = "widgetConnectionStatus"
    static let controllerName = "widgetControllerName"
    static let signalStrength = "widgetSignalStrength"
    static let temperature = "widgetTemperature"
    static let temperatureHistory = "temperatureHistoryData" // NEW Temp history for widgets
    
    static let selectedView = "widgetSelectedView"
    static let accelerometerEnabled = "accelerometerEnabled"
    static let sleepModeEnabled = "sleepModeEnabled"
    static let auroraModeEnabled = "auroraModeEnabled"
    static let widgetKind = "com.richies3d.lumifur.statuswidget"
}
