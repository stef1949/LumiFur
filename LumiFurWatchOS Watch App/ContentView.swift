//
//  ContentView.swift
//  LumiFurWatchOS Watch App
//
//  Created by Stephan Ritchie on 2/14/25.
//

import SwiftUI
import WatchConnectivity
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

// MARK - Gauge Views
struct StyledGauge: View {
    @State private var current = 47.0
    @State private var minValue = 15.0
    @State private var maxValue = 70.0
    let gradient = Gradient(colors: [.green, .yellow, .orange, .red])
    
    
    var body: some View {
        Gauge(value: current, in: minValue...maxValue) {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
        } currentValueLabel: {
            Text("\(Int(current))")
                .foregroundColor(Color.green)
        } minimumValueLabel: {
            Text("\(Int(minValue))")
                .foregroundColor(Color.green)
        } maximumValueLabel: {
            Text("\(Int(maxValue))")
                .foregroundColor(Color.red)
        }
        .gaugeStyle(CircularGaugeStyle(tint: gradient))
        
    }
}

struct GaugeUnit: View {
    var body: some View {
        VStack {
            StyledGauge()
            Text("Gauge")
                .font(.system(size: 10))
                .offset(y: -5)
            
        }
        .padding()
    }
}

struct currentViewGauge: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .frame(width: 25, height: 25)
            
            Text("4")
        }
    }
}

// MARK - Template data
struct MonthlyHoursOfSunshine: Identifiable {
    var id: Date { date } // Using the date as a unique identifier
    var date: Date
    var hoursOfSunshine: Double
    
    
    init(month: Int, hoursOfSunshine: Double) {
        let calendar = Calendar.autoupdatingCurrent
        self.date = calendar.date(from: DateComponents(year: 2020, month: month))!
        self.hoursOfSunshine = hoursOfSunshine
    }
}
//Dummy data
let sunshineData: [MonthlyHoursOfSunshine] = [
    MonthlyHoursOfSunshine(month: 1, hoursOfSunshine: 74),
    MonthlyHoursOfSunshine(month: 2, hoursOfSunshine: 99),
    MonthlyHoursOfSunshine(month: 3, hoursOfSunshine: 68),
    MonthlyHoursOfSunshine(month: 4, hoursOfSunshine: 80),
    MonthlyHoursOfSunshine(month: 5, hoursOfSunshine: 95),
    MonthlyHoursOfSunshine(month: 6, hoursOfSunshine: 110),
    MonthlyHoursOfSunshine(month: 7, hoursOfSunshine: 120),
    MonthlyHoursOfSunshine(month: 8, hoursOfSunshine: 115),
    MonthlyHoursOfSunshine(month: 9, hoursOfSunshine: 90),
    MonthlyHoursOfSunshine(month: 10, hoursOfSunshine: 80),
    MonthlyHoursOfSunshine(month: 11, hoursOfSunshine: 70),
    MonthlyHoursOfSunshine(month: 12, hoursOfSunshine: 62)
]
// MARK: - Face Grid View
struct FaceGridView: View {
    // The grid of face icons – same as your iOS protoActionOptions.
    let faces: [String] = ["", "🏳️‍⚧️", "🌈", "🙂", "😳", "😎", "☠️"]
    
    // Define a two-column grid.
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 2)
    
    var body: some View {
        
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(faces, id: \.self) { face in
                    Button(action: {
                        print("\(face) pressed - sending command...")
                        // *** Use the WatchConnectivityManager to send the selected face ***
                        let message: [String: Any] = [
                            "command": "setFace", // Define a command name
                            "faceValue": face     // Send the specific face emoji
                        ]
                        WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                            print("Set face reply: \(reply)")
                            // Optional: Update UI based on successful reply
                        }, errorHandler: { error in
                            print("Set face error: \(error.localizedDescription)")
                            // Optional: Show an error to the user
                        })
                    }) {
                        Text(face)
                            .font(.system(size: 40))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(8)
                            .cornerRadius(8)
                    }
                    .border(Color.green) // Consider removing or styling differently
                    // .backgroundStyle(.ultraThinMaterial) // This might be causing unexpected visual results with border
                }
            }
            .backgroundStyle(.ultraThinMaterial)
            .padding()
        }
    }
}

