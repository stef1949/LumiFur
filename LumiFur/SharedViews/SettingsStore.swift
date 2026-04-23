//
//  SettingsStore.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 8/13/25.
//
import SwiftUI

// Keep only app-level presentation preferences here. Device configuration now lives in AccessoryViewModel.
final class SettingsStore: ObservableObject {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = true
    @AppStorage("fancyMode") private var fancyMode: Bool = false
    @AppStorage("charts") private var isChartsExpanded = false
    @AppStorage("tempUnit") private var temperatureUnit = "C"
}
