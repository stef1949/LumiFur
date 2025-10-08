//
//  SettingsView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/4/25.
//


import SwiftUI

// --- OPTIMIZATION 1: Move Enums to Top-Level ---
// Makes them reusable and cleans up the view's namespace.
enum MatrixStyle: String, CaseIterable, Identifiable {
    case array, dot, wled
    var id: Self { self }
}

enum TempUnit: String, CaseIterable, Identifiable {
    case ℃, ℉
    var id: Self { self }
}

struct SettingsView: View {
    // MARK: - State Properties
    
    // View Models are the primary source of truth for complex state.
    @StateObject private var releaseViewModel: ReleaseViewModel
    @ObservedObject var bleModel: AccessoryViewModel
    
    // AppStorage for simple, persistent user settings.
    @AppStorage("fancyMode") private var fancyMode = false
    @AppStorage("autoBrightness") var autoBrightness = true
    @AppStorage("accelerometer") var accelerometer = true
    @AppStorage("sleepMode") var sleepMode = true
    @AppStorage("auroraMode") var auroraMode = true
    @AppStorage("customMessage") var customMessage = false
    
    // Local UI state.
    @State private var showAdvanced = false
    @State private var selectedUnits: TempUnit = .℃
    @State private var isLedArrayExpanded: Bool = false
    
    // Bindings passed from a parent view.
    @Binding var selectedMatrix: MatrixStyle
    
    // --- OPTIMIZATION 2: Centralized Initialization ---
    // The initializer correctly sets up all state and dependencies.
    init(bleModel: AccessoryViewModel, selectedMatrix: Binding<MatrixStyle>) {
        self.bleModel = bleModel
        self._selectedMatrix = selectedMatrix
        
        // Services are created once and injected into the ViewModel.
        let appService = GitHubService(owner: "stef1949", repo: "LumiFur")
        let controllerService = GitHubService(owner: "stef1949", repo: "LumiFur_Controller")
        
        _releaseViewModel = StateObject(wrappedValue: ReleaseViewModel(
            appReleaseService: appService,
            controllerReleaseService: controllerService
        ))
    }
    
    // MARK: - Body
    
    // --- OPTIMIZATION 3: Simplified View Body ---
    // The body is now extremely simple. It just composes the new, smaller,
    // and more efficient view structs. The Swift compiler can process this much faster.
    var body: some View {
        NavigationStack {
            List {
                // Connection view is a self-contained component.
                Section { // The List needs a Section to host the view
                        UnifiedConnectionView(accessoryViewModel: bleModel)
                    }
                    .listRowInsets(EdgeInsets()) // Optional: remove padding if needed
                
                // OTA Update link appears conditionally.
                if bleModel.isConnected {
                    otaUpdateLink
                }
                
                // Each section is now its own lightweight struct.
                ConfigSection(
                    bleModel: bleModel,
                    autoBrightness: $autoBrightness,
                    accelerometer: $accelerometer,
                    sleepMode: $sleepMode,
                    auroraMode: $auroraMode,
                    selectedUnits: $selectedUnits
                )
                
                MatrixSection(
                    isExpanded: $isLedArrayExpanded,
                    selectedMatrix: $selectedMatrix
                )
                
                AdvancedSettingsSection(
                    bleModel: bleModel,
                    showAdvanced: $showAdvanced,
                    fancyMode: $fancyMode
                )
                
                AboutSection(
                    firmwareVersion: bleModel.firmwareVersion,
                    isConnected: bleModel.isConnected
                )
                
                ReleaseNotesSection(
                    appReleases: releaseViewModel.appReleases,
                    controllerReleases: releaseViewModel.controllerReleases
                )
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    NavigationLink(destination: InfoView()) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .alert("Connection Error", isPresented: $bleModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(bleModel.errorMessage)
            }
            .task {
                // Data fetching logic remains centralized here.
                if releaseViewModel.appReleases.isEmpty {
                    await releaseViewModel.loadAppReleases()
                }
                if releaseViewModel.controllerReleases.isEmpty {
                    await releaseViewModel.loadControllerReleases()
                }
            }
            .onAppear {
                if bleModel.isBluetoothReady && !bleModel.isConnected {
                    bleModel.scanForDevices()
                }
            }
        }
    }
    
    // --- OPTIMIZATION 4: Computed Property for Simple Views ---
    // For a very simple, single view like this, a computed property is acceptable
    // and avoids the overhead of a new struct.
    private var otaUpdateLink: some View {
        NavigationLink {
            OTAUpdateView(viewModel: bleModel)
        } label: {
            HStack {
                Image(systemName: "arrow.up.circle")
                Text("Update Controller")
            }
        }
        .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
        .transition(.opacity.combined(with: .slide))
    }
}

// MARK: - Unified Connection View

/// A self-contained view that displays connection status, scan buttons,
/// and lists of discovered or connected devices.
private struct UnifiedConnectionView: View {
    // This view receives the view model it depends on.
    @ObservedObject var accessoryViewModel: AccessoryViewModel

