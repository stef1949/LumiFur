//
//  LumiFur_Widget.swift
//  LumiFur Widget
//
//  Created by Stephan Ritchie on 2/12/25.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//

import WidgetKit
import SwiftUI
import Intents
import Charts

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> LumiFurEntry {
        LumiFurEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (LumiFurEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LumiFurEntry>) -> Void) {
        let entry = makeEntry()
        let nextDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextDate))
        completion(timeline)
    }
    
    // Helper function to read data from shared UserDefaults
    // Consolidated read + fallback logic
        private func makeEntry() -> LumiFurEntry {
        guard let defaults = UserDefaults(suiteName: SharedDataKeys.suiteName) else {
            print("Widget Provider: Cannot access shared defaults.")
            return LumiFurEntry.placeholder // Return placeholder on error
        }
        
        print("Widget Provider: Reading data from shared UserDefaults.")
                // Connection
        let isConnected = defaults.bool(forKey: SharedDataKeys.isConnected)
        let connectionStatus = defaults.string(forKey: SharedDataKeys.connectionStatus) ?? (isConnected ? "Connected" : "Disconnected")
                
                // Controller name fallback: primary key, then lastConnectedPeripheral
        let controllerName = defaults.string(forKey: SharedDataKeys.controllerName)
        ?? defaults.string(forKey: SharedDataKeys.controllerName)
                    ?? "Unknown Device"
            print(controllerName)
        // Temperature fallback: live string, then lastKnownTemperature
        let tempString = defaults.string(forKey: SharedDataKeys.temperature)
                let temperature: String
                if let t = tempString, !t.isEmpty {
                    temperature = t
                } else if let lastTemp = defaults.object(forKey: SharedDataKeys.temperatureHistory) {
                    temperature = String(format: "%.1f°C", lastTemp as! CVarArg)
                } else {
                    temperature = "--°C"
                }
        
        let signalStrength = defaults.integer(forKey: SharedDataKeys.signalStrength) // Defaults to 0 if not found
        
        // Selected view fallback
        let sel: Int? = defaults.object(forKey: SharedDataKeys.selectedView) as? Int
                let selectedView = sel ?? 1
        
        // Handle default values more gracefully
        let finalSignalStrength = defaults.object(forKey: SharedDataKeys.signalStrength) == nil ? -100 : signalStrength
        let finalSelectedView = defaults.object(forKey: SharedDataKeys.selectedView) == nil ? 1 : selectedView // Default to 1 maybe?
        
        // 1) Decode your [TemperatureDataPoint]
        var temperatureHistory: [TemperatureData] = [] // Use TemperatureData type
            if let data = defaults.data(forKey: SharedDataKeys.temperatureHistory) {
            do {
                temperatureHistory = try JSONDecoder().decode([TemperatureData].self, from: data) // Decode TemperatureData
                print("Widget Provider: Decoded \(temperatureHistory.count) temperature history points.")
            } catch {
                // Log the specific decoding error!
                print("🔴 WIDGET DECODING ERROR for \(SharedDataKeys.temperature): \(error)")
                    //temperatureHistory = [] // Fallback to empty on error
            }
        } else {
                print("Widget Provider: No data found for key \(SharedDataKeys.temperature)")
            }
        
        return LumiFurEntry(
            date: Date(),
            connectionStatus: connectionStatus,
            controllerName: controllerName,
            temperature: temperature,
            signalStrength: finalSignalStrength,
            selectedView: finalSelectedView,
            isConnected: isConnected,
            temperatureHistory: temperatureHistory // Pass the decoded [TemperatureData]
        )
    }
}

// MARK: - Timeline Entry
struct LumiFurEntry: TimelineEntry {
    let date: Date // Required
    let connectionStatus: String
    let controllerName: String?
    let temperature: String
    let signalStrength: Int
    let selectedView: Int
    let isConnected: Bool
    let temperatureHistory: [TemperatureData]
    
