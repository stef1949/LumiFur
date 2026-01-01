//
//  ContentView.swift
//  LumiFurWatchOS Watch App
//
//  Created by Stephan Ritchie on 2/14/25.
//

import SwiftUI
import WatchConnectivity
import CoreMotion
import Charts



// MARK: - Face Grid View
enum Item: String, CaseIterable, Identifiable {
    case device
    case faces
    case status
    case settings
    
    var id: Self { self }
    
    var displayName: String {
        return self.rawValue.spaced
    }
}

/*
 // -----------------------------------------------------------------------------
 // 1.  Dummy model + sample data (place anywhere above your view)
 // -----------------------------------------------------------------------------
 struct SunshineDatum: Identifiable {
 let id = UUID()
 let date: Date
 let temp: Double
 }
 
 let templateSunshineData: [SunshineDatum] = {
 let today = Calendar.current.startOfDay(for: Date())
 // Five days ending today: 18 °C → 22 °C
 return (0..<5).map { i in
 SunshineDatum(
 date: Calendar.current.date(byAdding: .day, value: i - 4, to: today)!,
 temp: 18 + Double(i)          // 18,19,20,21,22
 )
 }
 }()
 */
// MARK: - Face Grid View
struct FaceGridView: View {
    // The grid of face icons – same as your iOS protoActionOptions.
    // let faces: [String] = ["", "🏳️‍⚧️", "🌈", "🙂", "😳", "😎", "☠️"]
    
    let faces: [SharedOptions.ProtoAction] = SharedOptions.protoActionOptions3
    
    // Define a two-column grid.
    let columns: [GridItem] = [GridItem(.adaptive(minimum: 50, maximum: 100))]
    
    // ✅ 1. Add an observer to the single source of truth.
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    
    // ❌ 2. REMOVE the conflicting local state.
    // @State private var selectedFace: SharedOptions.ProtoAction? = nil
    
    var body: some View {
        ScrollView {
            GlassEffectContainer {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(faces.enumerated()), id: \.offset) { (index, face) in
                        let viewNumber = index + 1 // Views are 1-based
                        
                        // ✅ 3. The `isSelected` logic now reads from the manager.
                        let isSelected = (connectivityManager.selectedView == viewNumber)
                        Button {
                            // Play haptic feedback
                            WKInterfaceDevice.current().play(.start)
                            // ✅ 4. The action now sends the 1-based view number.
                            // This makes the watch speak the same "language" as the iOS app.
                            let payload: [String: Any] = [
                                "command": "setFace",
                                "view": viewNumber // Send the integer view number
                            ]
                            
                            print("\(face.rawValue) pressed - sending command: \(payload)...")
                            WatchConnectivityManager.shared.sendMessage(payload) { reply in
                                print("Reply:", reply)
                            } errorHandler: { error in
                                print("Error:", error)
                            }
                        } label: {
                            faceView(for: face)
                                .aspectRatio(1, contentMode: .fit)
                                .font(.system(size: 30))
                                .foregroundStyle(isSelected ? Color.black : Color.white)
                        }
                        //.backgroundStyle(.clear)
                        .glassEffect(.regular.tint(isSelected ? Color.white : Color.clear).interactive(),
                                     in: RoundedRectangle(cornerRadius: 15)
                        )
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}

@ViewBuilder
private func faceView(for face: SharedOptions.ProtoAction) -> some View {
    switch face {
    case .emoji(let str):
        Text(str)
            .font(.system(size: 30))
    case .symbol(let name):
        Image(systemName: name)
            .font(.system(size: 30))
    }
}

// MARK: - Wrist Flick Detection (watchOS)
@MainActor
final class WristFlickDetector: ObservableObject {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    
    // Cooldown to prevent rapid repeats
    private var lastFlickTime: TimeInterval = 0
    
    // Tune these if needed
    private let accelerationThreshold: Double = 1.2
    private let cooldownSeconds: TimeInterval = 0.6
    
    // Callbacks
    var onFlickLeft: (() -> Void)?
    var onFlickRight: (() -> Void)?
    
    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        if motionManager.isDeviceMotionActive { return }
        
        queue.qualityOfService = .userInteractive
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }

            // userAcceleration removes gravity (best for flick detection)
            let ax = motion.userAcceleration.x
            let now = Date().timeIntervalSince1970

            // Cooldown gate on main actor
            if now - self.lastFlickTime < self.cooldownSeconds { return }

            // On Apple Watch, a lateral wrist flick often shows as a spike in X user acceleration.
            if ax <= -self.accelerationThreshold {
                self.lastFlickTime = now
                self.onFlickLeft?()
            } else if ax >= self.accelerationThreshold {
                self.lastFlickTime = now
                self.onFlickRight?()
            }
        }
    }
    
