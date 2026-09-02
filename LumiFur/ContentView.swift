//
//  ContentView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//

import AVKit
import Combine
import CoreBluetooth
import CoreHaptics
import CoreImage
import SwiftUI
import UniformTypeIdentifiers
import os

#if canImport(UIKit)
import UIKit
#endif

let actions = SharedOptions.protoActionOptions
let configs = SharedOptions.protoConfigOptions
private let contentLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.richies3d.LumiFur3.app",
    category: "ContentView"
)

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
                        contentLogger.debug("Received legacy watch setFace command for view \(view, privacy: .public)")
                        _ = self.bleModel.setView(view)
                        self.receivedFaceFromWatch = nil
                    } else if let face = messageData["faceValue"] as? String {
                        contentLogger.notice("Received legacy faceValue payload from watch")
                        self.receivedFaceFromWatch = face
                    } else {
                        contentLogger.error("Received legacy setFace command without a valid view value")
                    }
                } else if let command = messageData["command"] as? String {
                    self.receivedCommand = command
                    contentLogger.debug("Received legacy watch command \(command, privacy: .public)")
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

// MARK: ContentView
struct ContentView: View {
    @StateObject private var ledModel = LEDPreviewModel()
    @Environment(\.scenePhase) private var scenePhase
    //@StateObject private var accessoryViewModel = AccessoryViewModel()
    
    @ObservedObject var bleModel: AccessoryViewModel
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("fancyMode") private var fancyMode: Bool = false
    //@AppStorage("charts") var isChartsExpanded = false
    @AppStorage("charts") var isChartsExpanded = false // This now drives the ChartView
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

    private var customMessageToggleBinding: Binding<Bool> {
        Binding(
            get: { showCustomMessagePopup || !bleModel.customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            set: { newValue in
                if newValue {
                    customMessageText = bleModel.customMessage
                    showCustomMessagePopup = true
                } else {
                    customMessageText = ""
                    bleModel.sendScrollText("")
                }
            }
        )
    }

    private var autoBrightnessBinding: Binding<Bool> {
        Binding(
            get: { bleModel.autoBrightness },
            set: { newValue in
                bleModel.autoBrightness = newValue
                bleModel.writeConfigToCharacteristic()
            }
        )
    }
    
    private var mouthBrightnessOverrideBinding: Binding<Bool> {
        Binding(
            get: { bleModel.mouthBrightnessOverrideEnabled },
            set: { newValue in
                bleModel.mouthBrightnessOverrideEnabled = newValue
                bleModel.writeConfigToCharacteristic()
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

        /// Keep the editor implementation available to development builds while
        /// removing the unfinished destination from the shipped navigation.
        static let isCustomEditorAvailable = false
        static var visibleCases: [SidebarItem] {
            allCases.filter { item in
                item != .profile || isCustomEditorAvailable
            }
        }

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
            contentLogger.error("Failed to initialize haptics: \(error.localizedDescription, privacy: .public)")
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
            contentLogger.error("Failed to play haptics: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    var body: some View {
        let _ = IdleCPUDiagnostics.shared.recordViewBody("ContentView")

        #if targetEnvironment(macCatalyst)
            NavigationSplitView {
                List(selection: $selectedSidebarItem) {
                    ForEach(SidebarItem.visibleCases) { item in
                        Label(item.rawValue, systemImage: item.iconName)
                            .tag(item)
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle("LumiFur")
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
            } detail: {
                CompatibleNavigationStack {
                    macDetailContent
                        .navigationTitle(selectedSidebarItem?.rawValue ?? "LumiFur")
                        .toolbar {
                            if selectedSidebarItem == .dashboard,
                               bleModel.dashboardState.allowsControllerActions {
                                ToolbarItem(placement: .primaryAction) {
                                    Button {
                                        showQuickControls.toggle()
                                    } label: {
                                        Label("Quick Controls", systemImage: "slider.horizontal.3")
                                    }
                                    .popover(isPresented: $showQuickControls, arrowEdge: .top) {
                                        quickControlsContent
                                            .frame(width: 280)
                                    }
                                }
                            }

                            ToolbarItem(placement: .automatic) {
                                ToolbarStatusHost(bleModel: bleModel)
                            }
                        }
                }
            }
            .navigationSplitViewStyle(.balanced)
            .onAppear(perform: normalizeSidebarSelection)
            .onChange(of: bleModel.dashboardState.allowsControllerActions) { _, actionsAvailable in
                if !actionsAvailable {
                    showQuickControls = false
                }
            }
        #else
            TabView(selection: $selectedSidebarItem) {
                // MARK: – Custom Tab
                if SidebarItem.isCustomEditorAvailable {
                    CompatibleNavigationStack {
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
                }
                // MARK: – Dashboard Tab
                CompatibleNavigationStack {
                    detailContent
                    //.navigationTitle("LumiFur")
                    //.navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            if bleModel.dashboardState.allowsControllerActions {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button { showQuickControls.toggle() } label: {
                                        Image(systemName: "line.3.horizontal")
                                    }
                                    .accessibilityLabel("Quick Controls")
                                    .accessibilityHint("Shows controller settings")

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
                                            .compatibleClearPopoverPresentation()
                                            .padding()
                                    }
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                ToolbarStatusHost(bleModel: bleModel)
                            }
                        }
                }
                .tabItem {
                    Label(SidebarItem.dashboard.rawValue, systemImage: SidebarItem.dashboard.iconName)
                }
                .tag(SidebarItem.dashboard)
                // MARK: – Settings Tab
                
                //Divider()
                CompatibleNavigationStack {
                    SettingsView(
                        bleModel: bleModel,
                        selectedMatrix: $matrixStyle,
                        isActive: selectedSidebarItem == .settings
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
            }
            .onAppear {
                normalizeSidebarSelection()

                if selectedSidebarItem == .dashboard {
                    prepareHaptics()
                }
            }
            .onChange(of: bleModel.dashboardState.allowsControllerActions) { _, actionsAvailable in
                if !actionsAvailable {
                    showQuickControls = false
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

    private func normalizeSidebarSelection() {
        guard let selectedSidebarItem,
              SidebarItem.visibleCases.contains(selectedSidebarItem) else {
            self.selectedSidebarItem = .dashboard
            return
        }
    }

    #if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var macDetailContent: some View {
        switch selectedSidebarItem ?? .dashboard {
        case .dashboard:
            DashboardContentView(
                bleModel: bleModel,
                isChartsExpanded: $isChartsExpanded,
                selectedUnits: selectedUnitsBinding,
                receivedFaceFromWatch: viewModel.receivedFaceFromWatch,
                onPrepareHaptics: prepareHaptics,
                onHandleWatchFaceSelection: handleWatchFaceSelection
            )

        case .settings:
            SettingsView(
                bleModel: bleModel,
                selectedMatrix: $matrixStyle,
                isActive: true
            )

        case .profile:
            if SidebarItem.isCustomEditorAvailable {
                CustomLedView()
            } else {
                ContentUnavailableView(
                    "Custom Editor Unavailable",
                    systemImage: "hammer",
                    description: Text("The custom editor is still being developed.")
                )
            }
        }
    }
    #endif

    @AppStorage("tempUnit") private var tempUnitRaw: String = TempUnit.celsius.rawValue
    private var selectedUnitsBinding: Binding<TempUnit> {
        Binding(
            get: { TempUnit(rawValue: tempUnitRaw) ?? .celsius },
            set: { tempUnitRaw = $0.rawValue }
        )
    }
    @ViewBuilder
    private var detailContent: some View {
        ZStack {
            if selectedSidebarItem == .dashboard {
               // if bleModel.isConnected {
                    
                    DashboardContentView(
                        bleModel: bleModel,
                        isChartsExpanded: $isChartsExpanded,
                        selectedUnits: selectedUnitsBinding,
                        receivedFaceFromWatch: viewModel.receivedFaceFromWatch,
                        onPrepareHaptics: prepareHaptics,
                        onHandleWatchFaceSelection: handleWatchFaceSelection
                    )
                
                // .disabled(bleModel.isConnected)
                /*
              } else {
                
                    VStack {
                    Spacer()
                        Image("mps3")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 250, height: 200)
                        
                        Text("Connect your LumiFur controller to get started")
                            .font(.title)
                            .padding()
                            .foregroundStyle(.white)
                        Spacer()
                 
                   }
                 
                }
            */
        } else {
            Text("Select an item from the sidebar")
                .foregroundStyle(.secondary)
        }
        
        if !hasCompletedOnboarding && showSplash {
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
                binding: autoBrightnessBinding,
                type: .autoBrightness
            ),
            /*
            OptionConfig(
                title: "Maw Max Brightness Override",
                binding: mouthBrightnessOverrideBinding,
                type: .mouthBrightnessOverride
            ),
             */
            OptionConfig(
                title: "Accelerometer",
                binding: accelerometerBinding,
                type: .accelerometer
            ),
            OptionConfig(
                title: "Sleep Mode",
                binding: sleepModeBinding,
                type: .sleepMode
            ),
            OptionConfig(
                title: "Aurora Mode",
                binding: auroraModeBinding,
                type: .auroraMode
            ),
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
                    .onChange(of: option.binding.wrappedValue) { _, newValue in
                        option.action?(newValue)
                    }
                }
                // Custom Message Toggle - handled separately due to unique popover logic
                OptionToggleView(
                    title: "Custom Message",
                    isOn: customMessageToggleBinding,
                    optionType: .customMessage
                )
                .popover(
                    isPresented: $showCustomMessagePopup,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .top
                ) {
                    customMessagePopoverView
                        .compatibleClearPopoverPresentation()
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        //.frame(maxWidth: .infinity, maxHeight: 80)
        //.scrollContentBackground(.hidden)
        .compatibleScrollClipDisabled(true)
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
                    customMessageText = bleModel.customMessage
                    showCustomMessagePopup = false
                }
                Button("OK") {
                    showCustomMessagePopup = false
                    bleModel.sendScrollText(customMessageText)
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
        .disabled(!bleModel.isConnected)
    }
    
    // MARK: –––––––––––––––––––––––––––––––––
    // 1) Standalone grid view
    struct FaceGridSection: View, Equatable {
        // No longer observing the whole VM, but taking specific values/callbacks
        let bleModel: AccessoryViewModel
        let selectedView: Int
        let onSetView: (Int) -> Void  // Callback to update the selection
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
        private static let items: [FaceItem] = SharedOptions.protoActionOptions.map { FaceItem(content: $0) }
        
        
        // --- The rest of your view remains the same ---
        @State private var showStrobeOptions = false
        
        //@Namespace private var glassNamespace
        
        var body: some View {
            let _ = IdleCPUDiagnostics.shared.recordViewBody("FaceGridSection")

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
                        ForEach(Self.items.indices, id: \.self) { index in
                            let item = Self.items[index]
                            let faceNumber = index + 1
                            let showsStrobeMenu = shouldShowStrobeMenu(
                                for: item,
                                faceNumber: faceNumber
                            )

                            FaceCellView(
                                // 3. Pass the item and selection state cleanly.
                                item: item,
                                faceNumber: faceNumber,
                                isSelected: selectedView == faceNumber,
                                overlayColor: lightColor,
                                backgroundColor: darkColor,
                                showsMenuButton: showsStrobeMenu,
                                onMenuTap: showsStrobeMenu ? { showStrobeOptions = true } : nil
                                //namespace: glassNamespace,
                                
                                // The action now provides the item directly.
                            ) { _ in
                                onSetView(faceNumber)
                            }
                            .equatable()
                            .popover(
                                isPresented: Binding(
                                    get: {
                                        shouldShowStrobeMenu(for: item, faceNumber: faceNumber) &&
                                        showStrobeOptions
                                    },
                                    set: { showStrobeOptions = $0 }
                                ),
                                attachmentAnchor: .rect(.bounds),
                                arrowEdge: .top
                            ) {
                                StrobeControlsView(
                                    bleModel: bleModel,
                                    onDone: { showStrobeOptions = false }
                                )
                                .compatiblePopoverPresentation()
                            }
                        }
                    }
                    .padding(.horizontal)
                    //.scrollContentBackground(.hidden)
                }
                .compatibleScrollClipDisabled()
                .compatibleScrollDismissesKeyboard()
                //.border(.red)
        }

        private func shouldShowStrobeMenu(for item: FaceItem, faceNumber: Int) -> Bool {
            guard selectedView == faceNumber else { return false }

            switch item.content {
            case .symbol(let symbol):
                return symbol == SharedOptions.strobeActionSymbol
            case .emoji:
                return false
            }
        }

        static func == (lhs: FaceGridSection, rhs: FaceGridSection) -> Bool {
            lhs.selectedView == rhs.selectedView
        }
    }
    
    // MARK: - Helper Functions (Place handleWatchFaceSelection HERE)
    
    /// Handles processing the face selection received from the watch.
    private func handleWatchFaceSelection(face: String?) {  // <--- DEFINITION INSIDE ContentView
        guard let selectedFace = face else {
            contentLogger.notice("Ignored empty watch face selection")
            return
        }

        guard bleModel.dashboardState.allowsControllerActions else {
            contentLogger.notice("Ignored watch face selection while no controller is available")
            return
        }
        
        // Find the index where the enum's String == selectedFace
        if let index = SharedOptions.protoActionOptions.firstIndex(where: {
            action in
            switch action {
            case .emoji(let e): return e == selectedFace
            case .symbol(let s): return s == selectedFace
            }
        }) {
            let viewToSet = index + 1
            contentLogger.debug("Applying watch face selection for view \(viewToSet, privacy: .public)")
            _ = bleModel.setView(viewToSet)
        } else {
            contentLogger.error("Received unknown watch face selection")
        }
    }

    /// Given a numeric “view” (1…n), return the matching emoji or symbol-string,
    /// so you can show it back in your SwiftUI view or send it to the watch.
    private func getFaceForView(_ view: Int) -> String {
        let idx = view - 1
        guard SharedOptions.protoActionOptions.indices.contains(idx) else {
            return "❓"
        }
        switch SharedOptions.protoActionOptions[idx] {
        case .emoji(let e): return e
        case .symbol(let s): return s
        }
    }
}

private struct ToolbarStatusHost: View {
    @ObservedObject var bleModel: AccessoryViewModel

    private var toolbarModel: ToolbarStatusModel {
        let dashboardState = bleModel.dashboardState

        return .init(
            connectionState: dashboardState.statusConnectionState,
            toolbarStatusText: dashboardState.toolbarStatusText,
            signalStrength: bleModel.signalStrength,
            luxValue: Int(bleModel.luxValue)
        )
    }

    var body: some View {
        let _ = IdleCPUDiagnostics.shared.recordViewBody("ToolbarStatusHost")

        HeaderView(
            connectionState: toolbarModel.connectionState,
            connectionStatus: toolbarModel.toolbarStatusText,
            signalStrength: toolbarModel.signalStrength,
            luxValue: Double(toolbarModel.luxValue)
        )
        .equatable()
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct DashboardContentView: View {
    @ObservedObject var bleModel: AccessoryViewModel
    @Binding var isChartsExpanded: Bool
    let selectedUnits: Binding<TempUnit>
    let receivedFaceFromWatch: String?
    let onPrepareHaptics: () -> Void
    let onHandleWatchFaceSelection: (String?) -> Void

    var body: some View {
        let _ = IdleCPUDiagnostics.shared.recordViewBody("DashboardContentView")

        dashboardContent
            .safeAreaInset(edge: .top, spacing: 0) {
                if shouldShowInlineFeedback {
                    ConnectionFeedbackView(
                        message: bleModel.errorMessage,
                        onDismiss: bleModel.clearFeedback
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.bar)
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                }
            }
            .onAppear(perform: onPrepareHaptics)
            .onChange(of: receivedFaceFromWatch) { _, newFace in
                onHandleWatchFaceSelection(newFace)
            }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        switch bleModel.dashboardState {
        case .connected:
            connectedDashboard
        default:
            DashboardRecoveryView(
                state: bleModel.dashboardState,
                onScan: bleModel.scanForDevices,
                onStopScanning: bleModel.stopScan
            )
        }
    }

    private var connectedDashboard: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            Group {
                if isLandscape {
                    HStack(spacing: 16) {
                        faceGrid
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        chart(width: proxy.size.width * 0.33)
                            .frame(maxHeight: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isChartsExpanded)
                } else {
                    VStack {

                            faceGrid

                        chart(width: nil)
                            .frame(maxHeight: isChartsExpanded ? 160 : 55)
                            .padding(.horizontal)
                            .padding(.bottom)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isChartsExpanded)
                    }
                }
            }
        }
    }

    private var shouldShowInlineFeedback: Bool {
        guard bleModel.hasInlineFeedback else { return false }

        if case .failed = bleModel.dashboardState {
            return false
        }

        return true
    }

    private var faceGrid: some View {
        ContentView.FaceGridSection(
            bleModel: bleModel,
            selectedView: bleModel.selectedView,
            onSetView: { view in
                _ = bleModel.setView(view)
            }
        )
        .equatable()
    }

    @ViewBuilder
    private func chart(width: CGFloat?) -> some View {
        ChartView(
            isExpanded: $isChartsExpanded,
            seedData: bleModel.temperatureData,
            temperaturePublisher: bleModel.temperatureChartPublisher,
            selectedUnits: selectedUnits,
            connected: bleModel.isConnected
        )
        .equatable()
        .legacyGlassBackground(cornerRadius: 32)
        .frame(width: width, alignment: .top)
    }
}

private struct DashboardRecoveryView: View {
    let state: DashboardState
    let onScan: () -> Void
    let onStopScanning: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label(state.recoveryTitle, systemImage: state.recoverySymbol)
        } description: {
            Text(state.recoveryMessage)
        } actions: {
            recoveryActions
        }
    }

    @ViewBuilder
    private var recoveryActions: some View {
        switch state {
        case .checkingBluetooth, .connecting, .reconnecting, .temporarilyUnavailable:
            ProgressView()
                .accessibilityLabel(state.toolbarStatusText)

        case .scanning:
            VStack(spacing: 12) {
                ProgressView()
                    .accessibilityLabel("Scanning for controllers")

                Button("Stop Scanning", systemImage: "stop.circle", action: onStopScanning)
                    .buttonStyle(.bordered)
            }

        case .disconnected, .failed:
            Button("Scan for Controllers", systemImage: "antenna.radiowaves.left.and.right", action: onScan)
                .buttonStyle(.borderedProminent)

        case .permissionDenied:
            #if canImport(UIKit)
            Button("Open Settings", systemImage: "gear") {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                openURL(settingsURL)
            }
            .buttonStyle(.borderedProminent)
            #endif

        case .bluetoothOff, .unsupported, .connected:
            EmptyView()
        }
    }
}

private extension DashboardState {
    var recoveryTitle: String {
        switch self {
        case .checkingBluetooth:
            return "Checking Bluetooth"
        case .permissionDenied:
            return "Bluetooth Access Required"
        case .bluetoothOff:
            return "Bluetooth Is Off"
        case .unsupported:
            return "Bluetooth Isn't Supported"
        case .temporarilyUnavailable:
            return "Bluetooth Is Temporarily Unavailable"
        case .disconnected:
            return "No Controller Connected"
        case .scanning:
            return "Looking for Controllers"
        case .connecting:
            return "Connecting to Controller"
        case .reconnecting:
            return "Reconnecting to Controller"
        case .connected:
            return "Controller Connected"
        case .failed:
            return "Couldn't Connect"
        }
    }

    var recoveryMessage: String {
        switch self {
        case .checkingBluetooth:
            return "LumiFur is checking whether Bluetooth is available."
        case .permissionDenied:
            return "Allow LumiFur to use Bluetooth in Settings so it can find and connect to your controller."
        case .bluetoothOff:
            return "Turn on Bluetooth in Control Centre or Settings. LumiFur will resume automatically."
        case .unsupported:
            return "This device can't use the Bluetooth features required by LumiFur."
        case .temporarilyUnavailable:
            return "iOS is restoring Bluetooth. LumiFur will try again automatically."
        case .disconnected:
            return "Make sure your LumiFur controller is nearby and powered on, then scan to connect."
        case .scanning:
            return "Keep your controller nearby and powered on while LumiFur searches."
        case .connecting:
            return "Keep your controller nearby while LumiFur finishes connecting."
        case .reconnecting:
            return "LumiFur is reconnecting to your previous controller."
        case .connected:
            return "Your controller is ready."
        case .failed(let message):
            return "\(message) Try scanning again."
        }
    }

    var recoverySymbol: String {
        switch self {
        case .checkingBluetooth, .scanning, .connecting, .reconnecting:
            return "antenna.radiowaves.left.and.right"
        case .permissionDenied:
            return "hand.raised.fill"
        case .bluetoothOff:
            return "bluetooth"
        case .unsupported:
            return "xmark.circle"
        case .temporarilyUnavailable, .failed:
            return "exclamationmark.triangle"
        case .disconnected:
            return "link.badge.plus"
        case .connected:
            return "checkmark.circle"
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
                    .onChange(of: autoReconnect) { _, newValue in
                        bleModel.autoReconnectEnabled = newValue
                        contentLogger.debug("Auto reconnect changed to \(newValue, privacy: .public)")
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
                    .onChange(of: rssiUpdateInterval) { _, newValue in
                        // If your model supports adjustable intervals for reading RSSI, update it here.
                        contentLogger.debug("RSSI interval changed to \(newValue, privacy: .public)")
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
    ContentView(bleModel: AccessoryViewModel())
}
 
#Preview("SplashView") {
    SplashView(showSplash: .constant(true))
}

#Preview("Whats New") {
    let appReleases: [GitHubRelease] = []
    
    WhatsNew(appReleases: appReleases)
}

#Preview("Info View") {
    InfoView()
}

#Preview("Settings") {
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
    CompatibleNavigationStack {
        ReleaseNotesView(
            title: "App Releases",
            releases: sampleReleases // Pass the mock data to the view
        )
    }
}

#Preview("Release Notes (Empty)") {
    // It's also good practice to preview the empty state.
    CompatibleNavigationStack {
        ReleaseNotesView(
            title: "Controller Releases",
            releases: [] // Pass an empty array
        )
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