    // Placeholder data for previews and initial loading
    static var placeholder: LumiFurEntry {
        // Improved placeholder history for better chart preview
        let placeholderHistory: [TemperatureData] = (0..<20).map { index in
            let timeInterval = TimeInterval(-index * 300) // Points every 5 mins going back
            let timestamp = Date().addingTimeInterval(timeInterval)
            // Simulate some temperature variation
            let temperature = 20.0 + sin(Double(index) * 0.5) * 3.0 + Double.random(in: -0.5...0.5)
            return TemperatureData(timestamp: timestamp, temperature: temperature) // <-- Use TemperatureData init
                    }.reversed()
        
        return LumiFurEntry(date: Date(), connectionStatus: "Connecting...", controllerName: "LumiFur Device", temperature: "---°C", signalStrength: -75, selectedView: 1, isConnected: false, temperatureHistory: placeholderHistory)
    }
    // Sample data for snapshots (Unchanged)
    static var sample: LumiFurEntry {
        LumiFurEntry(date: Date(), connectionStatus: "Connected", controllerName: "LF-052618", temperature: "24.5°C", signalStrength: -60, selectedView: 3, isConnected: true, temperatureHistory: [
            .init(timestamp: Date().addingTimeInterval(-7200), temperature: 18.0),
                        .init(timestamp: Date().addingTimeInterval(-5400), temperature: 19.5),
                        .init(timestamp: Date().addingTimeInterval(-3600), temperature: 22.0),
                        .init(timestamp: Date().addingTimeInterval(-1800), temperature: 24.0),
                        .init(timestamp: Date().addingTimeInterval(-600), temperature: 25.5),
                        .init(timestamp: Date(), temperature: 24.5)
                    ])
    }
}



// MARK: - Widget View
struct LumiFur_WidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family // To adapt layout based on size
    
    var body: some View {
        // Use a switch to provide different layouts for different sizes
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
            //case .systemExtraLarge:
            //  ExtraLargeWidgetView(entry: entry)
        default:
            // Default or fallback view (medium)
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Specific Size Views (Examples)

struct SmallWidgetView: View {
    var entry: LumiFurEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(entry.connectionStatus)
                    .font(.caption)
                    .foregroundColor(entry.isConnected ? .primary : .gray)
            } icon: {
                Image(entry.isConnected ? "bluetooth.fill" : "bluetooth.slash.fill")
                    .foregroundColor(entry.isConnected ? .blue : .gray)
                    .frame(width:10)
            }
            
            Text(entry.controllerName ?? "No Controller")
                .font(.footnote)
                .lineLimit(1)
                .foregroundColor(entry.isConnected ? .primary : .secondary)
            
            Spacer()
            
            Label {
                Text(entry.temperature)
            } icon: {
                Image(systemName: "thermometer")
                    .symbolRenderingMode(.hierarchical)
                    .frame(width:10)
            }

            Label {
                Text("View: \(entry.selectedView)")
            } icon: {
                Image(systemName: "display")
                    .frame(width:10)
            }
            
            Spacer()
            
            Label {
                Text("\(entry.signalStrength) dBm")
                    .foregroundColor(signalStrengthColor(rssi: entry.signalStrength))
                    .font(.caption)
            } icon: {
                Image(systemName: signalStrengthIcon(rssi: entry.signalStrength))
                    .foregroundColor(signalStrengthColor(rssi: entry.signalStrength))
                    .imageScale(.small)
                    .frame(width:10)
            }
        }
        .padding(10)
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
        //.border(Color.gray.opacity(0.2), width: 1)
    }
}

struct MediumWidgetView: View {
    var entry: LumiFurEntry
    
    var body: some View {
        HStack(spacing: 15) {
            // Left Column (Status)
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text(entry.connectionStatus)
                        .font(.headline)
                        .foregroundColor(entry.isConnected ? .primary : .secondary)
                        .offset(x: -6)
                } icon: {
                    Image(systemName: entry.isConnected ? "link.circle.fill" : "link.circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(entry.isConnected ? .green : .gray)
                        .imageScale(.large)
                }
                
                Text(entry.controllerName ?? "No Controller Connected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                HStack {
                    VStack(alignment: .leading) {
                        Label(entry.temperature, systemImage: "thermometer")
                        Label("\(entry.selectedView)", systemImage: "display")
                    }
                    .font(.footnote)
                    .frame(width: 70)
                    //.border(.gray)
                    
                    VStack {
                        Spacer()
                        Image(systemName: signalStrengthIcon(rssi: entry.signalStrength))
                            .foregroundColor(signalStrengthColor(rssi: entry.signalStrength))
                            .scaleEffect(1.5)
                        
                        Text("\(entry.signalStrength) dBm")
                            .foregroundColor(signalStrengthColor(rssi: entry.signalStrength))
                    }
                    .font(.caption)
                    .frame(width: 50)
                    //.border(.gray)
                    
                }
            }
            //.border(.red)
            //.padding(.trailing, 5)
            
            
            // Right Column (Maybe a Chart or Gauge?) - Placeholder for now
            VStack {
                Spacer()
                Image("mps3")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.25)
                    //.rotationEffect(.degrees(90))
                 
                Spacer()
                // --- INTERACTIVE BUTTON ---
                Button(intent: ChangeLumiFurViewIntent()) { // Create instance of the intent
                    Label("Next View", systemImage: "arrow.right.circle")
                }
                .tint(.blue) // Style the button
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    }
}
struct LargeWidgetView: View {
    var entry: LumiFurEntry
    
