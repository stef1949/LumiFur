//
//  LumiFur_WidgetLiveActivity.swift
//  LumiFur Widget
//
//  Created by Stephan Ritchie on 2/12/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StyledGauge: View {
    let temperature: Double
    @State private var current = 47.0
    @State private var minValue = 15.0
    @State private var maxValue = 70.0
    let gradient = Gradient(colors: [.green, .yellow, .orange, .red])


    var body: some View {
        Gauge(value: temperature, in: minValue...maxValue) {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
        } currentValueLabel: {
            Text("\(Int(temperature))")
                .foregroundColor(Color.green)
        } minimumValueLabel: {
            Text("\(Int(minValue))")
                .foregroundColor(Color.green)
        } maximumValueLabel: {
            Text("\(Int(maxValue))")
                .foregroundColor(Color.red)
        }
        .gaugeStyle(.accessoryCircular)
        
    }
}

struct GaugeUnit: View {
    let temperature: Double = 47.0
    var body: some View {
        VStack {
            StyledGauge(temperature: temperature)
            Text("Gauge")
                .font(.system(size: 10))
                .offset(y: -5)
                
        }
        //.padding()
    }
}

struct currentViewGauge: View {
    let selectedView: Int  // Pass in the selected view value
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 50, height: 50)
                .foregroundStyle(.secondary)
            Text("\(selectedView)")
        }
    }
}


struct LumiFur_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var connectionStatus: String
        var signalStrength: Int
        var temperature: String
        var selectedView: Int
        //var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LumiFur_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LumiFur_WidgetAttributes.self) { context in
            // Lock screen/banner UI
            HStack {
                VStack {
                    Text("LumiFur")
                        .font(.title)
                        .fontDesign(.monospaced)
                        .padding([.top, .leading, .trailing])
                        .border(Color.red, width: 1)
                    Image("LumiFurFrontSymbol")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90, height: 90)
                        .padding(.horizontal)
                        .border(Color.green, width: 1)
                    Spacer()
                }
                
                Spacer()
                
                currentViewGauge(selectedView: context.state.selectedView)
                
                Spacer()
                
                VStack(spacing: 4) {
                        GaugeUnit()
                        GaugeUnit()
                }
                .padding(.top, 5.0)
                .padding()
                
                /*
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Temp: \(context.state.temperature)")
                        .font(.caption)
                    Text("Signal: \(context.state.signalStrength)%")
                        .font(.caption2)
                }
                 .padding()
                 */
                
            }
            .activityBackgroundTint(Color(uiColor: .systemGray6))
            .activitySystemActionForegroundColor(Color.gray)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    //Text("LumiFur")
                    VStack {
                        Spacer()
                        Text(context.state.connectionStatus == "Connected" ? "Connected" : "Disconnected")
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.center)
                                    .padding(2)
                                    .background(
                                        context.state.connectionStatus == "Connected" ?
                                            Color.green : Color.red
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                        Image(systemName:"aqi.medium")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    }
                    
                    //Image cannot exceed 4kb
                    
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack{
                        Spacer()
                        Text("Current View")
                        Text("Temp: \(context.state.temperature)")
                                                    .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("LumiFur")
                    // more content
                }
            } compactLeading: {
                //Text("LumiFur")
                Image("LumiFurFrontSymbol")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    
                //Image("Protogen")
            } compactTrailing: {
                //Text("T")
                Image("bluetooth.fill")
            } minimal: {
                //Text("m")
                Image("LumiFurFrontSymbol")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.white)
        }
    }
}

extension LumiFur_WidgetAttributes {
    fileprivate static var preview: LumiFur_WidgetAttributes {
        LumiFur_WidgetAttributes(name: "LumiFur")
    }
}

extension LumiFur_WidgetAttributes.ContentState {
    fileprivate static var smiley: LumiFur_WidgetAttributes.ContentState {
        LumiFur_WidgetAttributes.ContentState(connectionStatus: "Connected", signalStrength: 75,  temperature: "47.7°C", selectedView: 4)
    }
    
    fileprivate static var starEyes: LumiFur_WidgetAttributes.ContentState {
        LumiFur_WidgetAttributes.ContentState(connectionStatus: "Connected", signalStrength: 80,  temperature: "58.7°C", selectedView: 6)
    }
}

#Preview("Notification", as: .content, using: LumiFur_WidgetAttributes.preview) {
   LumiFur_WidgetLiveActivity()
} contentStates: {
    LumiFur_WidgetAttributes.ContentState.smiley
    LumiFur_WidgetAttributes.ContentState.starEyes
}
