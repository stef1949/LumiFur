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
class iOSViewModel: ObservableObject {
    @Published var receivedCommand: String = "None"
    // We can keep this for debugging, but it's not essential for the core logic anymore.
    @Published var receivedFaceFromWatch: String? = nil
    // This provides a link to the single source of truth for your app's state.
    @ObservedObject var accessoryViewModel = AccessoryViewModel.shared
    private var cancellables = Set<AnyCancellable>()
    
    // ✅ REPLACE YOUR OLD init() WITH THIS ONE
    init() {
        // This check is good practice to avoid running connectivity code in SwiftUI Previews.
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if isPreview { return }
        
        // Subscribe to messages from the WatchConnectivityManager
        WatchConnectivityManager.shared.messageSubject
            .receive(on: DispatchQueue.main) // Ensure UI updates happen on the main thread
            .sink { [weak self] messageData in
                // Use a guard to safely unwrap `self` and avoid retain cycles
                guard let self = self else { return }
                
                // Check if the command is "setFace"
                if let command = messageData["command"] as? String, command == "setFace" {
                    self.receivedCommand = command // Update for debugging
                    
                    // ✅ Look for the "view" integer key sent from the watch
                    if let view = messageData["view"] as? Int {
                        print("iOS ViewModel: Received 'setFace' command from watch for view: \(view)")
                        
                        // Call the accessory view model to update the app's state.
                        // This will update the iOS UI and send the command to the BLE device.
                        self.accessoryViewModel.setView(view)
                        
                        // Clear the old debugging property
                        self.receivedFaceFromWatch = nil
                        
                    } else {
                        // This block is for backwards compatibility or debugging the old format.
                        if let face = messageData["faceValue"] as? String {
                            print("iOS ViewModel: Received OLD format `faceValue`: \(face). Please ensure watch app is updated.")
                            self.receivedFaceFromWatch = face // For debugging
                        } else {
                            print("iOS ViewModel: Received 'setFace' command but 'view' key was missing or not an Int.")
                        }
                    }
                } else {
                    // Handle other potential commands from the watch
                    if let command = messageData["command"] as? String {
                        self.receivedCommand = command
                        print("iOS ViewModel: Received other command: \(command)")
                    }
                }
            }
            .store(in: &cancellables) // Store the subscription to keep it alive
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

/*
 struct SplashView2: View {
 @Environment(\.colorScheme) var colorScheme

 var overlayColor: Color {
 colorScheme == .dark ? .black : .clear
 }

 @State var isActive: Bool = false
 //Protogen hover effect
 @State private var yOffset: CGFloat = -10
 @State private var animationDirection: Bool = true // True for moving up, false for moving down
 let animationDuration: Double =  2.0 //Duratio for full hover effect

 var body: some View {
 ZStack {
 if self.isActive {
 ContentView()
 } else {
 NavigationStack {
 ZStack {
 VStack {
 animatedProtogenImage(yOffset: $yOffset, animationDirection: true, animationDuration: animationDuration)

 ZStack {
 Image(systemName: "aqi.medium")
 .resizable()
 .scaledToFit()
 .font(.title)
 .symbolEffect(.variableColor.cumulative)
 .blur(radius: 10)

 Image(systemName: "aqi.medium")
 .resizable()
 .scaledToFit()
 .font(.title)
 .symbolEffect(.variableColor.cumulative)
 .blur(radius: 1)
 .opacity(0.5)

 Circle()
 .fill(RadialGradient(
 gradient: Gradient(colors: [Color.clear, overlayColor]),
 center: .center,
 startRadius: 0,
 endRadius: 150
 )
 )
 .scaleEffect(CGSize(width: 1.2, height: 1.2))
 .font(.title)
 .blur(radius: 3.0)
 .scaledToFit()

 }
 .padding()

 Text("Welcome to LumiFur")
 .font(.title)
 .multilineTextAlignment(.trailing)
 .fontDesign(.monospaced)

 Text("An app designed to control your fursuit LEDs & light systems")
 .multilineTextAlignment(.center)
 .padding([.leading, .bottom, .trailing])
 .fontDesign(.monospaced)


 Button(action: {
 withAnimation {
 self.isActive = true
 }
 }) {
 Text("Start")
 .font(.title2)
 .padding()
 .padding(.horizontal)
 .background(.ultraThinMaterial)
 .tint(.gray)
 .clipShape(RoundedRectangle(cornerSize: CGSize(width: 15, height: 10)))
 }

 }
 }
 .overlay(alignment: .bottomTrailing) {
 NavigationLink(destination: InfoView()) {
 Image(systemName: "info.square")
 .imageScale(.large)
 .symbolRenderingMode(.multicolor)
 .tint(.gray)
 .padding()
 .offset(CGSize(width: -10.0, height: -5.0))
 }
 }
 .padding()
 }
 }
 }
 }
 }
 }
 }
 }
 }
 }
 */

/*
struct RootView2: View {
    var body: some View {
        ContentView(bleModel: bleModel)
    }
}
*/

// MARK: ContentView
struct ContentView: View {
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
    
    @State private var isLedArrayExpanded: Bool = false
    @StateObject private var viewModel = iOSViewModel()  // Instantiates the class defined above

    @State private var errorMessage: String?
    
    @State private var selectedSidebarItem: SidebarItem? = .dashboard
    @State private var showSplash = true  // Local state to control the splash screen appearance.
    
    @State private var drawProgress: CGFloat = 1.0
    
    @Environment(\.colorScheme) var colorScheme  // Colot Scheme
    var overlayColor: Color {
        colorScheme == .dark ? .init(uiColor: .systemGray6) : .white
    }
    
    @State private var matrixStyle: MatrixStyle = .array // The real source of truth
    
    @Namespace var namespace
    
    
    //Protogen image variables
    //@State private var yOffset: CGFloat = 0
    //@State private var animationDuration: Double = 1.0
    
    //@State private var selectedConnection: Connection = .bluetooth
    //@State private var selectedMatrix: SettingsView.Matrixstyle = .array

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
                // MARK: – Dashboard Tab
                NavigationStack {
                    detailContent
                    //.navigationTitle("LumiFur")
                    /*
                     .toolbar {
                         //ToolbarSpacer(.fixed)
                         ToolbarItemGroup(placement: .bottomBar) {
                             NavigationLink(destination: ContentView()) {
                             Image(systemName: "gear")
                             .glassEffect(.regular.interactive())
                             }
                             }
                         ToolbarSpacer(.fixed)
                    
                         ToolbarItemGroup(placement: .bottomBar) {
                     //Spacer()   // pushes the gear icon all the way to the right
                     NavigationLink(destination: SettingsView(bleModel: accessoryViewModel,
                     selectedMatrix: $selectedMatrix)) {
                     Image(systemName: "gear")
                     .glassEffect(.regular.interactive())
                     }
                     }
                     }
                     */
                }
                .tabItem {
                    Label(SidebarItem.dashboard.rawValue, systemImage: SidebarItem.dashboard.iconName)
                }
                .tag(SidebarItem.dashboard)
                
                // MARK: – Custom Tab
                NavigationStack {
                    CustomLedView()
                        .navigationTitle("Custom")
                }
                .tabItem {
                    Label(
                        SidebarItem.profile.rawValue,
                        systemImage: SidebarItem.profile.iconName
                    )
                }
                .tag(SidebarItem.profile)
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
    
    @ViewBuilder
    private var detailContent: some View {
        //@AppStorage("charts") var isChartsExpanded = false
        @AppStorage("hasLaunchedBefore") var hasLaunchedBefore: Bool = true
        
        ZStack {
            if selectedSidebarItem == .dashboard {
                VStack {
                    HStack{
                        HeaderView(
                            connectionState: bleModel.connectionState,
                            connectionStatus: bleModel.connectionStatus,
                            signalStrength: bleModel.signalStrength,
                            luxValue: Double(bleModel.luxValue)
                        )
                    }
                    optionGridSection
                    //ledArraySection
                    //.border(.green)
                    
                    FaceGridSection(
                        selectedView: bleModel.selectedView,
                        onSetView: { bleModel.setView($0) },
                        auroraModeEnabled: auroraModeEnabled
                        //items: SharedOptions.protoActionOptions3
                    )
                    .zIndex(-1)
                    
                    ChartView(isExpanded: $isChartsExpanded, accessoryViewModel: bleModel)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 32))
                        .frame(maxHeight: isChartsExpanded ? 160 : 55) // Animate height change
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
/*
    private var headerSection: some View {
        //HStack {
            /*
            Image("LumiFurFrontBottomSide")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 150, maxHeight: 150)
                .drawingGroup()  // renders once into a bitmap then reuses it
                */
        
            HStack {
                Text("LumiFur")
                    //.font(.largeTitle)
                    .font(Font.custom("Meloriac", size: 35))
                    .frame(width: 150)
                    .border(.purple)
                
                Spacer()
                
                statusSection
            }
      //  }
        //.frame(height: 100)
        .padding(.horizontal)
    }
    */
/*
    private var statusSection: some View {
        HStack(spacing: 8) {
            if showSignalView && accessoryViewModel.isConnected {
                SignalStrengthView(rssi: accessoryViewModel.signalStrength)
                    .transition(.move(edge: .trailing).combined(with: .opacity)) // Be explicit
                        
                    .padding(.leading, 5)

            }
            // only show RSSI when truly “.connected”
            accessoryViewModel.connectionImageName
                // choose a mode that *allows* tinting
                .symbolRenderingMode(
                    accessoryViewModel.connectionState == .connected
                        ? .multicolor  // iOS 15+; retains depth but is tinted
                        : .monochrome  // single-color, template style
                )
                // use foregroundStyle (preferred) or foregroundColor
                //.foregroundStyle(accessoryViewModel.connectionColor)
                // optional: fade out when not connected
                .opacity(
                    accessoryViewModel.connectionState == .connected ? 1 : 0.5
                )

            Text(accessoryViewModel.connectionStatus)
                .font(.caption)
                .foregroundStyle(accessoryViewModel.connectionColor)
        }
        .animation(.easeInOut, value: showSignalView)  // Smooth animation
        .onChange(of: accessoryViewModel.connectionState) {
            oldValue,
            newValue in
            withAnimation {
                showSignalView = newValue != .disconnected
            }
        }
        .padding(10)
        .glassEffect()
        //.border(.yellow)
        //.background(.ultraThinMaterial)

        /*
         .background(Group {
         if fancyMode {
         Color(overlayColor)
         }
         }
         )
         .clipShape(RoundedRectangle(cornerRadius: 10))
         */
    }
    */
    private var ledArraySection: some View {
        DisclosureGroup("LED Array", isExpanded: $isLedArrayExpanded) {
            if isLedArrayExpanded {
                HStack {
                    Spacer()
                    LEDPreview()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    LEDPreview()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                }
                .frame(maxHeight: 100)
            }
        }
        .padding(.horizontal)
        .accentColor(.gray)
        //.ignoresSafeArea()
        .scrollContentBackground(.hidden)
        //.background(overlayColor)
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
        ScrollView(.horizontal, showsIndicators: false) {  // Added showsIndicators: false
            LazyHGrid(rows: twoRowOptionGrid) {
                ForEach(standardOptions) { option in
                    OptionToggleView(
                        title: option.title,
                        isOn: option.binding,
                        optionType: option.type
                    )
                    .onChange(of: option.binding.wrappedValue) {
                        oldValue,
                        newValue in
                        option.action?(newValue)
                        // If accessoryViewModel actions are always the same,
                        // you might simplify the `action` closure further or move
                        // `writeConfigToCharacteristic` here.
                        // For now, I've kept the print and commented viewModel lines in the closures.
                    }
                }
                // Custom Message Toggle - handled separately due to unique popover logic
                OptionToggleView(
                    title: "Custom Message",
                    isOn: $customMessage,
                    optionType: .customMessage
                )
                .onChange(of: customMessage) { oldValue, newValue in  // Correct onChange signature
                    if newValue {  // Use newValue for clarity
                        showCustomMessagePopup = true
                    } else {
                        // Optionally handle if customMessage is turned OFF by means other than Cancel button
                        // For example, if customMessageText should be cleared.
                        // customMessageText = "" // If desired
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
            .padding(.horizontal)  // Apply padding to the HGrid content
        }
        .frame(maxWidth: .infinity, maxHeight: 80)
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
                    if customMessageText.isEmpty {  // If OK is pressed with no text, maybe turn off the feature?
                        // customMessage = false // Or provide feedback to user
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 300, height: 140)  // Slightly increased height for better spacing
        //.glassEffect(.regular.tint(.blue))
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

    /*
     // 1) Move this up in your View
     private var downsampledTempData: [TemperatureData] {
     // cut off 3 minutes ago
     let cutoff = Date().addingTimeInterval(-3 * 60)
     // only the recent bits
     let recent = accessoryViewModel.temperatureData
     .filter { $0.timestamp >= cutoff }
     // cap at ~100 points
     let strideSize = max(1, recent.count / 100)
     // take every Nth element
     return recent.enumerated().compactMap { idx, el in
     idx % strideSize == 0 ? el : nil
     }
     }
    
     @AppStorage("charts") private var isChartsExpanded = false
    
     @State private var samples: [TemperatureData] = []
    
     private var settingsAndChartsSection: some View {
     HStack {
     Spacer()
     // CPU Usage Chart
     /* VStack {
      Chart(accessoryViewModel.cpuUsageData) { element in
      LineMark(
      x: .value("Time", element.timestamp),
      y: .value("CPU Usage", element.cpuUsage)
      )
      .foregroundStyle(Color.blue)
      .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 2]))
      .symbol(Circle().strokeBorder(lineWidth: 2))
      }
      .chartYScale(domain: 0...100)
      .chartXAxis {
      AxisMarks(values: .stride(by: 1)) { value in
      AxisValueLabel {
      if let dateValue = value.as(Date.self) {
      Text(dateValue, format: .dateTime.hour().minute().second())
      }
      }
      }
      }
      .chartYAxis {
      AxisMarks(values: .stride(by: 50)) { value in
      AxisValueLabel {
      if let intValue = value.as(Int.self) {
      Text("\(intValue)%")
      }
      }
      }
      }
      .padding()
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .frame(maxWidth:500,maxHeight: 70)
    
      Text("CPU")
      .font(.footnote)
      }
      */
     // Temperature Chart
     DisclosureGroup("Charts", isExpanded: $isChartsExpanded) {
     if isChartsExpanded {
     VStack {
     Chart(samples) {
     element in
     LineMark(
     x: .value("Time", element.timestamp),
     y: .value("℃", element.temperature)
     )
     .lineStyle(StrokeStyle(lineWidth: 2))
     .interpolationMethod(.catmullRom)
     }
     .foregroundStyle(Color.blue)
     .chartXScale(
     domain: Date().addingTimeInterval(-3 * 60)...Date()
     )
     /*
      .foregroundStyle(
      LinearGradient(
      gradient: Gradient(colors: [Color.blue, Color.blue, Color.orange, Color.orange]),
      startPoint: .bottom,
      endPoint: .top
      )
      )
      */
     .chartXAxis {
     AxisMarks(values: .stride(by: .minute)) { value in
     AxisValueLabel(
     format: .dateTime.minute().second()
     )
     .font(.caption2)
     }
     }
     .chartYAxis {
     AxisMarks(values: .automatic) { axisValue in
     AxisValueLabel {
     if let temp = axisValue.as(Double.self) {
     Text(String(format: "%.0f°C", temp))
     .font(.caption2)
     }
     }
     }
     }
     //.drawingGroup()
     .padding()
     .background(.ultraThinMaterial)
     .clipShape(RoundedRectangle(cornerRadius: 25))
     .frame(maxWidth: .infinity, maxHeight: 80)
    
     Text("Temperature (°C)")
     .padding(.top, 4)
     .font(.caption)
     }
     // container transition
     .transition(
     .asymmetric(
     insertion: .move(edge: .top).combined(
     with: .opacity
     ),
     removal: .move(edge: .bottom).combined(
     with: .opacity
     )
     )
     )
     // slide+fade the chart’s canvas itself
     .modifier(ChartEntryAnimation(isVisible: isChartsExpanded))
     }
     }
     .tint(.primary)
     .onTapGesture {
     withAnimation { isChartsExpanded.toggle() }
     }
     .animation(.easeInOut(duration: 0.3), value: isChartsExpanded)
     .onReceive(
     accessoryViewModel.temperatureChartPublisher
     .throttle(
     for: .seconds(1),
     scheduler: DispatchQueue.main,
     latest: true
     )
     ) { newSamples in
     self.samples = newSamples
     }
     .animation(
     .easeInOut(duration: 1.5),
     value: accessoryViewModel.temperatureData
     )  // Single smooth update animation. Animate based on data change
     // Isolated NavigationLinks
     /*
      NavigationLink(
      destination: SettingsView(
      bleModel: accessoryViewModel,
      selectedMatrix: $selectedMatrix
      )
      ) {
      Image(systemName: "gear")
      .imageScale(.large)
      .symbolRenderingMode(.multicolor)
      .padding()
      .glassEffect(.regular.interactive())
      }
      */
     }
     //.listRowBackground(overlayColor)
     //.background(.clear)
     .padding()
     //.frame(maxHeight: 100)
     .scrollContentBackground(.hidden)
     //.background(overlayColor)
     //Prevents keyboard from pushing view contents up when opening custom message
     //.ignoresSafeArea(.keyboard, edges: .all)
     }
     */
}

struct ledArraySection: View {
    var body: some View {
        Text("Hello World!")
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

/*
 struct LedGridView: View {
 // Computed property to generate an array of random colors
 private var squares: [Color] {
 Array(repeating: Color.clear, count: 64).map { _ in randomColor() }
 }

 let spacing: CGFloat = 1 // Space between rows and columns

 // Define the number of columns in the grid
 let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 1), count: 8)

 var body: some View {

 LazyVGrid(columns: columns, spacing: 1) {  // Y Spacing
 ForEach(squares.indices, id: \.self) { index in
 Rectangle()
 .fill(squares[index])
 .frame(width: 5, height: 5)
 .cornerRadius(1)
 //.blur(radius: 3.0) //Potential blur effect?
 }
 }
 .padding(10.0)
 .background(.ultraThinMaterial)
 .clipShape(RoundedRectangle(cornerSize: CGSize(width: 5, height: 5)))
 .aspectRatio(0.5, contentMode: .fit)
 }
 }

 // Function to generate a random color (red, green, or blue)
 private func randomColor() -> Color {
 let colors: [Color] = [.red, .green, .blue, .white]
 return colors.randomElement() ?? .clear
 }
 */

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
                    .onChange(of: rssiMonitoringEnabled) { oldValue, newValue in
                        if newValue {
                            bleModel.startRSSIMonitoring()
                        } else {
                            // If you have a method to stop monitoring, you can call it here.
                            print("RSSI monitoring disabled")
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

/*
 struct SignalStrengthView: View {
 let rssi: Int

 // Convert RSSI to signal strength value (0.0 to 1.0)
 private var signalLevel: Double {
 // RSSI typically ranges from -30 (strong) to -100 (weak)
 let maxRSSI: Double = -30
 let minRSSI: Double = -100

 let signalStrength = Double(rssi)
 let normalizedSignal = (signalStrength - minRSSI) / (maxRSSI - minRSSI)
 return min(max(normalizedSignal, 0.0), 1.0) // Clamp between 0 and 1
 }

 // Check if there's an active connection
 private var isConnected: Bool {
 return rssi > -100
 }

 var body: some View {
 VStack(alignment: .center, spacing: 2) {
 Image(systemName: "cellularbars", variableValue: signalLevel)
 .symbolRenderingMode(.multicolor)
 .imageScale(.medium)
 .symbolEffect(.variableColor)
 .opacity(isConnected ? 1 : 0.3)
 .animation(.smooth, value: isConnected)

 if isConnected {
 Text("\(rssi) dBm")
 .font(.system(size: 8))
 .transition(.opacity)
 }
 }
 .padding(.vertical, 2)
 }
 }
 */
/*
 struct DotMatrixView: View {
 @Environment(\.colorScheme) var colorScheme

 var overlayColor: Color {
 colorScheme == .dark ? .gray : .black
 }

 var invertoverlayColor: Color {
 colorScheme == .light ? .black : .gray
 }

 let matrix: [[Bool]]

 var body: some View {
 ZStack {
 RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
 .foregroundStyle(.ultraThinMaterial)
 .aspectRatio(contentMode: .fit)
 .frame(width: 70)


 VStack(spacing: 1) {
 ForEach(0..<8, id: \.self) { y in
 HStack(spacing: 0.5) {
 ForEach(0..<8, id: \.self) { x in
 Rectangle()
 .fill(self.matrix[y][x] ? overlayColor : invertoverlayColor)
 .frame(width: 5, height: 5)
 .clipShape(RoundedRectangle(cornerRadius: CGFloat(1)))
 }
 }
 }
 }
 //.border(Color.green)
 .padding(.horizontal)

 }
 //.border(Color.purple)
 .aspectRatio(1, contentMode: .fit)
 }
 }

 struct CircleMatrixView: View {
 @Environment(\.colorScheme) var colorScheme
 var overlayColor: Color {
 colorScheme == .dark ? .gray : .white
 }

 var invertoverlayColor: Color {
 colorScheme == .light ? .black : .gray
 }

 let matrix: [[Bool]]

 var body: some View {
 VStack(spacing: 1) {
 ForEach(0..<8, id: \.self) { y in
 HStack(spacing: 1) {
 ForEach(0..<8, id: \.self) { x in
 Circle()
 .fill(self.matrix[y][x] ? overlayColor : invertoverlayColor)
 .frame(width: 5, height: 5)
 }
 }
 }
 }
 }
 }
 */

struct SocialLink: View {
    let imageName: String
    let appURL: URL
    let webURL: URL

    @Environment(\.openURL) var openURL

    var body: some View {
        Button {
            // Try opening the app URL first
            if UIApplication.shared.canOpenURL(appURL) {
                openURL(appURL)
            } else {
                // Fallback to web
                openURL(webURL)
            }
        } label: {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .tint(.primary)
                .opacity(0.5)
                .frame(width: 25, height: 25)
        }
        .drawingGroup()
    }
}

struct InfoView: View {
    struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
    }
    private let features: [Feature] = [
        .init(
            icon: "play.circle.fill",
            title: "Live Control",
            description: "Adjust brightness, speed & colour in real time."
        ),
        .init(
            icon: "sparkles",
            title: "Prebuilt Effects",
            description: "Pick from a gallery of dynamic patterns."
        ),
        .init(
            icon: "slider.horizontal.3",
            title: "Custom Sequences",
            description: "Compose and save your own light shows."
        ),
        .init(
            icon: "bluetooth.fill",
            title: "Bluetooth Sync",
            description: "Wireless pairing to your suit’s controller."
        ),
    ]
    var body: some View {
        NavigationStack {
            List {
                // MARK: – Logo Header
                VStack {
                    HStack {
                        Spacer()
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                        Spacer()
                    }
                    Spacer()
                    HStack(spacing: 15.0) {
                        SocialLink(
                            imageName: "bluesky.fill",
                            appURL: URL(string: "bsky://profile/richies.uk")!,
                            webURL: URL(
                                string: "https://bsky.app/profile/richies.uk"
                            )!
                        )
                        SocialLink(
                            imageName: "facebook.fill",
                            appURL: URL(string: "fb://profile/richies3d")!,
                            webURL: URL(
                                string: "https://www.facebook.com/richies3d/"
                            )!
                        )
                        SocialLink(
                            imageName: "x",
                            appURL: URL(
                                string: "twitter://user?screen_name=richies3d"
                            )!,
                            webURL: URL(string: "https://x.com/Richies3D")!
                        )
                        SocialLink(
                            imageName: "github.fill",
                            appURL: URL(
                                string: "github://user?username=stef1949"
                            )!,  // GitHub’s custom scheme
                            webURL: URL(string: "https://github.com/stef1949")!
                        )
                        SocialLink(
                            imageName: "linkedin.fill",
                            appURL: URL(
                                string: "linkedin://in/stefan-ritchie"
                            )!,
                            webURL: URL(
                                string:
                                    "https://www.linkedin.com/in/stefan-ritchie/"
                            )!
                        )
                    }

                }
                //.drawingGroup()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // MARK: – About Section
                Section(header: Text("About LumiFur")) {
                    Text(
                        """
                        LumiFur is an iOS‑native companion app for controlling LEDs on fursuits. It offers an intuitive interface for ramping colours, effects and sequences—right from your pocket.
                        """
                    )
                    .font(.body)
                    //.foregroundColor(.secondary)
                    .padding(.vertical, 4)
                }

                // MARK: – Features Section
                Section(header: Text("Features")) {
                    ForEach(features) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: feature.icon)
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                //.foregroundStyle()
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(.headline)
                                Text(feature.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        //.drawingGroup()
                        .padding(.vertical, 6)
                    }
                }

                // MARK: – Full List Link
                Section {
                    HStack {
                        Spacer()
                        Label(
                            "Complete feature list",
                            systemImage: "chevron.forward"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.insetGrouped)  // iOS18 default grouping
            .scrollContentBackground(.hidden)  // let our list sit over the material
            .background(.thinMaterial)  // global bg
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: -WORKING- Testing matrix arducode code
/*
 struct MatrixTestView4_4: View {
 static let X_SEGMENTS = 2
 static let Y_SEGMENTS = 1
 static let NUM_SEGMENTS = X_SEGMENTS * Y_SEGMENTS

 @State private var framebuffer = [UInt8](repeating: 0, count: 8 * NUM_SEGMENTS)
 @State private var isAnimating = false
 @State private var timer: Timer?
 @State private var sx1: Int32 = 15 << 8
 @State private var sx2: Int32 = 15 << 8
 @State private var sy1: Int32 = 0
 @State private var sy2: Int32 = 0
 @State private var travel: UInt8 = 0

 var body: some View {
 VStack {
 VStack {
 // Display the LED matrix
 ForEach(0..<Self.Y_SEGMENTS, id: \.self) { y in
 HStack {
 ForEach(0..<Self.X_SEGMENTS, id: \.self) { x in
 LEDMatrix(framebuffer: $framebuffer, xOffset: x * 8, yOffset: y * 8)
 }
 }
 }
 }
 .padding()
 .background(.ultraThinMaterial)
 .clipShape(RoundedRectangle(cornerRadius: 25.0))

 Text("4x4_Test")
 .font(.title)

 // Button to start/stop the animation
 Button(action: toggleAnimation) {
 Text(isAnimating ? "Stop" : "Start")
 .padding()
 .background(Color.blue)
 .foregroundColor(.white)
 .cornerRadius(8)
 }
 .padding(.top, 20)
 }
 .onAppear(perform: setup)
 }

 func setup() {
 clear()
 }

 func toggleAnimation() {
 isAnimating.toggle()
 if isAnimating {
 // Start the animation
 timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
 loop()
 }
 } else {
 // Stop the animation
 timer?.invalidate()
 timer = nil
 }
 }

 func loop() {
 sx1 = sx1 - (sy1 >> 6)
 sy1 = sy1 + (sx1 >> 6)
 sx2 = sx2 - (sy2 >> 5)
 sy2 = sy2 + (sx2 >> 5)

 travel = travel &- 1

 let x_offset = Int32(sx1 >> 8) - Int32(Self.X_SEGMENTS * 4)
 let y_offset = Int32(sx2 >> 8) - Int32(Self.Y_SEGMENTS * 4)

 clear()
 drawCircles(x_offset: x_offset, y_offset: y_offset, travel: travel)
 }

 func drawCircles(x_offset: Int32, y_offset: Int32, travel: UInt8) {
 var x = x_offset
 var y = y_offset
 var ysumsquares = x_offset * x_offset + y * y
 var yroot = Int32(sqrtf(Float(ysumsquares)))
 var ynextsquare = yroot * yroot

 for screeny in 0..<(Self.Y_SEGMENTS * 8) {
 x = x_offset
 var xsumsquares = ysumsquares
 var xroot = yroot
 var xnextsquare = xroot * xroot

 for screenx in 0..<(Self.X_SEGMENTS * 8) {
 let output = UInt8(((xroot + Int32(travel)) & 8) >> 3)
 setPixel(x: UInt8(screenx), y: UInt8(screeny), mode: output)

 xsumsquares += 2 * x + 1
 x += 1

 if x <= 0 {
 if xsumsquares < xnextsquare {
 xnextsquare -= 2 * xroot - 1
 xroot -= 1
 }
 } else {
 if xsumsquares >= xnextsquare {
 xroot += 1
 xnextsquare = (xroot + 1) * (xroot + 1)
 }
 }
 }

 ysumsquares += 2 * y + 1
 y += 1

 if y <= 0 {
 if ysumsquares < ynextsquare {
 ynextsquare -= 2 * yroot - 1
 yroot -= 1
 }
 } else {
 if ysumsquares >= ynextsquare {
 yroot += 1
 ynextsquare = (yroot + 1) * (yroot + 1)
 }
 }
 }
 }

 func setPixel(x: UInt8, y: UInt8, mode: UInt8) {
 let addr = Int(x / 8 + y * UInt8(Self.X_SEGMENTS))
 let mask: UInt8 = 128 >> (x % 8)
 switch mode {
 case 0: framebuffer[addr] &= ~mask // clear pixel
 case 1: framebuffer[addr] |= mask  // plot pixel
 default: break
 }
 }

 func clear() {
 framebuffer = [UInt8](repeating: 0, count: 8 * Self.NUM_SEGMENTS)
 }
 }

 struct MatrixTestView5: View {
 static let X_SEGMENTS = 2
 static let Y_SEGMENTS = 1
 static let NUM_SEGMENTS = X_SEGMENTS * Y_SEGMENTS

 @State private var framebuffer = [UInt8](repeating: 0, count: 8 * NUM_SEGMENTS)
 @State private var isAnimating = false
 @State private var timer: Timer?
 @State private var sx1: Int32 = 15 << 8
 @State private var sx2: Int32 = 15 << 8
 @State private var sy1: Int32 = 0
 @State private var sy2: Int32 = 0
 @State private var travel: UInt8 = 0

 var body: some View {
 LazyVStack {
 VStack {
 // Display the LED matrix
 ForEach((0...8), id: \.self){ y in
 HStack {
 ForEach(0..<Self.X_SEGMENTS, id: \.self) { x in
 LEDMatrix(framebuffer: $framebuffer, xOffset: x * 8, yOffset: y * 8)
 }
 }
 }
 }
 .padding()
 .background(.ultraThinMaterial)
 .clipShape(RoundedRectangle(cornerRadius: 25.0))

 Text("4x4_Test")
 .font(.title)

 // Button to start/stop the animation
 Button(action: toggleAnimation) {
 Text(isAnimating ? "Stop" : "Start")
 .padding()
 .background(Color.blue)
 .foregroundColor(.white)
 .cornerRadius(8)
 }
 .padding(.top, 20)
 }
 .onAppear(perform: setup)
 }

 func setup() {
 clear()
 }

 func toggleAnimation() {
 isAnimating.toggle()
 if isAnimating {
 // Start the animation
 timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
 loop()
 }
 } else {
 // Stop the animation
 timer?.invalidate()
 timer = nil
 }
 }

 func loop() {
 sx1 = sx1 - (sy1 >> 6)
 sy1 = sy1 + (sx1 >> 6)
 sx2 = sx2 - (sy2 >> 5)
 sy2 = sy2 + (sx2 >> 5)

 travel = travel &- 1

 let x_offset = Int32(sx1 >> 8) - Int32(Self.X_SEGMENTS * 4)
 let y_offset = Int32(sx2 >> 8) - Int32(Self.Y_SEGMENTS * 4)

 clear()
 drawCircles(x_offset: x_offset, y_offset: y_offset, travel: travel)
 }

 func drawCircles(x_offset: Int32, y_offset: Int32, travel: UInt8) {
 var x = x_offset
 var y = y_offset
 var ysumsquares = x_offset * x_offset + y * y
 var yroot = Int32(sqrtf(Float(ysumsquares)))
 var ynextsquare = yroot * yroot

 for screeny in 0..<(Self.Y_SEGMENTS * 8) {
 x = x_offset
 var xsumsquares = ysumsquares
 var xroot = yroot
 var xnextsquare = xroot * xroot

 for screenx in 0..<(Self.X_SEGMENTS * 8) {
 let output = UInt8(((xroot + Int32(travel)) & 8) >> 3)
 setPixel(x: UInt8(screenx), y: UInt8(screeny), mode: output)

 xsumsquares += 2 * x + 1
 x += 1

 if x <= 0 {
 if xsumsquares < xnextsquare {
 xnextsquare -= 2 * xroot - 1
 xroot -= 1
 }
 } else {
 if xsumsquares >= xnextsquare {
 xroot += 1
 xnextsquare = (xroot + 1) * (xroot + 1)
 }
 }
 }

 ysumsquares += 2 * y + 1
 y += 1

 if y <= 0 {
 if ysumsquares < ynextsquare {
 ynextsquare -= 2 * yroot - 1
 yroot -= 1
 }
 } else {
 if ysumsquares >= ynextsquare {
 yroot += 1
 ynextsquare = (yroot + 1) * (yroot + 1)
 }
 }
 }
 }

 func setPixel(x: UInt8, y: UInt8, mode: UInt8) {
 let addr = Int(x / 8 + y * UInt8(Self.X_SEGMENTS))
 let mask: UInt8 = 128 >> (x % 8)
 switch mode {
 case 0: framebuffer[addr] &= ~mask // clear pixel
 case 1: framebuffer[addr] |= mask  // plot pixel
 default: break
 }
 }

 func clear() {
 framebuffer = [UInt8](repeating: 0, count: 8 * Self.NUM_SEGMENTS)
 }
 }
 */
struct LEDPreview: View {
    // Your 64×32 LED state
    @State private var ledStates: [[Color]] = Array(
        repeating: Array(repeating: .black, count: 32),
        count: 64
    )

    // Snapshot image, updated only when ledStates changes
    @State private var snapshot: Image?

    var body: some View {
        Group {
            if let snapshot {
                snapshot
                    .resizable()
                    .aspectRatio(64 / 32, contentMode: .fit)
            } else {
                // placeholder while first snapshot is generated
                Color.white
                    .aspectRatio(64 / 32, contentMode: .fit)
            }
        }
        .onAppear { updateSnapshot() }
        // whenever ledStates changes, re‑rasterize
        .onChange(of: ledStates) { oldStates, newStates in
            updateSnapshot()
        }
        .padding(10)
    }

    private func updateSnapshot() {
        // Render into a tiny 64×32 bitmap
        let width = 64
        let height = 32
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height)
        )
        let uiImage = renderer.image { ctx in
            for x in 0..<width {
                for y in 0..<height {
                    ctx.cgContext.setFillColor(UIColor(ledStates[x][y]).cgColor)
                    ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        snapshot = Image(uiImage: uiImage).renderingMode(.original)
    }
}

// MARK: Old GPU Accelerated LED Preview
/*
 struct LEDPreview: View {
 // The state of the grid, with 64 rows and 32 columns
 @State private var ledStates: [[Color]] = Array(
 repeating: Array(repeating: .black, count: 32),
 count: 64
 )
 var body: some View {
 GeometryReader { geometry in
 Canvas { context, size in
 let xCount = 64
 let yCount = 32
 let ledWidth = size.width / CGFloat(xCount)
 let ledHeight = size.height / CGFloat(yCount)
 let rectWidth = ledWidth - 1
 let rectHeight = ledHeight - 1
 for x in 0..<xCount {
 let xOffset = CGFloat(x) * ledWidth
 for y in 0..<yCount {
 let yOffset = CGFloat(y) * ledHeight
 let rect = CGRect(
 x: xOffset,
 y: yOffset,
 width: rectWidth,
 height: rectHeight
 )
 context.fill(
 Path(rect),
 with: .color(ledStates[x][y])
 )
 }
 }
 }
 }
 .aspectRatio(64/32, contentMode: .fit)
 //.drawingGroup() // Metal-accelerated rendering
 .padding(10)
 }


 private func toggleLED(row: Int, col: Int) {
 // Toggle between red and black for the tapped LED
 ledStates[row][col] = ledStates[row][col] == .black ? .red : .black
 }
 }
 */

/*
 // Individual LED arrays
 struct LEDMatrix: View {
 @Binding var framebuffer: [UInt8]
 let xOffset: Int
 let yOffset: Int

 var body: some View {
 VStack(spacing: 1) {
 ForEach(0..<64, id: \.self) { row in
 HStack(spacing: 1) {
 ForEach(0..<32, id: \.self) { col in
 Rectangle()
 //.fill(ledColor(row: row, col: col))
 .frame(width: 5, height: 5)
 }
 }
 }
 }
 .background(.gray)
 .clipShape(RoundedRectangle(cornerRadius: 2.0))
 }
 /*
  private func ledColor(row: Int, col: Int) -> Color {
  let index = (yOffset + row) * MatrixTestView5.X_SEGMENTS + (xOffset / 8)
  let bit = 7 - col
  return framebuffer[index] & (1 << bit) != 0 ? .green : .black
  }
  */
 }
 */
/*
 private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FileImport")

 struct DetailedParsingError: LocalizedError {
 let description: String
 let detailedDescription: String

 var errorDescription: String? {
 return description
 }
 }

 struct Grid: Equatable {
 let width: Int
 let height: Int
 private var data: [Bool]

 init(width: Int, height: Int, data: [Bool]) {
 self.width = width
 self.height = height
 self.data = data
 }

 subscript(x: Int, y: Int) -> Bool {
 get { data[y * width + x] }
 set { data[y * width + x] = newValue }
 }

 func swappedHalves() -> Grid {
 var newData = [Bool]()
 let halfWidth = width / 2
 for y in 0..<height {
 for x in 0..<width {
 if x < halfWidth {
 newData.append(self[x + halfWidth, y])
 } else {
 newData.append(self[x - halfWidth, y])
 }
 }
 }
 return Grid(width: width, height: height, data: newData)
 }
 }

 class MatrixConfig: ObservableObject {
 @Published var rows: Int = 32
 @Published var columns: Int = 64
 @Published var chain: Int = 2
 @Published var grids: [String: Grid] = [:]
 @Published var currentGridKey: String = ""
 }
 */
/*
 struct LEDMatrix3: View {
 let grid: Grid

 var body: some View {
 let swappedGrid = grid.swappedHalves()
 VStack(spacing: 1) {
 ForEach(0..<swappedGrid.height, id: \.self) { row in
 HStack(spacing: 1) {
 ForEach(0..<swappedGrid.width, id: \.self) { column in
 Rectangle()
 .fill(swappedGrid[column, row] ? Color.white : Color.black)
 .frame(width: 3, height: 3)
 }
 }
 }
 }
 .background(Color.gray)
 .padding()
 }
 }
 */
/*
 struct ContentView3: View {
 @StateObject private var config = MatrixConfig()
 @State private var isImporting: Bool = false
 @State private var errorMessage: String?
 @State private var detailedErrorInfo: String?
 @State private var isAnimating: Bool = false

 let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

 var body: some View {
 VStack {
 if let currentGrid = config.grids[config.currentGridKey] {
 LEDMatrix3(grid: currentGrid)
 } else {
 Text("No grid data available")
 }
 VStack {
 Text("Matrix: \(config.rows)x\(config.columns * config.chain)")
 Text("Current Grid: \(config.currentGridKey)")
 }
 .padding()
 .background(.ultraThinMaterial)
 .clipShape(RoundedRectangle(cornerRadius: 5))
 VStack {
 Button("Import File") {
 isImporting = true
 }
 .buttonStyle(.borderedProminent)

 Button(isAnimating ? "Stop Animation" : "Start Animation") {
 isAnimating.toggle()
 logger.info("Animation toggled: \(isAnimating)")
 }
 .buttonStyle(.borderedProminent)

 Button("Next Grid") {
 showNextGrid()
 }
 .buttonStyle(.borderedProminent)
 }
 .padding()

 if let errorMessage = errorMessage {
 Text(errorMessage)
 .foregroundColor(.red)
 }

 if let detailedErrorInfo = detailedErrorInfo {
 Text("Detailed Error Info:")
 .font(.headline)
 Text(detailedErrorInfo)
 .font(.caption)
 }
 }
 .onReceive(timer) { _ in
 if isAnimating {
 showNextGrid()
 }
 }
 .fileImporter(
 isPresented: $isImporting,
 allowedContentTypes: [.text],
 allowsMultipleSelection: false
 ) { result in
 handleFileImport(result: result)
 }
 }
 */
/*
 func handleFileImport(result: Result<[URL], Error>) {
 do {
 guard let selectedFile: URL = try result.get().first else {
 throw NSError(domain: "FileImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file selected"])
 }
 logger.info("File selected: \(selectedFile.lastPathComponent)")

 guard selectedFile.startAccessingSecurityScopedResource() else {
 throw NSError(domain: "FileImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to access the file. Please check app permissions."])
 }

 defer {
 selectedFile.stopAccessingSecurityScopedResource()
 }

 let content = try String(contentsOf: selectedFile)
 logger.info("File content read successfully, length: \(content.count) characters")

 try parseHeaderFile(content)
 logger.info("File parsing completed successfully")
 } catch {
 logger.error("Error importing file: \(error.localizedDescription)")
 errorMessage = "Error importing file: \(error.localizedDescription)"
 if let detailedError = error as? DetailedParsingError {
 detailedErrorInfo = detailedError.detailedDescription
 } else {
 detailedErrorInfo = nil
 }
 }
 }

 func parseHeaderFile(_ content: String) throws {
 logger.info("Starting to parse header file")
 var grids: [String: Grid] = [:]
 var currentGridData: [Bool] = []
 var currentGridKey: String = ""
 var rowCount = 0
 var columnCount = 0
 var linesParsed = 0
 var inGridDeclaration = false
 var openBraceCount = 0
 var continuationLine = ""

 let lines = content.components(separatedBy: .newlines)
 logger.info("Number of lines in file: \(lines.count)")

 for (index, line) in lines.enumerated() {
 linesParsed += 1
 let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

 if trimmedLine.starts(with: "#") || trimmedLine.starts(with: "include") {
 logger.info("Skipping preprocessor line: \(trimmedLine)")
 continue
 }

 if trimmedLine.hasSuffix("=") {
 continuationLine = trimmedLine
 continue
 }

 let processLine = continuationLine + trimmedLine
 continuationLine = ""

 if processLine.contains("const vector<vector<bool>> grid") {
 inGridDeclaration = true
 if !currentGridData.isEmpty && !currentGridKey.isEmpty {
 logger.info("Completed parsing grid: \(currentGridKey), size: \(columnCount)x\(rowCount)")
 grids[currentGridKey] = Grid(width: columnCount, height: rowCount, data: currentGridData)
 currentGridData = []
 rowCount = 0
 }
 currentGridKey = processLine.components(separatedBy: " ").last?.replacingOccurrences(of: "=", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
 logger.info("Started parsing new grid: \(currentGridKey)")
 }

 if inGridDeclaration {
 openBraceCount += processLine.filter { $0 == "{" }.count
 openBraceCount -= processLine.filter { $0 == "}" }.count

 let cleanedLine = processLine.replacingOccurrences(of: "[{},]", with: " ", options: .regularExpression)
 let values = cleanedLine.split(separator: " ").compactMap { Int($0) }

 if !values.isEmpty {
 let boolValues = values.map { $0 == 1 }
 currentGridData.append(contentsOf: boolValues)
 rowCount += 1
 columnCount = max(columnCount, boolValues.count)
 logger.info("Parsed row \(rowCount) with \(boolValues.count) values")
 }

 if openBraceCount == 0 {
 inGridDeclaration = false
 if !currentGridData.isEmpty {
 logger.info("Completed parsing grid: \(currentGridKey), size: \(columnCount)x\(rowCount)")
 grids[currentGridKey] = Grid(width: columnCount, height: rowCount, data: currentGridData)
 currentGridData = []
 rowCount = 0
 columnCount = 0
 }
 }
 }

 if index % 100 == 0 {
 logger.info("Parsed \(index) lines")
 }
 }
 if !grids.isEmpty {
 DispatchQueue.main.async {
 self.config.grids = grids
 self.config.rows = rowCount
 self.config.columns = columnCount / self.config.chain
 self.config.currentGridKey = grids.keys.sorted().first ?? ""
 self.errorMessage = nil
 self.detailedErrorInfo = nil
 logger.info("Updated UI with parsed data. Current grid key: \(self.config.currentGridKey)")
 }
 } else {
 throw DetailedParsingError(
 description: "No valid grid data found in the file",
 detailedDescription: "Parsed \(linesParsed) lines, but couldn't extract any valid grid data."
 )
 }
 }


 func showNextGrid() {
 let sortedKeys = config.grids.keys.sorted()
 logger.info("Sorted keys: \(sortedKeys)")
 if let currentIndex = sortedKeys.firstIndex(of: config.currentGridKey) {
 let nextIndex = (currentIndex + 1) % sortedKeys.count
 config.currentGridKey = sortedKeys[nextIndex]
 logger.info("Switched to grid: \(config.currentGridKey)")
 } else {
 logger.warning("Current grid key not found in sorted keys")
 }
 }
 }
 */
/*
struct infoViewOld: View {
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
            //.border(.green)
            Spacer()
        }
        //.background(Color(UIColor.systemBackground))
    }
}
 */
/*
 struct GlassTest: View {
 struct ConfigOption: Identifiable {
 let id = UUID()
 let name: String
 }
 let rows: [GridItem] = [
 GridItem(.fixed(50)), // You can adjust the height or use `.flexible()` if needed
 GridItem(.fixed(50)) // You can adjust the height or use `.flexible()` if needed
 ]
 let configOptions: [ConfigOption] = SharedOptions.protoConfigOptions.map { ConfigOption(name: $0) }
 var body: some View{
 ZStack {
 // Vibrant Background
 VibrantBackground()
 /*
  GlassPane(cornerRadius: 20) {
  Text("Hello World! 🌐")
  }
  .padding(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
  */
 ScrollView(.horizontal) {
 // GlassLazyHGrid
 GlassLazyHGrid(items: configOptions, rows: rows, cornerRadius: 20.0, spacing: 8) { option in
 Text("\(option.name)")
 .padding()
 }
 .padding()
 }
 }
 }
 }
 */
/*
struct VibrantBackground: View {
    var body: some View {
        ZStack {
            Color.gray
                .opacity(0.25)
                .ignoresSafeArea()

            Color.white
                .opacity(0.7)
                .blur(radius: 200)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let size = proxy.size

                Circle()
                    .fill(.purple)
                    .padding(50)
                    .blur(radius: 120)
                    .offset(x: -size.width / 1.8, y: -size.height / 5)

                Circle()
                    .fill(.blue)
                    .padding(50)
                    .blur(radius: 150)
                    .offset(x: size.width / 1.8, y: size.height / 2)
            }
        }
    }
}
*/
/*
 #Preview("Glass View") {
 GlassTest()
 }
 */


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