    func stop() {
        guard motionManager.isDeviceMotionActive else { return }
        motionManager.stopDeviceMotionUpdates()
    }
}

/*
 private extension SharedOptions.ProtoAction {
 // helper to unify sending & comparison
 var rawValue: String {
 switch self {
 case .emoji(let s):  return s
 case .symbol(let s): return s
 }
 }
 var isEmoji: Bool {
 if case .emoji = self { return true }
 else                 { return false }
 }
 }
 */
// MARK: - Main View Structure
struct DeviceView: View {
    let item: Item
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var wristFlickDetector = WristFlickDetector()
    
    // AppStorage to persist on watch
    @AppStorage("wristFlickEnabled") private var wristFlickEnabled: Bool = true
    /*
     @State private var selectedView: Int? = nil
     @State private var autoBrightness: Bool = false
     @State private var accelerometer: Bool = false
     @State private var sleepMode: Bool = false
     @State private var arouraMode: Bool = false
     */
    
    var body: some View {
        VStack {
            if item == .device {
                Spacer()
                /*
                 Image ("Image")
                 .renderingMode(.template)
                 .resizable()
                 .aspectRatio(contentMode: .fit)
                 .padding(.bottom, 5)
                 */
                
                // --- Display Connection Info ---
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status: \(connectivityManager.connectionStatus)")
                        .foregroundColor(statusColor(connectivityManager.connectionStatus)) // Optional color coding
                    Text("Reachable: \(connectivityManager.isReachable ? "Yes" : "No")")
                        .foregroundColor(connectivityManager.isReachable ? .green : .orange)
                    
                    Group {
                        if let deviceName = connectivityManager.companionDeviceName {
                            Text("Companion: \(deviceName)")
                                .foregroundColor(.primary)
                                .transition(.slide)
                        } else if isConnectedOrConnecting(connectivityManager.connectionStatus) {
                            // Show placeholder only if actually connected but name not received yet
                            Text("iPhone: Requesting name…")
                                .foregroundColor(.gray)
                                .transition(.slide)
                        } else {
                            
                        }
                    }
                }
                .font(.system(size: 14)) // Adjust font size for watch
                .padding(.top, 10)
            }
            switch item {
            case .device:
                // Connection controls
                if !isConnectedOrConnecting(connectivityManager.connectionStatus) {
                    Button {
                        // Send connect command using the manager
                        let message = ["command": "connectToDevice"]
                        print("Watch sending 'connectToDevice' command...")
                        WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                            print("Connect command reply: \(reply)")
                        }, errorHandler: { error in
                            print("Connect command error: \(error.localizedDescription)")
                        })
                    } label: {
                        Text("Connect")
                    }
                    //.padding(.top, 5)
                    .glassEffect(.regular.interactive())
                    .disabled(!WCSession.default.isReachable)
                    
                    if !WCSession.default.isReachable {
                        Text("iPhone not reachable")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                            .transition(.slide)
                    }
                } else {
                    VStack(spacing: 8) {
                        Button("Disconnect") {
                            let message = ["command": "disconnectFromDevice"]
                            print("Watch sending 'disconnectFromDevice' command...")
                            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                                print("Disconnect command reply: \(reply)")
                            }, errorHandler: { error in
                                print("Disconnect command error: \(error.localizedDescription)")
                            })
                        }
                        .glassEffect(.regular.tint(.red).interactive())
                        .disabled(!WCSession.default.isReachable)
                        /*
                         Button("Reconnect") {
                         let message = ["command": "connectToDevice"]
                         print("Watch sending 'connectToDevice' command (reconnect)...")
                         WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                         print("Reconnect command reply: \(reply)")
                         }, errorHandler: { error in
                         print("Reconnect command error: \(error.localizedDescription)")
                         })
                         }
                         .glassEffect(.regular.interactive())
                         .disabled(!WCSession.default.isReachable)
                         */
                        if !WCSession.default.isReachable {
                            Text("iPhone not reachable")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 5)
                }
            case .faces:
                if isConnectedOrConnecting(connectivityManager.connectionStatus) {
                    ZStack {
                        VStack {
                            FaceGridView()
                                .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                        }
                        .overlay(alignment: .bottom){
                            HStack {
                                Spacer()
                                HStack {
                                    Text("Current View")
                                        .font(.callout)
                                        .opacity(1)
                                        .foregroundStyle(.secondary)
                                    CurrentViewGauge()
                                }
                                .padding()
                                //.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius:(8)))
                                .glassEffect()
                                //.glassEffect(.regular, in: RoundedRectangle(cornerRadius:(8)))
                                Spacer()
                                
                            }
                            .environment(\.colorScheme, .light)
                            .offset(y: 20)
                        }
                    }
                    .onAppear {
                        // Configure callbacks to move between views
                        wristFlickDetector.onFlickLeft = { [weak wristFlickDetector] in
                            guard let _ = wristFlickDetector, wristFlickEnabled else { return }
                            handleSwipeToChangeView(-100)
                        }
                        wristFlickDetector.onFlickRight = { [weak wristFlickDetector] in
                            guard let _ = wristFlickDetector, wristFlickEnabled else { return }
                            handleSwipeToChangeView(100)
                        }
                        
                        if wristFlickEnabled {
                            wristFlickDetector.start()
                        } else {
                            wristFlickDetector.stop()
                        }
                    }
                    .onDisappear {
                        wristFlickDetector.stop()
                    }
                    .onChange(of: wristFlickEnabled) { _, enabled in
                        // Toggles behaviour
                        if enabled {
                            wristFlickDetector.start()
                        } else {
                            wristFlickDetector.stop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                // Swipe gesture still works regardless of wrist-flick setting
                                handleSwipeToChangeView(value.translation.width)
                            }
                    )
                } else {
                    Text("Connect to LumiFur to configure your settings here")
                }
            case .status:
                StatusView()
            case .settings:
                
                if !isConnectedOrConnecting(connectivityManager.connectionStatus) {
                    Toggle("Wrist Flick to Change Face", isOn: $wristFlickEnabled)
                        .padding(15)
                        .glassEffect(.regular.interactive())
                        .listRowBackground(Color.clear)
                    Text("Connect to LumiFur to configure your settings here")
                }
                else {
                    // Wrap the whole List in a GlassEffectContainer
                    GlassEffectContainer {
                        List {
                            Toggle("Auto Brightness", isOn: $connectivityManager.autoBrightness)
                                .onChange(of: connectivityManager.autoBrightness) { _, newValue in
                                    // Send a specific message for this one setting
                                    print("Toggle changed. Sending autoBrightness: \(newValue)")
                                    sendMessage(["autoBrightness": newValue])
                                }
                                .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                                .padding(15)
                                .glassEffect(.regular
                                    .interactive())
                                .listRowBackground(Color.clear)
                                .disabled(!WCSession.default.isReachable)
                            Toggle("Accelerometer", isOn: $connectivityManager.accelerometerEnabled)
                                .onChange(of: connectivityManager.accelerometerEnabled) { _, newValue in
                                    sendMessage(["accelerometer": newValue])
                                }
                                .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                                .padding(15)
                                .glassEffect(.regular
                                    .interactive())
                                .listRowBackground(Color.clear)
                                .disabled(!WCSession.default.isReachable)
                            Toggle("Sleep Mode", isOn: $connectivityManager.sleepModeEnabled)
                                .onChange(of: connectivityManager.sleepModeEnabled) { _, newValue in
                                    sendMessage(["sleepMode": newValue])
                                }
                                .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                                .padding(15)
                                .glassEffect(.regular.interactive())
                                .listRowBackground(Color.clear)
                                .disabled(!WCSession.default.isReachable)
                            
                            Toggle("Aroura Mode", isOn: $connectivityManager.auroraModeEnabled)
                                .onChange(of: connectivityManager.auroraModeEnabled) { _, newValue in
                                    sendMessage(["arouraMode": newValue])
                                }
                                .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                                .padding(15)
                                .glassEffect(.regular
                                    .interactive())
                                .listRowBackground(Color.clear)
                                .disabled(!WCSession.default.isReachable)
                            
                            // Wrist-flick option (watch-local, so no sendMessage)
                            Toggle("Wrist Flick to Change Face", isOn: $wristFlickEnabled)
                                .padding(15)
                                .glassEffect(.regular.interactive())
                                .listRowBackground(Color.clear)
                        }
                    }
                    
                    .onAppear {
                        // Activates session as soon as this view appears
                        // _ = WatchConnectivityManager.shared
                        connectivityManager.requestSyncFromiOS()
                        
                    }
                }
            }
        }
    }
}