    // Local state for UI animations.
    @State private var scanButtonTapped = false

    var body: some View {
        // --- OPTIMIZATION: Main body is simple ---
        // It composes smaller, more focused child views.
        VStack(spacing: 16) {
            statusAndScanSection
                .padding()
            // The ZStack manages the animated transition between the
            // "discovered" and "connected" states.
            ZStack {
                if accessoryViewModel.isConnected {
                    connectedSection
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity))
                        )
                } else {
                    discoveredSection
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity))
                        )
                }
            }
            // Animate the transition whenever isConnected changes.
            .animation(.easeInOut(duration: 0.35), value: accessoryViewModel.isConnected)
        }
        .padding(.vertical)
    }
    
    // MARK: - Child Views (Computed Properties)

    /// Displays the main status icon/text and the scan button.
    private var statusAndScanSection: some View {
        VStack(spacing: 8) {
            ConnectionStateIconView(state: accessoryViewModel.connectionState)
                .font(.system(size: 60))
            Text(accessoryViewModel.connectionStatus)
                .font(.caption)
                .foregroundStyle(accessoryViewModel.connectionState.color)
                .backgroundStyle(accessoryViewModel.connectionState.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                //.backgroundStyle(accessoryViewModel.connectionState.color)
            if !accessoryViewModel.isConnected {
                Button("Scan for Devices", action: accessoryViewModel.scanForDevices)
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut, value: accessoryViewModel.connectionState)
    }
    
    /// Displays details for the currently connected peripheral.
    @ViewBuilder
    private var connectedSection: some View {
        if let device = accessoryViewModel.targetPeripheral {
            VStack(spacing: 12) {
                Text(device.name ?? "LumiFur Controller")
                    .font(.headline.bold())
                
                HStack {
                    VStack {
                        
                        SignalStrengthView(rssi: accessoryViewModel.signalStrength)
                        
                        Spacer()
                        
                        // Controller Image
                        Image("mps3")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(radius: 6)
                            .padding(.bottom, 8)
                    }
                    Spacer()
                    DeviceInfoView(accessoryViewModel: .shared) // Assuming a shared instance or pass bleModel
                }
                
                Button("Disconnect", role: .destructive, action: accessoryViewModel.disconnect)
                    .buttonStyle(.glassProminent)
            }
            .padding()
            //.background(Color(.secondarySystemGroupedBackground))
            //.clipShape(RoundedRectangle(cornerRadius: 15))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 15))
            .padding(.horizontal)
        }
    }
    
    /// Displays lists of discovered and previously connected devices.
    private var discoveredSection: some View {
        VStack(spacing: 12) {
            if accessoryViewModel.discoveredDevices.isEmpty && !accessoryViewModel.isScanning {
                Text("No devices found.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(accessoryViewModel.discoveredDevices) { device in
                    deviceRow(for: device)
                }
            }
            
            if !accessoryViewModel.previouslyConnectedDevices.isEmpty && !accessoryViewModel.discoveredDevices.contains(where: { dev in accessoryViewModel.previouslyConnectedDevices.contains(where: {$0.id == dev.id.uuidString}) }) {
                Text("Previously Connected").font(.headline).padding(.top)
                ForEach(accessoryViewModel.previouslyConnectedDevices) { storedDevice in
                    previousDeviceRow(for: storedDevice)
                }
            }
        }
        //.padding()
        //.glassEffect()
    }
    
    // MARK: - Reusable Row Helpers

    /// A button row for a discovered device.
    private func deviceRow(for device: PeripheralDevice) -> some View {
        Button(action: { accessoryViewModel.connect(to: device) }) {
            HStack {
                Text(device.name)
                Spacer()
                if accessoryViewModel.isConnecting && accessoryViewModel.connectingPeripheral?.id == device.id {
                    ProgressView()
                } else {
                    SignalStrengthView(rssi: device.rssi)
                }
            }
        }
        .padding()
        //.padding(.vertical)
        .glassEffect(.regular.interactive())
        //.buttonStyle(.bordered)
        .disabled(accessoryViewModel.isConnecting)
    }
    
    /// A button row for a previously connected (stored) device.
    private func previousDeviceRow(for storedDevice: StoredPeripheral) -> some View {
        Button(action: { accessoryViewModel.connectToStoredPeripheral(storedDevice) }) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text(storedDevice.name)
                Spacer()
                if accessoryViewModel.isConnecting && accessoryViewModel.connectingPeripheral?.id.uuidString == storedDevice.id {
                    ProgressView()
                }
            }
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .disabled(accessoryViewModel.isConnecting)
    }
}
// MARK: - Subviews as Structs (MAJOR OPTIMIZATION)
// Each major section of the List is now its own struct. This provides:
// 1. Stable Identity: SwiftUI knows these are distinct, reusable components.
// 2. Performance: Only the subviews whose state changes need to be re-evaluated.
// 3. Simpler Dependencies: Each view declares exactly what data it needs.
// 4. Faster Compilation: The compiler processes smaller, independent structs.

