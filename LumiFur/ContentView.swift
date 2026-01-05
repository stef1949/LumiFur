//
//  ContentView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//

import AVKit
import Charts
import Combine
import CoreBluetooth
import CoreHaptics
import CoreImage
import MarkdownUI
import SwiftUI
import UniformTypeIdentifiers
import os

let actions = SharedOptions.protoActionOptions3
let configs = SharedOptions.protoConfigOptions

// IOS 18.0 features
//import AccessorySetupKit

// ----- iOSViewModel Definition -----
// (Technically possible to put it here)
@MainActor
final class iOSViewModel: ObservableObject {
    @Published var receivedCommand: String = "None"
    @Published var receivedFaceFromWatch: String? = nil

    private let bleModel: AccessoryViewModel
    private var cancellables = Set<AnyCancellable>()

    init(bleModel: AccessoryViewModel) {
        self.bleModel = bleModel

        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if isPreview { return }

        WatchConnectivityManager.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messageData in
                guard let self else { return }

                if let command = messageData["command"] as? String, command == "setFace" {
                    self.receivedCommand = command

                    if let view = messageData["view"] as? Int {
                        print("iOS ViewModel: Received 'setFace' command from watch for view: \(view)")
                        self.bleModel.setView(view)          // ✅ FIXED
                        self.receivedFaceFromWatch = nil
                    } else if let face = messageData["faceValue"] as? String {
                        print("iOS ViewModel: Received OLD format `faceValue`: \(face). Please ensure watch app is updated.")
                        self.receivedFaceFromWatch = face
                    } else {
                        print("iOS ViewModel: Received 'setFace' command but 'view' key was missing or not an Int.")
                    }
                } else if let command = messageData["command"] as? String {
                    self.receivedCommand = command
                    print("iOS ViewModel: Received other command: \(command)")
                }
            }
            .store(in: &cancellables)
    }
}
struct WidgetItem: Identifiable, Equatable {
    let id: Int  // ← stable index, not UUID()
    let title: String
    let description: String
    let iconName: String
}

let widgetItems: [WidgetItem] = [
    WidgetItem(
        id: 0,
        title: "Non-Blocking Architecture",
        description: """
            • Smooth optimized dynamic animations
            • Power-saving features with CPU speed reduction and brightness adjustment
            • New sleep mode triggers via accelerometer and BLE wake-up commands
            • Customized breathing effect and low-sensitivity motion detection during sleep
            """,
        iconName: "cpu"
    ),
    WidgetItem(
        id: 1,
        title: "New Face Effects",
        description: """
            • Plasma animation functions for a smooth, dynamic facial display
            • Non-blocking blink animations and blush effect with easing functions
            • Rotating spiral animation triggered via strong shake detection
            """,
        iconName: "sparkles"
    ),
    WidgetItem(
        id: 2,
        title: "View Control & Temperature Updates",
        description: "• Sleep modes for improved battery life",
        iconName: "thermometer"
    ),
    WidgetItem(
        id: 3,
        title: "Robust Sensor Integration",
        description: """
            • Proximity sensor integration for triggering visual effects (e.g., blush)
            • Accelerometer-based motion detection with dual sensitivity for active and sleep modes
            • Adaptive brightness
            """,
        iconName: "sensor.tag.radiowaves.forward"
    ),
]

struct AppInfo {
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "N/A"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "N/A"
    }

    static var versionDisplay: String {
        "\(appVersion) (\(buildNumber))"
    }
}

extension ConnectionState {
    var toolbarStatusText: String {
        switch self {
        case .connected:    return "Connected"
        case .connecting:   return "Connecting…"
        case .disconnected: return "Disconnected"
        case .scanning:     return "Scanning…"
        case .bluetoothOff: return "Turn on Bluetooth"
        case .reconnecting: return "Reconnecting…"
        case .failed:       return "Error"
        case .unknown:      return "Unknown Error"
        }
    }
}

