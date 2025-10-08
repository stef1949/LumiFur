//
//  SettingsStore.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 8/13/25.
//
import SwiftUI

// Every @AppStorage read marks the whole ContentView dirty when it changes. Wrap them in a tiny settings store so only consumers who need a value re-render.
final class SettingsStore: ObservableObject {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = true
    @AppStorage("fancyMode") private var fancyMode: Bool = false
    @AppStorage("autoBrightness") private var autoBrightness = true
    @AppStorage("accelerometer") private var accelerometer = true
    @AppStorage("sleepMode") private var sleepMode = true
    @AppStorage("auroraMode") private var auroraMode = true
    @AppStorage("customMessage") private var customMessage = false
    @AppStorage("charts") var isChartsExpanded = false // This now drives the ChartView
}