private struct AboutSection: View {
    let firmwareVersion: String
    let isConnected: Bool
    
    var body: some View {
        Section("About") {
            HStack {
                Text("App Version")
                Spacer()
                Text(AppInfo.versionDisplay).foregroundStyle(.secondary)
            }
            HStack {
                Text("Controller Firmware")
                Spacer()
                Text(firmwareVersion).foregroundStyle(.secondary)
            }
            .opacity(isConnected ? 1 : 0.5)
        }
    }
}

private struct ReleaseNotesSection: View {
    let appReleases: [GitHubRelease]
    let controllerReleases: [GitHubRelease]
    
    var body: some View {
        Section("Release Notes") {
            NavigationLink {
                ReleaseNotesView(title: "App Releases", releases: appReleases)
            } label: {
                Text("App Release Notes")
            }
            .disabled(appReleases.isEmpty)
            
            NavigationLink {
                ReleaseNotesView(title: "Controller Releases", releases: controllerReleases)
            } label: {
                Text("Controller Release Notes")
            }
            .disabled(controllerReleases.isEmpty)
        }
    }
}

private struct MatrixSection: View {
    @Binding var isExpanded: Bool
    @Binding var selectedMatrix: MatrixStyle
    
    var body: some View {
        DisclosureGroup("LED Configuration", isExpanded: $isExpanded) {
            VStack(alignment: .leading) {
                Text("Preview:").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    LEDPreview()
                    Spacer()
                }
                MatrixStylePicker(selectedMatrix: $selectedMatrix)
            }
        }
    }
}

private struct ConfigSection: View {
    @ObservedObject var bleModel: AccessoryViewModel
    
    // Bindings passed down from the parent.
    @Binding var autoBrightness: Bool
    @Binding var accelerometer: Bool
    @Binding var sleepMode: Bool
    @Binding var auroraMode: Bool
    @Binding var selectedUnits: TempUnit
    