// MARK: ContentView
struct ContentView: View {
    @StateObject private var ledModel = LEDPreviewModel()
    @Environment(\.scenePhase) private var scenePhase
    //@StateObject private var accessoryViewModel = AccessoryViewModel()
    
    // 1. Declare this as an @ObservedObject. It will receive the instance
        //    created in the App struct.
    @ObservedObject var bleModel: AccessoryViewModel
    
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = true
    @AppStorage("fancyMode") private var fancyMode: Bool = false
    @AppStorage("autoBrightness") private var autoBrightness = true
    @AppStorage("accelerometer") private var accelerometer = true
    @AppStorage("sleepMode") private var sleepMode = true
    @AppStorage("auroraMode") private var auroraMode = true
    @AppStorage("customMessage") private var customMessage = false
    //@AppStorage("charts") var isChartsExpanded = false
    @AppStorage("charts") var isChartsExpanded = false // This now drives the ChartView
    @State var auroraModeEnabled = false
    @State private var customMessageText: String = ""
    @State private var showCustomMessagePopup = false
    
    // LEDPreview Valiables
    @State private var isLedArrayExpanded: Bool = false
    @State private var ledStates: [[Color]] = Array(
            repeating: Array(repeating: .black, count: 32),
            count: 64
        )
    
    @StateObject private var viewModel: iOSViewModel  // Instantiates the class defined above

    init(bleModel: AccessoryViewModel) {
            self.bleModel = bleModel
            _viewModel = StateObject(wrappedValue: iOSViewModel(bleModel: bleModel))
        }
    
    @State private var errorMessage: String?
    
    @State private var selectedSidebarItem: SidebarItem? = .dashboard
    @State private var showSplash = true  // Local state to control the splash screen appearance.
    @State private var showQuickControls = false
    
    @State private var drawProgress: CGFloat = 1.0
    
