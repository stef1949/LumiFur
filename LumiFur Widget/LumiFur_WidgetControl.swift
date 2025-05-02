//
//  LumiFur_WidgetControl.swift
//  LumiFur Widget
//
//  Created by Stephan Ritchie on 2/12/25.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//

import AppIntents
import SwiftUI
import WidgetKit

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

struct LumiFur_WidgetControl: ControlWidget {
    static let kind: String = "com.richies3d.lumifur.statuswidget"
    //static let kind: String = SharedDataKeys.widgetKind
    
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
        }
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
}

extension LumiFur_WidgetControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            LumiFur_WidgetControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let isRunning = true // Check if the timer is running
            return LumiFur_WidgetControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Timer Name Configuration"

    @Parameter(title: "Timer Name", default: "Timer")
    var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: "Timer Name")
    var name: String

    @Parameter(title: "Timer is running")
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        // Start the timer…
        return .result()
    }
}

struct TemperatureDataPoint: Identifiable, Codable, Equatable {
    var id = UUID()
    let timestamp: Date
    let temperature: Double
}
