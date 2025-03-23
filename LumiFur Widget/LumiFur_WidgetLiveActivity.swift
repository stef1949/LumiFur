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
                                .frame()
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
                        currentViewGauge(selectedView: context.state.selectedView)
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
        LumiFur_WidgetAttributes.ContentState(connectionStatus: "Connected", signalStrength: 75,  temperature: "47.7°C", selectedView: 4, isConnected: true)
    }
    
    fileprivate static var starEyes: LumiFur_WidgetAttributes.ContentState {
        LumiFur_WidgetAttributes.ContentState(connectionStatus: "Disconnected", signalStrength: 80,  temperature: "58.7°C", selectedView: 6, isConnected: false)
    }
}

#Preview("Notification", as: .content, using: LumiFur_WidgetAttributes.preview) {
   LumiFur_WidgetLiveActivity()
}

contentStates: {
    LumiFur_WidgetAttributes.ContentState.smiley
    LumiFur_WidgetAttributes.ContentState.starEyes
}