    @Environment(\.colorScheme) var colorScheme  // Colot Scheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var overlayColor: Color {
        colorScheme == .dark ? .init(uiColor: .systemGray6) : .white
    }
    
    @State private var matrixStyle: MatrixStyle = .array // The real source of truth
    
    @Namespace var namespace

    fileprivate let twoColumnGrid = [
        GridItem(.adaptive(minimum: 125, maximum: 250))
    ]
    private let twoRowOptionGrid = [
        GridItem(.adaptive(minimum: 25, maximum: 250))
    ]
    @State private var dotMatrices: [[Bool]] = Array(
        repeating: Array(repeating: false, count: 64),
        count: 32
    )
    
    //Connectivity Options
    enum Connection: String, CaseIterable, Identifiable {
        case bluetooth, wifi, matter, z_wave
        var id: Self { self }
    }
    
    enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
        case dashboard = "Dashboard"
        // Add more cases here, e.g.:
        case profile = "Custom"
        case settings = "Settings"
        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .dashboard: return "house"
            case .profile: return "inset.filled.center.rectangle.badge.plus"
            case .settings: return "gearshape"
            }
        }
    }
    
    // Taptic Engine
    @State private var engine: CHHapticEngine?
    
    // MARK: — Haptics Helpers
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptics init error: \(error.localizedDescription)")
        }
    }

    func complexSuccess() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }
        var events = [CHHapticEvent]()
        let intensity = CHHapticEventParameter(
            parameterID: .hapticIntensity,
            value: 1
        )
        let sharpness = CHHapticEventParameter(
            parameterID: .hapticSharpness,
            value: 1
        )
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0
        )
        events.append(event)
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Haptics play error: \(error.localizedDescription)")
        }
    }
    
    private var toolbarModel: ToolbarStatusModel {
        .init(
            connectionState: bleModel.connectionState,
            toolbarStatusText: bleModel.connectionState.toolbarStatusText,
            signalStrength: bleModel.signalStrength,
            luxValue: Int(bleModel.luxValue)
        )
    }
    
    var body: some View {
        #if os(macOS)
            NavigationSplitView {
                List(SidebarItem.allCases, selection: $selectedSidebarItem) {
                    item in
                    Text(item.rawValue)
                }
                .navigationTitle("Menu")
            } detail: {
                detailContent
            }
        #else
            TabView(selection: $selectedSidebarItem) {
                // MARK: – Custom Tab
                NavigationStack {
                    CustomLedView()
                        .navigationTitle("Custom View")
                }
                .tabItem {
                    Label(
                        SidebarItem.profile.rawValue,
                        systemImage: SidebarItem.profile.iconName
                    )
                }
                .tag(SidebarItem.profile)
                //.disabled(true)
                // MARK: – Dashboard Tab
                NavigationStack {
                    detailContent
                    //.navigationTitle("LumiFur")
                    //.navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { showQuickControls.toggle() } label: {
                                    Image(systemName: "line.3.horizontal")
                                }
                                .accessibilityLabel("Quick Controls")
                                .accessibilityHint("Shows quick controls and the LumiFur logo")
                            
                                // Present as popover on regular width (iPad), sheet on compact (iPhone)
                                .popover(
                                    isPresented: Binding(
                                        get: { showQuickControls && horizontalSizeClass == .regular },
                                        set: { if !$0 { showQuickControls = false } }
                                    ),
                                    attachmentAnchor: .rect(.bounds),
                                    arrowEdge: .top
                                ) {
                                    quickControlsContent
                                }
                                .popover(
                                    isPresented: Binding(
                                        get: { showQuickControls && horizontalSizeClass == .compact },
                                        set: { if !$0 { showQuickControls = false } }
                                    )
                                ) {
                                    quickControlsContent
                                        .presentationBackground(.clear)
                                        .presentationCompactAdaptation(.popover)
                                        .padding()
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                HeaderView(
                                    connectionState: toolbarModel.connectionState,
                                    // Use a stable status for width; don’t include fast-changing numbers
                                    connectionStatus: toolbarModel.connectionState.toolbarStatusText,
                                    // Still pass the real numbers, but HeaderView must not let them change width
                                    signalStrength: toolbarModel.signalStrength,
                                    luxValue: Double(toolbarModel.luxValue)
                                )
                                //.animation(.smooth(duration: 0.25), value: bleModel.connectionState)
                                //.animation(.smooth(duration: 0.25), value: bleModel.connectionState.toolbarStatusText)
                                .fixedSize(horizontal: true, vertical: false) // allow grow/shrink naturally
                            }
                        }
                }
                .tabItem {
                    Label(SidebarItem.dashboard.rawValue, systemImage: SidebarItem.dashboard.iconName)
                }
                .tag(SidebarItem.dashboard)
                // MARK: – Settings Tab
                
                //Divider()
                NavigationStack {
                    SettingsView(
                        bleModel: bleModel, selectedMatrix: $matrixStyle
                    )
                    .navigationTitle("Settings")
                }
                .tabItem {
                    Label(
                        SidebarItem.settings.rawValue,
                        systemImage: SidebarItem.settings.iconName
                    )
                }
                .tag(SidebarItem.settings)
                .badge("!")
            }
            .navigationTransition(.zoom(sourceID: "expand", in: namespace))
            .onAppear {
                if selectedSidebarItem == .dashboard {
                    prepareHaptics()
                }
            }
        //.tabBarMinimizeBehavior(.automatic)
        /*
         .tabViewBottomAccessory {
         ChartView()
         }
         */
        /*
         .safeAreaInset(edge: .bottom) {
         ChartView()
         .frame(height: 80)                // whatever height you need
         .glassEffect()
         //.containerRelativeShape()         // match iOS card style
         }
         */
