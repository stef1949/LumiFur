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

enum TempUnit: String, CaseIterable, Identifiable, Codable {
    case celsius, fahrenheit
    var id: String { rawValue }

    var unit: UnitTemperature {
        switch self {
        case .celsius: return .celsius
        case .fahrenheit: return .fahrenheit
        }
    }

    var shortLabel: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
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
    @State private var selectedIcon: String? = UIApplication.shared.alternateIconName
    
    //@State private var selectedUnits: TempUnit = .℃
    private var selectedUnitsBinding: Binding<TempUnit> {
        Binding(
            get: { TempUnit(rawValue: tempUnitRaw) ?? .celsius },
            set: { tempUnitRaw = $0.rawValue }
        )
    }
    @AppStorage("tempUnit") private var tempUnitRaw: String = TempUnit.celsius.rawValue
    
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
                        //.scrollContentBackground(.hidden)
                    }
                //.frame(maxWidth: .infinity, alignment: .center)
                //.listRowBackground(Color.blue.opacity(0.0))
                //.listRowInsets(EdgeInsets()) // Optional: remove padding if needed
                //.scrollContentBackground(.hidden)
                
                // OTA Update link appears conditionally.
                if bleModel.isConnected {
                    otaUpdateLink
                        .sheet(isPresented: $showOTAUpdate) {
                            OTAUpdateView(viewModel: bleModel)
                                .presentationDetents([.medium, .large])
                                .presentationDragIndicator(.visible)
                                .presentationCornerRadius(46)
                                //.padding()
                        }
                }
                
                // Each section is now its own lightweight struct.
                ConfigSection(
                    bleModel: bleModel,
                    autoBrightness: $autoBrightness,
                    accelerometer: $accelerometer,
                    sleepMode: $sleepMode,
                    auroraMode: $auroraMode,
                    selectedUnits: selectedUnitsBinding
                )
                
                MatrixSection(
                    isExpanded: $isLedArrayExpanded,
                    selectedMatrix: $selectedMatrix
                )
                //.disabled(true)
                
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
                
                AppIconPickerSection()
            }
            //.scrollContentBackground(.hidden)
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
    
    @State private var showOTAUpdate = false
    
    // --- OPTIMIZATION 4: Computed Property for Simple Views ---
    // For a very simple, single view like this, a computed property is acceptable
    // and avoids the overhead of a new struct.
    private var otaUpdateLink: some View {
        Button {
            showOTAUpdate = true
        } label: {
            HStack {
                Image(systemName: "arrow.up.circle")
                Text("Update Controller")
                Spacer()
            }
        }
        .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
    }

}


 struct DeviceRowButton: View {
    let leadingIcon: String?
    let title: String
    let rssi: Int?
    let isConnecting: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let leadingIcon {
                    Image(systemName: leadingIcon)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .lineLimit(1)
                Spacer()
                if isConnecting {
                    ProgressView()
                } else if let rssi {
                    SignalStrengthView(rssi: rssi)
                }
            }
        }
        .disabled(isDisabled)
        .connectionRow(interactive: true)
    }
}

// MARK: - Unified Connection View

/// A self-contained view that displays connection status, scan buttons,
/// and lists of discovered or connected devices.
private struct UnifiedConnectionView: View {
    @ObservedObject var accessoryViewModel: AccessoryViewModel

