//
//  ContentView.swift
//  LumiFurWatchOS Watch App
//
//  Created by Stephan Ritchie on 2/14/25.
//

import SwiftUI
import WatchConnectivity
//import Charts

// MARK: - Face Grid View
enum Item: String, CaseIterable, Identifiable {
    case device
    case faces
    //case status
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
    
    // now holds the selected ProtoAction
        @State private var selectedFace: SharedOptions.ProtoAction? = nil
    
    var body: some View {
        ScrollView {
            GlassEffectContainer {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(faces, id: \.rawValue) { face in
                    Button {
                        selectedFace = face
                        // Play system haptic (and sound, if available)
                        WKInterfaceDevice.current().play(.start)
                        print("\(face) pressed - sending command...")
                        // Uses  WatchConnectivityManager to send the selected face
                        // package up whatever you need to send:
                        let payload: [String: Any] = [
                            "command": "setFace",
                            "faceType": face.isEmoji ? "emoji" : "symbol",
                            "faceValue": face.rawValue
                        ]
                        WatchConnectivityManager.shared.sendMessage(payload) { reply in
                            print("Reply:", reply)
                        } errorHandler: { error in
                            print("Error:", error)
                        }
                    } label: {
                        faceView(for: face)
                            .aspectRatio(1, contentMode: .fit)
                            .font(.system(size: 30))
                            .foregroundStyle(selectedFace == face ? Color.black : Color.white)
                    }
                    //.backgroundStyle(.clear)
                    .glassEffect(.regular.tint(selectedFace == face ? Color.white : Color.clear).interactive(),
                                 in: RoundedRectangle(cornerRadius: 15),
                                 isEnabled: true
                    )
                    //         .background {
                    //                Rectangle()
                    //                .fill(selectedFace == face ? Color.white : Color.black)
                    //        }
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

// MARK: - Main View Structure
struct ItemView: View {
    let item: Item
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    
    @State private var selectedView: Int? = nil
    @State private var autoBrightness: Bool = true
    @State private var accelerometer: Bool = true
    @State private var sleepMode: Bool = true
    @State private var arouraMode: Bool = true
    
    
    var body: some View {
        VStack {
            if item == .device {
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
                            Text("Device: \(deviceName)")
                                .foregroundColor(.primary)
                        } else if connectivityManager.connectionStatus == "Connected"
                                    || connectivityManager.connectionStatus.starts(with: "Connected") {
                            // Show placeholder only if actually connected but name not received yet
                            Text("iPhone: Requesting name…")
                                .foregroundColor(.gray)
                        } else {
                            Text("Device: N/A")      // Show N/A if not connected
                                .foregroundColor(.gray)
                        }
                    }
                }
                .font(.system(size: 14)) // Adjust font size for watch
                .padding(.top, 10)
            }
            // Example content – replace with your own controls or info.
            switch item {
            case .device:
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
                    .padding(.top, 5)
                    .glassEffect(.regular.interactive())
                }
                // Optional: Add a Disconnect button when connected
                else if connectivityManager.connectionStatus == "Connected" {
                    HStack {
                        Button("Disconnect") {
                            print("Disconnect button tapped (action not implemented)")
                            // Send connect command using the manager
                            let message = ["command": "connectToDevice"]
                            print("Watch sending 'connectToDevice' command...")
                            WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                                print("Connect command reply: \(reply)")
                            }, errorHandler: { error in
                                print("Connect command error: \(error.localizedDescription)")
                            })
                        }
                        .glassEffect(.regular.tint(.red).interactive())
                    } // Make disconnect button red
                    //.padding(.top, 5)
                    Button("Reconnect") {
                        print("Atempting reconnect...")
                    }
                    .glassEffect(.regular.interactive())
                }
            case .faces:
                ZStack {
                    VStack {
                        FaceGridView()
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
                            
                        }.environment(\.colorScheme, .light)
                            .offset(y: 20)
                    }
                }/*
            case .status:
                VStack(alignment: .leading, spacing: 6) {

                    Chart(templateSunshineData, id: \.id) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Temp (°C)", point.temp)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            .linearGradient(
                                colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.05)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Temp (°C)", point.temp)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(.init(lineWidth: 2))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [Color.blue, Color.green],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    }
                    .frame(height: 120)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisGridLine() }
                    }
                    .chartPlotStyle { plot in
                        plot
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    .padding(8)
                    .drawingGroup()

                    
                    Text("Temperature ")
                        .font(.caption2)
                        .opacity(0.6)
                }
                  */
            case .settings:
                
                if !isConnectedOrConnecting(connectivityManager.connectionStatus) {
                    Text("Connect to LumiFur to configure your settings here")
                        .listItemTint(.clear)
                }
                // Wrap the whole List in a GlassEffectContainer
                    GlassEffectContainer {
                        List {
                            Toggle("Auto Brightness", isOn: $autoBrightness)
                                .onChange(of: autoBrightness) { newValue, _ in
                                    sendMessage(["autoBrightness": newValue])
                                }
                                .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                                .padding(15)
                                .glassEffect(.regular
                                    .interactive(),
                                             isEnabled: true)
                                .listRowBackground(Color.clear)
                                
                            Toggle("Accelerometer", isOn: $accelerometer)
                                .onChange(of: accelerometer) { newValue, _ in
                                    sendMessage(["accelerometer": newValue])
                                }
                                .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                                .padding(15)
                                .glassEffect(.regular
                                    .interactive(),
                                             isEnabled: true)
                                .listRowBackground(Color.clear)

                            Toggle("Sleep Mode", isOn: $sleepMode)
                                .onChange(of: sleepMode) { newValue, _ in
                                    sendMessage(["sleepMode": newValue])
                                }
                                .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                                .padding(15)
                                .glassEffect(.regular
                                    .interactive(),
                                             isEnabled: true)
                                .listRowBackground(Color.clear)

                            Toggle("Aroura Mode", isOn: $arouraMode)
                                .onChange(of: arouraMode) { newValue, _ in
                                    sendMessage(["arouraMode": newValue])
                                }
                                .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                                .padding(15)
                                .glassEffect(.regular
                                    .interactive(),
                                             isEnabled: true)
                                .listRowBackground(Color.clear)
                        }
                        //.listStyle(.automatic
                        //.scrollContentBackground(.hidden)
                    }
                    .onAppear {
                        // Activate the session as soon as this view appears
                        _ = WatchConnectivityManager.shared
                    }
                    //.listRowBackground(Color.clear)
            }
        }
        //.frame(maxWidth: .infinity, maxHeight: .infinity)
        //.containerBackground(.gray.gradient, for: .tabView)
        //.border(Color.yellow, width: 1)
        .containerBackground(statusColor(connectivityManager.connectionStatus).gradient, for: .navigation)
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
                        .tag(item)
             }
            }
            .listStyle(.carousel) // Use carousel for watchOS top-level navigation
            .containerBackground(.green.gradient, for: .navigationSplitView)
        } detail: {
            // Detail view: a vertically paging TabView
            TabView(selection: $selected) {
                ForEach(Item.allCases) { item in
                    ItemView(item: item)
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

#Preview {
    ContentView()
}