#endif
        /*
         .toolbar {
         ToolbarItem(placement: .navigationBarTrailing) {
         NavigationLink(destination: SettingsView(bleModel: accessoryViewModel, selectedMatrix: $selectedMatrix)) {
         Image(systemName: "gear")
         .glassEffect(.regular.tint(.orange).interactive())
         }
         }
         }
         */
        
    }
    @AppStorage("tempUnit") private var tempUnitRaw: String = TempUnit.celsius.rawValue
    private var selectedUnitsBinding: Binding<TempUnit> {
        Binding(
            get: { TempUnit(rawValue: tempUnitRaw) ?? .celsius },
            set: { tempUnitRaw = $0.rawValue }
        )
    }
    @ViewBuilder
    private var detailContent: some View {
        //@AppStorage("charts") var isChartsExpanded = false
        @AppStorage("hasLaunchedBefore") var hasLaunchedBefore: Bool = true

        ZStack {
            if selectedSidebarItem == .dashboard {
                VStack {
                    /*
                    HStack{
                        HeaderView(
                            connectionState: bleModel.connectionState,
                            connectionStatus: bleModel.connectionStatus,
                            signalStrength: bleModel.signalStrength,
                            luxValue: Double(bleModel.luxValue)
                        )
                    }
                     */
                    //ledArraySection
                    //.border(.green)
                    
                    FaceGridSection(
                        selectedView: bleModel.selectedView,
                        onSetView: { bleModel.setView($0) },
                        auroraModeEnabled: auroraModeEnabled
                        //items: SharedOptions.protoActionOptions3
                    )
                    //.zIndex(-1)
                    
                    ChartView(
                        isExpanded: $isChartsExpanded,
                        accessoryViewModel: bleModel,
                        selectedUnits: selectedUnitsBinding
                    )
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 32))
                    .frame(maxHeight: isChartsExpanded ? 160 : 55) // Animate height change
                    .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isChartsExpanded.toggle()
                            }
                        }
                    .padding(.horizontal)
                    .padding(.bottom)
                    // This animation smoothly handles the frame height change.
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isChartsExpanded)
                }
                .onAppear(perform: prepareHaptics)
                .onChange(of: viewModel.receivedFaceFromWatch) { _, newFace in
                    handleWatchFaceSelection(face: newFace)
                }
        } else {
            Text("Select an item from the sidebar")
                .foregroundStyle(.secondary)
        }
        
        if !hasLaunchedBefore && showSplash {
                SplashView(showSplash: $showSplash)
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        )
                    )
            }
        }
    }

    static let gradientStart = Color(
        red: 0 / 255,
        green: 0 / 255,
        blue: 0 / 255
    )
    static let gradientEnd = Color(
        red: 239.0 / 255,
        green: 172.0 / 255,
        blue: 120.0 / 255
    )
    // Define data structure for options
    struct OptionConfig: Identifiable {
        let id = UUID()
        let title: String
        let binding: Binding<Bool>
        let type: OptionType
        let action: ((Bool) -> Void)?  // Optional action for generic toggles

        // Initializer for standard options
        init(
            title: String,
            binding: Binding<Bool>,
            type: OptionType,
            action: ((Bool) -> Void)? = nil
        ) {
            self.title = title
            self.binding = binding
            self.type = type
            self.action = action
        }
    }
    // Data source for the grid (excluding custom message initially, as it has unique behavior)
    private var standardOptions: [OptionConfig] {
        [
            OptionConfig(
                title: "Auto Brightness",
                binding: $autoBrightness,
                type: .autoBrightness
            ) { newValue in
                print("Auto brightness changed to \(newValue)")
                // accessoryViewModel.autoBrightness = newValue
                // accessoryViewModel.writeConfigToCharacteristic()
            },
            OptionConfig(
                title: "Accelerometer",
                binding: $accelerometer,
                type: .accelerometer
            ) { newValue in
                print("Accelerometer changed to \(newValue)")
                // accessoryViewModel.accelerometerEnabled = newValue
                // accessoryViewModel.writeConfigToCharacteristic()
            },
            OptionConfig(
                title: "Sleep Mode",
                binding: $sleepMode,
                type: .sleepMode
            ) { newValue in
                print("Sleep mode changed to \(newValue)")
                // accessoryViewModel.sleepModeEnabled = newValue
                // accessoryViewModel.writeConfigToCharacteristic()
            },
            OptionConfig(
                title: "Aurora Mode",
                binding: $auroraMode,
                type: .auroraMode
            ) { newValue in  // Fixed typo "Aroura"
                print("Aurora Mode changed to \(newValue)")
                // accessoryViewModel.auroraModeEnabled = newValue
                // accessoryViewModel.writeConfigToCharacteristic()
            },
        ]
    }
    private var optionGridSection: some View {
        ScrollView(.vertical, showsIndicators: false) {  // Added showsIndicators: false
            VStack(alignment: .leading, spacing: 8) {
                ForEach(standardOptions) { option in
                    OptionToggleView(
                        title: option.title,
                        isOn: option.binding,
                        optionType: option.type
                    )
                    .onChange(of: option.binding.wrappedValue) { oldValue, newValue in
                        option.action?(newValue)
                    }
                }
                // Custom Message Toggle - handled separately due to unique popover logic
                OptionToggleView(
                    title: "Custom Message",
                    isOn: $customMessage,
                    optionType: .customMessage
                )
                .onChange(of: customMessage) { oldValue, newValue in
                    if newValue {
                        showCustomMessagePopup = true
                    }
                }
                .popover(
                    isPresented: $showCustomMessagePopup,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .top
                ) {
                    customMessagePopoverView
                        .presentationBackground(.clear)
                        .presentationCompactAdaptation(.popover)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        //.frame(maxWidth: .infinity, maxHeight: 80)
        //.scrollContentBackground(.hidden)
        .scrollClipDisabled(true)  // Explicitly false, default is true in some contexts. Check if still needed.
        // If you want content to extend beyond scroll view bounds, set true.
        .ignoresSafeArea(.keyboard, edges: .all)  // Keep this for keyboard behavior
    }

    // Extracted Popover View for clarity
    private var customMessagePopoverView: some View {
        VStack(spacing: 12) {
            Text("Custom Message")
                .font(.headline)
            TextField("Type…", text: $customMessageText)
                //.textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
            HStack {
                Spacer()
                Button("Cancel") {
                    customMessage = false  // Turn off the toggle
                    showCustomMessagePopup = false
                    // customMessageText = "" // Optionally clear text on cancel
                }
                Button("OK") {
                    showCustomMessagePopup = false
                    // Here you would typically use customMessageText
                    // e.g., accessoryViewModel.customMessageText = customMessageText
                    // accessoryViewModel.customMessageEnabled = customMessage // which is true
                    // accessoryViewModel.writeConfigToCharacteristic()
                    print("Custom message set: \(customMessageText)")
                    bleModel.customMessage = customMessageText
                    bleModel.sendScrollText(customMessageText)
                    // Optionally set a default speed on first send; comment out if not desired
                    // bleModel.sendScrollSpeed(50)
                    if customMessageText.isEmpty {  // If OK is pressed with no text, maybe turn off the feature?
                        // customMessage = false // Or provide feedback to user
                    }
                }
            }
            HStack(spacing: 12) {
                Text("Speed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach([100, 150, 200, 250], id: \.self) { s in
                    Button("\(s)") {
                        bleModel.sendScrollSpeed(UInt8(s))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!bleModel.isConnected)
                }
            }
        }
        .padding(12)
        .frame(width: 300, height: 140)  // Slightly increased height for better spacing
        //.glassEffect(.regular.tint(.blue))
    }
    
    // Quick Controls content used in both popover and sheet
    private var quickControlsContent: some View {
        VStack(spacing: 12) {
            /*
            Image("LumiFur_Controller_AK")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
             */
            Text("LumiFur")
                .font(Font.custom("Meloriac", size: 35))
                .frame(width: 150)
                //.border(.purple)
            optionGridSection
                //.frame(maxHeight: 120)
        }
        .padding()
    }
    
    // MARK: –––––––––––––––––––––––––––––––––
    // 1) Standalone grid view
    struct FaceGridSection: View {
        // No longer observing the whole VM, but taking specific values/callbacks
        let selectedView: Int
        let onSetView: (Int) -> Void  // Callback to update the selection
        let auroraModeEnabled: Bool
        //let items: [SharedOptions.ProtoAction]  // Pass the data directly
        
        @Environment(\.colorScheme) private var colorScheme
        
        // Computed once per body re-evaluation of FaceGridSection
        private var lightColor: Color { colorScheme == .dark ? .white : .black }
        private var darkColor: Color {
            colorScheme == .dark ? .black : .init(UIColor.systemGray5)
        }
        // Make grid configuration static so it's not re-created
        private static let twoColumnGrid = [
            GridItem(.adaptive(minimum: 100, maximum: 250))
        ]
        
        /*
        // The tap action now uses the passed-in callback and selectedView
        private func faceTap(_ faceIndex: Int) {
            guard faceIndex != selectedView else { return }
            onSetView(faceIndex)
        }
        */
        
        // Access the static property directly and use .map to convert it.
        @State private var items: [FaceItem] = SharedOptions.protoActionOptions3.map { FaceItem(content: $0) }
        
        
        // --- The rest of your view remains the same ---
        @State private var selectedItemID: FaceItem.ID?
        
        //@Namespace private var glassNamespace
        
        var body: some View {
            /*
             // --- DEBUG TEXT ---
             Text("Number of items: \(items.count)")
             .foregroundColor(.red)
             .font(.headline)
             .padding()
             */
           // GlassEffectContainer {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Self.twoColumnGrid) {  // Use Self.twoColumnGrid
                        // 2. ForEach loops over identifiable data, not indices.
                        ForEach(items) { item in
                            FaceCellView(
                                // 3. Pass the item and selection state cleanly.
                                item: item,
                                isSelected: selectedItemID == item.id,
                                auroraModeEnabled: auroraModeEnabled,
                                overlayColor: lightColor,
                                backgroundColor: darkColor
                                //namespace: glassNamespace,
                                
                                // The action now provides the item directly.
                            ) {tappedItem in
                                // Update selection state using the stable ID
                                selectedItemID = tappedItem.id
                                // 2. Find the 0-based index of the tapped item in our array.
                                if let index = items.firstIndex(where: { $0.id == tappedItem.id }) {
                                    // 3. Convert to the 1-based command index that the hardware expects.
                                    let commandIndex = index + 1
                                    // 4. Call the parent's `onSetView` function to send the command.
                                    onSetView(commandIndex)
                                    // Optional but recommended: Add a print statement for debugging.
                                    print("Tapped item with content '\(tappedItem.content)'. Sending command for view: \(commandIndex)")
                                }
                            }
                            .equatable() // This is good, keep it!
                        }
                    }
                    .padding(.horizontal)
                    //.scrollContentBackground(.hidden)
                }
                .scrollClipDisabled()
                .scrollDismissesKeyboard(.automatic)
                //.border(.red)
            // This watches for external changes (e.g., from the watch) and updates the local UI.
            .onChange(of: selectedView) { _, newViewIndex in
                let modelIndex = newViewIndex - 1
                if items.indices.contains(modelIndex) {
                    selectedItemID = items[modelIndex].id
                } else {
                    selectedItemID = nil // Deselect if index is out of bounds
                }
            }
        }
    }
    
    // MARK: - Helper Functions (Place handleWatchFaceSelection HERE)
    
    /// Handles processing the face selection received from the watch.
    private func handleWatchFaceSelection(face: String?) {  // <--- DEFINITION INSIDE ContentView
        guard let selectedFace = face else {
            print("Watch face selection cleared or invalid.")
            return
        }
        
        // Find the index where the enum's String == selectedFace
        if let index = SharedOptions.protoActionOptions3.firstIndex(where: {
            action in
            switch action {
            case .emoji(let e): return e == selectedFace
            case .symbol(let s): return s == selectedFace
            }
        }) {
            let viewToSet = index + 1
            print(
                "Watch requested face '\(selectedFace)' at index \(index). Setting view \(viewToSet)."
            )
            bleModel.setView(viewToSet)
        } else {
            print(
                "Received face '\(selectedFace)' from watch, but it wasn’t in protoActionOptions3."
            )
        }
    }

    /// Given a numeric “view” (1…n), return the matching emoji or symbol-string,
    /// so you can show it back in your SwiftUI view or send it to the watch.
    private func getFaceForView(_ view: Int) -> String {
        let idx = view - 1
        guard SharedOptions.protoActionOptions3.indices.contains(idx) else {
            return "❓"
        }
        switch SharedOptions.protoActionOptions3[idx] {
        case .emoji(let e): return e
        case .symbol(let s): return s
        }
    }
}



