//
//  ContentView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//

import SwiftUI
import CoreBluetooth
import AVKit
import CoreImage
import Charts
import UniformTypeIdentifiers
import os
import Combine
import MarkdownUI

import CoreHaptics

let actions = SharedOptions.protoActionOptions3
let configs = SharedOptions.protoConfigOptions

// IOS 18.0 features
//import AccessorySetupKit

// ----- iOSViewModel Definition -----
// (Technically possible to put it here)
@MainActor
class iOSViewModel: ObservableObject {
    @Published var receivedCommand: String = "None"
    @Published var receivedFaceFromWatch: String? = nil
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // ... (Subscription logic as before) ...
        WatchConnectivityManager.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messageData in
                // ... (message handling logic as before) ...
                guard let self = self, let command = messageData["command"] as? String else { return }
                self.receivedCommand = command
                if command == "setFace", let face = messageData["faceValue"] as? String {
                    self.receivedFaceFromWatch = face
                } else {
                    self.receivedFaceFromWatch = nil // Clear for other commands or errors
                }
            }
            .store(in: &cancellables)
    }
}

struct WidgetItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
}

let widgetItems = [
    WidgetItem(
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
        title: "New Face Effects",
        description: """
            • Plasma animation functions for a smooth, dynamic facial display
            • Non-blocking blink animations and blush effect with easing functions
            • Rotating spiral animation triggered via strong shake detection
            """,
        iconName: "sparkles"
    ),
    WidgetItem(
        title: "View Control & Temperature Updates",
        description: "• Sleep modes for improved battery life",
        iconName: "thermometer"
    ),
    WidgetItem(
        title: "Robust Sensor Integration",
        description: """
            • Proximity sensor integration for triggering visual effects (e.g., blush)
            • Accelerometer-based motion detection with dual sensitivity for active and sleep modes
            • Adaptive brightness
            """,
        iconName: "sensor.tag.radiowaves.forward"
    )
]

struct AppInfo {
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }
    
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }
    
    static var versionDisplay: String {
        "\(appVersion) (\(buildNumber))"
    }
}

struct WhatsNew: View {
    // Persist the last shown version in user defaults
    @AppStorage("lastAppVersion") private var lastAppVersion: String = ""
    // Get the current version from the bundle (default to "1.0" if not found)
    private let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    // Controls whether the splash screen is visible
    @State private var shouldShow: Bool = true
    @Environment(\.dismiss) var dismiss
    var body: some View {
        Group {
            if shouldShow {
                ZStack {
                    Color(.clear)
                        .ignoresSafeArea()
                        .background(.ultraThinMaterial)
                    VStack {
                        Spacer()
                        Text("What's New in LumiFur")
                            .font(.system(.largeTitle, weight: .bold))
                            .frame(width: 240)
                            .clipped()
                            .multilineTextAlignment(.center)
                            .padding(.top, 82)
                            .padding(.bottom, 10)
                        VStack(spacing: 28) {
                            ScrollView {
                                ForEach(widgetItems) { item in // Replace with your data model here
                                    HStack {
                                        Image(systemName: item.iconName)
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(.blue)
                                            .font(.system(.title, weight: .regular))
                                            .frame(width: 60, height: 50)
                                            .clipped()
                                        VStack(alignment: .leading, spacing: 3) {
                                            // Title
                                            Text(item.title)
                                                .font(.system(.footnote, weight: .semibold))
                                            // Description
                                            Text(item.description)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline) {
                            Text("Complete feature list")
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                        }
                        .padding(.top, 10)
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                        //Spacer()
                        BouncingButton(action: {
                            // Update the stored version and dismiss the splash screen
                            lastAppVersion = currentVersion
                            dismiss()
                            withAnimation { shouldShow = false }
                        }) {
                            Text("Continue")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .padding(.horizontal)
                        }
                        .padding()
                        Spacer()
                    }
                    //.background(.ultraThinMaterial)
                    .transition(.opacity)
                    .animation(.easeInOut, value: shouldShow)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .padding(.top, 53)
                    .padding(.bottom, 0)
                    .padding(.horizontal, 29)
                }
                //.padding()
                .ignoresSafeArea()
            }
        }
        .onAppear {
            // Show the "What's New" screen if the current version differs from the last stored version
            if lastAppVersion != currentVersion {
                shouldShow = true
            }
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity)
        //.clipped()
        //.padding(.top, 53)
        //.padding(.bottom, 0)
        //.padding(.horizontal, 29)
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
 */
struct SplashView: View {
    //Protogen hover effect
    @State private var fadeTitle: CGFloat = 20
    @State private var fadeSubtitle: CGFloat = 20
    @State private var yOffset: CGFloat = -10
    @State private var appearing: Bool = true
    @State private var animationDirection: Bool = true // True for moving up, false for moving down
    @Binding var showSplash: Bool
    let animationDuration: Double =  2.0 //Duratio for full hover effect
    var body: some View {
        NavigationStack {
            ZStack {
                meshGradient()
                    .ignoresSafeArea()
                    .opacity(0.2)
                //.saturation(1.2)
                VStack {
                    ZStack {
                        Image("Image")
                            .renderingMode(.template)
                            .resizable()
                            .offset(y: yOffset)
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
                                    yOffset = animationDirection ? -20 : 20
                                }
                            }
                            .aspectRatio(contentMode: .fill)
                            .opacity(0.5)
                            .background(Material.ultraThin)
                            .clipped()
                            .frame(minWidth: 30, maxHeight: .infinity)
                        //.border(.red)
                            .overlay(alignment: .topLeading) {
                                // Hero
                                VStack(alignment: .leading, spacing: 11) {
                                    // App Icon
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(Color(uiColor: .systemBackground))
                                        .frame(width: 72, height: 72)
                                        .clipped()
                                        .shadow(color: Color(.sRGBLinear, red: 0/255, green: 0/255, blue: 0/255).opacity(0.12), radius: 8, x: 0, y: 4)
                                        .overlay {
                                            Image("LumiFurFrontSymbol")
                                                .imageScale(.large)
                                                .font(.system(size: 31, weight: .regular, design: .default))
                                                .onAppear()
                                        }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("LumiFur")
                                        //.font(.largeTitle)
                                            .font(Font.custom("Meloriac", size: 45))
                                        //.fontDesign(.monospaced)
                                        //.fontWeight(.heavy)
                                            .blur(radius: fadeTitle)
                                            .onAppear {
                                                withAnimation(Animation.easeInOut(duration: 2)) {
                                                    fadeTitle = appearing ? 0 : 20
                                                }
                                            }
                                        Text("The worlds Most Advanced Fursuit software")
                                            .font(.system(.headline, weight: .medium))
                                            .frame(width: 190, alignment: .leading)
                                            .clipped()
                                            .multilineTextAlignment(.leading)
                                            .shadow(radius: 5)
                                            .blur(radius: fadeSubtitle)
                                            .onAppear {
                                                withAnimation(Animation.easeInOut(duration: 2).delay(1)) {
                                                    fadeSubtitle = appearing ? 0 : 20
                                                }
                                            }
                                    }
                                }
                                .padding(30)
                            }
                            .overlay(alignment: .bottom) {
                                // Planes Visual
                                HStack {
                                    Spacer()
                                    ForEach(0..<5) { _ in // Replace with your data model here
                                        //Spacer()
                                        Image(systemName: "sun.max.fill")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image("bluetooth.fill")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "thermometer")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "move.3d")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "applewatch")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "widget.extralarge.badge.plus")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "powersleep")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "keyboard.badge.ellipsis.fill")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "lines.measurement.vertical")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        //Spacer()
                                    }
                                }
                                .frame(maxWidth: 300)
                                .clipped()
                                .padding()
                                .background {
                                    Rectangle()
                                        .fill(Color.secondary)
                                        .opacity(0.5)
                                        .background(Material.thin)
                                        .mask {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .frame(maxHeight: .infinity)
                                                .clipped()
                                            
                                        }
                                        .padding(.horizontal, 12)
                                }
                                .padding()
                            }
                            .mask {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                            }
                            .padding()
                            .shadow(color: Color(.sRGBLinear, red: 0/255, green: 0/255, blue: 0/255).opacity(0.15), radius: 18, x: 0, y: 14)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity,maxHeight: 600)
                    
