//
//  LumiFur_WidgetLiveActivity.swift
//  LumiFur Widget
//
//  Created by Stephan Ritchie on 2/12/25.
//  Copyright © (Richies 3D Ltd). All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI
import Charts


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
        var isConnected: Bool
        //var emoji: String
        // New: an array of recent temperature values (you could also send timestamps if needed)
        var temperatureChartData: [Double]
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LumiFur_WidgetLiveActivity: Widget {
    //@ObservedObject var accessoryViewModel = AccessoryViewModel()
    //@State var isConnected = false
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LumiFur_WidgetAttributes.self) { context in
            // Lock screen/banner UI
            VStack {
                HStack(spacing: 16) {
                    HStack {
                        Image("LumiFurFrontBottomSide")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: .infinity, alignment: .center)
                            //.padding(.horizontal)
                            //.border(Color.green, width: 1)
                            .mask { RoundedRectangle(cornerRadius: 13, style: .continuous) }
                            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    //currentViewGauge(selectedView: context.state.selectedView)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LumiFur Controller")
                            .frame(width: 150, alignment: .bottom)
                            .font(.system(.callout, weight: .semibold))
                            .padding(.leading, 10)
                        Text("LF-052618")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .clipped()
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(.leading, 10)
                            .multilineTextAlignment(.trailing)
                        HStack {
                            Spacer()
                                //.frame()
                                .clipped()
                            ZStack {
                                ContainerRelativeShape()
                                    .stroke(.clear.opacity(0), lineWidth: 0)
                                    .background(.ultraThinMaterial)
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                    .aspectRatio(1/1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    //.clipped()
                                LazyHGrid(rows: [GridItem(.flexible(), alignment: .center), GridItem(.flexible(), alignment: .center)]) {
                                    ForEach(0..<1) { _ in // Replace with your data model here
                                        Image(systemName: context.state.isConnected ? "antenna.radiowaves.left.and.right": "antenna.radiowaves.left.and.right.slash")
                                            .imageScale(.medium)
                                            .symbolRenderingMode(.hierarchical)
                                            .symbolEffect(.variableColor)
                                            .contentTransition(.symbolEffect(.replace))
                                    /*
                                        if #available(iOS 18.0, *) {
                                            .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                                        } else {
                                            .contentTransition(.symbolEffect(.replace))
                                        }
                                    */
                                        
                                            //.opacity(accessoryViewModel.isConnected ? 1 : 0.3)
                                        Image(systemName: "rotate.3d.circle.fill")
                                            .symbolRenderingMode(.hierarchical)
                                            .imageScale(.medium)
                                        Image(systemName: "eye.square.fill")
                                            .symbolRenderingMode(.hierarchical)
                                        Image(systemName: "microphone.square.fill")
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                    .aspectRatio(1/1, contentMode: .fit)
                                    .clipped()
                                }
                                //.shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(4)
                                .fixedSize(horizontal: false, vertical: false)
                            }
                            .frame(maxWidth: 150, maxHeight: 150)
                            //.clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .border(.green)
                    }
                    .background {
                        Group {
                            
                        }
                    }
                }
                Spacer()
                HStack {
                    Text(context.state.connectionStatus == "Connected" ? "Connected" : "Disconnected")
                            .foregroundStyle(context.state.connectionStatus == "Connected" ?
                                             Color.green : Color.red)
                            .font(.system(.footnote, weight: .semibold))
                            .padding(5)
                            .padding(.horizontal, 5)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(context.state.connectionStatus == "Connected" ? 
                                          Color.green.opacity(0.12) : Color.red.opacity(0.12))
                            }
                    //Spacer()
                    Text("Current View: \(context.state.selectedView)")
                        .foregroundStyle(Color(.orange))
                        .font(.system(.footnote, weight: .semibold))
                        .padding(5)
                        .padding(.horizontal, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.orange.opacity(0.12))
                        }
                    //Spacer()
                    Text("Options")
                        .foregroundStyle(Color(.blue))
                        .font(.system(.footnote, weight: .semibold))
                        .padding(5)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.blue.opacity(0.12))
                        }
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .padding(16)
            .activityBackgroundTint(Color(uiColor: .systemGray6))
            .activitySystemActionForegroundColor(Color.gray)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    //Text("LumiFur")
                    VStack {
                        /*
                        Text(context.state.connectionStatus == "Connected" ? "Connected" : "Disconnected")
                                    .lineLimit(1)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.center)
                                    .padding(2)
                                    .background(
                                        context.state.connectionStatus == "Connected" ?
                                            Color.green : Color.red
                                    )
                                    .clipShape(ContainerRelativeShape())
                            */
                        Image("LumiFur_Controller_AK_Compressed")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            //.frame(width: 40, height: 40)
                    }
                    
                    //Image cannot exceed 4kb
                    
                }
                DynamicIslandExpandedRegion(.center){
                    VStack {
                        
                        //.frame()
                            //.clipped()
                        ZStack {
                            ContainerRelativeShape()
                                .stroke(.clear.opacity(0), lineWidth: 0)
                                .background(.ultraThinMaterial)
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                .aspectRatio(1/1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            //.clipped()
                            LazyHGrid(rows: [GridItem(.flexible(), alignment: .center), GridItem(.flexible(), alignment: .center)]) {
                                ForEach(0..<1) { _ in // Replace with your data model here
                                    Image(systemName: context.state.isConnected ? "antenna.radiowaves.left.and.right": "antenna.radiowaves.left.and.right.slash")
                                        .imageScale(.medium)
                                        .symbolRenderingMode(.hierarchical)
                                        .symbolEffect(.variableColor)
                                        .contentTransition(.symbolEffect(.replace))
                                    /*
                                     if #available(iOS 18.0, *) {
                                     .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                                     } else {
                                     .contentTransition(.symbolEffect(.replace))
                                     }
                                     */
                                    
                                    //.opacity(accessoryViewModel.isConnected ? 1 : 0.3)
                                    Image(systemName: "rotate.3d.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .imageScale(.medium)
                                    Image(systemName: "eye.square.fill")
                                        .symbolRenderingMode(.hierarchical)
                                    Image(systemName: "microphone.square.fill")
                                        .symbolRenderingMode(.hierarchical)
                                }
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                .aspectRatio(1/1, contentMode: .fit)
                                .clipped()
                            }
                            //.shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                            //.frame(maxWidth: 50, maxHeight: 50)
                            .padding(4)
                            .fixedSize(horizontal: false, vertical: false)
                        }
                        .frame(maxWidth: 70, maxHeight: 70)
                        //.clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .border(.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(){
                            
                                /*
                                Text("LumiFur Controller")
                                    .frame(width: 150, alignment: .bottom)
                                    .font(.system(.callout, weight: .semibold))
                                    .padding(.leading, 10)
                                 */
                                Text("LF-052618")
                                    //.frame(maxWidth: .infinity, alignment: .trailing)
                                    .clipped()
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(.blue)
                                    .padding(.leading, 10)
                                    .multilineTextAlignment(.trailing)
                        VStack {
                            // Render a temperature chart if data is available
                                Chart {
                                    ForEach(Array(context.state.temperatureChartData.enumerated()), id: \.offset) { index, temperature in
                                        AreaMark(
                                            x: .value("Reading", index),
                                            y: .value("Temperature", temperature)
                                        )
                                        .interpolationMethod(.cardinal)
                                        .foregroundStyle(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.8),
                                                    Color.white.opacity(0.1)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    }}
                                //.id(accessoryViewModel.temperatureData.count)
                            
                                .animation(.easeInOut(duration: 0.5), value: context.state.temperatureChartData.count)
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
                                .chartYScale(domain: .automatic(includesZero: false))
                                .chartYAxis {
                                    AxisMarks(position: .leading, values: .automatic) { axisValue in
                                        AxisValueLabel {
                                            if let tempValue = axisValue.as(Int.self) {
                                                Text(String(tempValue))
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                             
                                .chartXAxis(.hidden)
                                .chartYAxis(.hidden)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(ContainerRelativeShape())
                                .frame(maxWidth:100,maxHeight: 70)
                                
                                Text("Temperature (°C)")
                                //.fontDesign( .default)
                                .font(.footnote)
                                .foregroundColor(Color.gray)
                                
                                //.bold()
                            }
                            //Text("Temp: \(context.state.temperature)")
                            //.font(.callout)
                        }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing:5) {
                        Spacer()
                        Text(context.state.connectionStatus == "Connected" ? "Connected" : "Disconnected")
                            .lineLimit(1)
                                .foregroundStyle(context.state.connectionStatus == "Connected" ?
                                                 Color.green : Color.red)
                                .font(.system(.footnote, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(5)
                                .padding(.horizontal, 5)
                                .background {
                                    ContainerRelativeShape()
                                        .fill(context.state.connectionStatus == "Connected" ?
                                              Color.green.opacity(0.12) : Color.red.opacity(0.12))
                                }
                                .fixedSize(horizontal: true, vertical: false) // Prevent horizontal truncation
                        //Spacer()
                        Text("View: \(context.state.selectedView)")
                            .lineLimit(1)
                            .foregroundStyle(Color(.orange))
                            .font(.system(.footnote, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(5)
                            .padding(.horizontal, 5)
                            .background {
                                ContainerRelativeShape()
                                    .fill(.orange.opacity(0.12))
                            }
                        //Spacer()
                        Text("Options")
                            .lineLimit(1)
                            .foregroundStyle(Color(.blue))
                            .font(.system(.footnote, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(5)
                            .padding(.horizontal, 5)
                            .background {
                                ContainerRelativeShape()
                                    .fill(.blue.opacity(0.12))
                            }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    //.clipped()
                }
            } compactLeading: {
                //Text("LumiFur")
                Image("LumiFur_Controller_AK_100")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
                    
                //Image("Protogen")
            } compactTrailing: {
                //Text("T")
                Image(context.state.isConnected ? "bluetooth.fill": "bluetooth.slash.fill")
                    //.symbolEffect(.appear)
                    .contentTransition(.symbolEffect(.replace))
                    
            } minimal: {
                //Text("m")
                Image("LumiFur_Controller_AK_Compressed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(.degrees(90))
                    .frame(width: 25, height: 25)
            }
            .widgetURL(URL(string: "https://www.richies.uk"))
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
        LumiFur_WidgetAttributes.ContentState(connectionStatus: "Connected", signalStrength: 75,  temperature: "47.7°C", selectedView: 4, isConnected: true, temperatureChartData: [45.33])
    }
    
    fileprivate static var starEyes: LumiFur_WidgetAttributes.ContentState {
        LumiFur_WidgetAttributes.ContentState(connectionStatus: "Disconnected", signalStrength: 80,  temperature: "58.7°C", selectedView: 6, isConnected: false, temperatureChartData: [67.33])
    }
}

/*
#Preview("Notification", as: .content, using: LumiFur_WidgetAttributes.preview) {
   LumiFur_WidgetLiveActivity()
}
*/

#Preview("Expanded", as: .dynamicIsland(.expanded), using: LumiFur_WidgetAttributes.preview) {
    LumiFur_WidgetLiveActivity()
}

/*
#Preview("compact", as: .dynamicIsland(.compact), using: LumiFur_WidgetAttributes.preview) {
    LumiFur_WidgetLiveActivity()
}
*/
/*
#Preview("minimal", as: .dynamicIsland(.minimal), using: LumiFur_WidgetAttributes.preview) {
    LumiFur_WidgetLiveActivity()
}
*/
contentStates: {
    LumiFur_WidgetAttributes.ContentState.smiley
    LumiFur_WidgetAttributes.ContentState.starEyes
}