private struct StatusView: View {
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    
    private var temperatureHeadline: String {
        if let tempC = connectivityManager.temperatureC {
            return String(format: "%.1f°C", tempC)
        }
        return connectivityManager.temperatureText
    }
    
    private var temperatureSecondary: String? {
        guard let tempC = connectivityManager.temperatureC else { return nil }
        let tempF = (tempC * 9 / 5) + 32
        return String(format: "%.1f°F", tempF)
    }
    
    private var controllerTitle: String {
        connectivityManager.connectedControllerName ?? "Controller"
    }
    
    private var isControllerConnectedOrConnecting: Bool {
        isConnectedOrConnecting(connectivityManager.controllerConnectionStatus)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(controllerTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(connectivityManager.controllerConnectionStatus)
                    .font(.caption2)
                    .foregroundStyle(statusColor(connectivityManager.controllerConnectionStatus))
            }
            
            Text(temperatureHeadline)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            
            if let secondary = temperatureSecondary {
                Text(secondary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if isControllerConnectedOrConnecting, connectivityManager.temperatureHistory.count >= 2 {
                Chart(connectivityManager.temperatureHistory) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Temp", sample.temperatureC)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(.init(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 60)
                .padding(.vertical, 4)
            }
            
            if let updated = connectivityManager.temperatureTimestamp {
                Text("Updated \(updated, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .onAppear {
            connectivityManager.requestSyncFromiOS()
        }
    }
}

// Swipe gesture support for changing face/view
@MainActor  func handleSwipeToChangeView(_ translationWidth: CGFloat) {
    let connectivityManager = WatchConnectivityManager.shared
    // Only act if we're connected/connecting
    guard isConnectedOrConnecting(connectivityManager.connectionStatus) else { return }
    
    // Require a minimum swipe distance to avoid accidental changes
    let threshold: CGFloat = 30
    guard abs(translationWidth) > threshold else { return }
    
    // Determine direction: swipe left -> next, swipe right -> previous
    // (On watch, negative translation means finger moved left)
    let direction = translationWidth < 0 ? 1 : -1
    
    // Determine current view (defaults to 1 if unknown)
    let current = max(1, connectivityManager.selectedView)
    let maxView = SharedOptions.protoActionOptions3.count
    guard maxView > 0 else { return }
    
    // Compute next view and clamp to valid range
    var next = current + direction
    if next < 1 { next = 1 }
    if next > maxView { next = maxView }
    guard next != current else { return }
    
    WKInterfaceDevice.current().play(.click)
    
    // Send the same command as tapping a face, using the 1-based view number
    let payload: [String: Any] = [
        "command": "setFace",
        "view": next
    ]
    
    print("Swipe changing view from \\(current) -> \\(next). Sending: \\(payload)")
    WatchConnectivityManager.shared.sendMessage(payload) { reply in
        print("Reply:", reply)
    } errorHandler: { error in
        print("Error:", error)
    }
}

private func sendMessage(_ message: [String: Any]) {
    if WCSession.default.isReachable {
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message: \(error)")
        }
    }
}

struct ContentView: View {
    @State private var selected: Item? = .device
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        NavigationSplitView {
            // Primary view: a carousel-style list
            List(selection: $selected) {
                ForEach(Item.allCases) { item in
                    Text(item.displayName)
                        .navigationTitle("Options")
                        .tag(item)
                }
                .padding()
            }
            .listStyle(.carousel) // Carousel for watchOS top-level navigation
            //.containerBackground(.green.gradient, for: .navigationSplitView)
        } detail: {
            // Detail view: a vertically paging TabView
            TabView(selection: $selected) {
                ForEach(Item.allCases) { item in
                    DeviceView(item: item)
                        .navigationTitle(item.rawValue.capitalized)
                        .tag(Optional(item))
                }
            }
            .tabViewStyle(.automatic)
        }
    }
    
}

extension String {
    var spaced: String {
        // Replace a lowercase letter followed by an uppercase letter with the same letters separated by a space.
        let spacedString = self.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        return spacedString.capitalized // Optional: Capitalizes each word.
    }
}

/*
 #Preview {
 ContentView()
 }
 */

// MARK: - Preview Helpers (watchOS)
#if DEBUG

extension WatchConnectivityManager {
    /// Configure the shared manager with preview state and return it.
    /// This lets multiple previews set up different "worlds" for the watch UI.
    @MainActor @discardableResult
    static func configurePreview(
        connectionStatus: String = "Disconnected",
        controllerConnectionStatus: String? = nil,
        reachable: Bool = true,
        companionName: String? = "Steph’s iPhone",
        connectedControllerName: String? = "LumiFur Controller",
        tempC: Double? = 22.3,
        selectedView: Int = 3,
        autoBrightness: Bool = true,
        accelerometer: Bool = false,
        sleepMode: Bool = false,
        auroraMode: Bool = true
    ) -> WatchConnectivityManager {
        let m = WatchConnectivityManager.shared
        
        // High-level connection state
        m.connectionStatus = connectionStatus
        m.controllerConnectionStatus = controllerConnectionStatus ?? connectionStatus
        m.isReachable = reachable
        
        // Names
        m.companionDeviceName = companionName
        m.connectedControllerName = connectedControllerName
        
        // Temperature
        m.temperatureC = tempC
        m.temperatureText = tempC.map { String(format: "%.1f°C", $0) } ?? "--"
        m.temperatureTimestamp = tempC != nil ? Date() : nil
        
        // Face / view + toggles
        m.selectedView = selectedView
        m.autoBrightness = autoBrightness
        m.accelerometerEnabled = accelerometer
        m.sleepModeEnabled = sleepMode
        m.auroraModeEnabled = auroraMode
        
        return m
    }
}

// MARK: - SwiftUI Previews

#Preview("Content – Disconnected") {
    // Completely disconnected, phone not reachable
    WatchConnectivityManager.configurePreview(
        connectionStatus: "Disconnected",
        reachable: false,
        companionName: nil,
        connectedControllerName: nil,
        tempC: nil,
        selectedView: 1
    )
    return ContentView()
}