// MARK: - Main View Structure
struct ItemView: View {
    let item: Item
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        VStack {
            if item == .device {
                Image ("Image")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.bottom, 5)
                // --- Display Connection Info ---
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status: \(connectivityManager.connectionStatus)")
                        .foregroundColor(statusColor(connectivityManager.connectionStatus)) // Optional color coding
                    Text("Reachable: \(connectivityManager.isReachable ? "Yes" : "No")")
                        .foregroundColor(connectivityManager.isReachable ? .green : .orange)
                    
                    // Display companion device name
                    if let deviceName = connectivityManager.companionDeviceName {
                        Text("Device: \(deviceName)")
                    } else if connectivityManager.connectionStatus == "Connected" || connectivityManager.connectionStatus.starts(with: "Connected"){
                        // Show placeholder only if actually connected but name not received yet
                        Text("Device: iPhone (Requesting name...)")
                            .foregroundColor(.gray)
                    } else {
                        Text("Device: N/A") // Show N/A if not connected
                            .foregroundColor(.gray)
                    }
                }
                .font(.system(size: 14)) // Adjust font size for watch
                .padding(.vertical, 10)
                Spacer()
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
                }
                // Optional: Add a Disconnect button when connected
                else if connectivityManager.connectionStatus == "Connected" {
                    Button("Disconnect?") { // Example placeholder
                        print("Disconnect button tapped (action not implemented)")
                        // You would need to send a "disconnect" command to iOS
                        // WatchConnectivityManager.shared.sendMessage(["command": "disconnectRequest"], ...)
                    }
                    .tint(.red) // Make disconnect button red
                    .padding(.top, 5)
                }
                
                
                Spacer() // Pushes button down slightly if info is short
            }
            
            // Example content – replace with your own controls or info.
            switch item {
            case .device:
                Button {
                    // *** Use the WatchConnectivityManager to send the message ***
                    let message = ["command": "connectToDevice"]
                    WatchConnectivityManager.shared.sendMessage(message, replyHandler: { reply in
                        print("Connect command reply: \(reply)")
                    }, errorHandler: { error in
                        print("Connect command error: \(error.localizedDescription)")
                    })
                } label: {
                    Text("Connect")
                }
                .foregroundStyle(.white.gradient)
                .offset(y: 10)
                
            case .faces:
                VStack{
                    FaceGridView()
                        .frame(width: .infinity, height: 170)
                    HStack {
                        Spacer()
                        Text("Current View")
                            .font(.caption)
                            .opacity(0.4)
                        
                        Spacer()
                        currentViewGauge()
                        Spacer()
                    }
                }
            case .status:
                VStack{
                    HStack{
                        GaugeUnit()
                        Spacer()
                        GaugeUnit()
                    }
                    
                    Spacer()
                    //Dummy Data
                    Chart(sunshineData) {
                        LineMark(
                            x: .value("Time", $0.date),
                            y: .value("Temperature", $0.hoursOfSunshine)
                        )
                        .foregroundStyle(.white)
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYAxis {
                        AxisMarks(stroke: StrokeStyle(lineWidth: 0))
                    }
                    .chartXAxis {
                        AxisMarks(stroke: StrokeStyle(lineWidth: 0))
                    }
                    //.frame(width: .infinity, height: 89)
                    
                    
                    Text("Live information")
                        .font(.caption)
                        .opacity(0.4)
                }
                
                .border(Color.red, width: 1)
            case .settings:
                Text("Connect to LumiFur to configure your settings here")
            }
        }
        //.ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.gray.gradient, for: .tabView)
        .border(Color.yellow, width: 1)
    }
    // Helper for status color (Optional)
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Connected": return .green
        case "Connecting...", "Reconnecting...": return .yellow
        case "Disconnected", "Inactive", "Deactivated", "Not Supported", "Not Activated": return .red
        default: return .gray // Handle "Connected (Not Reachable)" or others
        }
    }
    
    // Helper to check connection state
    private func isConnectedOrConnecting(_ status: String) -> Bool {
        return status == "Connected" || status.starts(with: "Connecting") || status.starts(with: "Connected (")
    }
}


struct ContentView: View {
    @State private var selected: Item? = .device
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        NavigationSplitView {
            // Primary view: a carousel-style list
            List(selection: $selected) { /* ... List items ... */ }
                .listStyle(.carousel) // Use carousel for watchOS top-level navigation
                .containerBackground(.white.gradient, for: .navigation)
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
