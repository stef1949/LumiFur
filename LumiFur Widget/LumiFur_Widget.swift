//
//  LumiFur_Widget.swift
//  LumiFur Widget
//
//  Created by Stephan Ritchie on 2/12/25.
//

import WidgetKit
import SwiftUI
import Intents // If using configuration intents later


// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    // Provides a placeholder view for the widget gallery.
    func placeholder(in context: Context) -> LumiFurEntry {
        LumiFurEntry.placeholder
    }
    
    // Provides a snapshot entry for transient situations (e.g., gallery preview).
    func getSnapshot(in context: Context, completion: @escaping (LumiFurEntry) -> ()) {
        let entry = readDataFromUserDefaults()
        completion(entry)
    }
    
    // Provides the timeline (entries with dates) for the widget.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = readDataFromUserDefaults()
        
        // Determine the next update time (e.g., 15 minutes from now)
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        
        // Create a timeline with the single current entry and the reload policy
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    // Helper function to read data from shared UserDefaults
    private func readDataFromUserDefaults() -> LumiFurEntry {
        guard let defaults = UserDefaults(suiteName: SharedDataKeys.suiteName) else {
            print("Widget Provider: Cannot access shared defaults.")
            return LumiFurEntry.placeholder // Return placeholder on error
        }
        
        print("Widget Provider: Reading data from shared UserDefaults.")
        let isConnected = defaults.bool(forKey: SharedDataKeys.isConnected)
        let connectionStatus = defaults.string(forKey: SharedDataKeys.connectionStatus) ?? "Unknown"
        let controllerName = defaults.string(forKey: SharedDataKeys.controllerName) // Can be nil
        let temperature = defaults.string(forKey: SharedDataKeys.temperature) ?? "--°C"
        let signalStrength = defaults.integer(forKey: SharedDataKeys.signalStrength) // Defaults to 0 if not found
        let selectedView = defaults.integer(forKey: SharedDataKeys.selectedView) // Defaults to 0
        
        // Handle default values more gracefully
        let finalSignalStrength = defaults.object(forKey: SharedDataKeys.signalStrength) == nil ? -100 : signalStrength
        let finalSelectedView = defaults.object(forKey: SharedDataKeys.selectedView) == nil ? 1 : selectedView // Default to 1 maybe?
        
        // Optional: Read chart data
        // let chartData = defaults.array(forKey: SharedDataKeys.temperatureChartData) as? [Double] ?? []
        
        
        return LumiFurEntry(
            date: Date(),
            connectionStatus: connectionStatus,
            controllerName: controllerName,
            temperature: temperature,
            signalStrength: finalSignalStrength,
            selectedView: finalSelectedView,
            isConnected: isConnected
            // temperatureChartData: chartData
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
    // let temperatureChartData: [Double]
    
    // Placeholder data for previews and initial loading
    static var placeholder: LumiFurEntry {
        LumiFurEntry(date: Date(), connectionStatus: "Connecting...", controllerName: "LumiFur Device", temperature: "---°C", signalStrength: -75, selectedView: 1, isConnected: false/*, temperatureChartData: [20, 22, 21, 23, 25]*/)
    }
    // Sample data for snapshots
    static var sample: LumiFurEntry {
        LumiFurEntry(date: Date(), connectionStatus: "Connected", controllerName: "LumiFur Max", temperature: "24.5°C", signalStrength: -60, selectedView: 3, isConnected: true/*, temperatureChartData: [20, 22, 21, 23, 25]*/)
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
            HStack {
                Image(systemName: entry.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(entry.isConnected ? .green : .gray)
                Text(entry.connectionStatus)
                    .font(.caption)
                    .foregroundColor(entry.isConnected ? .green : .gray)
            }
            Text(entry.controllerName ?? "No Controller")
                .font(.footnote)
                .lineLimit(1)
                .foregroundColor(entry.isConnected ? .primary : .secondary)
            
            Spacer()
            
            HStack {
                Image(systemName: "thermometer")
                Text(entry.temperature)
            }
            .font(.title3)
            .minimumScaleFactor(0.7)
            
            HStack {
                Image(systemName: signalStrengthIcon(rssi: entry.signalStrength))
                    .foregroundColor(signalStrengthColor(rssi: entry.signalStrength))
                Text("View: \(entry.selectedView)")
            }
            .font(.caption)
            
        }
        .padding(10)
        // Use .widgetBackground modifier for background color (iOS 17+)
        .widgetBackground(backgroundView: Color(UIColor.systemBackground))
    }
}

struct MediumWidgetView: View {
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
                
                Spacer()
                
                HStack(spacing: 15) {
                    Label(entry.temperature, systemImage: "thermometer")
                    Label("View: \(entry.selectedView)", systemImage: "display")
                }
                .font(.footnote)
                
                
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
                    .rotationEffect(.degrees(90))
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
        .widgetBackground(backgroundView: Color(UIColor.systemBackground))
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
                
                Spacer()
                
                HStack(spacing: 15) {
                    Label(entry.temperature, systemImage: "thermometer")
                    Label("View: \(entry.selectedView)", systemImage: "display")
                }
                .font(.footnote)
                
                
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
        .widgetBackground(backgroundView: Color(UIColor.systemBackground))
    }
}
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

// Extension for widget background modifier (makes code cleaner)
extension View {
    func widgetBackground(backgroundView: some View) -> some View {
        if #available(iOS 17.0, *) { // Check availability for containerBackground
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
    }
}


// MARK: - Widget Definition
struct LumiFur_Widget: Widget {
    // Unique identifier for this widget kind
    static let kind: String = "com.richies3d.lumifur.statuswidget" // <<< Use a unique string
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:LumiFur_Widget.kind, provider: Provider()) { entry in
            LumiFur_WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("LumiFur Status")
        .description("Monitor your LumiFur device connection and status.")
        .supportedFamilies([.systemSmall, .systemMedium]) // Choose supported sizes
        //.contentMarginsDisabled() // Potentially better button placement
    }
}

// MARK: - Widget Bundle (If you have multiple widgets)
/*
 @main
 struct LumiFurWidgets: WidgetBundle {
 var body: some Widget {
 LumiFurWidget()
 // Add other widgets here if you create more
 // AnotherWidget()
 }
 }
 */

// MARK: - Previews (For SwiftUI Canvas)
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
    }
}