    private var autoBrightnessBindingWithAnimation: Binding<Bool> {
        Binding(
            get: { autoBrightness },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    autoBrightness = newValue
                }
            }
        )
    }
    
    var body: some View {
        Section(
            header: Text("Configuration"),
            footer: Text("Changes are saved immediately.")
        ) {
            HStack {
                Label("Temp Units", systemImage: "thermometer.high")
                Spacer(minLength: 50)
                Picker("Temperature Units", selection: $selectedUnits) {
                    ForEach(TempUnit.allCases) { unit in
                        Text(unit.rawValue.capitalized)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            BrightnessControls(bleModel: bleModel, autoBrightness: autoBrightnessBindingWithAnimation)
            
            Toggle(isOn: $accelerometer) {
                Label("Accelerometer", systemImage: "rotate.3d.fill")
            }
            .onChange(of: accelerometer) { _, newValue in
                bleModel.accelerometerEnabled = newValue
                bleModel.writeConfigToCharacteristic()
            }
            .disabled(!bleModel.isConnected)
            
            Toggle(isOn: $sleepMode) {
                Label("Sleep Mode", systemImage: "moon.fill")
            }
            .onChange(of: sleepMode) { _, newValue in
                bleModel.sleepModeEnabled = newValue
                bleModel.writeConfigToCharacteristic()
            }
            .disabled(!bleModel.isConnected)
            
            Toggle(isOn: $auroraMode) {
                Label("Aurora Mode", systemImage: "bubbles.and.sparkles.fill")
            }
            .toggleStyle(
                GradientToggleStyle(
                    gradient: LinearGradient(colors: [.pink, .purple, .blue], startPoint: .leading, endPoint: .trailing)
                )
            )
            .onChange(of: auroraMode) { _, newValue in
                bleModel.auroraModeEnabled = newValue
                bleModel.writeConfigToCharacteristic()
            }
            .disabled(!bleModel.isConnected)
        }
    }
}

private struct BrightnessControls: View {
    @ObservedObject var bleModel: AccessoryViewModel
    @Binding var autoBrightness: Bool
    
    var body: some View {
        VStack {
            Toggle(isOn: $autoBrightness) {
                Label("Auto Brightness", systemImage: "sun.max.fill")
            }
            .onChange(of: autoBrightness) { _, newValue in
                bleModel.autoBrightness = newValue
                bleModel.writeConfigToCharacteristic()
            }
            .disabled(!bleModel.isConnected)
            
            if !autoBrightness {
                Slider(
                    value: Binding(
                        get: { Double(bleModel.brightness) },
                        set: { bleModel.brightness = UInt8($0) }
                    ),
                    in: 0...255,
                    step: 15
                ) {
                    Text("Brightness")
                } minimumValueLabel: {
                    Image(systemName: "sun.min")
                } maximumValueLabel: {
                    Image(systemName: "sun.max")
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        // Apply animation at the container level for coordinated transitions.
        .animation(.easeInOut(duration: 0.3), value: autoBrightness)
    }
}

private struct AdvancedSettingsSection: View {
    @ObservedObject var bleModel: AccessoryViewModel
    @Binding var showAdvanced: Bool
    @Binding var fancyMode: Bool
    
    var body: some View {
        Section("Advanced") {
            Toggle("Show Advanced Options", isOn: $showAdvanced.animation())
            
            if showAdvanced {
                Toggle("Fancy Mode", isOn: $fancyMode)
                NavigationLink("Connection Parameters") {
                    AdvancedSettingsView(bleModel: bleModel)
                }
                Button("Reset to Defaults", role: .destructive) {
                    print("Resetting to defaults...")
                }
            }
        }
    }
}
/*
// MARK: - Preview Scenarios

// --- OPTIMIZATION 1: Create a dedicated extension for preview data ---
// This keeps your preview logic clean and separate from your main app code.
// It provides stable, pre-configured view models for different states.
private extension AccessoryViewModel {
    
    /// A view model configured for a disconnected state.
    static var previewDisconnected: AccessoryViewModel {
        let vm = AccessoryViewModel()
        vm.isConnected = false
        vm.isBluetoothReady = true
        return vm
    }
    
    /// A view model configured for a connected state with mock data.
    static var previewConnected: AccessoryViewModel {
        let vm = AccessoryViewModel()
        vm.isConnected = true
        vm.firmwareVersion = "2.1.0-beta"
        // You could add a mock targetPeripheral if needed for more detailed previews.
        return vm
    }

    /// A view model configured for a scanning state with mock discovered devices.
    static var previewScanning: AccessoryViewModel {
        let vm = AccessoryViewModel()
        vm.isScanning = true
        // Add mock devices to preview the discovered devices list.
        // Note: You might need a way to create mock `PeripheralDevice` instances.
        // For now, this demonstrates the concept.
        // vm.discoveredDevices = [PeripheralDevice(name: "LumiFur-A1B2", rssi: -55), ...]
        return vm
    }
}

// MARK: - Previews

#Preview("Disconnected") {
    @Previewable @State var matrixStyle: MatrixStyle = .array
    
    return SettingsView(
        // Use the new debug initializer to create the exact state you need.
        bleModel: AccessoryViewModel(isConnected: false),
        selectedMatrix: $matrixStyle
    )
}

#Preview("Connected") {
    @Previewable @State var matrixStyle: MatrixStyle = .dot
    
    return SettingsView(
        // Create a connected state with a specific firmware version.
        bleModel: AccessoryViewModel(isConnected: true, firmwareVersion: "2.1.0"),
        selectedMatrix: $matrixStyle
    )
    .preferredColorScheme(.dark)
}

#Preview("Error State") {
    @Previewable @State var matrixStyle: MatrixStyle = .wled
    
    return SettingsView(
        // Create an error state to preview the alert.
        bleModel: AccessoryViewModel(
            isConnected: false,
            errorMessage: "Failed to connect. The device is out of range."
        ),
        selectedMatrix: $matrixStyle
    )
}
*/