                    VStack(spacing: 10) {
                        // Button to dismiss the splash view.
                        Button {
                            // Dismiss the splash view with animation.
                            withAnimation {
                                showSplash = false
                            }
                        } label: {
                            // The Continue button design.
                            VStack(spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: "aqi.medium")
                                        .imageScale(.medium)
                                    Text("Continue")
                                }
                                .font(.system(.body, weight: .medium))
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .foregroundStyle(.purple)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(.clear.opacity(0.25), lineWidth: 0)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(.primary.opacity(0.15))
                                        )
                                }
                                .padding(.horizontal, 32)
                            }
                        }
                        .padding(.horizontal,10)
                        
                        NavigationLink {
                            InfoView()
                        } label: {
                            Label("About", systemImage: "info.circle")
                        }
                        .padding(.top)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        
                    }
                    .padding(.horizontal)
                    Spacer()
                }
            }
            .background(Color.white)
        }}
}

// MARK: ContentView
struct ContentView: View {
    // Use @AppStorage to persist a flag in UserDefaults.
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = true
    // Local state to control the splash screen appearance.
    @State private var showSplash = true
    @AppStorage("fancyMode") private var fancyMode: Bool = false
    // Colot Scheme
    @Environment(\.colorScheme) var colorScheme
    var overlayColor: Color {
        colorScheme == .dark ? .init(uiColor: .systemGray6) : .white
    }
    
    @State private var showSignalView = false
    