struct ChartEntryAnimation: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

struct ConnectedDeviceView: View {
    let peripheral: PeripheralDevice

    var body: some View {
        HStack {
            Image("LumiFur_Controller_AK")
                .resizable()
                .aspectRatio(contentMode: .fit)
            VStack(alignment: .leading) {
                Text(peripheral.name)
                    .font(.headline)
                Text(peripheral.id.uuidString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var bleModel: AccessoryViewModel

    // Example advanced settings state variables.
    // @State private var autoReconnect: Bool = true
    @AppStorage("autoReconnect") private var autoReconnect: Bool = true
    @AppStorage("rssiMonitoringEnabled") private var rssiMonitoringEnabled:
        Bool = false
    @AppStorage("rssiUpdateInterval") private var rssiUpdateInterval: Double =
        1.0

    var body: some View {
        Form {
            // Connection Options Section
            Section(header: Text("Connection Options")) {
                Toggle("Auto Reconnect", isOn: $autoReconnect)
                    .onChange(of: autoReconnect) { oldValue, newValue in
                        bleModel.autoReconnectEnabled = newValue
                        print(
                            "Auto Reconnect changed from \(oldValue) to \(newValue)"
                        )
                    }
                if bleModel.isConnected {
                    Button("Disconnect Device") {
                        bleModel.disconnect()
                    }
                    .animation(
                        .easeInOut(duration: 0.3),
                        value: bleModel.isConnected
                    )
                    Button("Reconnect Device") {
                        bleModel.scanForDevices()
                    }
                    .animation(
                        .easeInOut(duration: 0.3),
                        value: bleModel.isConnected
                    )
                }
            }
            // RSSI Monitoring Section
            Section(
                header: Text("RSSI Monitoring"),
                footer: Text(
                    "Will periodically read the RSSI value of the connected device. This may lead to increased battery drain of your iOS device."
                )
            ) {
                Toggle("Enable RSSI Monitoring", isOn: $rssiMonitoringEnabled)
                    .onChange(of: rssiMonitoringEnabled) { _, newValue in
                        Task { @MainActor in
                            if newValue {
                                bleModel.startRSSIMonitoring()
                            } else {
                                bleModel.stopRSSIMonitoring()
                            }
                        }
                    }
                if rssiMonitoringEnabled {
                    Stepper(
                        "Update Interval: \(rssiUpdateInterval, specifier: "%.1f") sec",
                        value: $rssiUpdateInterval,
                        in: 0.5...5.0,
                        step: 0.5
                    )
                    .onChange(of: rssiUpdateInterval) { oldValue, newValue in
                        // If your model supports adjustable intervals for reading RSSI, update it here.
                        print(
                            "RSSI update interval changed from \(oldValue) to \(newValue)"
                        )
                    }
                }
            }
            // Debug / Status Information Section
            Section(header: Text("Debug Info")) {
                Text("Connection Status: \(bleModel.connectionStatus)")
                Text("Selected View: \(bleModel.selectedView)")
                Text("Temperature: \(bleModel.temperature)")
                Text("Signal Strength: \(bleModel.signalStrength)dBm")
            }
            Section(
                header: Text("Console"),
                footer: Text(
                    "Debug logs for your LumiFur Controller will be diplayed in this field."
                )
            ) {
                RoundedRectangle(cornerRadius: 25)
                    .frame(minWidth: 200, minHeight: 200)
                    .foregroundStyle(Color.clear)
            }
        }
        .navigationTitle("Advanced Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}



 


#Preview("ContentView") {
    // 1. Create a @State variable to be the source of truth for this preview.
    //    This variable only exists for the preview's lifetime.
    @Previewable @State var previewMatrixStyle: MatrixStyle = .array

    // 2. ContentView now uses this local state. When you use the picker
    //    in the preview canvas, `previewMatrixStyle` will actually change.
    //    (Assuming ContentView has an init that accepts these, or default values)
    ContentView(bleModel: AccessoryViewModel())
}
 
#Preview("SplashView") {
    SplashView(showSplash: .constant(true))
}

#Preview("Whats New") {
    WhatsNew()
}

#Preview("Info View") {
    InfoView()
}

#Preview("Settings") {
    @Previewable @State var isScanningForButton = true
    SettingsView(
        bleModel: AccessoryViewModel(),
        selectedMatrix: .constant(MatrixStyle.array)
    )
}

#Preview("Custom View") {
    CustomLedView()
}

#Preview("Release Notes (Populated)") {
    // --- OPTIMIZATION 1: Create sample data for the preview ---
    // This allows you to design and test your view with realistic content
    // without needing to make a network call.
    let sampleReleases: [GitHubRelease] = [
        GitHubRelease(
            id: 1,
            tagName: "v1.2.0",
            name: "Major Feature Update",
            body: """
            ## New Features
            
            - You can now sync your settings across devices using iCloud.
            - Added support for new **WLED** matrix styles.
            - The UI has been updated with a fresh, modern look.
            
            ### Bug Fixes
            
            *   Fixed a bug where the app would occasionally crash on launch.
            *   Improved Bluetooth connection stability.
            *   The battery indicator is now more accurate.
            """,
            publishedAt: Date() // Represents "now"
        ),
        GitHubRelease(
            id: 2,
            tagName: "v1.1.1",
            name: "Minor Bug Fixes",
            body: "This update addresses minor bugs and improves performance.",
            publishedAt: Date().addingTimeInterval(-86400 * 7) // Represents 1 week ago
        ),
        GitHubRelease(
            id: 3,
            tagName: "v1.1.0",
            name: nil, // Test how it looks when 'name' is nil
            body: nil, // Test how it looks when 'body' is nil
            publishedAt: Date().addingTimeInterval(-86400 * 30) // Represents 1 month ago
        )
    ]
    
