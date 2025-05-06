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

// MARK - Template data
struct MonthlyHoursOfSunshine: Identifiable {
    var id: Date { date } // Using the date as a unique identifier
    var date: Date
    var templateTemp: Double
    
    
    init(month: Int, templateTemp: Double) {
        let calendar = Calendar.autoupdatingCurrent
        self.date = calendar.date(from: DateComponents(year: 2020, month: month))!
        self.templateTemp = templateTemp
    }
}
//Dummy data
let sunshineData: [MonthlyHoursOfSunshine] = [
    MonthlyHoursOfSunshine(month: 1, templateTemp: 17),
    MonthlyHoursOfSunshine(month: 2, templateTemp: 18),
    MonthlyHoursOfSunshine(month: 3, templateTemp: 18),
    MonthlyHoursOfSunshine(month: 4, templateTemp: 21),
    MonthlyHoursOfSunshine(month: 5, templateTemp: 34),
    MonthlyHoursOfSunshine(month: 6, templateTemp: 42),
    MonthlyHoursOfSunshine(month: 7, templateTemp: 47),
    MonthlyHoursOfSunshine(month: 8, templateTemp: 52),
    MonthlyHoursOfSunshine(month: 9, templateTemp: 51),
    MonthlyHoursOfSunshine(month: 10, templateTemp: 51),
    MonthlyHoursOfSunshine(month: 11, templateTemp: 51),
    MonthlyHoursOfSunshine(month: 12, templateTemp: 52)
]
// MARK: - Face Grid View
struct FaceGridView: View {
    // The grid of face icons – same as your iOS protoActionOptions.
    let faces: [String] = ["", "🏳️‍⚧️", "🌈", "🙂", "😳", "😎", "☠️"]
    
    // Define a two-column grid.
    let columns: [GridItem] = [GridItem(.adaptive(minimum: 50, maximum: 100))]
    
    @State private var selectedFace: String? = nil
    
    var body: some View {
        
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(faces, id: \.self) { face in
                    Button(action: {
                        selectedFace = face
                        // Play system haptic (and sound, if available)
                        WKInterfaceDevice.current().play(.start)
                        print("\(face) pressed - sending command...")
                        // Uses  WatchConnectivityManager to send the selected face
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
                            .font(.system(size: 30))
                    }
                    .background {
                        if selectedFace == face {
                            Rectangle()
                                .fill(Color.white)
                        } else {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(15)
                }
            }
            //.backgroundStyle(.ultraThinMaterial)
            //.padding()
        }
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
                }
                // Optional: Add a Disconnect button when connected
                else if connectivityManager.connectionStatus == "Connected" {
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
                    .tint(.red) // Make disconnect button red
                    //.padding(.top, 5)
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
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius:(8)))
                            Spacer()
                        }.environment(\.colorScheme, .light)
                            .offset(y: 20)
                    }
                }
            case .status:
                VStack {
                    //Spacer(minLength: 40)
                    // Nicer watchOS chart for sunshine data
                    Chart {
                        ForEach(sunshineData) { data in
                            // Light fill under the curve
                            AreaMark(
                                x: .value("Month", data.date),
                                y: .value("Sunshine (h)", data.templateTemp)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.05)]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            // Crisp line on top
                            LineMark(
                                x: .value("Month", data.date),
                                y: .value("Sunshine (h)", data.templateTemp)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.green]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                        }
                        // Highlight the latest point with trailing annotation
                        if let last = sunshineData.last {
                            PointMark(
                                x: .value("Month", last.date),
                                y: .value("Sunshine (h)", last.templateTemp)
                            )
                            .symbolSize(20)
                            .annotation(position: .trailing) {
                                Text("\(last.templateTemp.formatted())℃")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .chartXAxis {
                       // AxisMarks(values: .stride(by: .month)) { mark in
                          //  AxisGridLine()
                          //  AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                          //      .font(.caption2)
                       // }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine()
                        }
                    }
                    .chartPlotStyle { plotArea in
                        plotArea
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    .frame(height: 120)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    
                    Text("Temperature ")
                        .font(.caption2)
                        .opacity(0.6)
                }
            case .settings:
                
                if !isConnectedOrConnecting(connectivityManager.connectionStatus) {
                    Text("Connect to LumiFur to configure your settings here")
                        .listItemTint(.clear)
                }
                List{
                    Toggle("Auto Brightness", isOn: $autoBrightness)
                        .onChange(of: !autoBrightness) { newValue, _ in
                            sendMessage(["autoBrightness": newValue])
                        }
                        .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                    Toggle("Accelerometer", isOn: $accelerometer)
                        .onChange(of: !accelerometer) { newValue, _ in
                            sendMessage(["accelerometer": newValue])
                        }
                        .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                    Toggle("Sleep Mode", isOn: $sleepMode)
                        .onChange(of: !sleepMode) { newValue, _ in
                            sendMessage(["sleepMode": newValue])
                        }
                        .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                    Toggle("Aroura Mode", isOn: $arouraMode)
                        .onChange(of: !arouraMode) { newValue, _ in
                            sendMessage(["arouraMode": newValue])
                        }
                        .disabled(!isConnectedOrConnecting(connectivityManager.connectionStatus))
                }
                .onAppear {
                    // Ensure WCSession is activated
                    _ = WatchConnectivityManager.shared
                }
                .listStyle(.carousel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.gray.gradient, for: .tabView)
        //.border(Color.yellow, width: 1)
        .containerBackground(.green.gradient, for: .navigation)
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