    // Taptic Engine
    @State private var engine: CHHapticEngine?
    
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }; do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }
    }
    
    func complexSuccess() {
        // make sure that the device supports haptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        var events = [CHHapticEvent]()
        
        // create one intense, sharp tap
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(event)
        
        // convert those events into a pattern and play it immediately
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play pattern: \(error.localizedDescription).")
        }
    }
    
    @State private var isLedArrayExpanded: Bool = false
    @StateObject private var viewModel = iOSViewModel() // Instantiates the class defined above
    @StateObject private var accessoryViewModel = AccessoryViewModel()
    
    //Connectivity Options
    enum Connection: String, CaseIterable, Identifiable {
        case bluetooth, wifi, matter, z_wave
        var id: Self { self }
    }
    //@State private var selectedConnection: Connection = .bluetooth
    @State private var selectedMatrix: SettingsView.Matrixstyle = .array
    
    private let twoColumnGrid = [
        GridItem(.adaptive(minimum: 125, maximum: 250))
    ]
    private let twoRowOptionGrid = [
        GridItem(.adaptive(minimum: 25, maximum: 250)),
        GridItem(.adaptive(minimum: 25, maximum: 250))
    ]
    
    //dotMatrix variable
    @State private var dotMatrices: [[Bool]] = Array(repeating: Array(repeating: false, count: 64), count: 32)
    
    @State private var errorMessage: String? = nil
    
    //Protogen image variables
    @State private var yOffset: CGFloat = 0
    @State private var animationDuration: Double = 1.0
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack {
                    headerSection
                    ledArraySection
                    //.border(Color.green, width: 1)
                    optionGridSection
                    faceGridSection
                    settingsAndChartsSection
                    //.border(.green)
                    /*
                     HStack {
                     // animated image
                     animatedProtogenImage(yOffset: $yOffset, animationDirection: true, animationDuration: animationDuration)
                     
                     //.border(Color.red)
                     .scaledToFill()
                     .frame(height: 100)
                     .offset(CGSize(width: 0.0, height: 20.0))
                     
                     Text("LumiFur")
                     .font(.title)
                     .multilineTextAlignment(.trailing)
                     .fontDesign(.monospaced)
                     .padding(.horizontal)
                     
                     Spacer()
                     
                     }
                     
                     VStack {
                     // Status Indicators and Signal Strength
                     HStack {
                     Spacer()
                     HStack {
                     // Signal Strength Indicator
                     SignalStrengthView(rssi: bluetoothManager.signalStrength)
                     
                     // Connection Status
                     //Image(systemName: bluetoothManager.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                     //.symbolRenderingMode(.multicolor)
                     //.symbolEffect(.variableColor)
                     //.foregroundColor (bluetoothManager.isConnected ? .green : .gray)
                     
                     // Bluetooth Status
                     Image(systemName: "logo.bluetooth.capsule.portrait.fill")
                     .symbolRenderingMode(.multicolor)
                     .symbolEffect(.variableColor)
                     .opacity(bluetoothManager.isConnected ? 1 : 0.3)
                     }
                     .padding(.all, 10.0)
                     .background(.ultraThinMaterial)
                     .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
                     .border(Color.green)
                     }
                     //.border(Color.purple)
                     .offset(CGSize(width: -20.0, height: -40.0))
                     }
                     //LED ARRAY MAIN VIEW
                     VStack {
                     HStack {
                     Spacer()
                     //  MatrixTestView5()
                     // LEDMatrix()
                     LEDPreview()
                     .background(.ultraThinMaterial)
                     Spacer()
                     LEDPreview()
                     .background(.ultraThinMaterial)
                     Spacer()
                     }
                     .padding()
                     }
                     .background(.ultraThinMaterial)
                     .clipShape(RoundedRectangle(cornerRadius: 25.0))
                     .frame(width: .infinity, height: 100)
                     .offset(CGSize(width: 0, height: -40))
                     .padding()
                     .border(Color.purple)
                     //Spacer()
                     
                     // Grid of squares
                     ScrollView(.horizontal) {
                     LazyHGrid(rows: twoColumnGrid, alignment: .center, spacing: 0) {
                     ForEach(protoActionOptions , id: \.self) { item in
                     //GeometryReader { gr in
                     Button(action: {
                     // Define the action for the button here
                     print("\(item) button pressed")
                     }) {
                     Text(item)
                     //.imageScale(.large)
                     .font(.system(size: 120))
                     //.resizable()
                     //.frame(maxHeight: .infinity, maxWidth: .infinity) // Makes the image fill the available space
                     .aspectRatio(1, contentMode: .fit)
                     .border(Color.green)
                     .symbolRenderingMode(.monochrome)
                     .background(.clear)
                     }
                     .aspectRatio(1, contentMode: .fit)
                     .background(.ultraThinMaterial)
                     .cornerRadius(10)
                     .padding()
                     .frame(width: 175, height:175)
                     .border(Color.red)
                     }
                     }
                     .border(Color.yellow)
                     //.aspectRatio(1, contentMode: .fit)
                     .frame(maxHeight: .infinity)
                     .padding()
                     }
                     
                     // Settings Button
                     HStack {
                     Spacer()
                     HStack {
                     VStack {
                     Chart(bluetoothManager.cpuUsageData) {
                     LineMark(
                     x: .value("Time", $0.timestamp),
                     y: .value("CPU Usage", $0.cpuUsage)
                     )
                     .foregroundStyle(Color.blue)
                     .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 2]))
                     .symbol(Circle().strokeBorder(lineWidth: 2)) // Corrected symbol usage=
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
                     .cornerRadius(10)
                     .frame(height: 50)
                     
                     Text("CPU")
                     .fontDesign(.rounded)
                     .bold()
                     }
                     //.frame(width: 30, height: 50)
                     VStack {
                     Chart(bluetoothManager.cpuUsageData) {
                     LineMark(
                     x: .value("Time", $0.timestamp),
                     y: .value("CPU Usage", $0.cpuUsage)
                     )
                     .foregroundStyle(Color.blue)
                     .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 2]))
                     .symbol(Circle().strokeBorder(lineWidth: 2)) // Corrected symbol usage
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
                     .font(.caption2)
                     }
                     }
                     }
                     }
                     .padding()
                     .background(.ultraThinMaterial)
                     .cornerRadius(10)
                     .frame(height: 50)
                     
                     Text("Temperature")
                     .fontDesign(.rounded)
                     .bold()
                     
                     }
                     //.frame(maxWidth: 30, maxHeight: 50)
                     }
                     .padding(.bottom,40)
                     
                     //NavigationLink(destination: ContentView3()) {Image(systemName: "info")}
                     NavigationLink(destination: SettingsView(selectedMatrix: $selectedMatrix)) {
                     Image(systemName: "gear")
                     .imageScale(.large)
                     .symbolRenderingMode(.multicolor)
                     NavigationLink(destination: BluetoothConnectionView())
                     {Image(systemName: "1.circle.fill")}
                     }
                     .padding()
                     }
                     */
                }
                .background(Group {
                    if fancyMode {
                        if #available(iOS 18, *) {
                            meshGradient()
                                .ignoresSafeArea()
                                .opacity(0.2)
                        } else {
                            Color(overlayColor)
                        }
                    } else {
                        Color(overlayColor)
                    }
                }.ignoresSafeArea()
                )
                //.background(Color.clear)
                .onChange(of: viewModel.receivedFaceFromWatch) { oldValue, newValue in
                    handleWatchFaceSelection(face: newValue) }
                .onAppear(perform: prepareHaptics)
            }
            .scrollContentBackground(.hidden)
            //.background(overlayColor)
            .navigationTitle("LumiFur")
            //meshGradient()
            //.ignoresSafeArea()
            
            // Show splash only if it's the first launch and the splash hasn't been dismissed yet.
            if !hasLaunchedBefore && showSplash {
                SplashView(showSplash: $showSplash)
                // Using an asymmetric transition:
                // When appearing, the splash view fades in.
                // When dismissing, it scales down (with a fade effect as well)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 0.8, anchor: .center)
                    ))
                
            }
        }
        // Animate changes to showSplash.
        .animation(.easeInOut(duration: 1.5), value: showSplash)
        .onDisappear { engine?.stop() }
    }
    
    private var headerSection: some View {
        HStack {
            Image("Image")
                .resizable()
                .scaledToFit()
                .frame(maxWidth:150,maxHeight: 150)
            Spacer()
            VStack(alignment: .trailing, spacing: 6.0) {
                Text("LumiFur")
                //.font(.largeTitle)
                    .font(Font.custom("Meloriac", size: 35))
                    .frame(width: 150)
                //.fontDesign(.monospaced)
                    .padding(.top, 5)
                statusSection
            }
        }
        .frame(height: 100)
        .padding(.horizontal)
    }
    
    private var statusSection: some View {
        HStack(spacing: 8) {
            if showSignalView {
                SignalStrengthView(rssi: accessoryViewModel.signalStrength)
                    .transition(.move(edge: .trailing))
            }
            // only show RSSI when truly “.connected”
            Image(accessoryViewModel.connectionImageName)
            // choose a mode that *allows* tinting
                .symbolRenderingMode(
                    accessoryViewModel.connectionState == .connected
                    ? .hierarchical      // iOS 15+; retains depth but is tinted
                    : .monochrome        // single-color, template style
                )
            // use foregroundStyle (preferred) or foregroundColor
            //.foregroundStyle(accessoryViewModel.connectionColor)
            // optional: fade out when not connected
                .opacity(accessoryViewModel.connectionState == .connected ? 1 : 0.5)
            
            Text(accessoryViewModel.connectionStatus)
                .font(.caption)
                .foregroundStyle(accessoryViewModel.connectionColor)
        }
        .animation(.easeInOut, value: showSignalView) // Smooth animation
        .onChange(of: accessoryViewModel.connectionState) { oldValue, newValue in
            withAnimation {
                showSignalView = newValue != .disconnected
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .background(Group {
            if fancyMode {
                Color(overlayColor)
            }
        }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var ledArraySection: some View {
        DisclosureGroup("LED Array", isExpanded: $isLedArrayExpanded) {
            if isLedArrayExpanded{
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
            }}
                .padding([.top, .leading, .trailing])
                .accentColor(.gray)
                .ignoresSafeArea()
                .scrollContentBackground(.hidden)
            //.background(overlayColor)
        }
    
    static let gradientStart = Color(red: 0 / 255, green: 0 / 255, blue: 0 / 255)
    static let gradientEnd = Color(red: 239.0 / 255, green: 172.0 / 255, blue: 120.0 / 255)
    
    @AppStorage("autoBrightness") private var autoBrightness = true
    @AppStorage("accelerometer") private var accelerometer = true
    @AppStorage("sleepMode") private var sleepMode = true
    @AppStorage("auroraMode") private var auroraMode = true
    @AppStorage("customMessage") private var customMessage = false
    
    @State private var customMessageText: String = ""
    
    private var optionGridSection: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: twoRowOptionGrid) {
                OptionToggleView(
                    title: "Auto Brightness",
                    isOn: $autoBrightness,
                    optionType: .autoBrightness
                )
                OptionToggleView(
                    title: "Accelerometer",
                    isOn: $accelerometer,
                    optionType: .accelerometer
                )
                OptionToggleView(
                    title: "Sleep Mode",
                    isOn: $sleepMode,
                    optionType: .sleepMode
                )
                OptionToggleView(
                    title: "Aroura Mode",
                    isOn: $auroraMode,
                    optionType: .auroraMode
                )
                OptionToggleView(
                    title: "Custom Message",
                    isOn: $customMessage,  // Binding<Bool> for the toggle
                    optionType: .customMessage
                )
                
                // Optionally show a TextField when the toggle is on:
                if customMessage {
                    TextField("Enter your custom message", text: $customMessageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }
                
            }
        }
        .scrollContentBackground(.hidden)
        //.ignoresSafeArea()
        .scrollClipDisabled()
        .frame(maxHeight: 80)
        .padding(.horizontal)
        //.border(.blue)
    }
    
    private var faceGridSection: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: twoColumnGrid) {
                ForEach(SharedOptions.protoActionOptions3.indices, id: \.self) { index in
                    FaceCellView(
                        action: SharedOptions.protoActionOptions3[index],
                        index: index + 1,
                        selected: accessoryViewModel.selectedView,
                        onTap: { accessoryViewModel.setView($0) }
                    )
                }
            }
        }
        .padding()
        .scrollContentBackground(.hidden)
        .ignoresSafeArea()
        .scrollClipDisabled()
        .frame(maxHeight: .infinity)
        //.border(.red)
        
        //.mask(LinearGradient(gradient: Gradient(colors: [.clear, .black, .black, .black, .black, .black, .black, .black, .black, .black, .black, .black, .clear]), startPoint: .leading, endPoint: .trailing))
    }
    // MARK: - Helper Functions (Place handleWatchFaceSelection HERE)
    
    /// Handles processing the face selection received from the watch.
    private func handleWatchFaceSelection(face: String?) { // <--- DEFINITION INSIDE ContentView
        guard let selectedFace = face else {
            print("Watch face selection cleared or invalid.")
            return
        }
        
        // Find the index where the enum's String == selectedFace
        if let index = SharedOptions.protoActionOptions3.firstIndex(where: { action in
            switch action {
            case .emoji(let e):    return e == selectedFace
            case .symbol(let s):   return s == selectedFace
            }
        }) {
            let viewToSet = index + 1
            print("Watch requested face '\(selectedFace)' at index \(index). Setting view \(viewToSet).")
            accessoryViewModel.setView(viewToSet)
        } else {
            print("Received face '\(selectedFace)' from watch, but it wasn’t in protoActionOptions3.")
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
        case .emoji(let e):  return e
        case .symbol(let s): return s
        }
    }
    
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
                        .chartXScale(domain: Date().addingTimeInterval(-3 * 60)...Date())
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
                                AxisValueLabel(format: .dateTime.minute().second())
                                    .font(.caption2)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic) { axisValue in
                                AxisValueLabel() {
                                    if let temp = axisValue.as(Double.self) {
                                        Text(String(format: "%.0f°C", temp))
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                        .drawingGroup()
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .frame(maxWidth:.infinity,maxHeight: 80)
                        
                        Text("Temperature (°C)")
                            .padding(.top, 4)
                            .font(.caption)
                    }
                }
            }
            .onReceive(accessoryViewModel.temperatureChartPublisher) { newSamples in
                self.samples = newSamples
            }
            .animation(.easeInOut(duration: 1.5), value: accessoryViewModel.temperatureData) // Single smooth update animation. // Animate based on data change
            // Isolated NavigationLinks
            NavigationLink(destination: SettingsView(bleModel: accessoryViewModel, selectedMatrix: $selectedMatrix)) {
                Image(systemName: "gear")
                    .imageScale(.large)
                    .symbolRenderingMode(.multicolor)
            }
        }
        //.background(.clear)
        .padding([.top, .leading, .trailing])
        //.frame(maxHeight: 100)
        .scrollContentBackground(.hidden)
        //.background(overlayColor)
    }
}