    var body: some View {
        VStack(spacing: 16) {
            if !accessoryViewModel.isConnected {
                statusAndScanSection
                    .connectionCard()
                //.padding(.horizontal)
            }
            ZStack {
                if accessoryViewModel.isConnected {
                    connectedSection
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                } else {
                    discoveredSection
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: accessoryViewModel.isConnected)
        }
        //.padding(.vertical)
    }

    private var statusAndScanSection: some View {
        VStack(spacing: 10) {
            ConnectionStateIconView(state: accessoryViewModel.connectionState)
                .font(.system(size: accessoryViewModel.isConnected ? 72 : 56, weight: .regular))
                .animation(.easeInOut(duration: 0.25), value: accessoryViewModel.isConnected)
            HStack {
                Image("blueoth.fill")
                Text(accessoryViewModel.connectionStatus)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(.primary)
                    .background(accessoryViewModel.connectionState.color.opacity(0.18),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if !accessoryViewModel.isConnected && !accessoryViewModel.isScanning {
                Button("Scan for Devices", action: accessoryViewModel.scanForDevices)
                    .buttonStyle(.glassProminent)
                    .padding(.top, 6)
            }
        }
        .animation(.easeInOut, value: accessoryViewModel.connectionState)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var connectedSection: some View {
        if let device = accessoryViewModel.targetPeripheral {
            VStack(alignment: .leading, spacing: 16) {
                // Header: device name and connection status, with signal strength as a trailing accessory
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name ?? "LumiFur Controller")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .accessibilityAddTraits(.isHeader)
                        Text(accessoryViewModel.connectionStatus)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(.primary)
                            .background(accessoryViewModel.connectionState.color.opacity(0.18),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    Spacer()
                    SignalStrengthView(rssi: accessoryViewModel.signalStrength)
                        .accessibilityLabel("Signal strength")
                }

                Divider()

                // Details: product image and device info aligned to leading
                VStack(alignment: .center, spacing: 16) {
                    Image("mps3")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(radius: 2, y: 1)
                        .accessibilityHidden(true)

                    DeviceInfoView(accessoryViewModel: accessoryViewModel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Primary destructive action uses standard system styling for consistency
                Button(role: .destructive, action: accessoryViewModel.disconnect) {
                    Label("Disconnect", systemImage: "antenna.radiowaves.left.and.right.slash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .accessibilityHint("Disconnect from this controller")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .connectionCard()
            //.padding(.horizontal)
        }
    }

    private var discoveredSection: some View {
        VStack(spacing: 12) {
            if accessoryViewModel.discoveredDevices.isEmpty && !accessoryViewModel.isScanning {
                Text("No devices found.")
                    .foregroundStyle(.secondary)
                    .connectionRow(interactive: false)
            } else {
                ForEach(accessoryViewModel.discoveredDevices) { device in
                    DeviceRowButton(
                        leadingIcon: "antenna.radiowaves.left.and.right",
                        title: device.name,
                        rssi: device.rssi,
                        isConnecting: accessoryViewModel.isConnecting && accessoryViewModel.connectingPeripheral?.id == device.id,
                        isDisabled: accessoryViewModel.isConnecting,
                        action: { accessoryViewModel.connect(to: device) }
                    )
                }
            }

            if !accessoryViewModel.previouslyConnectedDevices.isEmpty {
                Text("Previously Connected")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                    .padding(.horizontal)

                ForEach(accessoryViewModel.previouslyConnectedDevices) { storedDevice in
                    DeviceRowButton(
                        leadingIcon: "clock.arrow.circlepath",
                        title: storedDevice.name,
                        rssi: nil,
                        isConnecting: accessoryViewModel.isConnecting &&
                                     accessoryViewModel.connectingPeripheral?.id.uuidString == storedDevice.id,
                        isDisabled: accessoryViewModel.isConnecting,
                        action: { accessoryViewModel.connectToStoredPeripheral(storedDevice) }
                    )
                }
            }
        }
        //.padding(.horizontal)
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

private struct AppIconPickerSection: View{
    @State private var shownIconName: String? = UIApplication.shared.alternateIconName
    var body: some View{
        Section("App Icon") {
            NavigationLink {
                AppIconPickerView { iconName in
                    shownIconName = iconName
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose an App Icon")
                        Text(displayName(for: shownIconName))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(iconAssetName(for: shownIconName))
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                
            }
        }
    }
}

// MARK: App Icon Helpers
private func displayName(for iconName: String?) -> String {
        if iconName == nil { return "Default" }
        return appIcons.first(where: { $0.iconName == iconName })?.displayName
            ?? iconName! // fallback, but should normally be found
    }
private func iconAssetName(for iconName: String?) -> String {
        if let iconName,
           let icon = appIcons.first(where: { $0.iconName == iconName }) {
            return icon.assetName
        } else {
            // This must match a real image asset in the catalog
            return appIcons.first(where: { $0.iconName == nil })?.assetName ?? "AppIcon"
        }
    }

private struct MatrixSection: View {

    @Binding var isExpanded: Bool
    @Binding var selectedMatrix: MatrixStyle
    
    @State private var ledStates: [[Color]] = Array(
            repeating: Array(repeating: .black, count: 32),
            count: 64
        )
    
    var body: some View {
        DisclosureGroup("LED Configuration", isExpanded: $isExpanded) {
            VStack(alignment: .leading) {
                Text("Preview:").font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Spacer()
                    LEDPreview(
                        ledStates: $ledStates,
                        activeColor: .white,
                        isErasing: false,
                        brushRadius: 1
                    )
                    Spacer()
                }
                MatrixStylePicker(selectedMatrix: $selectedMatrix)
            }
        }
        //.disabled(true)
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
                        Text(unit.shortLabel).tag(unit)   // FIX: Changed to shortlist
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

 */

// MARK: - Previews

#Preview("Disconnected") {
    @Previewable @State var matrixStyle: MatrixStyle = .array
    
    SettingsView(
        bleModel: .previewDisconnected,
        selectedMatrix: $matrixStyle
    )
}

#Preview("Scanning") {
    @Previewable @State var matrixStyle: MatrixStyle = .array
    
    SettingsView(
        bleModel: .previewScanning,
        selectedMatrix: $matrixStyle
    )
}

#Preview("Connected") {
    @Previewable @State var matrixStyle: MatrixStyle = .dot
    
    SettingsView(
        bleModel: .previewConnected,
        selectedMatrix: $matrixStyle
    )
    .preferredColorScheme(.dark)
}

#Preview("Error State") {
    @Previewable @State var matrixStyle: MatrixStyle = .wled
    
    SettingsView(
        bleModel: .previewError,
        selectedMatrix: $matrixStyle
    )
}


