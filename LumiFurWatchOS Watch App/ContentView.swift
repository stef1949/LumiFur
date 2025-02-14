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
                        print("\(face) pressed")
                        // Add any additional action for selecting a face.
                    }) {
                        Text(face)
                            .font(.system(size: 40))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(8)
                            .cornerRadius(8)
                    }
                    .border(Color.green)
                    .backgroundStyle(.ultraThinMaterial)
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

    var body: some View {
        VStack {
            if item == .device {
                Image ("Image")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    //.padding(.bottom)
            }
            /*
            Text(item.rawValue.capitalized)
                .font(.headline)
                .padding(.bottom, 8)
            */
            
            // Example content – replace with your own controls or info.
            switch item {
            case .device:
                Button {
                    sendConnectCommand()
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
}

// MARK: - WatchConnectivity Command
func sendConnectCommand() {
    if WCSession.default.isReachable {
        WCSession.default.sendMessage(["command": "connectToDevice"],
                                      replyHandler: { response in
                                          print("Response from iOS: \(response)")
                                      },
                                      errorHandler: { error in
                                          print("Error sending command: \(error.localizedDescription)")
                                      })
    } else {
        print("iOS app is not reachable")
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
                           NavigationLink(item.rawValue.uppercased(), value: item)
                       }
                   }
                   .listStyle(.automatic)
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
    
    /// Sends a command message to the iOS app.
    func sendCommand(_ command: String) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["command": command],
                                          replyHandler: { response in
                print("Response from iOS: \(response)")
            },
                                          errorHandler: { error in
                print("Error sending message: \(error.localizedDescription)")
            })
        } else {
            print("iOS app is not reachable")
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