struct FaceCellView: View {
    let action: SharedOptions.ProtoAction
    let index: Int
    let selected: Int
    let onTap: (Int) -> Void
    
    var body: some View {
        BouncingButton {
            withAnimation(.easeInOut(duration: 0.3)) {
                onTap(index)
            }
        } label: {
            Group {
                switch action {
                case .emoji(let e):
                    Text(e)
                        .dynamicTypeSize(.xxxLarge)
                        .font(.system(size: 40))
                case .symbol(let s):
                    Image(systemName: s)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(0.25)
                        //.padding(70)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .frame(maxWidth: 250, maxHeight: 250)
            .foregroundStyle(.foreground)
            .background {
                if selected == index {
                    ZStack {
                        //meshGradient()
                        Rectangle()
                            .fill(Color.white)
                            .opacity(0.8)
                            .overlay(.ultraThinMaterial)
                    }
                } else {
                    // Material must be used inside a view
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(15)
        }
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
// MARK: SettingsView

struct SettingsView: View {
    
    // Using @AppStorage to persist each option's state.
    @AppStorage("fancyMode") private var fancyMode = true
    @AppStorage("autoBrightness")  var autoBrightness = true
    @AppStorage("accelerometer")  var accelerometer = true
    @AppStorage("sleepMode")  var sleepMode = true
    @AppStorage("arouraMode")  var arouraMode = true
    @AppStorage("customMessage")  var customMessage = false
    
    @State private var scanButtonTapped = false
    
    @State private var fontSize: CGFloat = 15
    @State private var showLineNumbers = false
    @State private var showPreview = true
    @ObservedObject var bleModel: AccessoryViewModel
    //ObservedObject var toggledStates: ContentView
    @State private var showAdvanced = false
    @State private var selectedUnits: TempUnit = .℃
    @Binding var selectedMatrix: Matrixstyle
    @Environment(\.repositoryConfig) private var config // Still read config here
    @StateObject private var releaseViewModel = ReleaseViewModel()
    //Connectivity Options
    enum Connection: String, CaseIterable, Identifiable {
        case bluetooth, wifi, matter
        var id: Self { self }
    }
    //Matrix Options
    enum Matrixstyle: String, CaseIterable, Identifiable {
        case array, dot, wled
        var id: Self { self }
    }
    enum TempUnit: String, CaseIterable, Identifiable {
        case ℃, ℉
        var id: Self { self }
    }
    
    // State for Scan button animation
    @State private var isScanningForButton = false // Separate state for button animation trigger
    @Environment(\.colorScheme) var colorScheme
    
    var overlayColor: Color {
        colorScheme == .dark ? .init(uiColor: .systemGray5) : .white
    }
    
    @State private var isLedArrayExpanded: Bool = false
    
    var body: some View {
        
        NavigationStack {
            List {
                // Section 1: Connection Status
                connectionStatusSection
                // Section 2: Device Connection (Dynamic Content)
                if bleModel.isConnected {
                    connectedDeviceSection
                } else {
                    discoveredDevicesSection
                    if !bleModel.previouslyConnectedDevices.isEmpty {
                        previouslyConnectedSection
                            .transition(.opacity.combined(with: .slide))
                    }
                }
                // Section 3: Regional Settings
                configSection
                // Section 4: Matrix Configuration
                matrixSection
                // Section 5: Advanced Settings
                advancedSettingsSection
                // Section 6: More Options
                aboutSection
                releaseNotesSection
            }
            .animation(.easeInOut, value: bleModel.isConnected)
            //.animation(.easeInOut, value: bleModel.previouslyConnectedDevices) // Watch array changes
            .animation(.easeInOut, value: bleModel.discoveredDevices) // Watch array changes
            .animation(.easeInOut, value: bleModel.connectingPeripheral) // Watch connecting state
            //.listStyle(.insetGrouped)
            //.listRowBackground(Color.blue)
            .background(Color(UIColor.systemGray6))
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Consider moving Info link into the About section?
                    NavigationLink(destination: InfoView()) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            /*
             .toolbar {
             ToolbarItem(placement: .navigationBarTrailing) {
             NavigationLink(destination: InfoView()) {
             Image(systemName: "info.circle")
             }
             }
             }
             */
            .alert("Connection Error", isPresented: $bleModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(bleModel.errorMessage)
            }
            // Refresh list content when connection state changes
            .id(bleModel.isConnected)
            // Start scanning immediately if BT is ready and not connected
            .task {
                // Use config directly from environment when calling load methods
                // Only fetch if needed
                if releaseViewModel.appReleases.isEmpty && !releaseViewModel.isLoadingAppReleases {
                    await releaseViewModel.loadAppReleases(
                        owner: config.appRepoName, // Get from config
                        repo: config.appRepoName      // Get from config
                    )
                }
                if releaseViewModel.controllerReleases.isEmpty && !releaseViewModel.isLoadingControllerReleases {
                    await releaseViewModel.loadControllerReleases(
                        owner: config.controllerRepoOwner, // Get from config
                        repo: config.controllerRepoName   // Get from config
                    )
                }
            }
            .onAppear {
                if bleModel.isBluetoothReady && !bleModel.isConnected {
                    // Don't trigger button animation on initial appear scan
                    bleModel.scanForDevices()
                }
            }
        }
    }
    
    // MARK: - About Section (New)
    private var aboutSection: some View {
        Section("About") {
            HStack { Text("App Version"); Spacer(); Text(AppInfo.versionDisplay).foregroundColor(.secondary) }
            // Read directly from environment config here
            HStack {
                Text("LumiFur Controller Firmware"); Spacer(); Text(bleModel.firmwareVersion)
                    .foregroundColor(.secondary)
            }
            .opacity(bleModel.isConnected ? 1 : 0.5)
        }
    }
    
    // MARK: - Connection Section
    @State  var animateSymbol = false
    var connectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Section{
                if !bleModel.isConnected {
                    HStack {
                        Spacer()
                        Button(action: {
                            self.scanButtonTapped = true
                            bleModel.scanForDevices()
                            animateSymbol.toggle()
                        }){
                            if #available(iOS 18.0, *) {
                                Label("Scan for Devices", systemImage: "arrow.clockwise")
                                    .symbolEffect(.rotate, value: animateSymbol)
                            } else {
                                Label("Scan for Devices", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        onChange(of: bleModel.isScanning) { _ , isScanningNow in
                            if !isScanningNow {
                                scanButtonTapped = false // Reset when scanning stops
                            }
                        }
                        .onChange(of: bleModel.isConnected) { _, isConnectedNow in
                            if isConnectedNow {
                                scanButtonTapped = false // Reset if connected
                            }
                        }
                        Spacer()
                    }
                }
                deviceList
            }
        }
    }
    
    var deviceList: some View {
        Group {
            if bleModel.isConnected, let device = bleModel.connectedDevice {
                AnyView(ConnectedDeviceView(peripheral: device))
            } else {
                AnyView(
                    VStack(alignment: .leading, spacing: 16) {
                        // Discovered Devices Section
                        ForEach(bleModel.discoveredDevices) { device in
                            Button(action: {
                                bleModel.connect(to: device)
                            }) {
                                HStack {
                                    Text(device.name)
                                    Spacer()
                                    SignalStrengthView(rssi: bleModel.signalStrength)
                                    if bleModel.connectingPeripheral?.id == device.id {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(bleModel.isConnecting)
                        }
                        
                        // Previously Connected Devices Section
                        if !bleModel.previouslyConnectedDevices.isEmpty {
                            Text("Previously Connected Devices")
                                .font(.headline)
                                .padding(.top)
                            
                            ForEach(bleModel.previouslyConnectedDevices) { storedDevice in
                                Button(action: {
                                    bleModel.connectToStoredPeripheral(storedDevice)
                                }) {
                                    HStack {
                                        Text(storedDevice.name)
                                        Spacer()
                                        Image(systemName: "clock.arrow.circlepath")
                                    }
                                }
                                .disabled(bleModel.isConnecting)
                            }
                        }
                    }
                        .padding()
                )
            }
        }
    }
    
    var advancedSettings: some View {
        Section {
            Toggle("Show Advanced Settings", isOn: $showAdvanced)
            
            if showAdvanced {
                Toggle("Fancy Mode", isOn: $fancyMode)
                    .toggleStyle(SwitchToggleStyle())
                
                NavigationLink("Connection Parameters") {
                    AdvancedSettingsView(bleModel: bleModel)
                }
                Button("Reset to Defaults") {
                    // Handle reset logic here
                    //resetAdvancedSettings()
                }
                .disabled(true)
            }
        }
        // Smoothly animate changes when showAdvanced toggles.
        .animation(.easeInOut, value: showAdvanced)
    }
    
    // MARK: - Connection Status Section
    var connectionStatusSection: some View {
        Section("Status") {
            VStack {
                Image("bluetooth.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height:40)
                    .padding(.top)
                    .symbolRenderingMode(.monochrome)
                    .opacity(0.5)
                
                Text("Connect to your LumiFur Controller accessory to start using this app.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                HStack {
                    Spacer()
                    Image(systemName: bleModel.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(bleModel.connectionColor)
                    Text(bleModel.connectionStatus)
                        .foregroundColor(bleModel.connectionColor)
                    //Spacer()
                    if bleModel.isConnected {
                        //SignalStrengthView(rssi: bleModel.signalStrength)
                        if #available(iOS 17.0, *) {
                            SignalStrengthView(rssi: bleModel.signalStrength)
                                .transition(.symbolEffect(.disappear.down)) // iOS 17+ transition
                            
                        } else if bleModel.isConnecting || bleModel.isScanning { // Combine conditions
                            ProgressView()
                                .frame(width: 20, height: 20)
                                .transition(.opacity) // Transition for ProgressView
                        }
                        // Implicit else: Disconnected, not connecting/scanning
                    }
                    Spacer()
                }
                .animation(.easeInOut, value: bleModel.isConnected)
                .animation(.easeInOut, value: bleModel.isConnecting)
                .animation(.easeInOut, value: bleModel.isScanning)
                //.border(.green)
            }
        }
        .listRowBackground(overlayColor)
    }
    
    // MARK: - Connected Device Section
    @State private var showControllerImage: Bool = false
    
    var connectedDeviceSection: some View {
        Section("Connected Device") {
            if let device = bleModel.targetPeripheral { // Use targetPeripheral directly
                VStack {
                    HStack {
                        Image(systemName: "personalhotspot.circle.fill") // Example icon
                            .foregroundColor(.blue)
                        Text(device.name ?? "Unknown Device")
                            .fontWeight(.semibold)
                        Spacer()
                        Button("Disconnect", role: .destructive) {
                            bleModel.disconnect()
                        }
                        //.buttonStyle(.bordered)
                        .tint(.red) // Make disconnect button red
                    }
                    HStack {
                        HStack {
                            Image("mps3")
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .frame(width: 150, height: 150)
                            
                        }.animation(.easeInOut(duration: 0.5), value: bleModel.targetPeripheral)
                            .transition(.move(edge: .leading))
                        
                        Spacer()
                        HStack {
                            VStack(alignment: .trailing, spacing: 4) {
                                if let name = device.name, !name.isEmpty {
                                    //Text("Name")
                                    //    .font(.title3).bold()
                                    Text("LF-05082")
                                        .font(.title).bold()
                                }
                                HStack {
                                    Text("Hardware Version:")
                                    // Text(device.hardwareVersion)
                                    Text("2.0.1")
                                }
                                HStack {
                                    Text("Software Version:")
                                    // Text(device.softwareVersion)
                                    Text("1.5.0")
                                }
                            }
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                        }
                    }
                }
                .transition(.opacity.combined(with: .slide))
            } else {
                // This shouldn't ideally happen if isConnected is true, but good fallback
                Text("Connected (Error fetching name)")
                    .foregroundColor(.orange)
            }
        }
        .transition(.opacity.combined(with: .slide))
        .listRowBackground(overlayColor)
    }
    
    // MARK: - Discovered Devices Section
    
    var discoveredDevicesSection: some View {
        // let isConnected = bleModel.isConnected
        // let isScanning = bleModel.isScanning
        return Section {
            // Scan Button
            Button {
                isScanningForButton.toggle() // Trigger animation
                bleModel.scanForDevices()
            } label: {
                if !bleModel.isConnected && !bleModel.isScanning{
                    
                    if #available(iOS 18.0, *) {
                        Label("Scan for Devices", systemImage: "arrow.clockwise")
                        // Apply effect only on iOS 17+
                            .symbolEffect(.rotate, options: .repeating, value: bleModel.isScanning && isScanningForButton)
                    } else {
                        Label("Scan for Devices", systemImage: "arrow.clockwise")
                    } // Rotate when scanning AND button triggered it
                }
            }
            //.disabled(!bleModel.isBluetoothReady || bleModel.isConnecting)
            .frame(maxWidth: .infinity, alignment: .center) // Center the button
            
            // Device List
            if bleModel.discoveredDevices.isEmpty && !bleModel.isScanning {
                Text("No devices found. Ensure your LumiFur Controller is nearby and powered on.")
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(bleModel.discoveredDevices) { device in
                    Button {
                        if !bleModel.isConnecting { // Prevent multiple connection attempts
                            bleModel.connect(to: device)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "wave.3.right.circle") // Example icon
                                .foregroundColor(.blue)
                            Text(device.name)
                                .foregroundColor(.primary) // Ensure text is default color
                            Spacer()
                            if bleModel.connectingPeripheral?.id == device.id {
                                ProgressView()
                                    .frame(width: 20, height: 20)
                            } else {
                                SignalStrengthView(rssi: device.rssi) // Use device's discovered RSSI
                            }
                        }
                    }
                    .disabled(bleModel.isConnecting) // Disable row if any connection is in progress
                }
            }
        } header: {
            Text("Discovered Devices")
        } footer: {
            if bleModel.isScanning {
                Text("Scanning...")
                    .foregroundColor(.secondary)
            } else if !bleModel.isBluetoothReady {
                Text("Bluetooth is turned off.")
                    .foregroundColor(.red)
            }
        }
        .listRowBackground(overlayColor)
    }
    
    // MARK: - Previously Connected Section
    @ViewBuilder // Use ViewBuilder to conditionally show the section
    private var previouslyConnectedSection: some View {
        // Only show this section if not connected AND there are previous devices
        if !bleModel.isConnected && !bleModel.previouslyConnectedDevices.isEmpty {
            Section("Previously Connected") {
                ForEach(bleModel.previouslyConnectedDevices) { storedDevice in
                    // Avoid showing if already listed in discovered devices
                    if !bleModel.discoveredDevices.contains(where: { $0.id.uuidString == storedDevice.id }) {
                        Button {
                            if !bleModel.isConnecting {
                                bleModel.connectToStoredPeripheral(storedDevice)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.purple) // Different color for distinction
                                Text(storedDevice.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if bleModel.connectingPeripheral?.id.uuidString == storedDevice.id {
                                    ProgressView()
                                        .frame(width: 20, height: 20)
                                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                                }
                            }
                            //.animation(.easeInOut(duration: 0.2), value: bleModel.connectingPeripheral?.id == storedDevice.id)
                        }
                        .disabled(bleModel.isConnecting)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
            }
            .listRowBackground(overlayColor)
            // This transition applies to the entire Section when the outer 'if' condition changes its result
            .transition(.opacity.combined(with: .slide))
        }
    }
    
    // MARK: - Matrix Configuration Section
    private var matrixSection: some View {
        DisclosureGroup("LED Configuration", isExpanded: $isLedArrayExpanded) {
            if isLedArrayExpanded {
            // Section("Matrix Configuration") {
            // Example Layout: Could be more sophisticated
            VStack(alignment: .leading) {
                Text("Preview:") // Add a label for context
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Spacer()
                    LEDPreview() // Your custom preview view
                    Spacer()
                    // You might add another preview or controls here
                }
                .padding(.bottom, 5) // Add some spacing
                
                MatrixStylePicker(selectedMatrix: $selectedMatrix) // Your custom picker
            }
        }}
        .listRowBackground(overlayColor)
    }
    
    private var releaseNotesSection: some View {
        Section("Release Notes") {
            NavigationLink {
                ReleaseNotesView() // Destination view
            } label: {
                HStack {
                    Image(systemName: "list.bullet.clipboard") // Example icon
                    Text("App Release Notes")
                }
            }
            // Same styling as other NavLink rows if desired
            .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
            
            NavigationLink {
                ReleaseNotesView() // Destination view
            } label: {
                HStack {
                    Image(systemName: "list.bullet.clipboard") // Example icon
                    Text("Controller Release Notes")
                }
            }
            // Same styling as other NavLink rows if desired
            .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
            // Row for Controller Version
            
            // .listRowInsets(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)) // Standard padding
            .padding(.vertical, 5) // Add some vertical padding if needed
        }
        // Apply .clear background if the section contains custom styled rows
        //.listRowBackground(Color.clear)
        // If the App Version row should have default background, remove .listRowBackground from the Section
        // and apply .listRowBackground(.clear) ONLY to the Release Notes NavLink individually.
    }
    
    // MARK: - Advanced Settings Section
    private var configSection: some View {
        
        Section(header: Text("Configuration"), footer: Text("Changes are saved immediately. Please ensure your selections reflect your preferences.")) {
            VStack {
                HStack {
                    Image(systemName: "thermometer.high")
                        .symbolRenderingMode(.hierarchical)
                    Text("Temp Units")
                    Spacer(minLength: 50)
                    Picker("Temperature Units", selection: $selectedUnits) {
                        ForEach(TempUnit.allCases) { TempUnit in
                            Text(TempUnit.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(.blue)
                }
                HStack {
                    Image(systemName: "sun.max.fill")
                        .symbolRenderingMode(.hierarchical)
                    Toggle("Auto Brightness", isOn: $autoBrightness)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: autoBrightness) { oldValue, newValue in
                            print("Auto Brightness changed to \(newValue)")
                            bleModel.autoBrightness = newValue
                            bleModel.writeConfigToCharacteristic()
                        }
                    
                        .disabled(!bleModel.isConnected)
                }
                HStack {
                    Image(systemName: "rotate.3d.fill")
                        .symbolRenderingMode(.hierarchical)
                    
                    Toggle("Accelerometer", isOn: $accelerometer)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: accelerometer) { oldValue, newValue in
                            print("Accelerometer changed to \(newValue)")
                            bleModel.accelerometerEnabled = newValue
                            bleModel.writeConfigToCharacteristic()
                        }
                        .disabled(!bleModel.isConnected)
                }
                HStack {
                    Image(systemName: "moon.fill")
                        .symbolRenderingMode(.hierarchical)
                    Toggle("Sleep Mode", isOn: $sleepMode)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: sleepMode) { oldValue, newValue in
                            print("Sleep Mode changed to \(newValue)")
                            bleModel.sleepModeEnabled = newValue
                            bleModel.writeConfigToCharacteristic()
                        }
                    
                        .disabled(!bleModel.isConnected)
                }
                HStack {
                    Image(systemName: "bubbles.and.sparkles.fill")
                        .symbolRenderingMode(.hierarchical)
                    Toggle("Aroura Mode", isOn: $arouraMode)
                        .toggleStyle(GradientToggleStyle(gradient: LinearGradient(gradient: Gradient(colors: [Color.pink, Color.purple, Color.blue]), startPoint: .leading, endPoint: .trailing)))
                        .onChange(of: arouraMode) { oldValue, newValue in
                            print("Aroura Mode changed to \(newValue)")
                            bleModel.auroraModeEnabled = newValue
                            bleModel.writeConfigToCharacteristic()
                        }
                        .disabled(!bleModel.isConnected)
                    //TextField("Custom Message", text: $customMessage)
                }
            }
            
        }
        .listRowBackground(overlayColor)
    }
    
    // MARK: - Advanced Settings Section
    private var advancedSettingsSection: some View {
        Section("Advanced") {
            Toggle("Show Advanced Options", isOn: $showAdvanced.animation()) // Animate toggle reveal
            if showAdvanced {
                NavigationLink("Connection Parameters") {
                    // Ensure AdvancedSettingsView is correctly defined
                    AdvancedSettingsView(bleModel: bleModel)
                }
                Button("Reset to Defaults", role: .destructive) {
                    // Add your reset logic here
                    print("Resetting to defaults...")
                }
                .tint(.red)
            }
        }
        .listRowBackground(overlayColor)
    }
}

struct MatrixStylePicker: View {
    @Binding var selectedMatrix: SettingsView.Matrixstyle
    
    var body: some View {
        Picker("Visual Style", selection: $selectedMatrix) {
            ForEach(SettingsView.Matrixstyle.allCases) { style in
                Text(style.rawValue.capitalized)
                    .tag(style)
            }
        }
        .pickerStyle(.segmented)
        
        Text("Current style: \(selectedMatrix.rawValue.capitalized)")
            .font(.caption)
            .foregroundColor(.secondary)
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

struct SignalStrengthView: View {
    @AppStorage("rssiMonitoringEnabled") private var rssiMonitoringEnabled: Bool = false
    
    let rssi: Int
    
    private var signalLevel: Double {
        let normalized = Double(rssi + 90) / 35.0 // Normalize between -90dBm and -40dBm
        return min(max(normalized, 0.0), 1.0)
    }
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<4) { bar in
                RoundedRectangle(cornerRadius: 2)
                    .fill(bar < Int(signalLevel * 4) ? .blue : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(bar + 2) * 4)
            }
            if rssiMonitoringEnabled {
                Text("\(rssi)dBm")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: rssiMonitoringEnabled)
            }
        }
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var bleModel: AccessoryViewModel
    
    // Example advanced settings state variables.
    // @State private var autoReconnect: Bool = true
    @AppStorage("autoReconnect") private var autoReconnect: Bool = true
    @AppStorage("rssiMonitoringEnabled") private var rssiMonitoringEnabled: Bool = false
    @AppStorage("rssiUpdateInterval") private var rssiUpdateInterval: Double = 1.0
    
    var body: some View {
        Form {
            // Connection Options Section
            Section(header: Text("Connection Options")) {
                Toggle("Auto Reconnect", isOn: $autoReconnect)
                    .onChange(of: autoReconnect) { oldValue, newValue in
                        // Implement auto-reconnect logic here if desired.
                        // For example, you might store this setting in your model or user defaults.
                        print("Auto Reconnect changed from \(oldValue) to \(newValue)")
                    }
                if bleModel.isConnected {
                    Button("Disconnect Device") {
                        bleModel.disconnect()
                    }
                    .animation(.easeInOut(duration: 0.3), value: bleModel.isConnected)
                    Button("Reconnect Device") {
                        bleModel.scanForDevices()
                    }
                    .animation(.easeInOut(duration: 0.3), value: bleModel.isConnected)
                }
            }
            // RSSI Monitoring Section
            Section(header: Text("RSSI Monitoring"), footer: Text("Will periodically read the RSSI value of the connected device. This may lead to increased battery drain of your iOS device.")) {
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
                    Stepper("Update Interval: \(rssiUpdateInterval, specifier: "%.1f") sec", value: $rssiUpdateInterval, in: 0.5...5.0, step: 0.5)
                        .onChange(of: rssiUpdateInterval) { oldValue, newValue in
                            // If your model supports adjustable intervals for reading RSSI, update it here.
                            print("RSSI update interval changed from \(oldValue) to \(newValue)")
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
            Section(header: Text("Console"), footer: Text("Debug logs for your LumiFur Controller will be diplayed in this field.")) {
                RoundedRectangle(cornerRadius: 25)
                    .frame(minWidth: 200, minHeight: 200)
                    .foregroundStyle(Color.clear)
            }
        }
        .navigationTitle("Advanced Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReleaseNotesView: View {
    @State private var releases: [GitHubRelease] = []
    @State private var isLoading = true // Start in loading state
    @State private var errorMessage: String? = nil
    
    private let githubService = GitHubService() // Instance of the service
    
    var body: some View {
        Group { // Use Group to switch between views based on state
            if isLoading {
                ProgressView("Loading Release Notes...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
            } else if let errorMsg = errorMessage {
                VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .symbolRenderingMode(.hierarchical)
                    Text("Failed to Load Notes")
                        .font(.headline)
                    Text(errorMsg)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await loadReleases()
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
            } else if releases.isEmpty {
                Text("No release notes found.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
            } else {
                // Display fetched releases in a List
                List {
                    ForEach(releases) { release in
                        Section {
                            if let releaseBody = release.body {
                                // Use MarkdownUI to render GitHub-flavored Markdown
                                Markdown(releaseBody)
                                //.lineSpacing(5)
                                    .environment(\.openURL, OpenURLAction { url in
                                        print("Opening URL: \(url)")
                                        return .systemAction
                                    })
                            } else {
                                Text("No details provided.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineSpacing(5)
                            }
                        } header: {
                            HStack {
                                Text(release.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                                
                                
                                Spacer()
                                Text(release.publishedAt, style: .date) // Format date
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        // Use clear background if your List has a colored background overall
                        // .listRowBackground(Color.clear)
                    }
                }
                // Optional: Apply List style if needed
                // .listStyle(.plain)
            }
        }
        .navigationTitle("Release Notes")
        //.navigationBarTitleDisplayMode(.inline)
        // Use .task for async operations tied to view lifecycle
        .task {
            await loadReleases()
        }
    }
    
    // Function to load releases using the service
    private func loadReleases() async {
        // Reset state before loading
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedReleases = try await githubService.fetchReleases()
            // Update state on the main thread
            await MainActor.run {
                self.releases = fetchedReleases
                self.isLoading = false
            }
        } catch {
            // Update state on the main thread
            await MainActor.run {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? "An unexpected error occurred."
                self.isLoading = false
            }
        }
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
                .foregroundStyle(.black)
                .opacity(0.5)
                .frame(width: 20, height: 20)
        }
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
        .init(icon: "play.circle.fill",     title: "Live Control",     description: "Adjust brightness, speed & colour in real time."),
        .init(icon: "sparkles",              title: "Prebuilt Effects", description: "Pick from a gallery of dynamic patterns."),
        .init(icon: "slider.horizontal.3",   title: "Custom Sequences", description: "Compose and save your own light shows."),
        .init(icon: "bluetooth.fill",              title: "Bluetooth Sync",   description: "Wireless pairing to your suit’s controller.")
    ]
    var body: some View {
        NavigationStack {
            List {
                // MARK: – Logo Header
                VStack {
                    HStack{
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
                            webURL: URL(string: "https://bsky.app/profile/richies.uk")!
                        )
                        SocialLink(
                            imageName: "facebook.fill",
                            appURL: URL(string: "fb://profile/richies3d")!,
                            webURL: URL(string: "https://www.facebook.com/richies3d/")!
                        )
                        SocialLink(
                            imageName: "x",
                            appURL: URL(string: "twitter://user?screen_name=richies3d")!,
                            webURL: URL(string: "https://x.com/Richies3D")!
                        )
                        SocialLink(
                            imageName: "github.fill",
                            appURL: URL(string: "github://user?username=stef1949")!, // GitHub’s custom scheme
                            webURL: URL(string: "https://github.com/stef1949")!
                        )
                        SocialLink(
                            imageName: "linkedin.fill",
                            appURL: URL(string: "linkedin://in/stefan-ritchie")!,
                            webURL: URL(string: "https://www.linkedin.com/in/stefan-ritchie/")!
                        )
                    }
                    
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                
                // MARK: – About Section
                Section(header: Text("About LumiFur")) {
                    Text("""
                             LumiFur is an iOS‑native companion app for controlling LEDs on fursuits. It offers an intuitive interface for ramping colours, effects and sequences—right from your pocket.
                             """)
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
                        .padding(.vertical, 6)
                    }
                }
                
                // MARK: – Full List Link
                Section {
                    HStack {
                        Spacer()
                        Label("Complete feature list", systemImage: "chevron.forward")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.insetGrouped)                         // iOS18 default grouping
            .scrollContentBackground(.hidden)                 // let our list sit over the material
            .background(.thinMaterial)                        // global bg
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
 struct MatrixTestView_FileImporter: View {
 static let X_SEGMENTS = 4
 static let Y_SEGMENTS = 4
 static let NUM_SEGMENTS = X_SEGMENTS * Y_SEGMENTS
 
 @State private var framebuffer = [UInt8](repeating: 0, count: 8 * NUM_SEGMENTS)
 @State private var isAnimating = false
 @State private var timer: Timer?
 @State private var sx1: Int32 = 15 << 8
 @State private var sx2: Int32 = 15 << 8
 @State private var sy1: Int32 = 0
 @State private var sy2: Int32 = 0
 @State private var travel: UInt8 = 0
 @State private var showingFileImporter = false
 private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FileImport")
 
 
 var body: some View {
 VStack {
 VStack {
 // Display the LED matrix
 ForEach(0..<Self.Y_SEGMENTS, id: \.self) { y in
 HStack {
 ForEach(0..<Self.X_SEGMENTS, id: \.self) { x in
 LED_Matrix(framebuffer: $framebuffer, xOffset: x * 8, yOffset: y * 8)
 }
 }
 }
 }
 .padding()
 .background(.ultraThinMaterial)
 .clipShape(RoundedRectangle(cornerRadius: 25.0))
 
 Text("4x4_Test_File_Importer")
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
 
 // Button to upload the matrix file
 Button(action: { showingFileImporter = true }) {
 Text("Upload Matrix File")
 .padding()
 .background(Color.green)
 .foregroundColor(.white)
 .cornerRadius(8)
 }
 .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.text]) { result in
 handleFileImport(result: result)
 print("importing")
 }
 }
 .onAppear(perform: setup)
 }
 
 func setup() {
 clear()
 }
 
 func toggleAnimation() {
 isAnimating.toggle()
 if isAnimating {
 timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
 loop()
 }
 } else {
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
 // Your drawing logic here
 }
 
 func setPixel(x: UInt8, y: UInt8, mode: UInt8) {
 // Your setPixel logic here
 }
 
 func clear() {
 framebuffer = [UInt8](repeating: 0, count: 8 * Self.NUM_SEGMENTS)
 }
 
 func handleFileImport(result: Result<URL, Error>) {
 switch result {
 case .success(let fileURL):
 do {
 let content = try String(contentsOf: fileURL)
 parseMatrixFile(content: content)
 } catch {
 print("Error reading file: \(error.localizedDescription)")
 }
 case .failure(let error):
 print("File import failed: \(error.localizedDescription)")
 }
 }
 
 func parseMatrixFile(content: String) {
 // Updated parsing logic to handle matrix format correctly
 guard let startIndex = content.range(of: "const vector<vector<bool>> grid0 = {")?.upperBound else { return }
 let matrixString = content[startIndex...].components(separatedBy: "};").first ?? ""
 
 let rows = matrixString.split(separator: "{").dropFirst().map { $0.split(separator: "}") }
 var matrix = [[Bool]]()
 
 for row in rows {
 let boolRow = row.first?.split(separator: ",").compactMap { $0.trimmingCharacters(in: .whitespaces) == "1" }
 if let boolRow = boolRow {
 matrix.append(boolRow)
 }
 }
 
 // Update the framebuffer
 updateFramebuffer(with: matrix)
 }
 
 func updateFramebuffer(with matrix: [[Bool]]) {
 // Convert matrix data to framebuffer format
 clear()
 for (y, row) in matrix.enumerated() {
 for (x, value) in row.enumerated() {
 let mode: UInt8 = value ? 1 : 0
 setPixel(x: UInt8(x), y: UInt8(y), mode: mode)
 }
 }
 }
 }
 */
/*
 struct LED_Matrix: View {
 @Binding var framebuffer: [UInt8]
 let xOffset: Int
 let yOffset: Int
 
 var body: some View {
 VStack(spacing: 1) {
 ForEach(0..<8, id: \.self) { row in
 HStack(spacing: 1) {
 ForEach(0..<8, id: \.self) { col in
 Rectangle()
 .fill(ledColor(row: row, col: col))
 .frame(width: 5, height: 5)
 }
 }
 }
 }
 .background(.gray)
 .clipShape(RoundedRectangle(cornerRadius: 2.0))
 }
 
 private func ledColor(row: Int, col: Int) -> Color {
 let index = (yOffset + row) * MatrixTestView_FileImporter.X_SEGMENTS + (xOffset / 8)
 let bit = 7 - col
 return framebuffer[index] & (1 << bit) != 0 ? .green : .black
 }
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

struct infoViewold: View {
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


#Preview("ContentView") {
    ContentView()
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
    SettingsView(bleModel: AccessoryViewModel(), selectedMatrix: .constant(SettingsView.Matrixstyle.array))
}

#Preview("Release Notes") {
    ReleaseNotesView()
}

// ——————— Your mock view model at file-scope ———————
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
 */