    var body: some View {
        HStack(spacing: 15) {
            // Left Column (Status)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: entry.isConnected ? "link.circle.fill" : "link.circle")
                        .foregroundColor(entry.isConnected ? .green : .gray)
                        .imageScale(.large)
                    Text(entry.connectionStatus)
                        .font(.headline)
                        .foregroundColor(entry.isConnected ? .primary : .secondary)
                }
                Text(entry.controllerName ?? "No Controller Connected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Chart {
                    ForEach(entry.temperatureHistory, id: \.timestamp) { element in
                        let _ = print("Charting point: Time=\(element.timestamp), Temp=\(element.temperature)")
                        LineMark(
                            x: .value("Time", element.timestamp),
                            y: .value("Temperature", element.temperature)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue, Color.orange, Color.orange]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            )
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                }
                //.id(accessoryViewModel.temperatureData.count)
                .animation(.easeInOut(duration: 0.5), value: entry.temperatureHistory)
                .chartYScale(domain: .automatic) // Adjust the domain to your expected temperature range.
                .chartXAxis {
                    AxisMarks(values: .automatic) { axisValue in
                        AxisValueLabel() {
                            if let tempValue = axisValue.as(Double.self) {
                                Text(String(format: "%.1f°C", tempValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis { // Simplified Y Axis
                    AxisMarks(preset: .automatic, values: .automatic) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let temp = value.as(Double.self) {
                                Text(String(format: "%.0f°", temp)) // Format as integer degree
                            }
                        }
                    }
                }
                .padding(.vertical)
                .padding(.leading, 10)
                .padding(.trailing, 5)

                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth:500,maxHeight: .infinity)
                .padding(.vertical,5)
                VStack(alignment: .leading, spacing: 10) {
                    Label(entry.temperature, systemImage: "thermometer")
                        .font(.caption)
                        .symbolRenderingMode(.hierarchical)
                    Label("View: \(entry.selectedView)", systemImage: "display")
                        .font(.headline)
                        .symbolRenderingMode(.hierarchical)
                }
                .fixedSize(horizontal: true, vertical: false)
                .lineLimit(1)
                .allowsTightening(false)
                .padding(.bottom)
                
                HStack {
                    Image(systemName: signalStrengthIcon(rssi: entry.signalStrength))
                        .foregroundColor(signalStrengthColor(rssi: entry.signalStrength))
                    Text("Signal: \(entry.signalStrength) dBm")
                        .foregroundColor(signalStrengthColor(rssi: entry.signalStrength))
                }
                .font(.caption)
                
            }
            .padding(.trailing, 5)
            
            
            // Right Column (Maybe a Chart or Gauge?) - Placeholder for now
            VStack {
                Spacer()
                Image("mps3")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.2)
                Spacer()
                // --- INTERACTIVE BUTTON ---
                Button(intent: ChangeLumiFurViewIntent()) { // Create instance of the intent
                    Label("Next View", systemImage: "arrow.right.circle")
                }
                .tint(.blue) // Style the button
                // Add Chart here if desired using entry.temperatureChartData
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    }
}
/*
 struct ExtraLargeWidgetView: View {
 var entry: LumiFurEntry
 
 var body: some View {
 HStack(spacing: 15) {
 // Left Column (Status)
 VStack(alignment: .leading, spacing: 4) {
 HStack {
 Image(systemName: entry.isConnected ? "link.circle.fill" : "link.circle")
 .foregroundColor(entry.isConnected ? .green : .gray)
 .imageScale(.large)
 Text(entry.connectionStatus)
 .font(.headline)
 .foregroundColor(entry.isConnected ? .primary : .secondary)
 }
 Text(entry.controllerName ?? "No Controller Connected")
 .font(.subheadline)
 .foregroundColor(.secondary)
 .lineLimit(1)
 Chart {
 ForEach(entry.temperatureHistory, id: \.timestamp) { element in
 LineMark(
 x: .value("Time", element.timestamp),
 y: .value("Temperature", element.temperature)
 )
 //.foregroundStyle(.red) // Change to blue if preferred.
 .lineStyle(StrokeStyle(lineWidth: 2))
 
 }
 }
 //.id(accessoryViewModel.temperatureData.count)
 .animation(.easeInOut(duration: 0.5), value: entry.temperatureHistory)
 .chartYScale(domain: 15...85) // Adjust the domain to your expected temperature range.
 .chartXAxis {
 AxisMarks(values: .automatic) { axisValue in
 AxisValueLabel() {
 if let tempValue = axisValue.as(Double.self) {
 Text(String(format: "%.1f°C", tempValue))
 .font(.caption2)
 }
 }
 }
 }
 .chartYAxis {
 AxisMarks(position: .leading, values: .stride(by: 25)) { axisValue in
 AxisValueLabel() {
 if let tempValue = axisValue.as(Int.self) {
 Text(String(tempValue))
 .font(.caption2)
 }
 }
 }
 }
 .padding()
 .background(.ultraThinMaterial)
 .clipShape(RoundedRectangle(cornerRadius: 10))
 .frame(maxWidth:500,maxHeight: .infinity)
 .padding(.vertical,5)
 VStack(spacing: 10) {
 Label(entry.temperature, systemImage: "thermometer")
 .font(.caption)
 Label("View: \(entry.selectedView)", systemImage: "display")
 .font(.headline)
 }
 .fixedSize(horizontal: true, vertical: false)
 .lineLimit(1)
 .allowsTightening(false)
 .padding(.bottom)
 
 HStack {
 Image(systemName: signalStrengthIcon(rssi: entry.signalStrength))
 .foregroundColor(signalStrengthColor(rssi: entry.signalStrength))
 Text("Signal: \(entry.signalStrength) dBm")
 .foregroundColor(signalStrengthColor(rssi: entry.signalStrength))
 }
 .font(.caption)
 
 }
 .padding(.trailing, 5)
 
 
 // Right Column (Maybe a Chart or Gauge?) - Placeholder for now
 VStack {
 Spacer()
 Image("LumiFur_Controller_AK_Compressed")
 .resizable()
 .scaledToFit()
 .scaleEffect(2)
 Spacer()
 // --- INTERACTIVE BUTTON ---
 Button(intent: ChangeLumiFurViewIntent()) { // Create instance of the intent
 Label("Next View", systemImage: "arrow.right.circle")
 }
 .tint(.blue) // Style the button
 // Add Chart here if desired using entry.temperatureChartData
 }
 }
 .padding()
 .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
 }
 }
 */

struct circleView: View {
    var body: some View {
        Circle()
            .stroke(Color.blue, lineWidth: 1)
            .frame(width: 100, height: 100)
    }
}
// Helper functions for Icons/Colors (can be placed outside views)
func signalStrengthIcon(rssi: Int) -> String {
    switch rssi {
    case -60...0: return "wifi" // Strong
    case -75 ..< -60: return "wifi.exclamationmark" // Medium
    case -90 ..< -75: return "wifi.slash" // Weak
    default: return "wifi.slash" // Very Weak or Unknown
    }
}

func signalStrengthColor(rssi: Int) -> Color {
    switch rssi {
    case -60...0: return .green
    case -75 ..< -60: return .orange
    case -90 ..< -75: return .red
    default: return .gray
    }
}


// MARK: - Widget Definition
struct LumiFur_Widget: Widget {
    static let kind = SharedDataKeys.widgetKind
        var body: some WidgetConfiguration {
            StaticConfiguration(kind: Self.kind, provider: Provider()) { entry in
                LumiFur_WidgetEntryView(entry: entry)
            }
            .configurationDisplayName("LumiFur Status")
            .description("Monitor your LumiFur device connection and status.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        }
    }

// MARK: - Previews (For SwiftUI Canvas) (Using improved placeholder)
struct LumiFur_Widget_Previews: PreviewProvider {
    static var previews: some View {
        // Preview for Small
        LumiFur_WidgetEntryView(entry: LumiFurEntry.sample)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small Widget")
        
        // Preview for Medium
        LumiFur_WidgetEntryView(entry: LumiFurEntry.sample)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium Widget")
        
        // Preview for Large
        LumiFur_WidgetEntryView(entry: LumiFurEntry.sample)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large Widget")
        /*
         // Preview for Extra Large (Not supported on iOS)
         LumiFur_WidgetEntryView(entry: LumiFurEntry.placeholder)
         .previewContext(WidgetPreviewContext(family: .systemExtraLarge))
         .previewDisplayName("Extra Large Widget")
         */
    }
}