    // --- OPTIMIZATION 2: Preview the view inside a NavigationStack ---
    // This is crucial for seeing the navigation title correctly.
    return NavigationStack {
        ReleaseNotesView(
            title: "App Releases",
            releases: sampleReleases // Pass the mock data to the view
        )
    }
}

#Preview("Release Notes (Empty)") {
    // It's also good practice to preview the empty state.
    NavigationStack {
        ReleaseNotesView(
            title: "Controller Releases",
            releases: [] // Pass an empty array
        )
    }
}


// ——————— Your mock view model at file-scope ———————
@MainActor
class MockViewModel: AccessoryViewModel {
    init(state: ConnectionState, rssi: Int = -65) {
        super.init()
        self.connectionState = state
        self.signalStrength = rssi
    }
}

/*
 // ——————— Three separate #Preview entries at file-scope ———————
 #Preview("Connected") {
 @Previewable @StateObject var accessoryViewModel = MockViewModel(state: .connected)
 ContentView(accessoryViewModel: accessoryViewModel)
 }

 #Preview("Disconnected") {
 @Previewable @StateObject var accessoryViewModel = MockViewModel(state: .disconnected, rssi: -100)
 ContentView(accessoryViewModel: accessoryViewModel)
 }

 #Preview("Connecting") {
 @Previewable @StateObject var accessoryViewModel = MockViewModel(state: .connecting, rssi: -70)
 ContentView(accessoryViewModel: accessoryViewModel)
 }
 }
 */


