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

    // Local UI state.
    @State private var showOnboarding = false
    @State private var showOTAUpdate = false

    private var selectedUnitsBinding: Binding<TempUnit> {
        Binding(
            get: { TempUnit(rawValue: tempUnitRaw) ?? .celsius },
            set: { tempUnitRaw = $0.rawValue }
        )
    }
    @AppStorage("tempUnit") private var tempUnitRaw: String = TempUnit.celsius.rawValue

    let isActive: Bool

    // Bindings passed from a parent view.
    @Binding var selectedMatrix: MatrixStyle

    // --- OPTIMIZATION 2: Centralized Initialization ---
    // The initializer correctly sets up all state and dependencies.
    init(
        bleModel: AccessoryViewModel,
        selectedMatrix: Binding<MatrixStyle>,
        isActive: Bool = true
    ) {
        self.bleModel = bleModel
        self._selectedMatrix = selectedMatrix
        self.isActive = isActive

        // Services are created once and injected into the ViewModel.
        let appService = GitHubService(owner: "stef1949", repo: "LumiFur")
        let controllerService = GitHubService(owner: "stef1949", repo: "LumiFur_Controller")

        _releaseViewModel = StateObject(wrappedValue: ReleaseViewModel(
            appReleaseService: appService,
            controllerReleaseService: controllerService
        ))
    }

    // MARK: - Body

    var body: some View {
        let _ = IdleCPUDiagnostics.shared.recordViewBody("SettingsView")

        List {
            ControllerHeroSection(
                accessoryViewModel: bleModel,
                tempUnit: selectedUnitsBinding.wrappedValue
            )

            if bleModel.hasInlineFeedback {
                Section {
                    ConnectionFeedbackView(
                        message: bleModel.errorMessage,
                        onDismiss: bleModel.clearFeedback
                    )
                }
            }

            if bleModel.isConnected {
                Section("Controller") {
                    updateControllerRow
                        .sheet(isPresented: $showOTAUpdate) {
                            OTAUpdateView(
                                viewModel: bleModel,
                                releaseViewModel: releaseViewModel
                            )
                            .compatibleSheetPresentation(cornerRadius: 46)
                        }
                }

                ConfigSections(
                    bleModel: bleModel,
                    selectedUnits: selectedUnitsBinding
                )
            }

            DeviceSections(accessoryViewModel: bleModel)

            Section {
                NavigationLink {
                    AdvancedSettingsPage(
                        bleModel: bleModel,
                        fancyMode: $fancyMode,
                        onResetToDefaults: resetAdvancedPreferences
                    )
                } label: {
                    SettingsLabel("Advanced", systemImage: "gearshape.fill", color: .gray)
                }
            }

            AppIconPickerSection()

            GettingStartedSection {
                showOnboarding = true
            }

            ReleaseNotesSection(
                appReleases: releaseViewModel.appReleases,
                controllerReleases: releaseViewModel.controllerReleases,
                isLoadingAppReleases: releaseViewModel.isLoadingAppReleases,
                isLoadingControllerReleases: releaseViewModel.isLoadingControllerReleases,
                appReleaseError: releaseViewModel.appReleaseError,
                controllerReleaseError: releaseViewModel.controllerReleaseError
            )

            AboutSection(
                firmwareVersion: bleModel.firmwareVersion,
                isConnected: bleModel.isConnected
            )
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                NavigationLink(destination: InfoView()) {
                    Image(systemName: "info.circle")
                }
            }
        }
        #if targetEnvironment(macCatalyst)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
            .frame(minWidth: 680, minHeight: 520)
        }
        #else
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
        #endif
        .task(id: isActive) {
            guard isActive else { return }
            await activateIfNeeded()
        }
    }

    /// True when the newest controller release on GitHub is newer than the connected firmware.
    private var isControllerUpdateAvailable: Bool {
        guard let latest = releaseViewModel.latestControllerRelease?.semanticVersion,
              let installed = SemanticVersion.parse(bleModel.firmwareVersion) else {
            return false
        }
        return installed < latest
    }

    // Looks like a navigation row, but presents the OTA sheet.
    private var updateControllerRow: some View {
        Button {
            showOTAUpdate = true
        } label: {
            HStack {
                SettingsLabel("Update Controller", systemImage: "arrow.down.circle.fill", color: .green)
                Spacer()
                if isControllerUpdateAvailable {
                    Text("Update Available")
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
    }

    @MainActor
    private func activateIfNeeded() async {
        IdleCPUDiagnostics.shared.recordTaskFire("settings.activate")

        if releaseViewModel.appReleases.isEmpty {
            await releaseViewModel.loadAppReleases()
        }
        if releaseViewModel.controllerReleases.isEmpty {
            await releaseViewModel.loadControllerReleases()
        }
        if bleModel.isBluetoothReady, !bleModel.isConnected, !bleModel.isScanning {
            bleModel.scanForDevices()
        }
    }

    @MainActor
    private func resetAdvancedPreferences() {
        fancyMode = false
        tempUnitRaw = TempUnit.celsius.rawValue

        _ = bleModel.resetConfigurationToDefaults(syncToDevice: bleModel.isConnected)
        _ = bleModel.updateCustomMessage("", syncToDevice: bleModel.isConnected)
    }

}

// MARK: - Settings Row Styling

/// A white SF Symbol on a tinted rounded tile, matching the iOS Settings app.
struct SettingsIcon: View {
    let systemImage: String
    let background: AnyShapeStyle

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 29

    init(systemImage: String, color: Color) {
        self.systemImage = systemImage
        self.background = AnyShapeStyle(color.gradient)
    }

    init<S: ShapeStyle>(systemImage: String, background: S) {
        self.systemImage = systemImage
        self.background = AnyShapeStyle(background)
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.58, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A list row label with a `SettingsIcon` tile, for toggles, pickers and navigation rows.
struct SettingsLabel: View {
    let title: String
    let icon: SettingsIcon

    init(_ title: String, systemImage: String, color: Color) {
        self.title = title
        self.icon = SettingsIcon(systemImage: systemImage, color: color)
    }

    init(_ title: String, icon: SettingsIcon) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            icon
        }
    }
}

// MARK: - Device List Rows

// Card-styled device row, still used by DeviceListView.
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

/// A plain device row in the style of iOS Bluetooth settings.
private struct SettingsDeviceRow: View {
    let title: String
    let rssi: Int?
    let isConnecting: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer()
                if isConnecting {
                    ProgressView()
                } else if let rssi {
                    SignalStrengthView(rssi: rssi)
                        .accessibilityLabel("Signal strength")
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(isDisabled)
    }
}

// MARK: - Controller Hero

/// A large product image with the controller's name and status, modelled on the AirPods page in iOS Settings.
/// It's the first row of the list, so it scrolls with the content under the large title.
private struct ControllerHeroSection: View {
    @ObservedObject var accessoryViewModel: AccessoryViewModel
    let tempUnit: TempUnit

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isConnected: Bool { accessoryViewModel.isConnected }

    private var isScanning: Bool {
        accessoryViewModel.isScanning || accessoryViewModel.connectionState == .scanning
    }

    var body: some View {
        Section {
            VStack(spacing: 0) {
                productImage
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                VStack(spacing: 4) {
                    Text(accessoryViewModel.targetPeripheral?.name ?? "LumiFur Controller")
                        .font(.title2.weight(.semibold))
                        .fontDesign(.rounded)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    statusLine
                }
                .padding(.horizontal)

                Group {
                    if isConnected {
                        chips
                    } else {
                        scanButton
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal)
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth, value: isConnected)
            .sensoryFeedback(trigger: isConnected) { _, connected in
                connected ? .success : .impact(weight: .light)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    // MARK: Image

    private var productImage: some View {
        Image(decorative: "mps3") // The name sits directly below.
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 280, maxHeight: 200)
            .saturation(isConnected ? 1 : 0)
            .opacity(isConnected ? 1 : 0.55)
            .background {
                // A halo just past the board's edges. It fades to clear at its own frame,
                // so the row never clips it into a hard line.
                EllipticalGradient(
                    stops: [
                        .init(color: Color.accentColor.opacity(0.35), location: 0),
                        .init(color: Color.accentColor.opacity(0.2), location: 0.55),
                        .init(color: .clear, location: 1)
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.5
                )
                .frame(width: 380, height: 236)
                .opacity(isConnected ? 1 : 0)
                .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
    }

    // MARK: Status

    private var statusLine: some View {
        // Stacks rather than a Label, which gets a fixed-width icon column in list rows.
        // At the largest text sizes the symbol moves above the text so the text can wrap.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
                statusSymbol
                Text(status.text)
            }
            VStack(spacing: 2) {
                statusSymbol
                Text(status.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: some View {
        Image(systemName: status.systemImage)
            .foregroundStyle(status.tint)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: reduceMotion ? false : isConnected)
            .accessibilityHidden(true) // The text states the status.
    }

    private var status: (text: String, systemImage: String, tint: Color) {
        switch accessoryViewModel.connectionState {
        case .connected:
            return ("Connected", "checkmark.circle.fill", .green)
        case .connecting:
            return ("Connecting…", "antenna.radiowaves.left.and.right", .secondary)
        case .reconnecting:
            return ("Reconnecting…", "antenna.radiowaves.left.and.right", .secondary)
        case .failed:
            return ("Connection Failed", "exclamationmark.circle.fill", .orange)
        case .bluetoothOff:
            return ("Bluetooth Off", "exclamationmark.circle.fill", .orange)
        case .scanning, .disconnected, .unknown:
            if isScanning {
                return ("Scanning…", "antenna.radiowaves.left.and.right", .secondary)
            }
            return ("Not Connected", "antenna.radiowaves.left.and.right.slash", .secondary)
        }
    }

    // MARK: Connected

    private var firmware: String? {
        let version = accessoryViewModel.deviceInfo?.fw ?? accessoryViewModel.firmwareVersion
        return version.isEmpty || version == "N/A" ? nil : version
    }

    // Same –100…–70 dBm range as SignalStrengthView.
    private var signalLevel: Double {
        min(max(Double(accessoryViewModel.signalStrength + 100) / 30, 0), 1)
    }

    private var signalDescription: String {
        switch signalLevel {
        case ..<0.25: return "Weak"
        case ..<0.5: return "Fair"
        case ..<0.75: return "Good"
        default: return "Strong"
        }
    }

    private var temperature: String? {
        guard let celsius = accessoryViewModel.currentTempC else { return nil }
        return Measurement(value: celsius, unit: UnitTemperature.celsius)
            .converted(to: tempUnit.unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    private var chips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chipContent }
            VStack(spacing: 8) { chipContent }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chipsAccessibilityLabel)
    }

    @ViewBuilder
    private var chipContent: some View {
        if let firmware {
            HeroChip("v\(firmware)", systemImage: "memorychip")
        }
        HeroChip(signalDescription, systemImage: "cellularbars", variableValue: signalLevel)
        if let temperature {
            HeroChip(temperature, systemImage: "thermometer.medium")
        }
    }

    private var chipsAccessibilityLabel: String {
        var parts: [String] = []
        if let firmware { parts.append("Firmware \(firmware)") }
        parts.append("\(signalDescription) signal")
        if let temperature { parts.append("Temperature \(temperature)") }
        return parts.joined(separator: ", ")
    }

    // MARK: Disconnected

    // The only tinted primary action in Settings.
    private var scanButton: some View {
        Button(action: accessoryViewModel.scanForDevices) {
            Group {
                if isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Scanning…")
                    }
                } else {
                    Text("Scan for Devices")
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 8)
        }
        .disabled(isScanning)
        .buttonBorderShape(.capsule)
        .modifier(ProminentButtonStyle())
    }
}

/// A small capsule of hero metadata, such as the firmware version or signal strength.
private struct HeroChip: View {
    let text: String
    let systemImage: String
    var variableValue: Double?

    init(_ text: String, systemImage: String, variableValue: Double? = nil) {
        self.text = text
        self.systemImage = systemImage
        self.variableValue = variableValue
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage, variableValue: variableValue)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .fontDesign(.rounded)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.quaternary))
        .fixedSize()
    }
}

/// Liquid Glass on iOS 26, bordered prominent before it.
private struct ProminentButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Device Sections

/// Controller details and Disconnect when connected; Bluetooth-style device lists when not.
private struct DeviceSections: View {
    @ObservedObject var accessoryViewModel: AccessoryViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showDisconnectConfirmation = false

    var body: some View {
        Group {
            if accessoryViewModel.isConnected {
                connectedSections
            } else {
                disconnectedSections
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: accessoryViewModel.isConnected)
    }

    // MARK: Connected

    @ViewBuilder
    private var connectedSections: some View {
        Section {
            if let info = accessoryViewModel.deviceInfo {
                LabeledContent("Model", value: info.model)
                LabeledContent("Firmware", value: info.fw)
                LabeledContent("Branch", value: info.branch)
                LabeledContent("Build", value: info.build)
                LabeledContent("Compat", value: "\(info.compat)+")
                LabeledContent("ID") {
                    Text(info.id)
                        .font(.body.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .contextMenu {
                    Button("Copy ID", systemImage: "doc.on.doc") {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = info.id
                        #endif
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Reading device info…")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("About This Controller")
        }

        Section {
            Button(role: .destructive) {
                showDisconnectConfirmation = true
            } label: {
                Text("Disconnect")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityHint("Disconnect from this controller")
            .confirmationDialog(
                "Disconnect from \(accessoryViewModel.targetPeripheral?.name ?? "LumiFur Controller")?",
                isPresented: $showDisconnectConfirmation,
                titleVisibility: .visible
            ) {
                Button("Disconnect", role: .destructive, action: accessoryViewModel.disconnect)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: Disconnected

    @ViewBuilder
    private var disconnectedSections: some View {
        Section {
            ForEach(accessoryViewModel.discoveredDevices) { device in
                SettingsDeviceRow(
                    title: device.name,
                    rssi: device.rssi,
                    isConnecting: accessoryViewModel.isConnecting && accessoryViewModel.connectingPeripheral?.id == device.id,
                    isDisabled: accessoryViewModel.isConnecting,
                    action: { accessoryViewModel.connect(to: device) }
                )
            }
        } header: {
            HStack(spacing: 6) {
                Text("Devices")
                if accessoryViewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Scanning")
                }
            }
        } footer: {
            Text(devicesFooter)
        }

        if !accessoryViewModel.previouslyConnectedDevices.isEmpty {
            Section("Previously Connected") {
                ForEach(accessoryViewModel.previouslyConnectedDevices) { storedDevice in
                    SettingsDeviceRow(
                        title: storedDevice.name,
                        rssi: nil,
                        isConnecting: accessoryViewModel.isConnecting &&
                                     accessoryViewModel.connectingPeripheral?.id.uuidString == storedDevice.id,
                        isDisabled: accessoryViewModel.isConnecting,
                        action: { accessoryViewModel.connectToStoredPeripheral(storedDevice) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                accessoryViewModel.deleteStoredPeripheral(storedDevice)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var devicesFooter: String {
        if accessoryViewModel.discoveredDevices.isEmpty && !accessoryViewModel.isScanning {
            return "\(accessoryViewModel.connectionStatus). No devices found."
        }
        return accessoryViewModel.connectionStatus
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
        Section {
            LabeledContent("App Version", value: AppInfo.versionDisplay)
            LabeledContent("Controller Firmware", value: firmwareVersion)
                .opacity(isConnected ? 1 : 0.5)
        } header: {
            Text("About")
        } footer: {
            Text("© 2026 Richies 3D Ltd. All Rights Reserved.")
        }
    }
}

private struct ReleaseNotesSection: View {
    let appReleases: [GitHubRelease]
    let controllerReleases: [GitHubRelease]
    let isLoadingAppReleases: Bool
    let isLoadingControllerReleases: Bool
    let appReleaseError: NetworkError?
    let controllerReleaseError: NetworkError?

    var body: some View {
        Section {
            NavigationLink {
                ReleaseNotesView(title: "App Releases", releases: appReleases)
            } label: {
                SettingsLabel("App Release Notes", systemImage: "doc.text.fill", color: .blue)
            }
            .disabled(appReleases.isEmpty && !isLoadingAppReleases)

            NavigationLink {
                ReleaseNotesView(title: "Controller Releases", releases: controllerReleases)
            } label: {
                SettingsLabel("Controller Release Notes", systemImage: "doc.text.fill", color: .green)
            }
            .disabled(controllerReleases.isEmpty && !isLoadingControllerReleases)

            if isLoadingAppReleases || isLoadingControllerReleases {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading Release Notes…")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Release Notes")
        } footer: {
            if appReleaseError != nil || controllerReleaseError != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let appReleaseError {
                        Text("App releases failed to load: \(appReleaseError.localizedDescription)")
                    }
                    if let controllerReleaseError {
                        Text("Controller releases failed to load: \(controllerReleaseError.localizedDescription)")
                    }
                }
            }
        }
    }
}

private struct GettingStartedSection: View {
    let showOnboarding: () -> Void

    var body: some View {
        Section("Getting Started") {
            Button(action: showOnboarding) {
                SettingsLabel("Replay Onboarding", systemImage: "sparkles", color: .pink)
            }
            .tint(.primary)
        }
    }
}

private struct AppIconPickerSection: View {
    @State private var shownIconName: String? = UIApplication.shared.alternateIconName
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 29

    var body: some View {
        Section("App Icon") {
            NavigationLink {
                AppIconPickerView { iconName in
                    shownIconName = iconName
                }
            } label: {
                LabeledContent {
                    Text(displayName(for: shownIconName))
                } label: {
                    Label {
                        Text("App Icon")
                    } icon: {
                        iconPreview
                    }
                }
            }
        }
    }
}

private extension AppIconPickerSection {
    @ViewBuilder
    var iconPreview: some View {
        if let image = UIImage(named: iconAssetName(for: shownIconName)) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.24, style: .continuous))
                .accessibilityHidden(true)
        } else {
            // The default icon lives in the app icon set, which isn't loadable as an image.
            SettingsIcon(systemImage: "app.fill", color: .gray)
        }
    }
}

// MARK: App Icon Helpers
private func displayName(for iconName: String?) -> String {
        if iconName == nil { return "Default" }
        return appIcons.first(where: { $0.iconName == iconName })?.displayName
            ?? "Custom"
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

// MARK: - Controller Configuration

/// Controller configuration, split into Display, Effects, Sensors & Power,
/// Status Indicators and Hardware sections.
private struct ConfigSections: View {
    @ObservedObject var bleModel: AccessoryViewModel
    @Binding var selectedUnits: TempUnit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var autoBrightnessBindingWithAnimation: Binding<Bool> {
        Binding(
            get: { bleModel.autoBrightness },
            set: { newValue in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                    bleModel.autoBrightness = newValue
                }
                bleModel.writeConfigToCharacteristic()
            }
        )
    }
    private var mouthBrightnessOverrideBinding: Binding<Bool> {
        Binding(
            get: { bleModel.mouthBrightnessOverrideEnabled },
            set: { newValue in
                var configuration = bleModel.currentConfiguration()
                configuration.mouthBrightnessOverrideEnabled = newValue
                bleModel.applyUserConfiguration(configuration)
            }
        )
    }
    private var disableBleIndicatorBinding: Binding<Bool> {
        Binding(
            get: { bleModel.disableBleIndicatorLight },
            set: { newValue in
                var configuration = bleModel.currentConfiguration()
                configuration.disableBleIndicatorLight = newValue // byte 6
                bleModel.applyUserConfiguration(configuration)
            }
        )
    }

    private var disableBleStatusIconBinding: Binding<Bool> {
        Binding(
            get: { bleModel.disableBleStatusIcon },
            set: { newValue in
                var configuration = bleModel.currentConfiguration()
                configuration.disableBleStatusIcon = newValue // byte 7
                bleModel.applyUserConfiguration(configuration)
            }
        )
    }

    private var waveshareBoostBinding: Binding<Bool> {
        Binding(
            get: { bleModel.waveshareBrightnessBoost },
            set: { newValue in
                var configuration = bleModel.currentConfiguration()
                configuration.waveshareBrightnessBoost = newValue // byte 8, controller reboots
                bleModel.applyUserConfiguration(configuration)
            }
        )
    }

    // Config byte 9. Face masks render matrix rain instead of plasma.
    private var matrixRainInsteadOfPlasmaBinding: Binding<Bool> {
        Binding(
            get: { bleModel.matrixRainInsteadOfPlasma },
            set: { newValue in
                var configuration = bleModel.currentConfiguration()
                configuration.matrixRainInsteadOfPlasma = newValue
                bleModel.applyUserConfiguration(configuration)
            }
        )
    }

    private var boopModeBinding: Binding<UInt8> {
        Binding(
            get: { bleModel.boopMode },
            set: { newValue in
                var configuration = bleModel.currentConfiguration()
                configuration.boopMode = newValue // byte 10
                bleModel.applyUserConfiguration(configuration)
            }
        )
    }

    private var accelerometerBinding: Binding<Bool> {
        Binding(
            get: { bleModel.accelerometerEnabled },
            set: { newValue in
                bleModel.accelerometerEnabled = newValue
                bleModel.writeConfigToCharacteristic()
            }
        )
    }

    private var sleepModeBinding: Binding<Bool> {
        Binding(
            get: { bleModel.sleepModeEnabled },
            set: { newValue in
                bleModel.sleepModeEnabled = newValue
                bleModel.writeConfigToCharacteristic()
            }
        )
    }

    private var auroraModeBinding: Binding<Bool> {
        Binding(
            get: { bleModel.auroraModeEnabled },
            set: { newValue in
                bleModel.auroraModeEnabled = newValue
                bleModel.writeConfigToCharacteristic()
            }
        )
    }

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { Double(bleModel.brightness) },
            set: { bleModel.setBrightness(UInt8($0)) }
        )
    }

    // Not a config byte. Writes the floor characteristic. Minimum on device is 15.
    private var autoBrightnessFloorBinding: Binding<Double> {
        Binding(
            get: { Double(bleModel.autoBrightnessFloor) },
            set: { bleModel.setAutoBrightnessFloor(UInt8($0)) }
        )
    }

    var body: some View {
        displaySection
        effectsSection
        sensorsAndPowerSection
        statusIndicatorsSection
        hardwareSection
    }

    private var displaySection: some View {
        Section {
            Toggle(isOn: autoBrightnessBindingWithAnimation) {
                SettingsLabel("Auto-Brightness", systemImage: "sun.max.fill", color: .orange)
            }
            .disabled(!bleModel.isConnected)

            if !bleModel.autoBrightness {
                Slider(value: brightnessBinding, in: 0...255, step: 15) {
                    Text("Brightness")
                } minimumValueLabel: {
                    Image(systemName: "sun.min")
                } maximumValueLabel: {
                    Image(systemName: "sun.max")
                }
                .foregroundStyle(.secondary)
                .disabled(!bleModel.isConnected)
            } else {
                Toggle(isOn: mouthBrightnessOverrideBinding) {
                    SettingsLabel("Maw Brightness Override", systemImage: "mouth.fill", color: .orange)
                }
                .disabled(!bleModel.isConnected)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Auto-Brightness Floor")
                        .accessibilityHidden(true)
                    Slider(value: autoBrightnessFloorBinding, in: 15...255, step: 5) {
                        Text("Auto-Brightness Floor")
                    } minimumValueLabel: {
                        Image(systemName: "sun.min")
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "sun.max")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!bleModel.isConnected)
            }
        } header: {
            Text("Display")
        } footer: {
            Text("Changes are saved to the controller immediately.")
        }
    }

    private var effectsSection: some View {
        Section("Effects") {
            Toggle(isOn: auroraModeBinding) {
                SettingsLabel(
                    "Aurora Mode",
                    icon: SettingsIcon(
                        systemImage: "sparkles",
                        background: LinearGradient(
                            colors: [.pink, .purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
            }
            .disabled(!bleModel.isConnected)

            Toggle(isOn: matrixRainInsteadOfPlasmaBinding) {
                SettingsLabel("Matrix Rain Instead of Plasma", systemImage: "character.textbox", color: .purple)
            }
            .disabled(!bleModel.isConnected)

            Picker(selection: boopModeBinding) {
                Text("Default").tag(UInt8(0))
                Text("Advanced Boop 1").tag(UInt8(1))
                Text("Advanced Boop 2").tag(UInt8(2))
                Text("Advanced Boop 4").tag(UInt8(3))
            } label: {
                SettingsLabel("Boop Behavior", systemImage: "hand.tap.fill", color: .purple)
            }
            .pickerStyle(.menu)
            .disabled(!bleModel.isConnected)
        }
    }

    private var sensorsAndPowerSection: some View {
        Section("Sensors & Power") {
            Toggle(isOn: accelerometerBinding) {
                SettingsLabel("Accelerometer", systemImage: "gyroscope", color: .teal)
            }
            .disabled(!bleModel.isConnected)

            Toggle(isOn: sleepModeBinding) {
                SettingsLabel("Sleep Mode", systemImage: "moon.fill", color: .indigo)
            }
            .disabled(!bleModel.isConnected)

            Picker(selection: $selectedUnits) {
                ForEach(TempUnit.allCases) { unit in
                    Text(unit.shortLabel).tag(unit)
                }
            } label: {
                SettingsLabel("Temperature Units", systemImage: "thermometer.medium", color: .red)
            }
            .pickerStyle(.menu)
            .disabled(!bleModel.isConnected)
        }
    }

    private var statusIndicatorsSection: some View {
        Section("Status Indicators") {
            Toggle(isOn: disableBleIndicatorBinding) {
                SettingsLabel("Disable BLE Indicator Light", systemImage: "lightbulb.slash.fill", color: .blue)
            }
            .disabled(!bleModel.isConnected)

            Toggle(isOn: disableBleStatusIconBinding) {
                SettingsLabel("Hide BLE Status Icon", systemImage: "eye.slash.fill", color: .blue)
            }
            .disabled(!bleModel.isConnected)
        }
    }

    private var hardwareSection: some View {
        Section {
            Toggle(isOn: waveshareBoostBinding) {
                SettingsLabel("Waveshare Brightness Boost", systemImage: "sun.max.trianglebadge.exclamationmark", color: .orange)
            }
            .disabled(!bleModel.isConnected)
        } header: {
            Text("Hardware")
        } footer: {
            Text("Changing brightness boost restarts the controller.")
        }
    }
}

// MARK: - Advanced

private struct AdvancedSettingsPage: View {
    @ObservedObject var bleModel: AccessoryViewModel
    @Binding var fancyMode: Bool
    let onResetToDefaults: () -> Void

    @State private var showResetConfirmation = false

    var body: some View {
        List {
            Section {
                Toggle("Fancy Mode", isOn: $fancyMode)
                NavigationLink("Connection Parameters") {
                    AdvancedSettingsView(bleModel: bleModel)
                }
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Text("Reset to Defaults")
                        .frame(maxWidth: .infinity)
                }
                .confirmationDialog(
                    "Reset all settings to their defaults?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset to Defaults", role: .destructive) {
                        onResetToDefaults()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } footer: {
                Text("Restores app preferences and the controller configuration to their defaults.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Disconnected") {
    NavigationStack {
        SettingsView(
            bleModel: .previewDisconnected,
            selectedMatrix: .constant(.array)
        )
    }
}

#Preview("Scanning") {
    NavigationStack {
        SettingsView(
            bleModel: .previewScanning,
            selectedMatrix: .constant(.array)
        )
    }
}

#Preview("Connected") {
    NavigationStack {
        SettingsView(
            bleModel: .previewConnected,
            selectedMatrix: .constant(.dot)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Error State") {
    NavigationStack {
        SettingsView(
            bleModel: .previewError,
            selectedMatrix: .constant(.wled)
        )
    }
}
#endif