#Preview("Content – Connected") {
    // Happy path: phone reachable, LumiFur connected
    WatchConnectivityManager.configurePreview(
        connectionStatus: "Connected",
        reachable: true,
        companionName: "Steph’s iPhone",
        connectedControllerName: "LumiFur-1234",
        tempC: 23.4,
        selectedView: 4,
        autoBrightness: true,
        accelerometer: true,
        sleepMode: false,
        auroraMode: true
    )
    return ContentView()
}

// Focused previews for each item tab if you like:

#Preview("Device Tab – Connected") {
    WatchConnectivityManager.configurePreview(
        connectionStatus: "Connected",
        reachable: true,
        companionName: "Steph’s iPhone",
        connectedControllerName: "LumiFur-Head",
        tempC: 22.0
    )
    return DeviceView(item: .device)
}

#Preview("Faces Tab – Connected") {
    WatchConnectivityManager.configurePreview(
        connectionStatus: "Connected",
        reachable: true,
        connectedControllerName: "LumiFur-Head",
        tempC: 21.7,
        selectedView: 5
    )
    return DeviceView(item: .faces)
}

#Preview("Status Tab – With Temp") {
    WatchConnectivityManager.configurePreview(
        connectionStatus: "Connected",
        reachable: true,
        connectedControllerName: "LumiFur-Head",
        tempC: 24.1
    )
    return DeviceView(item: .status)
}

#Preview("Settings Tab – Connected") {
    WatchConnectivityManager.configurePreview(
        connectionStatus: "Connected",
        controllerConnectionStatus: "Connected",
        reachable: true,
        connectedControllerName: "LumiFur-Head",
        tempC: 23.0,
        autoBrightness: true,
        accelerometer: true,
        sleepMode: false,
        auroraMode: true
    )
    return DeviceView(item: .settings)
}

#endif


